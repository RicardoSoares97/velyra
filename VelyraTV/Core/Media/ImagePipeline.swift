import Foundation
import ImageIO
import SwiftUI
import UIKit

private final class ImageMemoryCache: @unchecked Sendable {
  let storage = NSCache<NSString, UIImage>()
  init() {
    storage.countLimit = 160
    storage.totalCostLimit = 160 * 1024 * 1024
  }
}

actor ImagePipeline {
  static let shared = ImagePipeline()

  private static let maximumDownloadSize = 25 * 1024 * 1024
  private let memory = ImageMemoryCache()
  private let session: URLSession
  private var inFlight: [String: Task<UIImage, Error>] = [:]

  init(session: URLSession? = nil) {
    if let session {
      self.session = session
    } else {
      let configuration = URLSessionConfiguration.default
      configuration.urlCache = URLCache(
        memoryCapacity: 32 * 1024 * 1024,
        diskCapacity: 512 * 1024 * 1024
      )
      configuration.requestCachePolicy = .returnCacheDataElseLoad
      configuration.timeoutIntervalForRequest = 20
      configuration.waitsForConnectivity = true
      self.session = URLSession(configuration: configuration)
    }
  }

  func image(for url: URL, targetSize: CGSize, scale: CGFloat = 1) async throws -> UIImage {
    let pixelSize = max(targetSize.width, targetSize.height) * scale
    let key = "\(url.absoluteString)|\(Int(pixelSize))"
    if let cached = memory.storage.object(forKey: key as NSString) { return cached }
    if let task = inFlight[key] { return try await task.value }

    let task = Task<UIImage, Error> { [session, memory] in
      var request = URLRequest(url: url)
      request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        throw URLError(.badServerResponse)
      }
      if let mimeType = http.mimeType, !mimeType.lowercased().hasPrefix("image/") {
        throw URLError(.cannotDecodeContentData)
      }
      guard data.count <= Self.maximumDownloadSize else {
        throw URLError(.dataLengthExceedsMaximum)
      }
      let image = try Self.downsample(data: data, maximumPixelSize: pixelSize)
      let decodedCost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? data.count
      memory.storage.setObject(image, forKey: key as NSString, cost: decodedCost)
      return image
    }
    inFlight[key] = task
    defer { inFlight.removeValue(forKey: key) }
    return try await task.value
  }

  func clearMemory() { memory.storage.removeAllObjects() }

  func clearAll() {
    memory.storage.removeAllObjects()
    session.configuration.urlCache?.removeAllCachedResponses()
    for task in inFlight.values {
      task.cancel()
    }
    inFlight.removeAll()
  }

  private static func downsample(data: Data, maximumPixelSize: CGFloat) throws -> UIImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      throw URLError(.cannotDecodeContentData)
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maximumPixelSize)),
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else {
      throw URLError(.cannotDecodeContentData)
    }
    return UIImage(cgImage: cgImage)
  }
}

@MainActor
final class RemoteImageLoader: ObservableObject {
  enum State {
    case idle
    case loading
    case loaded(Image)
    case failed
  }

  @Published private(set) var state: State = .idle
  private var task: Task<Void, Never>?

  deinit { task?.cancel() }

  func load(url: URL?, targetSize: CGSize) {
    task?.cancel()
    guard let url else {
      state = .failed
      return
    }
    state = .loading
    task = Task { [weak self] in
      do {
        let image = try await ImagePipeline.shared.image(for: url, targetSize: targetSize)
        guard !Task.isCancelled else { return }
        self?.state = .loaded(Image(uiImage: image))
      } catch {
        guard !Task.isCancelled else { return }
        self?.state = .failed
      }
    }
  }
}

struct CachedRemoteImage<Placeholder: View>: View {
  let url: URL?
  let targetSize: CGSize
  let contentMode: ContentMode
  let placeholder: Placeholder
  @StateObject private var loader = RemoteImageLoader()

  init(
    url: URL?,
    targetSize: CGSize,
    contentMode: ContentMode = .fill,
    @ViewBuilder placeholder: () -> Placeholder
  ) {
    self.url = url
    self.targetSize = targetSize
    self.contentMode = contentMode
    self.placeholder = placeholder()
  }

  var body: some View {
    Group {
      if case .loaded(let image) = loader.state {
        image
          .resizable()
          .aspectRatio(contentMode: contentMode)
      } else {
        placeholder
      }
    }
    .task(id: CachedImageRequest(url: url, targetSize: targetSize)) {
      loader.load(url: url, targetSize: targetSize)
    }
  }
}

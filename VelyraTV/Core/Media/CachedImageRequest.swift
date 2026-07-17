import Foundation

struct CachedImageRequest: Hashable, Sendable {
  let url: URL?
  let targetSize: CGSize

  static func == (lhs: CachedImageRequest, rhs: CachedImageRequest) -> Bool {
    lhs.url == rhs.url
      && lhs.targetSize.width == rhs.targetSize.width
      && lhs.targetSize.height == rhs.targetSize.height
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
    hasher.combine(targetSize.width)
    hasher.combine(targetSize.height)
  }
}

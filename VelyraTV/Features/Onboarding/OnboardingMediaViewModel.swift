import Foundation
import SwiftUI

protocol OnboardingImagePrefetching: Sendable {
  func prefetch(_ url: URL) async -> Bool
}

struct DefaultOnboardingImagePrefetcher: OnboardingImagePrefetching {
  func prefetch(_ url: URL) async -> Bool {
    do {
      _ = try await ImagePipeline.shared.image(
        for: url,
        targetSize: CGSize(width: 1920, height: 1080)
      )
      return true
    } catch {
      return false
    }
  }
}

@MainActor
final class OnboardingMediaViewModel: ObservableObject {
  @Published private(set) var items: [OnboardingMediaItem] = []

  private let repository: any OnboardingMediaProviding
  private let prefetcher: any OnboardingImagePrefetching
  private var task: Task<Void, Never>?

  init(
    repository: any OnboardingMediaProviding = TMDBOnboardingMediaRepository(),
    prefetcher: any OnboardingImagePrefetching = DefaultOnboardingImagePrefetcher()
  ) {
    self.repository = repository
    self.prefetcher = prefetcher
  }

  deinit {
    task?.cancel()
  }

  func load(language: String, region: String) async {
    task?.cancel()
    items = []

    let loadTask = Task { [weak self, repository, prefetcher] in
      let candidates = await repository.media(language: language, region: region)
      guard !Task.isCancelled else { return }

      var prefetchedItems: [OnboardingMediaItem] = []
      for candidate in candidates {
        guard !Task.isCancelled else { return }
        if await prefetcher.prefetch(candidate.backdropURL) {
          prefetchedItems.append(candidate)
          if prefetchedItems.count == 2 { break }
        }
      }

      guard !Task.isCancelled else { return }
      self?.items = prefetchedItems
    }
    task = loadTask

    await withTaskCancellationHandler {
      await loadTask.value
    } onCancel: {
      loadTask.cancel()
    }
  }
}

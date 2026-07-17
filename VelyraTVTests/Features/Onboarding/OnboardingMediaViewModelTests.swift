import XCTest

@testable import VelyraTV

final class OnboardingMediaViewModelTests: XCTestCase {
  @MainActor
  func testStartsEmpty() {
    let viewModel = OnboardingMediaViewModel(
      repository: StubOnboardingMediaRepository(items: []),
      prefetcher: StubOnboardingImagePrefetcher(outcomes: [:])
    )

    XCTAssertEqual(viewModel.items, [])
  }

  @MainActor
  func testPublishesOnlyFirstSuccessfullyPrefetchedItemInCandidateOrder() async {
    let candidates = [
      mediaItem(id: "failed"),
      mediaItem(id: "first"),
      mediaItem(id: "second"),
      mediaItem(id: "unused"),
    ]
    let prefetcher = StubOnboardingImagePrefetcher(
      outcomes: [
        candidates[0].backdropURL: false,
        candidates[1].backdropURL: true,
        candidates[2].backdropURL: true,
        candidates[3].backdropURL: true,
      ]
    )
    let viewModel = OnboardingMediaViewModel(
      repository: StubOnboardingMediaRepository(items: candidates),
      prefetcher: prefetcher
    )

    let loadTask = Task { @MainActor in
      await viewModel.load(language: "en-US", region: "US")
    }
    await loadTask.value
    let receivedURLs = await prefetcher.receivedURLs()

    XCTAssertEqual(viewModel.items, [candidates[1]])
    XCTAssertEqual(receivedURLs, candidates.prefix(2).map(\.backdropURL))
  }

  @MainActor
  func testAllFailedPrefetchesLeaveFallbackEmpty() async {
    let candidates = [mediaItem(id: "one"), mediaItem(id: "two"), mediaItem(id: "three")]
    let prefetcher = StubOnboardingImagePrefetcher(outcomes: [:])
    let viewModel = OnboardingMediaViewModel(
      repository: StubOnboardingMediaRepository(items: candidates),
      prefetcher: prefetcher
    )

    let loadTask = Task { @MainActor in
      await viewModel.load(language: "en-US", region: "US")
    }
    await loadTask.value
    let receivedURLs = await prefetcher.receivedURLs()

    XCTAssertEqual(viewModel.items, [])
    XCTAssertEqual(receivedURLs, candidates.map(\.backdropURL))
  }

  @MainActor
  func testCancelledPreviousLoadCannotOverwriteNewerResult() async {
    let repository = ControlledOnboardingMediaRepository()
    let prefetcher = StubOnboardingImagePrefetcher(defaultOutcome: true)
    let viewModel = OnboardingMediaViewModel(repository: repository, prefetcher: prefetcher)
    let oldItem = mediaItem(id: "old")
    let newItem = mediaItem(id: "new")

    let oldTask = Task { @MainActor in
      await viewModel.load(language: "old", region: "US")
    }
    await repository.waitForRequestCount(1)
    let newTask = Task { @MainActor in
      await viewModel.load(language: "new", region: "US")
    }
    await repository.waitForRequestCount(2)

    await repository.resolveRequest(2, with: [newItem])
    await newTask.value
    await repository.resolveRequest(1, with: [oldItem])
    await oldTask.value
    let receivedURLs = await prefetcher.receivedURLs()

    XCTAssertEqual(viewModel.items, [newItem])
    XCTAssertEqual(receivedURLs, [newItem.backdropURL])
  }

  @MainActor
  func testCancellingHostLoadCancelsSuspendedRepositoryWithoutPublishing() async {
    let cancelledItem = mediaItem(id: "cancelled")
    let repository = HostCancellationOnboardingMediaRepository(items: [cancelledItem])
    let prefetcher = StubOnboardingImagePrefetcher(defaultOutcome: true)
    let viewModel = OnboardingMediaViewModel(repository: repository, prefetcher: prefetcher)

    let hostTask = Task { @MainActor in
      await viewModel.load(language: "en-US", region: "US")
    }
    await repository.waitUntilSuspended()

    hostTask.cancel()
    let repositoryObservedCancellation = await repository.resumeAndObserveCancellation()
    await hostTask.value
    let receivedURLs = await prefetcher.receivedURLs()

    XCTAssertEqual(repositoryObservedCancellation, true)
    XCTAssertEqual(viewModel.items, [])
    XCTAssertEqual(receivedURLs, [])
  }

  private func mediaItem(id: String) -> OnboardingMediaItem {
    OnboardingMediaItem(
      id: id,
      kind: .movie,
      title: id,
      backdropURL: URL(string: "https://example.com/\(id).jpg")!
    )
  }

}

private actor HostCancellationOnboardingMediaRepository: OnboardingMediaProviding {
  private let items: [OnboardingMediaItem]
  private var requestContinuation: CheckedContinuation<Void, Never>?
  private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
  private var observationContinuation: CheckedContinuation<Bool, Never>?

  init(items: [OnboardingMediaItem]) {
    self.items = items
  }

  func media(language: String, region: String) async -> [OnboardingMediaItem] {
    await withCheckedContinuation { continuation in
      requestContinuation = continuation
      let waiters = suspensionWaiters
      suspensionWaiters.removeAll()
      for waiter in waiters {
        waiter.resume()
      }
    }

    observationContinuation?.resume(returning: Task.isCancelled)
    observationContinuation = nil
    return items
  }

  func waitUntilSuspended() async {
    guard requestContinuation == nil else { return }
    await withCheckedContinuation { continuation in
      suspensionWaiters.append(continuation)
    }
  }

  func resumeAndObserveCancellation() async -> Bool {
    await withCheckedContinuation { continuation in
      observationContinuation = continuation
      requestContinuation?.resume()
      requestContinuation = nil
    }
  }
}

private struct StubOnboardingMediaRepository: OnboardingMediaProviding {
  let items: [OnboardingMediaItem]

  func media(language: String, region: String) async -> [OnboardingMediaItem] {
    items
  }
}

private actor ControlledOnboardingMediaRepository: OnboardingMediaProviding {
  private var requestCount = 0
  private var continuations: [Int: CheckedContinuation<[OnboardingMediaItem], Never>] = [:]
  private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

  func media(language: String, region: String) async -> [OnboardingMediaItem] {
    requestCount += 1
    let requestNumber = requestCount
    resumeCountWaiters()
    return await withCheckedContinuation { continuation in
      continuations[requestNumber] = continuation
    }
  }

  func waitForRequestCount(_ expectedCount: Int) async {
    guard requestCount < expectedCount else { return }
    await withCheckedContinuation { continuation in
      countWaiters.append((expectedCount, continuation))
    }
  }

  func resolveRequest(_ requestNumber: Int, with items: [OnboardingMediaItem]) {
    continuations.removeValue(forKey: requestNumber)?.resume(returning: items)
  }

  private func resumeCountWaiters() {
    let ready = countWaiters.filter { $0.0 <= requestCount }
    countWaiters.removeAll { $0.0 <= requestCount }
    for waiter in ready {
      waiter.1.resume()
    }
  }
}

private actor StubOnboardingImagePrefetcher: OnboardingImagePrefetching {
  private let outcomes: [URL: Bool]
  private let defaultOutcome: Bool
  private var urls: [URL] = []

  init(outcomes: [URL: Bool] = [:], defaultOutcome: Bool = false) {
    self.outcomes = outcomes
    self.defaultOutcome = defaultOutcome
  }

  func prefetch(_ url: URL) async -> Bool {
    urls.append(url)
    return outcomes[url] ?? defaultOutcome
  }

  func receivedURLs() -> [URL] {
    urls
  }
}

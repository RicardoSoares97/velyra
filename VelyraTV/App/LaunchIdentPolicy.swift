import Foundation

enum LaunchIdentPresentation: Equatable {
  case ribbonStrike
  case fade
}

struct LaunchIdentPolicy {
  private var hasPresented = false

  mutating func consumePresentation(reduceMotion: Bool) -> LaunchIdentPresentation? {
    guard !hasPresented else { return nil }
    hasPresented = true
    return reduceMotion ? .fade : .ribbonStrike
  }
}

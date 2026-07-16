import Foundation

struct DistributionCapabilities: Equatable, Sendable {
  let isSideload: Bool
  let supportsICloudPreferences: Bool
  let supportsCloudKit: Bool
  let supportsTopShelf: Bool

  static let full = DistributionCapabilities(
    isSideload: false,
    supportsICloudPreferences: true,
    supportsCloudKit: true,
    supportsTopShelf: true
  )

  static let sideload = DistributionCapabilities(
    isSideload: true,
    supportsICloudPreferences: false,
    supportsCloudKit: false,
    supportsTopShelf: false
  )

  static var current: DistributionCapabilities {
    #if VELYRA_SIDELOAD
      .sideload
    #else
      .full
    #endif
  }
}

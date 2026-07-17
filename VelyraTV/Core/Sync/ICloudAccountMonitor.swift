import CloudKit
import Foundation

@MainActor
final class ICloudAccountMonitor: ObservableObject {
  enum Status: Equatable {
    case checking
    case available
    case unavailable
    case restricted
    case couldNotDetermine

    var localizedKey: String {
      switch self {
      case .checking: "icloud.status.checking"
      case .available: "icloud.status.available"
      case .unavailable: "icloud.status.unavailable"
      case .restricted: "icloud.status.restricted"
      case .couldNotDetermine: "icloud.status.unknown"
      }
    }
  }

  @Published private(set) var status: Status

  private let container: CKContainer?

  init(
    container: CKContainer? = CKContainer(identifier: "iCloud.pt.ricardosoares.velyra"),
    initialStatus: Status = .checking
  ) {
    self.container = container
    status = initialStatus
  }

  static func localOnly() -> ICloudAccountMonitor {
    ICloudAccountMonitor(container: nil, initialStatus: .unavailable)
  }

  func refresh() async {
    guard let container else {
      status = .unavailable
      return
    }
    do {
      switch try await container.accountStatus() {
      case .available: status = .available
      case .noAccount: status = .unavailable
      case .restricted: status = .restricted
      case .couldNotDetermine, .temporarilyUnavailable: status = .couldNotDetermine
      @unknown default: status = .couldNotDetermine
      }
    } catch {
      status = .couldNotDetermine
    }
  }
}

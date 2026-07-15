import Foundation
import Network

@MainActor
final class NetworkStatusMonitor: ObservableObject {
  enum Interface: String, Sendable {
    case ethernet
    case wifi
    case cellular
    case other
    case unavailable
  }

  @Published private(set) var isConnected = true
  @Published private(set) var isConstrained = false
  @Published private(set) var isExpensive = false
  @Published private(set) var interface: Interface = .unavailable

  private let monitor: NWPathMonitor
  private let queue = DispatchQueue(label: "pt.ricardosoares.velyra.network-status")

  init(monitor: NWPathMonitor = NWPathMonitor()) {
    self.monitor = monitor
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in self?.apply(path) }
    }
    monitor.start(queue: queue)
  }

  deinit { monitor.cancel() }

  private func apply(_ path: NWPath) {
    isConnected = path.status == .satisfied
    isConstrained = path.isConstrained
    isExpensive = path.isExpensive
    if path.usesInterfaceType(.wiredEthernet) {
      interface = .ethernet
    } else if path.usesInterfaceType(.wifi) {
      interface = .wifi
    } else if path.usesInterfaceType(.cellular) {
      interface = .cellular
    } else if isConnected {
      interface = .other
    } else {
      interface = .unavailable
    }
  }
}

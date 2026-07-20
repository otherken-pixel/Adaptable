import Foundation
import Network

/// App-wide reachability. Surfaces a simple online/offline flag for banners
/// and avoids silent failed mutations when the device is offline.
@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true

    private let pathMonitor = NWPathMonitor()

    private init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        pathMonitor.start(queue: .global(qos: .utility))
    }
}

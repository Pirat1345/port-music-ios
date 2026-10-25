//
//  NetworkMonitor.swift
//  octave
//

import Network
import Observation

@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    var isConnected: Bool = true
    var isCellular: Bool = false
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isCellular = path.isExpensive
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
}

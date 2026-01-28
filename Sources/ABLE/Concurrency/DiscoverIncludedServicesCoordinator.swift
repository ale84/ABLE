//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

actor DiscoverIncludedServicesCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<[Service], Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [CBUUID: Entry] = [:] // serviceUUID -> entry

    func begin(
        serviceUUID: CBUUID,
        continuation: CheckedContinuation<[Service], Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {
        if let prev = entries[serviceUUID] {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(
                throwing: Peripheral.PeripheralError.discoverIncludedServicesReplaced(service: serviceUUID)
            )
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)
        if let timeout {
            entry.timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                await onTimeout()
            }
        }
        entries[serviceUUID] = entry
    }

    func succeed(serviceUUID: CBUUID, services: [Service]) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: services)
    }

    func fail(serviceUUID: CBUUID, error: Error) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func hasInFlight(serviceUUID: CBUUID) -> Bool { entries[serviceUUID] != nil }
}




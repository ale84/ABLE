//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

actor AddServiceCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Service, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [CBUUID: Entry] = [:]

    func begin(
        serviceUUID: CBUUID,
        continuation: CheckedContinuation<Service, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {
        // replace semantics per UUID
        if let prev = entries[serviceUUID] {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(
                throwing: PeripheralManager.PeripheralManagerError.addServiceReplaced(serviceUUID: serviceUUID)
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

    func succeed(serviceUUID: CBUUID, service: Service) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: service)
    }

    func fail(serviceUUID: CBUUID, error: Error) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }
}



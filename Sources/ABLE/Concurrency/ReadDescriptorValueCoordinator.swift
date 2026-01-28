//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

actor ReadDescriptorValueCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Data, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [CBUUID: Entry] = [:] // descriptorUUID -> entry

    func begin(
        descriptorUUID: CBUUID,
        continuation: CheckedContinuation<Data, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {
        if let prev = entries[descriptorUUID] {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(throwing: Peripheral.PeripheralError.readDescriptorValueReplaced(descriptor: descriptorUUID))
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)
        if let timeout {
            entry.timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                await onTimeout()
            }
        }
        entries[descriptorUUID] = entry
    }

    func succeed(descriptorUUID: CBUUID, data: Data) {
        guard let entry = entries.removeValue(forKey: descriptorUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: data)
    }

    func fail(descriptorUUID: CBUUID, error: Error) {
        guard let entry = entries.removeValue(forKey: descriptorUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func hasInFlight(descriptorUUID: CBUUID) -> Bool { entries[descriptorUUID] != nil }
}



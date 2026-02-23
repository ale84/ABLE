//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

actor WriteCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Void, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [CBUUID: Entry] = [:]

    func begin(
        characteristicUUID: CBUUID,
        continuation: CheckedContinuation<Void, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {
        // replace semantics per stessa characteristic
        if let prev = entries[characteristicUUID] {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(
                throwing: Peripheral.PeripheralError.writeReplaced(characteristic: characteristicUUID)
            )
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)

        if let timeout {
            entry.timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                await onTimeout()
            }
        }

        entries[characteristicUUID] = entry
    }

    func succeed(characteristicUUID: CBUUID) {
        guard let entry = entries.removeValue(forKey: characteristicUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: ())
    }

    func fail(characteristicUUID: CBUUID, error: Error) {
        guard let entry = entries.removeValue(forKey: characteristicUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func hasInFlight(characteristicUUID: CBUUID) -> Bool {
        entries[characteristicUUID] != nil
    }
}

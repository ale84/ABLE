//
//  Created by Alessio on 26/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation

actor DisconnectionCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Peripheral, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [UUID: Entry] = [:]   // peripheralID -> entry

    enum CoordinatorError: Error {
        case alreadyInProgress
        case noEntry
    }

    func begin(
        peripheralID: UUID,
        continuation: CheckedContinuation<Peripheral, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) throws {

        guard entries[peripheralID] == nil else {
            throw CoordinatorError.alreadyInProgress
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)

        if let timeout {
            entry.timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                await onTimeout()
            }
        }
        
        entries[peripheralID] = entry
    }

    func succeed(peripheralID: UUID, peripheral: Peripheral) {
        guard let entry = entries.removeValue(forKey: peripheralID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: peripheral)
    }

    func fail(peripheralID: UUID, error: Error) {
        guard let entry = entries.removeValue(forKey: peripheralID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func hasInFlight(peripheralID: UUID) -> Bool {
        entries[peripheralID] != nil
    }
}





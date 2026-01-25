//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation

actor ConnectionCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Peripheral, Error>
        var attemptTimeoutTask: Task<Void, Never>?
        var connectionTimeoutTask: Task<Void, Never>?
    }

    private var entries: [UUID: Entry] = [:]   // peripheralID -> entry

    enum CoordinatorError: Error {
        case alreadyInProgress
        case noEntry
    }

    func begin(
        peripheralID: UUID,
        continuation: CheckedContinuation<Peripheral, Error>,
        attemptTimeout: Duration?,
        connectionTimeout: Duration?,
        onAttemptTimeout: @escaping @Sendable () async -> Void,
        onConnectionTimeout: @escaping @Sendable () async -> Void
    ) throws {

        guard entries[peripheralID] == nil else {
            throw CoordinatorError.alreadyInProgress
        }

        var entry = Entry(continuation: continuation,
                          attemptTimeoutTask: nil,
                          connectionTimeoutTask: nil)

        if let attemptTimeout {
            entry.attemptTimeoutTask = Task {
                do { try await Task.sleep(for: attemptTimeout) } catch { return }
                await onAttemptTimeout()
            }
        }

        if let connectionTimeout {
            entry.connectionTimeoutTask = Task {
                do { try await Task.sleep(for: connectionTimeout) } catch { return }
                await onConnectionTimeout()
            }
        }

        entries[peripheralID] = entry
    }

    func succeed(peripheralID: UUID, peripheral: Peripheral) {
        guard let entry = entries.removeValue(forKey: peripheralID) else { return }
        entry.attemptTimeoutTask?.cancel()
        entry.connectionTimeoutTask?.cancel()
        entry.continuation.resume(returning: peripheral)
    }

    func fail(peripheralID: UUID, error: Error) {
        guard let entry = entries.removeValue(forKey: peripheralID) else { return }
        entry.attemptTimeoutTask?.cancel()
        entry.connectionTimeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func hasInFlight(peripheralID: UUID) -> Bool {
        entries[peripheralID] != nil
    }
}




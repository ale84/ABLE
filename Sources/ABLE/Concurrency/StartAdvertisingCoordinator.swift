//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation

actor StartAdvertisingCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Void, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var current: Entry?

    func begin(
        continuation: CheckedContinuation<Void, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {
        // replace semantics
        if let prev = current {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(throwing: PeripheralManager.PeripheralManagerError.advertisingReplaced)
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)

        if let timeout {
            entry.timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                await onTimeout()
            }
        }

        current = entry
    }

    func succeed() {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume()
    }

    func fail(error: Error) {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }
}



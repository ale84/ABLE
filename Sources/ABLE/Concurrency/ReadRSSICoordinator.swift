//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

actor ReadRSSICoordinator {

    struct Entry {
        let continuation: CheckedContinuation<Int, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var current: Entry?

    func begin(
        continuation: CheckedContinuation<Int, Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {

        // rimpiazza la precedente
        if let prev = current {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(throwing: Peripheral.PeripheralError.readRSSIReplaced)
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

    func succeed(rssi: Int) {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: rssi)
    }

    func fail(error: Error) {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }
}





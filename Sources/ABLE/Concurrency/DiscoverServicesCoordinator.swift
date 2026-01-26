//
//  Created by Alessio on 26/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

actor DiscoverServicesCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<[Service], Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var current: Entry?

    enum CoordinatorError: Error {
        case alreadyInProgress
    }

    func begin(
        uuid: [CBUUID],
        continuation: CheckedContinuation<[Service], Error>,
        timeout: Duration?,
        onTimeout: @escaping @Sendable () async -> Void
    ) {

        // rimpiazza la precedente
        if let prev = current {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(throwing: Peripheral.PeripheralError.discoverServicesReplaced)
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

    func succeed(services: [Service]) {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: services)
    }

    func fail(error: Error) {
        guard let entry = current else { return }
        current = nil
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }
}



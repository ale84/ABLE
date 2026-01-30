//
//  Created by Alessio on 27/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

actor DiscoverCharacteristicsCoordinator {

    struct Entry {
        let continuation: CheckedContinuation<[Characteristic], Error>
        var timeoutTask: Task<Void, Never>?
    }

    private var entries: [CBUUID: Entry] = [:]   // keyed by service UUID

    func begin(
        serviceUUID: CBUUID,
        continuation: CheckedContinuation<[Characteristic], Error>,
        timeout: Duration?
    ) {
        // mixed: parallel per service, replace per stesso service
        if let prev = entries[serviceUUID] {
            prev.timeoutTask?.cancel()
            prev.continuation.resume(
                throwing: Peripheral.PeripheralError.discoverCharacteristicsReplaced(service: serviceUUID)
            )
            entries[serviceUUID] = nil
        }

        var entry = Entry(continuation: continuation, timeoutTask: nil)

        if let timeout {
            entry.timeoutTask = Task { [serviceUUID] in
                do { try await Task.sleep(for: timeout) } catch { return }
                self.fail(
                    serviceUUID: serviceUUID,
                    error: Peripheral.PeripheralError.discoverCharacteristicsTimeout(service: serviceUUID)
                )
            }
        }

        entries[serviceUUID] = entry
    }

    func succeed(serviceUUID: CBUUID, characteristics: [Characteristic]) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: characteristics)
    }

    func fail(serviceUUID: CBUUID, error: Error) {
        guard let entry = entries.removeValue(forKey: serviceUUID) else { return }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
    }

    func cancel(serviceUUID: CBUUID) {
        fail(
            serviceUUID: serviceUUID,
            error: Peripheral.PeripheralError.discoverCharacteristicsCancelled(service: serviceUUID)
        )
    }
}

//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public extension Peripheral {

    func write(
        _ data: Data,
        for characteristic: Characteristic,
        type: CBCharacteristicWriteType,
        timeout: Duration?
    ) async throws {

        let uuid = characteristic.uuid

        // withoutResponse: fire-and-forget
        guard type == .withResponse else {
            cbPeripheral.writeValue(data, for: characteristic.cbCharacteristic, type: type)
            return
        }

        // withResponse: wait didWriteValueFor
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.writeCoordinator.begin(
                        characteristicUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.writeCoordinator.fail(
                                characteristicUUID: uuid,
                                error: PeripheralError.writeTimeout(characteristic: uuid)
                            )
                        }
                    )

                    self.cbPeripheral.writeValue(data, for: characteristic.cbCharacteristic, type: type)
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.writeCoordinator.fail(
                    characteristicUUID: uuid,
                    error: PeripheralError.writeCancelled(characteristic: uuid)
                )
            }
        })
    }

    // Legacy bridge
    func write(
        _ data: Data,
        for characteristic: Characteristic,
        type: CBCharacteristicWriteType,
        completion: @escaping WriteCharacteristicCompletion
    ) {
        if type != .withResponse {
            cbPeripheral.writeValue(data, for: characteristic.cbCharacteristic, type: type)
            completion(.success(()))
            return
        }

        Task {
            do {
                try await write(data, for: characteristic, type: type, timeout: nil)
                completion(.success(()))
            } catch let e as PeripheralError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(detail: error)))
            }
        }
    }
}

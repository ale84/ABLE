//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public extension Peripheral {

    func readValue(
        for characteristic: Characteristic,
        timeout: Duration?
    ) async throws -> Data {

        let uuid = characteristic.uuid

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.readValueCoordinator.begin(
                        characteristicUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.readValueCoordinator.fail(
                                characteristicUUID: uuid,
                                error: PeripheralError.readValueTimeout(characteristic: uuid)
                            )
                        }
                    )

                    self.cbPeripheral.readValue(for: characteristic.cbCharacteristic)
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.readValueCoordinator.fail(
                    characteristicUUID: uuid,
                    error: PeripheralError.readValueCancelled(characteristic: uuid)
                )
            }
        })
    }

    // Bridge legacy (closure) sopra async
    func readValue(
        for characteristic: Characteristic,
        completion: @escaping ReadCharacteristicCompletion
    ) {
        Task {
            do {
                let data = try await readValue(for: characteristic, timeout: .seconds(3))
                completion(.success(data))
            } catch let e as PeripheralError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(detail: error)))
            }
        }
    }
}

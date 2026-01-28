//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


public extension Peripheral {

    func discoverDescriptors(
        for characteristic: Characteristic,
        timeout: Duration?
    ) async throws -> [Descriptor] {

        let uuid = characteristic.uuid

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.discoverDescriptorsCoordinator.begin(
                        characteristicUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.discoverDescriptorsCoordinator.fail(
                                characteristicUUID: uuid,
                                error: PeripheralError.discoverDescriptorsTimeout(characteristic: uuid)
                            )
                        }
                    )

                    self.cbPeripheral.discoverDescriptors(for: characteristic.cbCharacteristic)
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.discoverDescriptorsCoordinator.fail(
                    characteristicUUID: uuid,
                    error: PeripheralError.discoverDescriptorsCancelled(characteristic: uuid)
                )
            }
        })
    }
}



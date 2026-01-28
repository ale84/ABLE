//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public extension Peripheral {

    func writeValue(
        _ data: Data,
        for descriptor: Descriptor,
        timeout: Duration?
    ) async throws {

        let uuid = descriptor.uuid

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.writeDescriptorCoordinator.begin(
                        descriptorUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.writeDescriptorCoordinator.fail(
                                descriptorUUID: uuid,
                                error: PeripheralError.writeDescriptorTimeout(descriptor: uuid)
                            )
                        }
                    )

                    self.cbPeripheral.writeValue(data, for: descriptor.cbDescriptor) // CBDescriptorType o CBDescriptor
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.writeDescriptorCoordinator.fail(
                    descriptorUUID: uuid,
                    error: PeripheralError.writeDescriptorCancelled(descriptor: uuid)
                )
            }
        })
    }
}



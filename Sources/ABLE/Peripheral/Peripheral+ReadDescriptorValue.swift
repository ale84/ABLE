//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation

public extension Peripheral {

    func readValue(
        for descriptor: Descriptor,
        timeout: Duration?
    ) async throws -> Data {

        let uuid = descriptor.uuid

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.readDescriptorValueCoordinator.begin(
                        descriptorUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.readDescriptorValueCoordinator.fail(
                                descriptorUUID: uuid,
                                error: PeripheralError.readDescriptorValueTimeout(descriptor: uuid)
                            )
                        }
                    )

                    self.cbPeripheral.readValue(for: descriptor.cbDescriptor)
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.readDescriptorValueCoordinator.fail(
                    descriptorUUID: uuid,
                    error: PeripheralError.readDescriptorValueCancelled(descriptor: uuid)
                )
            }
        })
    }
}



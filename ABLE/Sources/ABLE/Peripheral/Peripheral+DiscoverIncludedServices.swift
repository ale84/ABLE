//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public extension Peripheral {

    func discoverIncludedServices(
        _ uuids: [CBUUID]?,
        for service: Service,
        timeout: Duration?
    ) async throws -> [Service] {

        let serviceUUID = service.uuid

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.discoverIncludedServicesCoordinator.begin(
                        serviceUUID: serviceUUID,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.discoverIncludedServicesCoordinator.fail(
                                serviceUUID: serviceUUID,
                                error: PeripheralError.discoverIncludedServicesTimeout(service: serviceUUID)
                            )
                        }
                    )

                    self.cbPeripheral.discoverIncludedServices(uuids, for: service.cbService)
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.discoverIncludedServicesCoordinator.fail(
                    serviceUUID: serviceUUID,
                    error: PeripheralError.discoverIncludedServicesCancelled(service: serviceUUID)
                )
            }
        })
    }
}


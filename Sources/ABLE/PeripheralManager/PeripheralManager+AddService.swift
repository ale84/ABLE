//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public extension PeripheralManager {

    func add(_ service: CBMutableService, timeout: Duration? = .seconds(3)) async throws -> Service {
        let uuid = service.uuid

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.addServiceCoordinator.begin(
                        serviceUUID: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.addServiceCoordinator.fail(
                                serviceUUID: uuid,
                                error: PeripheralManagerError.addServiceTimeout(
                                    serviceUUID: uuid,
                                    lastState: self.state
                                )
                            )
                        }
                    )

                    self.cbPeripheralManager.add(service)
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.addServiceCoordinator.fail(
                    serviceUUID: uuid,
                    error: PeripheralManagerError.addServiceCancelled(serviceUUID: uuid)
                )
            }
        }
    }

    /// Bridge legacy (closure) sopra async
    func add(_ service: CBMutableService, completion: @escaping AddServiceCompletion) {
        Task {
            do {
                let result = try await add(service, timeout: nil)
                completion(.success(result))
            } catch let e as PeripheralManagerError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(error)))
            }
        }
    }
}




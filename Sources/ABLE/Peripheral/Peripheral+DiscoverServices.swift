//
//  Created by Alessio on 26/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth


public extension Peripheral {

    func discoverServices(
        with uuid: [CBUUID],
        timeout: Duration?
    ) async throws -> [Service] {

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }
                    
                    await self.discoverServicesCoordinator.begin(
                        uuid: uuid,
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            
                            guard let self else { return }
                            await self.discoverServicesCoordinator.fail(
                                error: PeripheralError.discoverServicesTimeout
                            )
                            
                        })
                    
                    self.cbPeripheral.discoverServices(uuid)
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.discoverServicesCoordinator.fail(
                    error: PeripheralError.discoverServicesCancelled
                )
            }
        }
    }
    
    // Bridge legacy (closure)
    func discoverServices(with uuid: [CBUUID], timeout: TimeInterval = 3, completion: @escaping DiscoverServicesCompletion) {
        Task {
            do {
                let services = try await discoverServices(
                    with: uuid,
                    timeout: .milliseconds(Int(timeout * 1000))
                )
                completion(.success(services))
            } catch let e as PeripheralError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(detail: error)))
            }
        }
    }
}





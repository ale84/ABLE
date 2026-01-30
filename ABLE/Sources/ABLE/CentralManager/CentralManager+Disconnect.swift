//
//  Created by Alessio on 26/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

public extension CentralManager {

    func disconnect(
        from peripheral: Peripheral,
        timeout: Duration?
    ) async throws -> Peripheral {

        guard state == .poweredOn else {
            throw CentralManagerError.bluetoothNotAvailable(state)
        }

        // Normalizza: se CentralManager conosce già quel CBPeripheral,
        // usa la sua istanza "owned" (evita mismatch di identità)
        let targetPeripheral = self.peripheral(for: peripheral.cbPeripheral) ?? peripheral
        let peripheralID = targetPeripheral.cbPeripheral.identifier

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    do {
                        try await self.disconnectionCoordinator.begin(
                            peripheralID: peripheralID,
                            continuation: continuation,
                            timeout: timeout,
                            onTimeout: { [weak self] in
                                
                                guard let self else { return }
                                await self.disconnectionCoordinator.fail(
                                    peripheralID: peripheralID,
                                    error: CentralManagerError.disconnectAttemptTimedOut
                                )
                                
                                self.cbCentralManager.cancelPeripheralConnection(targetPeripheral.cbPeripheral)
                            })

                        // Start CB disconnect dopo aver registrato l'attempt
                        self.cbCentralManager.cancelPeripheralConnection(targetPeripheral.cbPeripheral)

                    } catch DisconnectionCoordinator.CoordinatorError.alreadyInProgress {
                        continuation.resume(throwing: CentralManagerError.disconnectAlreadyInProgress)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.disconnectionCoordinator.fail(
                    peripheralID: peripheralID,
                    error: CentralManagerError.disconnectCancelled
                )
                self.cbCentralManager.cancelPeripheralConnection(targetPeripheral.cbPeripheral)
            }
        }
    }
    
    // Bridge legacy (closure) sopra async
    func disconnect(from peripheral: Peripheral, completion: DisconnectionCompletion? = nil) {
        Task {
            do {
                let p = try await disconnect(from: peripheral, timeout: nil)
                completion?(p)
            }
            catch {
                completion?(peripheral)
            }
        }
    }
}



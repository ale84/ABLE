//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation

public extension CentralManager {

    func connect(
        to peripheral: Peripheral,
        options: [String: Any]? = nil,
        attemptTimeout: Duration? = nil,
        connectionTimeout: Duration? = nil
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
                        try await self.connectionCoordinator.begin(
                            peripheralID: peripheralID,
                            continuation: continuation,
                            attemptTimeout: attemptTimeout,
                            connectionTimeout: connectionTimeout,

                            onAttemptTimeout: { [weak self] in
                                guard let self else { return }
                                await self.connectionCoordinator.fail(
                                    peripheralID: peripheralID,
                                    error: CentralManagerError.connectAttemptTimedOut
                                )
                                self.cbCentralManager.cancelPeripheralConnection(targetPeripheral.cbPeripheral)
                            },

                            onConnectionTimeout: { [weak self] in
                                guard let self else { return }
                                self.disconnect(from: targetPeripheral)
                            }
                        )

                        // Start CB connect dopo aver registrato l'attempt
                        self.cbCentralManager.connect(targetPeripheral.cbPeripheral, options: options)

                    } catch ConnectionCoordinator.CoordinatorError.alreadyInProgress {
                        continuation.resume(throwing: CentralManagerError.connectAlreadyInProgress)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.connectionCoordinator.fail(
                    peripheralID: peripheralID,
                    error: CentralManagerError.connectCancelled
                )
                self.cbCentralManager.cancelPeripheralConnection(targetPeripheral.cbPeripheral)
            }
        }
    }

    // Bridge legacy (closure) sopra async
    func connect(
        to peripheral: Peripheral,
        options: [String : Any]? = nil,
        attemptTimeout: TimeInterval? = nil,
        connectionTimeout: TimeInterval? = nil,
        completion: @escaping ConnectionCompletion
    ) {
        Task {
            do {
                let p = try await connect(
                    to: peripheral,
                    options: options,
                    attemptTimeout: attemptTimeout.map { .milliseconds(Int($0 * 1000)) },
                    connectionTimeout: connectionTimeout.map { .milliseconds(Int($0 * 1000)) }
                )
                completion(.success(p))
            } catch let e as CentralManagerError {
                completion(.failure(e))
            } catch is CancellationError {
                completion(.failure(.connectCancelled))
            } catch {
                completion(.failure(.connectionFailed(error)))
            }
        }
    }
}

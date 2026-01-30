//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public extension PeripheralManager {

    // MARK: Async API

    func startAdvertising(_ advertisementData: [String: Any]?,
                          timeout: Duration? = .seconds(3)) async throws {

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.startAdvertisingCoordinator.begin(
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.startAdvertisingCoordinator.fail(
                                error: PeripheralManagerError.advertisingTimeout(lastState: self.state)
                            )
                        }
                    )

                    self.cbPeripheralManager.startAdvertising(advertisementData)
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task {
                await self.startAdvertisingCoordinator.fail(
                    error: PeripheralManagerError.advertisingCancelled
                )
            }
        }
    }

    func startAdvertising(with localName: String? = nil,
                          UUIDs: [CBUUID]? = nil,
                          timeout: Duration? = .seconds(3)) async throws {

        var advertisementData: [String: Any] = [:]
        if let localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }
        if let UUIDs {
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = UUIDs
        }

        try await startAdvertising(advertisementData, timeout: timeout)
    }
    
    func stopAdvertising() {
        cbPeripheralManager.stopAdvertising()
    }

    // MARK: Legacy bridge (closure)
    func startAdvertising(_ advertisementData: [String: Any]?,
                          completion: @escaping StartAdvertisingCompletion) {
        Task {
            do {
                try await startAdvertising(advertisementData, timeout: nil) // o .seconds(3) se vuoi default
                completion(.success(()))
            } catch let e as PeripheralManagerError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(error)))
            }
        }
    }

    func startAdvertising(with localName: String? = nil,
                          UUIDs: [CBUUID]? = nil,
                          completion: @escaping StartAdvertisingCompletion) {
        Task {
            do {
                try await startAdvertising(with: localName, UUIDs: UUIDs, timeout: nil)
                completion(.success(()))
            } catch let e as PeripheralManagerError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(error)))
            }
        }
    }
}



//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth


public extension Peripheral {

    func readRSSI(
        timeout: Duration?
    ) async throws -> Int {

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }
                    await self.readRSSICoordinator.begin(
                        continuation: continuation,
                        timeout: timeout,
                        onTimeout: { [weak self] in
                            guard let self else { return }
                            await self.readRSSICoordinator.fail(error: PeripheralError.readRSSITimeout)
                        }
                    )
                    self.cbPeripheral.readRSSI()
                }
            }
        }, onCancel: { [weak self] in
            guard let self else { return }
            Task { await self.readRSSICoordinator.fail(error: PeripheralError.readRSSICancelled) }
        })
    }
    
    func readRSSI(with completion: @escaping ReadRSSICompletion) {
        Task {
            do {
                let rssi = try await readRSSI(timeout: nil)
                completion(.success(rssi))
            }
            catch let e as PeripheralError {
                completion(.failure(e))
            }
            catch {
                completion(.failure(.cbError(detail: error)))
            }
        }
    }
}







//
//  Created by Alessio on 27/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public extension Peripheral {

    func discoverCharacteristics(
        with uuids: [CBUUID],
        service: Service,
        timeout: Duration? = .seconds(3)
    ) async throws -> [Characteristic] {

        let serviceUUID = service.uuid

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { [weak self] in
                    guard let self else { return }

                    await self.discoverCharacteristicsCoordinator.begin(
                        serviceUUID: serviceUUID,
                        continuation: continuation,
                        timeout: timeout
                    )

                    self.cbPeripheral.discoverCharacteristics(uuids, for: service.cbService)
                    Logger.debug("start discovering characteristics: \(uuids) from: \(service), timeout: \(String(describing: timeout))")
                }
            }
        } onCancel: { [weak self] in
            guard let self else { return }
            Task { await self.discoverCharacteristicsCoordinator.cancel(serviceUUID: serviceUUID) }
        }
    }

    // Bridge legacy
    func discoverCharacteristics(
        with uuids: [CBUUID],
        service: Service,
        timeout: TimeInterval = 3,
        completion: @escaping DiscoverCharacteristicsCompletion
    ) {
        Task {
            do {
                let chars = try await discoverCharacteristics(
                    with: uuids,
                    service: service,
                    timeout: .milliseconds(Int(timeout * 1000))
                )
                completion(.success(chars))
            } catch let e as PeripheralError {
                completion(.failure(e)) // ✅ no double wrap
            } catch {
                completion(.failure(.cbError(detail: error)))
            }
        }
    }
}

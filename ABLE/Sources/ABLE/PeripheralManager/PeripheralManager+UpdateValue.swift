//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public extension PeripheralManager {
    
    var readyToUpdateSubscribersStream: AsyncStream<Void> {
        readyToUpdateSubscribersCoordinator.stream()
    }
    
    /// Variante sync “raw” (senza callback): utile anche internamente
    @discardableResult
    func updateValue(_ value: Data,
                     for characteristic: CBMutableCharacteristic,
                     onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        cbPeripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
    }
    
    /// Variante async: se buffer pieno, aspetta "ready" e ritenta finché riesce o scade timeout/cancel
    func updateValueWhenReady(_ value: Data,
                              for characteristic: CBMutableCharacteristic,
                              onSubscribedCentrals centrals: [CBCentral]?,
                              timeout: Duration? = .seconds(3)) async throws {
        
        // Fast-path: se va al primo colpo, fine
        if updateValue(value, for: characteristic, onSubscribedCentrals: centrals) {
            return
        }
        
        let readyStream = readyToUpdateSubscribersCoordinator.stream()
        do {
            try await withTaskCancellationHandler {
                if let timeout {
                    try await withThrowingTaskGroup(of: Void.self) { group in
                        // Task 1: retry loop
                        group.addTask { [weak self] in
                            guard let self else { return }
                            for await _ in readyStream {
                                if self.updateValue(value, for: characteristic, onSubscribedCentrals: centrals) {
                                    return
                                }
                            }
                        }
                        
                        // Task 2: timeout
                        group.addTask { [weak self] in
                            guard let self else { return }
                            try await Task.sleep(for: timeout)
                            throw PeripheralManagerError.updateValueTimeout(lastState: self.state)
                        }
                        
                        // aspetta il primo che completa/throw
                        let _ = try await group.next()!
                        group.cancelAll()
                    }
                } else {
                    // no-timeout: aspetta all'infinito finché non diventa ready e l'update passa
                    for await _ in readyStream {
                        if updateValue(value, for: characteristic, onSubscribedCentrals: centrals) {
                            return
                        }
                    }
                }
            } onCancel: { // non c’è “cancel updateValue” in CoreBluetooth, quindi solo errore coerente
            }
        } catch is CancellationError {
            throw PeripheralManagerError.updateValueCancelled
        }
    }
    
    // Legacy
    @discardableResult
    func updateValue(_ value: Data,
                     for characteristic: CBMutableCharacteristic,
                     onSubscribedCentrals centrals: [CBCentral]?,
                     readyToUpdateCallback: @escaping ReadyToUpdateSubscribersCallback) -> Bool {

        let ok = updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
        if ok { return true }

        // Bridge: ascolta UN SOLO evento "ready", poi chiama callback e termina
        Task { [weak self] in
            guard let self else { return }
            for await _ in self.readyToUpdateSubscribersStream {
                readyToUpdateCallback()
                return
            }
        }

        return false
    }

    func updateValueWhenReady(_ value: Data,
                              for characteristic: CBMutableCharacteristic,
                              onSubscribedCentrals centrals: [CBCentral]?,
                              timeout: TimeInterval = 3,
                              completion: @escaping (Result<Void, PeripheralManagerError>) -> Void) {
        Task {
            do {
                try await updateValueWhenReady(
                    value,
                    for: characteristic,
                    onSubscribedCentrals: centrals,
                    timeout: .milliseconds(Int(timeout * 1000))
                )
                completion(.success(()))
            } catch let e as PeripheralManagerError {
                completion(.failure(e))
            } catch {
                completion(.failure(.cbError(error)))
            }
        }
    }
}


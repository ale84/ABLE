//
//  Created by Alessio on 27/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

actor NotifyCoordinator {

    struct Entry {
        var token: UUID                      // identifica lo stream owner attuale
        var continuation: AsyncThrowingStream<Data, Error>.Continuation?
        var updateState: Peripheral.SetNotifyUpdateStateCompletion?
        var updateValue: Peripheral.SetNotifyUpdateValueCallback?
        var enabledConfirmed: Bool
    }

    private var entries: [CBUUID: Entry] = [:]

    // MARK: - Stream API (modern)

    nonisolated func stream(
        characteristicUUID: CBUUID,
        onStart: @escaping @Sendable () -> Void,
        onStop: @escaping @Sendable () -> Void
    ) -> AsyncThrowingStream<Data, Error> {

        let token = UUID()

        return AsyncThrowingStream { continuation in

            Task { [weak self] in
                guard let self else { return }
                await self.registerStreamContinuation(
                    continuation,
                    token: token,
                    for: characteristicUUID
                )
                onStart()
            }

            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    guard let self else { return }
                    let shouldStop = await self.terminateStream(
                        token: token,
                        characteristicUUID: characteristicUUID
                    )
                    if shouldStop { onStop() }
                }
            }
        }
    }

    /// Registra/replace lo stream per questa characteristic. Replace chiude il vecchio stream (ma NON stoppa CB: quello è demandato all'onTermination, che col token non farà danni).
    private func registerStreamContinuation(
        _ continuation: AsyncThrowingStream<Data, Error>.Continuation,
        token: UUID,
        for characteristicUUID: CBUUID
    ) {
        if let prev = entries[characteristicUUID] {
            // chiudi stream precedente con errore di replace
            prev.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyReplaced(characteristic: characteristicUUID)
            )
            prev.updateState?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
            prev.updateValue?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
        }

        // conserva eventuali callback legacy già registrate
        let legacyState = entries[characteristicUUID]?.updateState
        let legacyValue = entries[characteristicUUID]?.updateValue

        entries[characteristicUUID] = Entry(
            token: token,
            continuation: continuation,
            updateState: legacyState,
            updateValue: legacyValue,
            enabledConfirmed: false
        )
    }

    /// Termination di uno stream. Ritorna true solo se lo stream che termina è ancora l'owner attuale.
    private func terminateStream(token: UUID, characteristicUUID: CBUUID) -> Bool {
        guard let entry = entries[characteristicUUID] else { return false }
        guard entry.token == token else {
            // stream vecchio rimpiazzato: non toccare nulla, non stoppare
            return false
        }
        // questo era l'owner attuale: rimuovi l'entry
        entries[characteristicUUID] = nil
        return true
    }

    // MARK: - Legacy registration

    func registerLegacy(
        characteristicUUID: CBUUID,
        replace: Bool,
        updateState: @escaping Peripheral.SetNotifyUpdateStateCompletion,
        updateValue: @escaping Peripheral.SetNotifyUpdateValueCallback
    ) {
        if replace, let prev = entries[characteristicUUID] {
            prev.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyReplaced(characteristic: characteristicUUID)
            )
            prev.updateState?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
            prev.updateValue?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
        }

        var entry = entries[characteristicUUID] ?? Entry(
            token: UUID(), // token “dummy” per legacy; non usato per onTermination
            continuation: nil,
            updateState: nil,
            updateValue: nil,
            enabledConfirmed: false
        )

        entry.updateState = updateState
        entry.updateValue = updateValue
        // non toccare continuation/token se già c'è uno stream attivo: legacy può coesistere come listener
        entries[characteristicUUID] = entry
    }

    func unregister(characteristicUUID: CBUUID) {
        if let entry = entries.removeValue(forKey: characteristicUUID) {
            // chiudi stream se esiste (esplicito stop da legacy)
            entry.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyCancelled(characteristic: characteristicUUID)
            )
        }
    }

    // MARK: - Delegate events

    func handleDidUpdateNotificationState(
        characteristicUUID: CBUUID,
        isNotifying: Bool,
        error: Error?
    ) {
        guard var entry = entries[characteristicUUID] else { return }

        if let error {
            entry.updateState?(.failure(.notifyEnableFailed(characteristic: characteristicUUID, underlying: error)))
            entry.updateValue?(.failure(.notifyEnableFailed(characteristic: characteristicUUID, underlying: error)))

            entries[characteristicUUID] = nil
            entry.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyEnableFailed(characteristic: characteristicUUID, underlying: error)
            )
            return
        }

        if isNotifying {
            entry.enabledConfirmed = true
            entry.updateState?(.success(()))
            entries[characteristicUUID] = entry
        } else {
            // notify disabilitato -> termina
            entry.updateState?(.success(()))
            entries[characteristicUUID] = nil
            entry.continuation?.finish()
        }
    }

    func handleDidUpdateValue(
        characteristicUUID: CBUUID,
        data: Data?,
        error: Error?
    ) {
        guard let entry = entries[characteristicUUID] else { return }

        if let error {
            entry.updateValue?(.failure(.notifyValueFailed(characteristic: characteristicUUID, underlying: error)))
            entries[characteristicUUID] = nil
            entry.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyValueFailed(characteristic: characteristicUUID, underlying: error)
            )
            return
        }

        guard entry.enabledConfirmed else { return }

        let value = data ?? Data()
        entry.updateValue?(.success(value))
        entry.continuation?.yield(value)
    }
}

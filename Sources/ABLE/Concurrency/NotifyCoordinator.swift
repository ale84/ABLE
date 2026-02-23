//
//  Created by Alessio on 27/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

actor NotifyCoordinator {

    struct Entry {
        var token: UUID                      // identifies the current stream owner
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

    private func registerStreamContinuation(
        _ continuation: AsyncThrowingStream<Data, Error>.Continuation,
        token: UUID,
        for characteristicUUID: CBUUID
    ) {
        if let prev = entries[characteristicUUID] {
            // close the previous stream with replace error
            prev.continuation?.finish(
                throwing: Peripheral.PeripheralError.notifyReplaced(characteristic: characteristicUUID)
            )
            prev.updateState?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
            prev.updateValue?(.failure(.notifyReplaced(characteristic: characteristicUUID)))
        }

        // keep already registered legacy callback
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

    /// Stream termination. Returns true only if the terminating stream is still the current owner.
    private func terminateStream(token: UUID, characteristicUUID: CBUUID) -> Bool {
        guard let entry = entries[characteristicUUID] else { return false }
        guard entry.token == token else {
            // old stream replaced
            return false
        }
        // this was the current owner: remove the entry
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
            token: UUID(), // dummy token for legacy; not used for onTermination
            continuation: nil,
            updateState: nil,
            updateValue: nil,
            enabledConfirmed: false
        )

        entry.updateState = updateState
        entry.updateValue = updateValue
        // don't touch continuation/token if there is already an active stream; legacy can coexist as listener
        entries[characteristicUUID] = entry
    }

    func unregister(characteristicUUID: CBUUID) {
        if let entry = entries.removeValue(forKey: characteristicUUID) {
            // close stream if it exists
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
            // notify disabled -> terminate
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

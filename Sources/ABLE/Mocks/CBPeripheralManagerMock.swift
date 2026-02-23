//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public final class CBPeripheralManagerMock: CBPeripheralManagerType {

    // MARK: - Delegate

    public var cbDelegate: CBPeripheralManagerDelegateType?

    // MARK: - State

    public var managerState: ManagerState = .poweredOn
    public lazy var managerAuthorization: ManagerAuthorization = .allowedAlways
    public var isAdvertising: Bool = false

    // MARK: - Behaviours

    public var addServiceBehaviour: AddServiceBehaviour = .success
    public var startAdvertiseBehaviour: StartAdvertiseBehaviour = .success

    /// Controls how/when the manager changes state and emits `didUpdateState`.
    public var stateBehaviour: StateBehaviour = .alreadyPoweredOn {
        didSet { applyStateBehaviour() }
    }

    /// Controls how `updateValue` behaves and whether it needs a readiness signal.
    public var updateValueBehaviour: UpdateValueBehaviour = .alwaysReady

    /// Controls whether the mock emits read/write requests events.
    public var readRequestsBehaviour: RequestsBehaviour = .idle
    public var writeRequestsBehaviour: RequestsBehaviour = .idle

    // MARK: - Scheduling

    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]
    private let scheduledTasksLock = NSLock()

    public init() {
        applyStateBehaviour()
    }

    deinit {
        scheduledTasksLock.lock()
        let tasks = Array(scheduledTasks.values)
        scheduledTasks.removeAll()
        scheduledTasksLock.unlock()

        tasks.forEach { $0.cancel() }
    }

    // MARK: - CBPeripheralManagerType

    public func add(_ service: CBMutableService) {
        switch addServiceBehaviour {
        case .success:
            cbDelegate?.peripheralManager(self, didAdd: service, error: nil)
        case .failure:
            cbDelegate?.peripheralManager(self, didAdd: service, error: AddServiceError.addServiceFailed)
        }
    }

    public func remove(_ service: CBMutableService) { }

    public func removeAllServices() { }

    public func startAdvertising(_ advertisementData: [String : Any]?) {
        switch startAdvertiseBehaviour {
        case .success:
            isAdvertising = true
            cbDelegate?.peripheralManagerDidStartAdvertising(self, error: nil)
        case .failure:
            isAdvertising = false
            cbDelegate?.peripheralManagerDidStartAdvertising(self, error: StartAdvertiseError.startAdvertiseFailed)
        }
    }

    public func stopAdvertising() {
        isAdvertising = false
    }

    public func updateValue(_ value: Data,
                            for characteristic: CBMutableCharacteristic,
                            onSubscribedCentrals centrals: [CBCentral]?) -> Bool {

        switch updateValueBehaviour {
        case .alwaysReady:
            return true

        case .notReadyThenReady(let delay):
            // First call returns false, then we notify readiness.
            updateValueBehaviour = .alwaysReady
            schedule(after: delay) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.peripheralManagerIsReady(toUpdateSubscribers: self)
            }
            return false
        }
    }

    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) { }

    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) { }

    public func publishL2CAPChannel(withEncryption encryptionRequired: Bool) { }

    public func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM) { }

    // MARK: - Test helpers (events)

    /// Manually emit a state update (useful for waitForState tests).
    public func emitState(_ state: ManagerState) {
        managerState = state
        cbDelegate?.peripheralManagerDidUpdateState(self)
    }

    public func emitReadRequest(
        characteristic: CBCharacteristic,
        value: Data? = nil,
        after delay: TimeInterval = 0
    ) {
        schedule(after: delay) { [weak self] in
            guard let self else { return }
            let req = CBATTRequestMock(characteristic: characteristic, value: value)
            self.cbDelegate?.peripheralManager(self, didReceiveRead: req)
        }
    }

    public func emitWriteRequests(
        characteristic: CBCharacteristic,
        values: [Data?] = [nil, nil],
        after delay: TimeInterval = 0
    ) {
        schedule(after: delay) { [weak self] in
            guard let self else { return }
            let reqs: [CBATTRequestType] = values.map { CBATTRequestMock(characteristic: characteristic, value: $0) }
            self.cbDelegate?.peripheralManager(self, didReceiveWrite: reqs)
        }
    }

    // MARK: - Private

    private func applyStateBehaviour() {
        switch stateBehaviour {
        case .already(let state):
            managerState = state
            cbDelegate?.peripheralManagerDidUpdateState(self)   // needed to update the state on the coordinator as well

        case .transition(let from, let to, let after):
            managerState = from
            cbDelegate?.peripheralManagerDidUpdateState(self)   // needed to update the state on the coordinator as well
            schedule(after: after) { [weak self] in
                guard let self else { return }
                self.managerState = to
                self.cbDelegate?.peripheralManagerDidUpdateState(self)
            }
        }
    }

    private func schedule(after seconds: TimeInterval, _ action: @escaping @Sendable () -> Void) {
        let id = UUID()
        let task = Task { [weak self] in
            if seconds > 0 {
                let nanos = UInt64(max(0, seconds) * 1_000_000_000)
                do { try await Task.sleep(nanoseconds: nanos) } catch {
                    self?.removeTask(for: id)
                    return
                }
            }

            guard !Task.isCancelled else {
                self?.removeTask(for: id)
                return
            }

            action()
            self?.removeTask(for: id)
        }

        storeTask(task, for: id)
    }

    private func storeTask(_ task: Task<Void, Never>, for id: UUID) {
        scheduledTasksLock.lock()
        scheduledTasks[id] = task
        scheduledTasksLock.unlock()
    }

    private func removeTask(for id: UUID) {
        scheduledTasksLock.lock()
        scheduledTasks[id] = nil
        scheduledTasksLock.unlock()
    }
}

// MARK: - Behaviours

extension CBPeripheralManagerMock {

    public enum AddServiceBehaviour {
        case success
        case failure
    }

    public enum StartAdvertiseBehaviour {
        case success
        case failure
    }

    public enum StateBehaviour {
        case already(ManagerState)
        case transition(from: ManagerState, to: ManagerState, after: TimeInterval)
        static var alreadyPoweredOn: StateBehaviour { .already(.poweredOn) }
    }

    public enum UpdateValueBehaviour {
        case alwaysReady
        case notReadyThenReady(after: TimeInterval)
    }

    public enum RequestsBehaviour {
        case idle
        case emitOnce(after: TimeInterval)
    }
}

// MARK: - Errors

extension CBPeripheralManagerMock {
    public enum AddServiceError: Error { case addServiceFailed }
    public enum StartAdvertiseError: Error { case startAdvertiseFailed }
}

//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public final class CBCentralManagerMock: CBCentralManagerType {

    // MARK: Behaviours

    public var waitForPoweredOnBehaviour: WaitForPoweredOnBehaviour = .alreadyPoweredOn {
        didSet { applyWaitForPoweredOnBehaviour() }
    }

    public var peripheralConnectionBehaviour: ConnectPeripheralBehaviour = .success(after: 0)
    public var disconnectionBehaviour: DisconnectPeripheralBehaviour = .success
    public var connectionEventBehaviour: ConnectionEventBehaviour = .generateEvent(event: .peerConnected, after: 2.0)

    // MARK: State

    public var cbDelegate: CBCentralManagerDelegateType?

    public var managerState: ManagerState = .poweredOff
    public lazy var managerAuthorization: ManagerAuthorization = .allowedAlways

    public var peripherals: [Peripheral] = []

    // MARK: Scheduling (no timers / cancellable)

    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]

    public init() {
        applyWaitForPoweredOnBehaviour()
    }

    deinit {
        scheduledTasks.values.forEach { $0.cancel() }
        scheduledTasks.removeAll()
    }

    // MARK: CBCentralManagerType

    public func connect(_ peripheral: CBPeripheralType, options: [String : Any]?) {
        switch peripheralConnectionBehaviour {
        case .success(let seconds):
            schedule(after: seconds) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.centralManager(self, didConnect: peripheral)
            }

        case .failure:
            schedule(after: 0) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.centralManager(self, didFailToConnect: peripheral, error: nil)
            }
        }
    }

    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        switch disconnectionBehaviour {
        case .success:
            schedule(after: 0) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
            }

        case .successAfter(let seconds):
            schedule(after: seconds) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
            }
        }
    }

    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType] { [] }

    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheralType] { [] }

    public func scanForPeripherals(withServices: [CBUUID]?, options: [String : Any]?) {
        
        for p in peripherals {
            cbDelegate?.centralManager(self,
                                       didDiscover: p.cbPeripheral,
                                       advertisementData: [:],
                                       rssi: NSNumber(value: 0))
        }
    }

    public func stopScan() { }

    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]?) {
        switch connectionEventBehaviour {
        case .generateEvent(let event, let after):
            let peripheralMock = CBPeripheralMock()
            peripheralMock.name = "ConnectionEventTest"

            schedule(after: after) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.centralManager(self, connectionEventDidOccur: event, for: peripheralMock)
            }

        case .idle:
            break
        }
    }

    // MARK: Internals

    private func applyWaitForPoweredOnBehaviour() {

        switch waitForPoweredOnBehaviour {
        case .alreadyPoweredOn:
            managerState = .poweredOn
            cbDelegate?.centralManagerDidUpdateState(self)

        case .poweredOn(let seconds):
            managerState = .poweredOff
            cbDelegate?.centralManagerDidUpdateState(self)
            schedule(after: seconds) { [weak self] in
                guard let self else { return }
                self.managerState = .poweredOn
                self.cbDelegate?.centralManagerDidUpdateState(self)
            }
        }
    }

    private func schedule(after seconds: TimeInterval, _ action: @escaping @Sendable () -> Void) {
        let id = UUID()
        let task = Task { [weak self] in
            if seconds > 0 {
                let nanos = UInt64(max(0, seconds) * 1_000_000_000)
                do { try await Task.sleep(nanoseconds: nanos) } catch { return }
            }
            guard !Task.isCancelled else { return }
            action()
            self?.scheduledTasks[id] = nil
        }
        scheduledTasks[id] = task
    }
}

// MARK: Behaviours
public extension CBCentralManagerMock {
    enum WaitForPoweredOnBehaviour {
        case alreadyPoweredOn
        case poweredOn(after: TimeInterval)
    }

    enum ConnectPeripheralBehaviour {
        case success(after: TimeInterval)
        case failure
    }

    enum DisconnectPeripheralBehaviour {
        case success
        case successAfter(seconds: TimeInterval)
    }

    enum ConnectionEventBehaviour {
        case generateEvent(event: CBConnectionEvent, after: TimeInterval)
        case idle
    }
}

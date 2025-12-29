//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBCentralManagerMock: CBCentralManagerType {
    
    public var waitForPoweredOnBehaviour: WaitForPoweredOnBehaviour = .alreadyPoweredOn {
        didSet {
            switch waitForPoweredOnBehaviour {
            case .alreadyPoweredOn:
                managerState = .poweredOn
            case .poweredOn(let seconds):
                managerState = .poweredOff
                // Timer per simulare il power on dopo X secondi
                waitForPoweredOnTimer = Timer.scheduledTimer(
                    timeInterval: seconds,
                    target: self,
                    selector: #selector(handleWaitForPoweredOnTimer(_:)),
                    userInfo: nil,
                    repeats: false
                )
            }
        }
    }
    public var peripheralConnectionBehaviour: ConnectPeripheralBehaviour = .success(after: 0)
    public var disconnectionBehaviour: DisconnectPeripheralBehaviour = .success
    public var connectionEventBehaviour: ConnectionEventBehaviour = .generateEvent(event: .peerConnected, after: 2.0)
    
    public init() {}
    
    public var peripherals: [Peripheral] = []
    
    public var cbDelegate: CBCentralManagerDelegateType?
    
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return []
    }
    
    public var managerState: ManagerState = .poweredOff
    
    public lazy var managerAuthorization: ManagerAuthorization = .allowedAlways
    
    // Timers interni
    private var waitForPoweredOnTimer: Timer?
    private var disconnectTimers: [Timer] = []
    private var connectTimers: [Timer] = []
    private var connectionEventTimers: [Timer] = []

    // Box per userInfo dei timer
    private class DisconnectContext {
        let peripheral: CBPeripheralType
        init(peripheral: CBPeripheralType) { self.peripheral = peripheral }
    }

    private class ConnectContext {
        let peripheral: CBPeripheralType
        init(peripheral: CBPeripheralType) { self.peripheral = peripheral }
    }

    private class ConnectionEventContext {
        let event: CBConnectionEvent
        let peripheral: CBPeripheralType
        init(event: CBConnectionEvent, peripheral: CBPeripheralType) {
            self.event = event
            self.peripheral = peripheral
        }
    }
    
    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        switch disconnectionBehaviour {
        case .success:
            cbDelegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
        case .successAfter(let seconds):
            let context = DisconnectContext(peripheral: peripheral)
            let timer = Timer.scheduledTimer(
                timeInterval: seconds,
                target: self,
                selector: #selector(handleDisconnectTimer(_:)),
                userInfo: context,
                repeats: false
            )
            disconnectTimers.append(timer)
        }
    }
    
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType] {
        return []
    }
    
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheralType] {
        return []
    }
    public func scanForPeripherals(withServices: [CBUUID]?, options: [String : Any]?) {
        peripherals.forEach { (peripheral) in
            cbDelegate?.centralManager(self, didDiscover: peripheral.cbPeripheral, advertisementData: [:], rssi: NSNumber(value: 0))
        }
    }
    
    public func stopScan() { }
    
    public func connect(_ peripheral: CBPeripheralType, options: [String : Any]?) {
        switch peripheralConnectionBehaviour {
        case .success(let seconds):
            let context = ConnectContext(peripheral: peripheral)
            let timer = Timer.scheduledTimer(
                timeInterval: seconds,
                target: self,
                selector: #selector(handleConnectTimer(_:)),
                userInfo: context,
                repeats: false
            )
            connectTimers.append(timer)
        case .failure:
            cbDelegate?.centralManager(self, didFailToConnect: peripheral, error: CentralManager.CentralManagerError.connectionFailed(nil))
        }
    }
    
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]?) {
        switch connectionEventBehaviour {
        case .generateEvent(let event, let after):
            
            let peripheralMock = CBPeripheralMock()
            peripheralMock.name = "ConnectionEventTest"
            
            let context = ConnectionEventContext(event: event, peripheral: peripheralMock)
            let timer = Timer.scheduledTimer(
                timeInterval: after,
                target: self,
                selector: #selector(handleConnectionEventTimer(_:)),
                userInfo: context,
                repeats: false
            )
            connectionEventTimers.append(timer)
            
        case .idle:
            break
        }
    }
}

// MARK: Behaviours.
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

// MARK: Timer Handlers.
private extension CBCentralManagerMock {

    @objc func handleWaitForPoweredOnTimer(_ timer: Timer) {
        waitForPoweredOnTimer?.invalidate()
        waitForPoweredOnTimer = nil
        managerState = .poweredOn
    }

    @objc func handleDisconnectTimer(_ timer: Timer) {
        defer {
            if let index = disconnectTimers.firstIndex(of: timer) {
                disconnectTimers.remove(at: index)
            }
        }

        guard let context = timer.userInfo as? DisconnectContext else { return }
        cbDelegate?.centralManager(self,
                                   didDisconnectPeripheral: context.peripheral,
                                   error: nil)
    }

    @objc func handleConnectTimer(_ timer: Timer) {
        defer {
            if let index = connectTimers.firstIndex(of: timer) {
                connectTimers.remove(at: index)
            }
        }

        guard let context = timer.userInfo as? ConnectContext else { return }
        cbDelegate?.centralManager(self,
                                   didConnect: context.peripheral)
    }

    @objc func handleConnectionEventTimer(_ timer: Timer) {
        defer {
            if let index = connectionEventTimers.firstIndex(of: timer) {
                connectionEventTimers.remove(at: index)
            }
        }

        guard let context = timer.userInfo as? ConnectionEventContext else { return }
        cbDelegate?.centralManager(self,
                                   connectionEventDidOccur: context.event,
                                   for: context.peripheral)
    }
}

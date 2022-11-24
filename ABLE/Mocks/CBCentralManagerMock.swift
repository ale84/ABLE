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
                delay(seconds) { [weak self] in
                    self?.managerState = .poweredOn
                }
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
    
    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        switch disconnectionBehaviour {
        case .success:
            cbDelegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
        case .successAfter(let seconds):
            delay(seconds) {
                self.cbDelegate?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
            }
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
            delay(seconds) {
                self.cbDelegate?.centralManager(self, didConnect: peripheral)
            }
        case .failure:
            cbDelegate?.centralManager(self, didFailToConnect: peripheral, error: CentralManager.CentralManagerError.connectionFailed(nil))
        }
    }
    
    @available(iOS 13.0, *)
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]?) {
        switch connectionEventBehaviour {
        case .generateEvent(let event, let after):
            
            let peripheralMock = CBPeripheralMock()
            peripheralMock.name = "ConnectionEventTest"
            
            delay(after) {
                self.cbDelegate?.centralManager(self, connectionEventDidOccur: event, for: peripheralMock)
            }
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

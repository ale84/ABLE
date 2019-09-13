//
//  CentralManagerMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBCentralManagerMock: CBCentralManagerType {
    
    public enum WaitForPoweredOnBehaviour {
        case alreadyPoweredOn
        case poweredOn(after: TimeInterval)
    }
    
    public enum ConnectPeripheralBehaviour {
        case success(after: TimeInterval)
        case failure
    }
    
    public enum DisconnectPeripheralBehaviour {
        case success
        case successAfter(seconds: TimeInterval)
    }
    
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
    
    public init() {}
    public var peripherals: [Peripheral] = []
    
    public var cbDelegate: CBCentralManagerDelegateType?
    
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return []
    }
    
    public var managerState: ManagerState = .poweredOff
    
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
    
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]?) {
        // TODO: Implement mocked behavior.
    }
}

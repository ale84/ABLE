//
//  CentralManagerMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBCentralManagerMock: CBCentralManagerType {
    
    public enum WaitForPoweredOnBehaviour {
        case alreadyPoweredOn
        case poweredOnAfter(seconds: TimeInterval)
    }
    
    public enum ConnectPeripheralBehaviour {
        case success
        case successAfter(seconds: TimeInterval)
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
            case .poweredOnAfter(let seconds):
                managerState = .poweredOff
                delay(seconds) { [weak self] in
                    self?.managerState = .poweredOn
                }
            }
        }
    }
    public var peripheralConnectionBehaviour: ConnectPeripheralBehaviour = .success
    public var disconnectionBehaviour: DisconnectPeripheralBehaviour = .success
    
    public init() {}
    public var peripherals: [Peripheral] = []
    
    public var delegateType: CBCentralManagerDelegateType?
    
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        return []
    }
    
    public var managerState: ManagerState = .poweredOff
    
    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        switch disconnectionBehaviour {
        case .success:
            delegateType?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
        case .successAfter(let seconds):
            delay(seconds) {
                self.delegateType?.centralManager(self, didDisconnectPeripheral: peripheral, error: nil)
            }
        }
    }
    
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType] {
        return []
    }
    
    func retrievePeripherals(withIdentifiers: [UUID]) { }
    
    public func scanForPeripherals(withServices: [CBUUID]?, options: [String : Any]?) {
        peripherals.forEach { (peripheral) in
            delegateType?.centralManager(self, didDiscover: peripheral.cbPeripheral, advertisementData: [:], rssi: NSNumber(value: 0))
        }
    }
    
    public func stopScan() { }
    
    public func connect(_ peripheral: CBPeripheralType, options: [String : Any]?) {
        switch peripheralConnectionBehaviour {
        case .success:
            delegateType?.centralManager(self, didConnect: peripheral)
        case .successAfter(let seconds):
            delay(seconds) {
                self.delegateType?.centralManager(self, didConnect: peripheral)
            }
        case .failure:
            delegateType?.centralManager(self, didFailToConnect: peripheral, error: CentralManager.BLEError.connectionFailed(nil))
        }
    }
}

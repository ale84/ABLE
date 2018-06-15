//
//  CBCentralManagerType.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBCentralManagerType: CBManagerType {
    var cbDelegate: CBCentralManagerDelegateType? { get set }
    func connect(_ peripheral: CBPeripheralType, options: [String : Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheralType)
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType]
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheralType]
    func scanForPeripherals(withServices: [CBUUID]?, options: [String : Any]?)
    func stopScan()
}

extension CBCentralManager: CBCentralManagerType {
    public func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheralType] {
        let cbPeripherals: [CBPeripheral] = retrievePeripherals(withIdentifiers: identifiers)
        return cbPeripherals
    }
    
    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        cancelPeripheralConnection(peripheral as! CBPeripheral)
    }
    
    public var cbDelegate: CBCentralManagerDelegateType? {
        get {
            return nil
        }
        set { }
    }

    
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType] {
        let cbPeripherals: [CBPeripheral] = retrieveConnectedPeripherals(withServices: serviceUUIDs)
        return cbPeripherals
    }
    
    public func connect(_ peripheral: CBPeripheralType, options: [String : Any]?) {
        let cbPeripheral = peripheral as! CBPeripheral
        connect(cbPeripheral, options: options)
    }
}

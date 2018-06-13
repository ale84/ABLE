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
    func connect(_ peripheral: CBPeripheralType, options: [String : Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheralType)
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType]
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]
    func scanForPeripherals(withServices: [CBUUID]?, options: [String : Any]?)
    func stopScan()
    var delegateType: CBCentralManagerDelegateType? { get set }
}

extension CBCentralManager: CBCentralManagerType {
    public var delegateType: CBCentralManagerDelegateType? {
        get {
            return nil
        }
        set { }
    }
    public func cancelPeripheralConnection(_ peripheral: CBPeripheralType) {
        cancelPeripheralConnection(peripheral)
    }
    
    public func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheralType] {
        return retrieveConnectedPeripherals(withServices: serviceUUIDs)
    }
    
    public func connect(_ peripheral: CBPeripheralType, options: [String : Any]?) {
        let cbPeripheral = peripheral as! CBPeripheral
        connect(cbPeripheral, options: options)
    }
}

//
//  CBPeripheralType.swift
//  ABLE
//
//  Created by Alessio Orlando on 06/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralType: class, CBPeerType {
    var name: String? { get }
    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBServiceType)
    var cbServices: [CBServiceType]? { get }
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBServiceType)
    func discoverDescriptors(for characteristic: CBCharacteristicType)
    func readValue(for characteristic: CBCharacteristicType)
    func readValue(for descriptor: CBDescriptor)
    func writeValue(_ data: Data, for characteristic: CBCharacteristicType, type: CBCharacteristicWriteType)
    func writeValue(_ data: Data, for descriptor: CBDescriptor)
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristicType)
    var state: CBPeripheralState { get }
    func readRSSI()
    var canSendWriteWithoutResponse: Bool { get }
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
    //func openL2CAPChannel(_ PSM: CBL2CAPPSM)
    var delegateType: CBPeripheralDelegateType? { get set }
}

extension CBPeripheral: CBPeripheralType {
    public var cbServices: [CBServiceType]? {
        return services
    }
    
    public func discoverDescriptors(for characteristic: CBCharacteristicType) {
        return discoverDescriptors(for: characteristic as! CBCharacteristic)
    }
    
    public func readValue(for characteristic: CBCharacteristicType) {
        return readValue(for: characteristic as! CBCharacteristic)
    }
    
    public func writeValue(_ data: Data, for characteristic: CBCharacteristicType, type: CBCharacteristicWriteType) {
        return writeValue(data, for: characteristic as! CBCharacteristic, type: type)
    }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristicType) {
        return setNotifyValue(enabled, for: characteristic as! CBCharacteristic)
    }
    
    public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBServiceType) {
        return discoverIncludedServices(includedServiceUUIDs, for: service as! CBService)
    }
    
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBServiceType) {
        discoverCharacteristics(characteristicUUIDs, for: service as! CBService)
    }
    
    weak public var delegateType: CBPeripheralDelegateType? {
        get {
            return nil
        }
        set { }
    }
}

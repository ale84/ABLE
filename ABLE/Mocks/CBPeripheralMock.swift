//
//  CBPeripheralMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBPeripheralMock: CBPeripheralType {
    
    public var delegateType: CBPeripheralDelegateType?
    
    public var name: String?
    
    public func discoverServices(_ serviceUUIDs: [CBUUID]?) { }
    
    public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBService) { }
    
    public var services: [CBService]?
    
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) { }
    
    public func discoverDescriptors(for characteristic: CBCharacteristic) { }
    
    public func readValue(for characteristic: CBCharacteristic) { }
    
    public func readValue(for descriptor: CBDescriptor) { }
    
    public func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) { }
    
    public func writeValue(_ data: Data, for descriptor: CBDescriptor) { }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) { }
    
    public var state: CBPeripheralState = .connected
    
    public func readRSSI() { }
    
    public var canSendWriteWithoutResponse: Bool = false
    
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return 100
    }
    
    public var identifier: UUID = UUID()
}

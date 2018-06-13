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
    func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBService)
    var services: [CBService]? { get }
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService)
    func discoverDescriptors(for characteristic: CBCharacteristic)
    func readValue(for characteristic: CBCharacteristic)
    func readValue(for descriptor: CBDescriptor)
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType)
    func writeValue(_ data: Data, for descriptor: CBDescriptor)
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
    var state: CBPeripheralState { get }
    func readRSSI()
    var canSendWriteWithoutResponse: Bool { get }
    func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int
    //func openL2CAPChannel(_ PSM: CBL2CAPPSM)
    var delegateType: CBPeripheralDelegateType? { get set }
}

extension CBPeripheral: CBPeripheralType {
    weak public var delegateType: CBPeripheralDelegateType? {
        get {
            return nil
        }
        set { }
    }
}

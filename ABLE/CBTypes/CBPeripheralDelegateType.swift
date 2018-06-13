//
//  CBPeripheralDelegateType.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralDelegateType: class {
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverServices error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverIncludedServicesFor service: CBService, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor descriptor: CBDescriptor, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor descriptor: CBDescriptor, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didReadRSSI RSSI: NSNumber, error: Error?)
    func peripheralDidUpdateName(_ peripheral: CBPeripheralType)
    func peripheral(_ peripheral: CBPeripheralType, didModifyServices invalidatedServices: [CBService])
    @available(iOS 11.0, *)
    func peripheral(_ peripheral: CBPeripheralType, didOpen channel: CBL2CAPChannel?, error: Error?)
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheralType)
}

//
//  CBPeripheralManagerDelegateType.swift
//  ABLE
//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralManagerDelegateType: class {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManagerType)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, willRestoreState dict: [String : Any])
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didAdd service: CBServiceType, error: Error?)
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManagerType, error: Error?)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didSubscribeTo characteristic: CBCharacteristicType)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristicType)
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManagerType)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didReceiveRead request: CBATTRequest)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didReceiveWrite requests: [CBATTRequest])
    @available(iOS 11.0, *)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didOpen channel: CBL2CAPChannel?, error: Error?)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?)
    func peripheralManager(_ peripheral: CBPeripheralManagerType, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?)
}

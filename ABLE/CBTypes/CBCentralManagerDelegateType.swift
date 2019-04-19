//
//  CBCentralManagerDelegateType.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBCentralManagerDelegateType: class {
    func centralManager(_ central: CBCentralManagerType, didConnect peripheral: CBPeripheralType)
    func centralManager(_ central: CBCentralManagerType, didDisconnectPeripheral peripheral: CBPeripheralType, error: Error?)
    func centralManager(_ central: CBCentralManagerType, didFailToConnect: CBPeripheralType, error: Error?)
    func centralManager(_ central: CBCentralManagerType, didDiscover peripheral: CBPeripheralType, advertisementData: [String : Any], rssi RSSI: NSNumber)
    func centralManagerDidUpdateState(_ central: CBCentralManagerType)
    func centralManager(_ central: CBCentralManagerType, willRestoreState dict: [String : Any])
}

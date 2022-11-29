//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

class CBCentralManagerDelegateProxy: NSObject, CBCentralManagerDelegate {
    weak var target: CBCentralManagerDelegateType?
    
    init(withTarget target: CBCentralManagerDelegateType) {
        self.target = target
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        target?.centralManagerDidUpdateState(central)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        target?.centralManager(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        target?.centralManager(central as CBCentralManagerType, didConnect: peripheral as CBPeripheralType)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        target?.centralManager(central, didFailToConnect: peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        target?.centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        target?.centralManager(central, connectionEventDidOccur: event, for: peripheral as CBPeripheralType)
    }
    
    public func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        target?.centralManager(central, didUpdateANCSAuthorizationFor: peripheral as CBPeripheralType)
    }
}

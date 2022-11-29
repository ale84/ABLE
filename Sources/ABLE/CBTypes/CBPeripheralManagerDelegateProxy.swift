//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

class CBPeripheralManagerDelegateProxy: NSObject, CBPeripheralManagerDelegate {
    weak var target: CBPeripheralManagerDelegateType?
    
    init(withTarget target: CBPeripheralManagerDelegateType) {
        self.target = target
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        target?.peripheralManagerDidUpdateState(peripheral)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        target?.peripheralManager(peripheral, willRestoreState: dict)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        target?.peripheralManager(peripheral, didAdd: service, error: error)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        target?.peripheralManagerDidStartAdvertising(peripheral, error: error)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        target?.peripheralManager(peripheral, central: central, didSubscribeTo: characteristic)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        target?.peripheralManager(peripheral, central: central, didUnsubscribeFrom: characteristic)
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        target?.peripheralManagerIsReady(toUpdateSubscribers: peripheral)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        target?.peripheralManager(peripheral, didReceiveRead: request)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        target?.peripheralManager(peripheral, didReceiveWrite: requests)
    }    
}

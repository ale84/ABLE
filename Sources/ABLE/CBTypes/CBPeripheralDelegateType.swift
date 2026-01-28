//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralDelegateType: AnyObject {
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverServices error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverIncludedServicesFor service: CBServiceType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverCharacteristicsFor service: CBServiceType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didDiscoverDescriptorsFor characteristic: CBCharacteristicType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor characteristic: CBCharacteristicType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor descriptor: CBDescriptorType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor characteristic: CBCharacteristicType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor descriptor: CBDescriptorType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didUpdateNotificationStateFor characteristic: CBCharacteristicType, error: Error?)
    func peripheral(_ peripheral: CBPeripheralType, didReadRSSI RSSI: NSNumber, error: Error?)
    func peripheralDidUpdateName(_ peripheral: CBPeripheralType)
    func peripheral(_ peripheral: CBPeripheralType, didModifyServices invalidatedServices: [CBServiceType])
    func peripheral(_ peripheral: CBPeripheralType, didOpen channel: CBL2CAPChannel?, error: Error?)
    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheralType)
}

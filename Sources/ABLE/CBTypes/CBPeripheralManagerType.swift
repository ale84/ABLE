//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralManagerType: AnyObject, CBManagerType {
    var cbDelegate: CBPeripheralManagerDelegateType? { get set }
    var isAdvertising: Bool { get }
    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    func removeAllServices()
    func startAdvertising(_ advertisementData: [String : Any]?)
    func stopAdvertising()
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral)
    func publishL2CAPChannel(withEncryption encryptionRequired: Bool)
    func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM)
}

extension CBPeripheralManager: CBPeripheralManagerType {
    weak public var cbDelegate: CBPeripheralManagerDelegateType? {
        get {
            return nil
        }
        set { }
    }
}

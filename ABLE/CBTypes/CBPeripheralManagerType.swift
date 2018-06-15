//
//  CBPeripheralManagerType.swift
//  ABLE
//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeripheralManagerType: class, CBManagerType {
    static func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus
    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    func removeAllServices()
    func startAdvertising(_ advertisementData: [String : Any]?)
    func stopAdvertising()
    var isAdvertising: Bool { get }
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral)
//    func publishL2CAPChannel(withEncryption encryptionRequired: Bool)
//    func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM)
    var cbDelegate: CBPeripheralManagerDelegateType? { get set }
}

extension CBPeripheralManager: CBPeripheralManagerType {
    weak public var cbDelegate: CBPeripheralManagerDelegateType? {
        get {
            return nil
        }
        set { }
    }
}

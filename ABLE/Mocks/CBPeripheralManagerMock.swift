//
//  CBPeripheralManagerMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBPeripheralManagerMock: CBPeripheralManagerType {
    public var delegateType: CBPeripheralManagerDelegateType?
    public var managerState: ManagerState = .poweredOn
    public var isAdvertising: Bool = false
    
    public init() { }
    
    public static func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    public func add(_ service: CBMutableService) { }
    
    public func remove(_ service: CBMutableService) { }
    
    public func removeAllServices() { }
    
    public func startAdvertising(_ advertisementData: [String : Any]?) { }
    
    public func stopAdvertising() { }
    
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        return true
    }
    
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) { }
    
    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) { }
}

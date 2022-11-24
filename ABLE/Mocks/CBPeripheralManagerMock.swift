//
//  Created by Alessio Orlando on 11/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBPeripheralManagerMock: CBPeripheralManagerType {
    
    public var cbDelegate: CBPeripheralManagerDelegateType?
    
    public var managerState: ManagerState = .poweredOn
    
    public lazy var managerAuthorization: ManagerAuthorization = .allowedAlways
    
    public var isAdvertising: Bool = false
    
    public var addServiceBehaviour: AddServiceBehaviour = .success
    
    public var startAdvertiseBehaviour: StartAdvertiseBehaviour = .success
    
    public init() { }
    
    public static func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    public func add(_ service: CBMutableService) {
        switch addServiceBehaviour {
        case .success:
            cbDelegate?.peripheralManager(self, didAdd: service, error: nil)
        case .failure:
            cbDelegate?.peripheralManager(self, didAdd: service, error: AddServiceError.addServiceFailed)
        }
    }
    
    public func remove(_ service: CBMutableService) {}
    
    public func removeAllServices() { }
    
    public func startAdvertising(_ advertisementData: [String : Any]?) {
        switch startAdvertiseBehaviour {
        case .success:
            cbDelegate?.peripheralManagerDidStartAdvertising(self, error: nil)
        case .failure:
            cbDelegate?.peripheralManagerDidStartAdvertising(self, error: StartAdvertiseError.startAdvertiseFailed)
        }
    }
    
    public func stopAdvertising() { }
    
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        return true
    }
    
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) { }
    
    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) { }
    
    public func publishL2CAPChannel(withEncryption encryptionRequired: Bool) { }
    
    public func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM) { }
}

// MARK: Behaviours.
extension CBPeripheralManagerMock {
    public enum AddServiceBehaviour {
        case success
        case failure
    }
    public enum StartAdvertiseBehaviour {
        case success
        case failure
    }
}

// MARK: Errors.
extension CBPeripheralManagerMock {
    public enum AddServiceError: Error {
        case addServiceFailed
    }
    public enum StartAdvertiseError: Error {
        case startAdvertiseFailed
    }
}

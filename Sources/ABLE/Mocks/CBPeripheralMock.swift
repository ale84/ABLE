//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBPeripheralMock: CBPeripheralType {
    public var discoverServicesBehaviour: DiscoverServicesBehaviour = .success(with: [], after: 0)
    public var discoverCharacteristicsBehaviour: DiscoverCharacteristicsBehaviour = .failure
    public var readValueBehaviour: ReadValueBehaviour = .success
    public var writeValueBehaviour: WriteValueBehaviour = .success
    public var notifyBehaviour: NotifyBehaviour = .success
    public var readRSSIBehaviour: ReadRSSIBehaviour = .success

    public var cbDelegate: CBPeripheralDelegateType?
    
    public var name: String?
    
    public var state: CBPeripheralState = .connected
    
    public var canSendWriteWithoutResponse: Bool = false
    
    public var identifier: UUID = UUID()
    
    public var cbServices: [CBServiceType]? = []
    
    public var ancsAuthorized: Bool = false
    
    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        switch discoverServicesBehaviour {
        case .success(let services, let interval):
            delay(interval) {
                self.cbServices = services
                self.cbDelegate?.peripheral(self, didDiscoverServices: nil)
            }
        case .failure:
            cbDelegate?.peripheral(self, didDiscoverServices: DiscoverServicesError.discoveryFailed)
        }
    }
    
    public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBServiceType) { }
    
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBServiceType) {
        switch discoverCharacteristicsBehaviour {
        case .success(let service, let interval):
            delay(interval) {
                self.cbDelegate?.peripheral(self, didDiscoverCharacteristicsFor: service, error: nil)
            }
        case .failure:
            cbDelegate?.peripheral(self, didDiscoverCharacteristicsFor: service, error: DiscoverCharacteristicError.discoveryFailed)
        }
    }
    
    public func discoverDescriptors(for characteristic: CBCharacteristicType) { }
    
    public func readValue(for characteristic: CBCharacteristicType) {
        switch readValueBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didUpdateValueFor: characteristic, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didUpdateValueFor: characteristic, error: ReadValueError.readFailed)
        }
    }
    
    public func writeValue(_ data: Data, for characteristic: CBCharacteristicType, type: CBCharacteristicWriteType) {
        switch writeValueBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didWriteValueFor: characteristic, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didWriteValueFor: characteristic, error: WriteValueError.writeFailed)
        }
    }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristicType) {
        switch notifyBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: nil)
            if enabled {
                cbDelegate?.peripheral(self, didUpdateValueFor: characteristic, error: nil)
            }
        case .failure:
            cbDelegate?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: NotifyError.updateStateFailure)
        }
    }
    
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return 100
    }
    
    public func readRSSI() {
        switch readRSSIBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didReadRSSI: NSNumber(value: -30), error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didReadRSSI: NSNumber(value: 0), error: ReadRSSIError.readFailed)
        }
    }
    
    public func readValue(for descriptor: CBDescriptor) { }
    
    public func writeValue(_ data: Data, for descriptor: CBDescriptor) { }
    
    public func openL2CAPChannel(_ PSM: CBL2CAPPSM) { }
}

// MARK: Behaviours.
extension CBPeripheralMock {
    public enum DiscoverServicesBehaviour {
        case success(with: [CBServiceType], after: TimeInterval)
        case failure
    }
    
    public enum DiscoverCharacteristicsBehaviour {
        case success(with: CBServiceType, after: TimeInterval)
        case failure
    }
    
    public enum ReadValueBehaviour {
        case success
        case failure
    }
    
    public enum WriteValueBehaviour {
        case success
        case failure
    }
    
    public enum NotifyBehaviour {
        case success
        case failure
    }
    
    public enum ReadRSSIBehaviour {
        case success
        case failure
    }
}

// MARK: Errors.
extension CBPeripheralMock {
    public enum DiscoverServicesError: Error {
        case discoveryFailed
    }
    public enum DiscoverCharacteristicError: Error {
        case discoveryFailed
    }
    public enum ReadValueError: Error {
        case readFailed
    }
    public enum WriteValueError: Error {
        case writeFailed
    }
    public enum NotifyError: Error {
        case updateStateFailure
    }
    public enum ReadRSSIError: Error {
        case readFailed
    }
}

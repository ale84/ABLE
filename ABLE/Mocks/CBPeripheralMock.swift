//
//  CBPeripheralMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBPeripheralMock: CBPeripheralType {
    
    enum DiscoverServicesError: Error {
        case discoveryFailed
    }
    enum DiscoverCharacteristicError: Error {
        case discoveryFailed
    }
    enum ReadValueError: Error {
        case readFailed
    }
    enum WriteValueError: Error {
        case writeFailed
    }
    enum NotifyError: Error {
        case updateStateFailure
    }
    enum ReadRSSIError: Error {
        case readFailed
    }
    
    enum DiscoverServicesBehaviour {
        case success(with: [CBServiceType], after: TimeInterval)
        case failure
    }
    
    enum DiscoverCharacteristicsBehaviour {
        case success(with: CBServiceType, after: TimeInterval)
        case failure
    }
    
    enum ReadValueBehaviour {
        case success
        case failure
    }
    
    enum WriteValueBehaviour {
        case success
        case failure
    }
    
    enum NotifyBehaviour {
        case success
        case failure
    }
    
    enum ReadRSSIBehaviour {
        case success
        case failure
    }
    
    var discoverServicesBehaviour: DiscoverServicesBehaviour = .success(with: [], after: 0)
    var discoverCharacteristicsBehaviour: DiscoverCharacteristicsBehaviour = .failure
    var readValueBehaviour: ReadValueBehaviour = .success
    var writeValueBehaviour: WriteValueBehaviour = .success
    var notifyBehaviour: NotifyBehaviour = .success
    var readRSSIBehaviour: ReadRSSIBehaviour = .success

    public var delegateType: CBPeripheralDelegateType?
    
    public var name: String?
    
    public var state: CBPeripheralState = .connected
    
    public var canSendWriteWithoutResponse: Bool = false
    
    public var identifier: UUID = UUID()
    
    public var cbServices: [CBServiceType]? = []
    
    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        switch discoverServicesBehaviour {
        case .success(let services, let interval):
            delay(interval) {
                self.cbServices = services
                self.delegateType?.peripheral(self, didDiscoverServices: nil)
            }
        case .failure:
            delegateType?.peripheral(self, didDiscoverServices: DiscoverServicesError.discoveryFailed)
        }
    }
    
    public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBServiceType) { }
    
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBServiceType) {
        switch discoverCharacteristicsBehaviour {
        case .success(let service, let interval):
            delay(interval) {
                self.delegateType?.peripheral(self, didDiscoverCharacteristicsFor: service, error: nil)
            }
        case .failure:
            delegateType?.peripheral(self, didDiscoverCharacteristicsFor: service, error: DiscoverCharacteristicError.discoveryFailed)
        }
    }
    
    public func discoverDescriptors(for characteristic: CBCharacteristicType) { }
    
    public func readValue(for characteristic: CBCharacteristicType) {
        switch readValueBehaviour {
        case .success:
            delegateType?.peripheral(self, didUpdateValueFor: characteristic, error: nil)
        case .failure:
            delegateType?.peripheral(self, didUpdateValueFor: characteristic, error: ReadValueError.readFailed)
        }
    }
    
    public func writeValue(_ data: Data, for characteristic: CBCharacteristicType, type: CBCharacteristicWriteType) {
        switch writeValueBehaviour {
        case .success:
            delegateType?.peripheral(self, didWriteValueFor: characteristic, error: nil)
        case .failure:
            delegateType?.peripheral(self, didWriteValueFor: characteristic, error: WriteValueError.writeFailed)
        }
    }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristicType) {
        switch notifyBehaviour {
        case .success:
            delegateType?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: nil)
            if enabled {
                delegateType?.peripheral(self, didUpdateValueFor: characteristic, error: nil)
            }
        case .failure:
            delegateType?.peripheral(self, didUpdateNotificationStateFor: characteristic, error: NotifyError.updateStateFailure)
        }
    }
    
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return 100
    }
    
    public func readRSSI() {
        switch readRSSIBehaviour {
        case .success:
            delegateType?.peripheral(self, didReadRSSI: NSNumber(value: -30), error: nil)
        case .failure:
            delegateType?.peripheral(self, didReadRSSI: NSNumber(value: 0), error: ReadRSSIError.readFailed)
        }
    }
    
    public func readValue(for descriptor: CBDescriptor) { }
    
    public func writeValue(_ data: Data, for descriptor: CBDescriptor) { }
}

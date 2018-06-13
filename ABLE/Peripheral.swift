//
//  Peripheral.swift
//  aBLE
//
//  Created by Alessio Orlando on 05/04/17.
//  Copyright © 2017 aBLE. All rights reserved.
//

import Foundation
import CoreBluetooth

// MARK: - PeripheralAdvertisements -

public struct PeripheralAdvertisements {
    
    let advertisements: [String : Any]
    
    public var localName: String? {
        return advertisements[CBAdvertisementDataLocalNameKey] as? String
    }
    
    public var manufactuereData: Data? {
        return advertisements[CBAdvertisementDataManufacturerDataKey] as? Data
    }
    
    public var txPower: NSNumber? {
        return advertisements[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }
    
    public var isConnectable: NSNumber? {
        return advertisements[CBAdvertisementDataIsConnectable] as? NSNumber
    }
    
    public var serviceUUIDs: [CBUUID]? {
        return advertisements[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }
    
    public var serviceData: [CBUUID : Data]? {
        return advertisements[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data]
    }
    
    public var overflowServiceUUIDs: [CBUUID]? {
        return advertisements[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }
    
    public var solicitedServiceUUIDs: [CBUUID]? {
        return advertisements[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }
}

public class Peripheral: NSObject {
    
    public enum PeripheralError: Error {
        case timeoutReached
        case cbError(detail: Error)
    }
    
    private struct DiscoverServicesAttempt {
        var uuids: [CBUUID]
        var completion: DiscoverServicesCompletion
        var timer: Timer
        var isValid: Bool {
            return timer.isValid
        }
        
        func invalidate() {
            timer.invalidate()
        }
    }
    
    private struct DiscoverCharacteristicsAttempt {
        var uuids: [CBUUID]
        var completion: DiscoverCharacteristicsCompletion
        var timer: Timer
        var isValid: Bool {
            return timer.isValid
        }
        
        func invalidate() {
            timer.invalidate()
        }
    }
    
    public private (set) var cbPeripheral: CBPeripheralType

    /// Connection name.
    public var name: String? {
        return cbPeripheral.name
    }
    
    /// Connection state.
    public var isConnected: Bool {
        return cbPeripheral.state == .connected
    }
    
    public var discoveredServices: [CBService] {
        return cbPeripheral.services ?? []
    }
    
    public var RSSI: Int
    
    public var state: CBPeripheralState {
        return cbPeripheral.state
    }
    
    public private(set) var advertisements: PeripheralAdvertisements
    
    public typealias ReadRSSICompletion = ((Result<Int>) -> Void)
    private var readRSSICompletion: ReadRSSICompletion?
    
    public typealias DiscoverServicesCompletion = ((Result<[CBService]>) -> Void)
    private var discoverServicesAttempt: DiscoverServicesAttempt?
    
    public typealias DiscoverCharacteristicsCompletion = ((Result<[CBCharacteristic]>) -> Void)
    private var discoverCharacteristicsAttempt: DiscoverCharacteristicsAttempt?
    
    public typealias ReadCharacteristicCompletion = ((Result<Data>) -> Void)
    private var readCharacteristicCompletion: ReadCharacteristicCompletion?
    
    public typealias WriteCharacteristicCompletion = ((Result<Void>) -> Void)
    private var writeCharacteristicCompletion: WriteCharacteristicCompletion?
    
    public typealias SetNotifyUpdateStateCompletion = ((Result<Void>) -> Void)
    private var setNotifyUpdateStateCompletion: SetNotifyUpdateStateCompletion?
    
    public typealias SetNotifyUpdateValueCallback = ((Result<Data>) -> Void)
    private var setNotifyUpdateValueCallback: SetNotifyUpdateValueCallback?
    
    private var peripheralDelegateProxy: CBPeripheralDelegateProxy?
    
    public init(with peripheral: CBPeripheralType, advertisements: [String : Any] = [:], RSSI: Int = 0) {
        self.cbPeripheral = peripheral
        self.advertisements = PeripheralAdvertisements(advertisements: advertisements)
        self.RSSI = RSSI
        super.init()
        peripheral.delegateType = self
        
        if let peripheral = peripheral as? CBPeripheral {
            self.peripheralDelegateProxy = CBPeripheralDelegateProxy(withTarget: self)
            peripheral.delegate = peripheralDelegateProxy
            Logger.debug("peripheral delegate set. \(String(describing: peripheral.delegate))")
        }
    }
    
    public func readRSSI(with completion: @escaping ReadRSSICompletion) {
        self.readRSSICompletion = completion
        cbPeripheral.readRSSI()
    }
    
    public func discoverServices(with uuid: [CBUUID], timeout: TimeInterval = 3, completion: @escaping DiscoverServicesCompletion) {
        discoverServicesAttempt?.invalidate()
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleDiscoverServicesTimeoutReached(timer:)), userInfo: nil, repeats: false)
        discoverServicesAttempt = DiscoverServicesAttempt(uuids: uuid, completion: completion, timer: timer)
        cbPeripheral.discoverServices(uuid)
        Logger.debug("start discovering services: \(uuid), timeout: \(timeout)")
    }
    
    public func discoverCharacteristics(with uuid: [CBUUID], service: CBService, timeout: TimeInterval = 3, completion: @escaping DiscoverCharacteristicsCompletion) {
        discoverCharacteristicsAttempt?.invalidate()
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleDiscoverCharacteristicsTimeoutReached(timer:)), userInfo: nil, repeats: false)
        discoverCharacteristicsAttempt = DiscoverCharacteristicsAttempt(uuids: uuid, completion: completion, timer: timer)
        cbPeripheral.discoverCharacteristics(uuid, for: service)
        Logger.debug("start discovering characteristics: \(uuid) from: \(service), timeout: \(timeout)")
    }
    
    public func service(for uuid: CBUUID) -> CBService? {
        return cbPeripheral.services?.filter { $0.uuid == uuid }.first
    }
    
    public func characteristic(for uuid: CBUUID, service: CBService) -> CBCharacteristic? {
        return service.characteristics?.filter { $0.uuid == uuid }.first
    }
    
    public func readValue(for characteristic: CBCharacteristic, completion: @escaping ReadCharacteristicCompletion) {
        self.readCharacteristicCompletion = completion
        cbPeripheral.readValue(for: characteristic)
    }
    
    public func write(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType, completion: @escaping WriteCharacteristicCompletion) {
        if type == .withResponse {
            writeCharacteristicCompletion = completion
        }
        cbPeripheral.writeValue(data, for: characteristic, type: type)
    }
    
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic, updateState: @escaping SetNotifyUpdateStateCompletion, updateValue: @escaping SetNotifyUpdateValueCallback) {
        setNotifyUpdateStateCompletion = updateState
        setNotifyUpdateValueCallback = updateValue
        Logger.debug("peripheral setting notyfy: \(enabled), for: \(characteristic)")
        cbPeripheral.setNotifyValue(enabled, for: characteristic)
    }
    
    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        return cbPeripheral.maximumWriteValueLength(for: type)
    }
    
    @objc private func handleDiscoverServicesTimeoutReached(timer: Timer) {
        Logger.debug("discover services timeout reached.")
        if let attempt = discoverServicesAttempt, attempt.isValid {
            attempt.completion(.failure(PeripheralError.timeoutReached))
            attempt.invalidate()
        }
        discoverServicesAttempt = nil
    }
    
    @objc private func handleDiscoverCharacteristicsTimeoutReached(timer: Timer) {
        Logger.debug("discover characteristics timeout reached.")
        if let attempt = discoverCharacteristicsAttempt, attempt.isValid {
            attempt.completion(.failure(PeripheralError.timeoutReached))
            attempt.invalidate()
        }
        discoverCharacteristicsAttempt = nil
    }
}

extension Peripheral {
    override public var hash: Int {
        return cbPeripheral.identifier.hashValue
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        if let otherPeripheral = object as? Peripheral {
            return cbPeripheral.identifier.uuidString == otherPeripheral.cbPeripheral.identifier.uuidString
        }
        else {
            return false
        }
    }
}

extension Peripheral {
    override public var debugDescription: String {
        return name ?? "-"
    }
}

extension Peripheral: CBPeripheralDelegateType {
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverServices error: Error?) {
        if let attempt = discoverServicesAttempt {
            discoverServicesAttempt = nil
            if let error = error {
                Logger.debug("discover services failure: \(error)")
                attempt.completion(.failure(PeripheralError.cbError(detail: error)))
            }
            else {
                Logger.debug("discover services success: \(String(describing: peripheral.services))")
                attempt.completion(.success(cbPeripheral.services ?? []))
            }
            attempt.invalidate()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverIncludedServicesFor service: CBService, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let attempt = discoverCharacteristicsAttempt {
            discoverCharacteristicsAttempt = nil
            if let error = error {
                Logger.debug("discover characteristics failure: \(error)")
                attempt.completion(.failure(PeripheralError.cbError(detail: error)))
            }
            else {
                Logger.debug("discover characteristics success: \(String(describing: service.characteristics))")
                attempt.completion(.success(service.characteristics ?? []))
            }
            attempt.invalidate()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let readCompletion = readCharacteristicCompletion
        readCharacteristicCompletion = nil
        if let error = error {
            readCompletion?(.failure(PeripheralError.cbError(detail: error)))
            setNotifyUpdateValueCallback?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            Logger.debug("peripheral characteristic update value for: \(characteristic)")
            readCompletion?(.success(characteristic.value ?? Data()))
            setNotifyUpdateValueCallback?(.success(characteristic.value ?? Data()))
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor descriptor: CBDescriptor, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let completion = writeCharacteristicCompletion
        writeCharacteristicCompletion = nil
        if let error = error {
            completion?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            completion?(.success(()))
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor descriptor: CBDescriptor, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        let updateStateCompletion = setNotifyUpdateStateCompletion
        setNotifyUpdateStateCompletion = nil
        if let error = error {
            updateStateCompletion?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            updateStateCompletion?(.success(()))
            if characteristic.isNotifying == false {
                setNotifyUpdateValueCallback = nil
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didReadRSSI RSSI: NSNumber, error: Error?) {
        let completion = readRSSICompletion
        readRSSICompletion = nil
        if let error = error {
            completion?(.failure(error))
        }
        else {
            completion?(.success(RSSI.intValue))
        }
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheralType) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didModifyServices invalidatedServices: [CBService]) { }
    
    @available(iOS 11.0, *)
    public func peripheral(_ peripheral: CBPeripheralType, didOpen channel: CBL2CAPChannel?, error: Error?) { }
    
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheralType) { }
}

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
    
    public private (set) var cbPeripheral: CBPeripheral

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
    
    public init(with peripheral: CBPeripheral, advertisements: [String : Any] = [:], RSSI: Int = 0) {
        self.cbPeripheral = peripheral
        self.advertisements = PeripheralAdvertisements(advertisements: advertisements)
        self.RSSI = RSSI
        super.init()
        cbPeripheral.delegate = self
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

extension Peripheral: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let error = error {
            readRSSICompletion?(.failure(error))
        }
        else {
            readRSSICompletion?(.success(RSSI.intValue))
        }
        readRSSICompletion = nil
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let attempt = discoverServicesAttempt {
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
        discoverServicesAttempt = nil
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let attempt = discoverCharacteristicsAttempt {
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
        discoverCharacteristicsAttempt = nil
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            readCharacteristicCompletion?(.failure(PeripheralError.cbError(detail: error)))
            setNotifyUpdateValueCallback?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            Logger.debug("peripheral characteristic update value for: \(characteristic)")
            readCharacteristicCompletion?(.success(characteristic.value ?? Data()))
            setNotifyUpdateValueCallback?(.success(characteristic.value ?? Data()))
        }
        readCharacteristicCompletion = nil
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            writeCharacteristicCompletion?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            writeCharacteristicCompletion?(.success(()))
        }
        writeCharacteristicCompletion = nil
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            setNotifyUpdateStateCompletion?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            setNotifyUpdateStateCompletion?(.success(()))
            if characteristic.isNotifying == false {
                setNotifyUpdateValueCallback = nil
            }
        }
        setNotifyUpdateStateCompletion = nil
    }
}

extension Peripheral {
    override public var debugDescription: String {
        return name ?? "-"
    }
}

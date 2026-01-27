//
//  Created by Alessio Orlando on 05/04/17.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
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

// MARK: - Peripheral -
public class Peripheral: NSObject {
    
    public private(set) var cbPeripheral: CBPeripheralType

    /// Connection name.
    public var name: String? {
        return cbPeripheral.name
    }
    
    /// Connection state.
    public var isConnected: Bool {
        return cbPeripheral.state == .connected
    }
    
    public var discoveredServices: [Service] {
        return cbPeripheral.cbServices?.map { Service(with: $0) } ?? []
    }
    
    public var RSSI: Int
    
    public var state: CBPeripheralState {
        return cbPeripheral.state
    }
    
    public var ancsAuthorized: Bool {
        return cbPeripheral.ancsAuthorized
    }
    
    public private(set) var advertisements: PeripheralAdvertisements
    
    private var readRSSICompletion: ReadRSSICompletion?
    private var discoverServicesAttempt: DiscoverServicesAttempt?
    private var discoverCharacteristicsAttempt: DiscoverCharacteristicsAttempt?
    private var readCharacteristicCompletion: ReadCharacteristicCompletion?
    private var writeCharacteristicCompletion: WriteCharacteristicCompletion?
    private var setNotifyUpdateStateCompletion: SetNotifyUpdateStateCompletion?
    private var setNotifyUpdateValueCallback: SetNotifyUpdateValueCallback?
    private var peripheralDelegateProxy: CBPeripheralDelegateProxy?
    
    // MARK: Async api support.
    internal var discoverServicesCoordinator = DiscoverServicesCoordinator()
    internal var discoverCharacteristicsCoordinator = DiscoverCharacteristicsCoordinator()
    internal var notifyCoordinator = NotifyCoordinator()
    
    public init(with peripheral: CBPeripheralType, advertisements: [String : Any] = [:], RSSI: Int = 0) {
        self.cbPeripheral = peripheral
        self.advertisements = PeripheralAdvertisements(advertisements: advertisements)
        self.RSSI = RSSI
        super.init()
        peripheral.cbDelegate = self
        
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
    
    public func service(for uuid: CBUUID) -> Service? {
        return discoveredServices.filter { $0.cbService.uuid == uuid }.first
    }
    
    public func characteristic(for uuid: CBUUID, service: Service) -> Characteristic? {
        return service.characteristics.filter { $0.uuid == uuid }.first
    }
    
    public func readValue(for characteristic: Characteristic, completion: @escaping ReadCharacteristicCompletion) {
        self.readCharacteristicCompletion = completion
        cbPeripheral.readValue(for: characteristic.cbCharacteristic)
    }
    
    public func write(_ data: Data, for characteristic: Characteristic, type: CBCharacteristicWriteType, completion: @escaping WriteCharacteristicCompletion) {
        if type == .withResponse {
            writeCharacteristicCompletion = completion
        }
        cbPeripheral.writeValue(data, for: characteristic.cbCharacteristic, type: type)
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

// MARK: Public support.
public extension Peripheral {
    enum PeripheralError: Error {
        case timeoutReached
        case cbError(detail: Error)

        case discoverServicesReplaced
        case discoverServicesCancelled
        case discoverServicesTimeout

        case discoverCharacteristicsReplaced(service: CBUUID)
        case discoverCharacteristicsTimedOut(service: CBUUID)
        case discoverCharacteristicsCancelled(service: CBUUID)
        
        case notifyReplaced(characteristic: CBUUID)
        case notifyCancelled(characteristic: CBUUID)
        case notifyEnableFailed(characteristic: CBUUID, underlying: Error?)
        case notifyValueFailed(characteristic: CBUUID, underlying: Error?)

    }
}

// MARK: Private support.
private extension Peripheral {
    struct DiscoverServicesAttempt {
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
    
    struct DiscoverCharacteristicsAttempt {
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
}

// MARK: Equality.
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

// MARK: CBPeripheral delegate.
extension Peripheral: CBPeripheralDelegateType {
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverServices error: Error?) {
        Task {
            if let error = error {
                await discoverServicesCoordinator.fail(error: PeripheralError.cbError(detail: error))
            } else {
                await discoverServicesCoordinator.succeed(services: discoveredServices)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverIncludedServicesFor service: CBServiceType, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType,
                           didDiscoverCharacteristicsFor service: CBServiceType,
                           error: Error?) {
        let serviceUUID = service.uuid

        Task { [weak self] in
            guard let self else { return }

            if let error {
                await self.discoverCharacteristicsCoordinator.fail(
                    serviceUUID: serviceUUID,
                    error: PeripheralError.cbError(detail: error)
                )
                return
            }

            let chars = (service.cbCharacteristics ?? []).map { Characteristic(with: $0) }

            await self.discoverCharacteristicsCoordinator.succeed(
                serviceUUID: serviceUUID,
                characteristics: chars
            )
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didDiscoverDescriptorsFor characteristic: CBCharacteristicType, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType,
                           didUpdateValueFor characteristic: CBCharacteristicType,
                           error: Error?) {

        // 1) One-shot read (se esiste)
        let readCompletion = readCharacteristicCompletion
        readCharacteristicCompletion = nil
        if let error = error {
            readCompletion?(.failure(PeripheralError.cbError(detail: error)))
        } else {
            readCompletion?(.success(characteristic.value ?? Data()))
        }

        // 2) Notify stream / legacy (se esiste)
        let uuid = characteristic.uuid
        Task { [weak self] in
            guard let self else { return }
            await self.notifyCoordinator.handleDidUpdateValue(
                characteristicUUID: uuid,
                data: characteristic.value,
                error: error
            )
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didUpdateValueFor descriptor: CBDescriptor, error: Error?) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didWriteValueFor characteristic: CBCharacteristicType, error: Error?) {
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
  
    public func peripheral(_ peripheral: CBPeripheralType,
                           didUpdateNotificationStateFor characteristic: CBCharacteristicType,
                           error: Error?) {
        let uuid = characteristic.uuid
        Task { [weak self] in
            guard let self else { return }
            await self.notifyCoordinator.handleDidUpdateNotificationState(
                characteristicUUID: uuid,
                isNotifying: characteristic.isNotifying,
                error: error
            )
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheralType, didReadRSSI RSSI: NSNumber, error: Error?) {
        let completion = readRSSICompletion
        readRSSICompletion = nil
        if let error = error {
            completion?(.failure(PeripheralError.cbError(detail: error)))
        }
        else {
            completion?(.success(RSSI.intValue))
        }
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheralType) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didModifyServices invalidatedServices: [CBServiceType]) { }
    
    public func peripheral(_ peripheral: CBPeripheralType, didOpen channel: CBL2CAPChannel?, error: Error?) { }
    
    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheralType) { }
}

// MARK: Aliases.
public extension Peripheral {
    typealias ReadRSSICompletion = ((Result<Int, PeripheralError>) -> Void)
    typealias DiscoverServicesCompletion = ((Result<[Service], PeripheralError>) -> Void)
    typealias DiscoverCharacteristicsCompletion = ((Result<[Characteristic], PeripheralError>) -> Void)
    typealias ReadCharacteristicCompletion = ((Result<Data, PeripheralError>) -> Void)
    typealias WriteCharacteristicCompletion = ((Result<Void, PeripheralError>) -> Void)
    typealias SetNotifyUpdateStateCompletion = ((Result<Void, PeripheralError>) -> Void)
    typealias SetNotifyUpdateValueCallback = ((Result<Data, PeripheralError>) -> Void)
}

// MARK: Debug.
extension Peripheral {
    override public var debugDescription: String {
        return name ?? "-"
    }
}

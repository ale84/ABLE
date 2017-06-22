//
//  PeripheralManager.swift
//  Cinello
//
//  Created by Alessio Orlando on 15/05/17.
//  Copyright © 2017 Cinello. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol PeripheralManagerDelegate: class {
    func didUpdateState(_ state: ManagerState, from peripheralManager: PeripheralManager)
}

public class PeripheralManager: NSObject {
    
    // MARK: Enums.
    
    public enum PeripheralManagerError: Error {
        case cbError(Error)
    }
    
    public enum PeripheralManagerNotification: String {
        case stateChanged = "it.able.peripheralmanager.statechangednotification"
        
        var notificationName: Notification.Name {
            return Notification.Name(rawValue)
        }
    }
    
    // MARK: Nested types.
    
    fileprivate struct WaitForStateAttempt {
        var state: ManagerState
        var completion: WaitForStateCompletion
        var timer: Timer
        var isValid: Bool {
            return timer.isValid
        }
        
        func invalidate() {
            timer.invalidate()
        }
    }
    
    fileprivate struct AddServiceAttempt: Hashable {
        private (set) var service: CBMutableService
        private (set) var completion: AddServiceCompletion
        
        static func == (lhs: AddServiceAttempt, rhs: AddServiceAttempt) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
        
        var hashValue: Int {
            return service.hashValue
        }
    }

    // MARK: Aliases.

    public typealias WaitForStateCompletion = ((ManagerState) -> Void)
    public typealias AddServiceCompletion = ((Result<CBService>) -> Void)
    public typealias StartAdvertisingCompletion = ((Result<Void>) -> Void)
    public typealias ReadyToUpdateSubscribersCallback = ((Void) -> Void)
    public typealias ReadRequestCallback = ((CBATTRequest) -> Void)
    public typealias WriteRequestsCallback = (([CBATTRequest]) -> Void)
    public typealias StateChangedCallback = ((ManagerState) -> Void)

    // MARK: -.

    public weak var delegate: PeripheralManagerDelegate?
    
    fileprivate var waitForStateAttempt: WaitForStateAttempt?
    fileprivate var addServiceCompletion: AddServiceCompletion?
    fileprivate var startAdvertisingCompletion: StartAdvertisingCompletion?
    fileprivate var readyToUpdateCallback: ReadyToUpdateSubscribersCallback?
    
    fileprivate var addServiceAttempts: Set<AddServiceAttempt> = []
    
    fileprivate (set) var cbPeripheralManager: CBPeripheralManager
    
    public var readRequestCallback: ReadRequestCallback?
    public var writeRequestsCallback: WriteRequestsCallback?
    public var stateChangedCallback: StateChangedCallback?
    
    public var state: ManagerState {
        if #available(iOS 10.0, *) {
            return ManagerState(with: cbPeripheralManager.state)
        }
        else {
            // Fallback on earlier versions
            return ManagerState(with: cbPeripheralManager.state.rawValue)
        }
    }
    
    public var isAdvertising: Bool {
        return cbPeripheralManager.isAdvertising
    }
    
    public init(_ delegate: PeripheralManagerDelegate? = nil, queue: DispatchQueue?, options: [String : Any]? = nil) {
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: queue, options: options)
        super.init()
        cbPeripheralManager.delegate = self
    }
    
    public func wait(for state: ManagerState, timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        if state == self.state {
            completion(state)
            return
        }
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleWaitStateTimeoutReached(_:)), userInfo: nil, repeats: false)
        waitForStateAttempt = WaitForStateAttempt(state: state, completion: completion, timer: timer)
    }
    
    public class func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    public func add(_ service: CBMutableService, completion: @escaping AddServiceCompletion) {
        let addServiceAttempt = AddServiceAttempt(service: service, completion: completion)
        addServiceAttempts.update(with: addServiceAttempt)
        
        cbPeripheralManager.add(service)
    }
    
    public func remove(_ service: CBMutableService) {
        cbPeripheralManager.remove(service)
    }
    
    public func removeAllServices() {
        cbPeripheralManager.removeAllServices()
    }
    
    public func startAdvertising(_ advertisementData: [String : Any]?, completion: @escaping StartAdvertisingCompletion) {
        startAdvertisingCompletion = completion
        cbPeripheralManager.startAdvertising(advertisementData)
    }
    
    public func startAdvertising(with localName: String? = nil, UUIDs: [CBUUID]? = nil, completion: @escaping StartAdvertisingCompletion) {
        var advertisementData: [String : Any] = [:]
        if let localName = localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }
        if let UUIDs = UUIDs {
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = UUIDs
        }
        startAdvertising(advertisementData, completion: completion)
    }
    
    public func stopAdvertising() {
        cbPeripheralManager.stopAdvertising()
    }
    
    public func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?, readyToUpdateCallback: @escaping ReadyToUpdateSubscribersCallback) -> Bool {
        self.readyToUpdateCallback = readyToUpdateCallback
        return cbPeripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
    }
    
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        cbPeripheralManager.respond(to: request, withResult: result)
    }
    
    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) {
        cbPeripheralManager.setDesiredConnectionLatency(latency, for: central)
    }
}

// MARK: Timers handling.
extension PeripheralManager {
    @objc fileprivate func handleWaitStateTimeoutReached(_ timer: Timer) {
        if let attempt = waitForStateAttempt, attempt.isValid {
            attempt.invalidate()
            attempt.completion(state)
        }
    }
}

extension PeripheralManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Logger.debug("peripheral manager updated state: \(state)")
        stateChangedCallback?(state)
        delegate?.didUpdateState(state, from: self)
        NotificationCenter.default.post(name: PeripheralManagerNotification.stateChanged.notificationName, object: self, userInfo: ["state": state])
        if let attempt = waitForStateAttempt, attempt.isValid {
            attempt.completion(state)
            attempt.invalidate()
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let attempt = addServiceAttempts.filter({ $0.service.uuid.uuidString == service.uuid.uuidString }).first {
            if let error = error {
                attempt.completion(.failure(PeripheralManagerError.cbError(error)))
            }
            else {
                attempt.completion(.success(service))
            }
            addServiceAttempts.remove(attempt)
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            startAdvertisingCompletion?(.failure(PeripheralManagerError.cbError(error)))
        }
        else {
            startAdvertisingCompletion?(.success())
        }
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        readyToUpdateCallback?()
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        readRequestCallback?(request)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        writeRequestsCallback?(requests)
    }
}
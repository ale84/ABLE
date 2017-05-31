//
//  PeripheralManager.swift
//  Cinello
//
//  Created by Alessio Orlando on 15/05/17.
//  Copyright © 2017 Cinello. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol PeripheralManagerDelegate: class {
    func didUpdateState(_ state: ManagerState, from peripheralManager: PeripheralManager)
}

class PeripheralManager: NSObject {
    
    // MARK: Enums.
    
    enum PeripheralManagerError: Error {
        case cbError(Error)
    }
    
    enum PeripheralManagerNotification: String {
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

    typealias WaitForStateCompletion = ((ManagerState) -> Void)
    typealias AddServiceCompletion = ((Result<CBService>) -> Void)
    typealias StartAdvertisingCompletion = ((Result<Void>) -> Void)
    typealias ReadyToUpdateSubscribersCallback = ((Void) -> Void)
    typealias ReadRequestCallback = ((CBATTRequest) -> Void)
    typealias WriteRequestsCallback = (([CBATTRequest]) -> Void)
    typealias StateChangedCallback = ((ManagerState) -> Void)

    // MARK: -.

    weak var delegate: PeripheralManagerDelegate?
    
    fileprivate var waitForStateAttempt: WaitForStateAttempt?
    fileprivate var addServiceCompletion: AddServiceCompletion?
    fileprivate var startAdvertisingCompletion: StartAdvertisingCompletion?
    fileprivate var readyToUpdateCallback: ReadyToUpdateSubscribersCallback?
    
    fileprivate var addServiceAttempts: Set<AddServiceAttempt> = []
    
    fileprivate (set) var cbPeripheralManager: CBPeripheralManager
    
    var readRequestCallback: ReadRequestCallback?
    var writeRequestsCallback: WriteRequestsCallback?
    var stateChangedCallback: StateChangedCallback?
    
    var state: ManagerState {
        if #available(iOS 10.0, *) {
            return ManagerState(with: cbPeripheralManager.state)
        } else {
            // Fallback on earlier versions
            return ManagerState(with: cbPeripheralManager.state.rawValue)
        }
    }
    
    var isAdvertising: Bool {
        return cbPeripheralManager.isAdvertising
    }
    
    init(_ delegate: PeripheralManagerDelegate? = nil, queue: DispatchQueue?, options: [String : Any]? = nil) {
        cbPeripheralManager = CBPeripheralManager(delegate: nil, queue: queue, options: options)
        super.init()
        cbPeripheralManager.delegate = self
    }
    
    func wait(for state: ManagerState, timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        if state == self.state {
            completion(state)
            return
        }
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleWaitStateTimeoutReached(_:)), userInfo: nil, repeats: false)
        waitForStateAttempt = WaitForStateAttempt(state: state, completion: completion, timer: timer)
    }
    
    class func authorizationStatus() -> CBPeripheralManagerAuthorizationStatus {
        return CBPeripheralManager.authorizationStatus()
    }
    
    func add(_ service: CBMutableService, completion: @escaping AddServiceCompletion) {
        let addServiceAttempt = AddServiceAttempt(service: service, completion: completion)
        addServiceAttempts.update(with: addServiceAttempt)
        
        cbPeripheralManager.add(service)
    }
    
    func remove(_ service: CBMutableService) {
        cbPeripheralManager.remove(service)
    }
    
    func removeAllServices() {
        cbPeripheralManager.removeAllServices()
    }
    
    func startAdvertising(_ advertisementData: [String : Any]?, completion: @escaping StartAdvertisingCompletion) {
        startAdvertisingCompletion = completion
        cbPeripheralManager.startAdvertising(advertisementData)
    }
    
    func startAdvertising(with localName: String? = nil, UUIDs: [CBUUID]? = nil, completion: @escaping StartAdvertisingCompletion) {
        var advertisementData: [String : Any] = [:]
        if let localName = localName {
            advertisementData[CBAdvertisementDataLocalNameKey] = localName
        }
        if let UUIDs = UUIDs {
            advertisementData[CBAdvertisementDataServiceUUIDsKey] = UUIDs
        }
        startAdvertising(advertisementData, completion: completion)
    }
    
    func stopAdvertising() {
        cbPeripheralManager.stopAdvertising()
    }
    
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?, readyToUpdateCallback: @escaping ReadyToUpdateSubscribersCallback) -> Bool {
        self.readyToUpdateCallback = readyToUpdateCallback
        return cbPeripheralManager.updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
    }
    
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        cbPeripheralManager.respond(to: request, withResult: result)
    }
    
    func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) {
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
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Logger.debug("peripheral manager updated state: \(state)")
        stateChangedCallback?(state)
        delegate?.didUpdateState(state, from: self)
        NotificationCenter.default.post(name: PeripheralManagerNotification.stateChanged.notificationName, object: self, userInfo: ["state": state])
        if let attempt = waitForStateAttempt, attempt.isValid {
            attempt.completion(state)
            attempt.invalidate()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let attempt = addServiceAttempts.filter ({ $0.service.uuid.uuidString == service.uuid.uuidString }).first {
            if let error = error {
                attempt.completion(.failure(PeripheralManagerError.cbError(error)))
            }
            else {
                attempt.completion(.success(service))
            }
            addServiceAttempts.remove(attempt)
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            startAdvertisingCompletion?(.failure(PeripheralManagerError.cbError(error)))
        }
        else {
            startAdvertisingCompletion?(.success())
        }
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        readyToUpdateCallback?()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        readRequestCallback?(request)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        writeRequestsCallback?(requests)
    }
}

//
//  Created by Alessio Orlando on 15/05/17.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class PeripheralManager: NSObject {
    
    public var bluetoothStateUpdate: BluetoothStateUpdate?
    public var readRequestCallback: ReadRequestCallback?
    public var writeRequestsCallback: WriteRequestsCallback?
    
    public var state: ManagerState {
        return cbPeripheralManager.managerState
    }
    
    @available(iOS 13.0, *)
    public var authorization: ManagerAuthorization {
        return cbPeripheralManager.managerAuthorization
    }
    
    public var isAdvertising: Bool {
        return cbPeripheralManager.isAdvertising
    }
    
    private (set) var cbPeripheralManager: CBPeripheralManagerType
    
    private var waitForStateAttempts: Set<WaitForStateAttempt> = []
    private var addServiceCompletion: AddServiceCompletion?
    private var startAdvertisingCompletion: StartAdvertisingCompletion?
    private var readyToUpdateCallback: ReadyToUpdateSubscribersCallback?
    private var addServiceAttempts: Set<AddServiceAttempt> = []
    
    private var cbPeripheralManagerDelegateProxy: CBPeripheralManagerDelegateProxy?
    
    public init(with peripheralManager: CBPeripheralManagerType,
                queue: DispatchQueue?,
                options: [String : Any]? = nil,
                stateUpdate: BluetoothStateUpdate? = nil) {
        cbPeripheralManager = peripheralManager
        bluetoothStateUpdate = stateUpdate
        
        super.init()
        
        cbPeripheralManager.cbDelegate = self
    }
    
    public convenience init(queue: DispatchQueue?,
                            options: [String : Any]? = nil,
                            stateUpdate: BluetoothStateUpdate? = nil) {
        let manager = CBPeripheralManager(delegate: nil, queue: queue, options: options)
        self.init(with: manager, queue: queue, options: options, stateUpdate: stateUpdate)
        self.cbPeripheralManagerDelegateProxy = CBPeripheralManagerDelegateProxy(withTarget: self)
        manager.delegate = cbPeripheralManagerDelegateProxy
    }
    
    public func waitForPoweredOn(withTimeout timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        wait(for: .poweredOn, timeout: timeout, completion: completion)
    }
    
    public func wait(for state: ManagerState, timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        if state == self.state {
            completion(state)
            return
        }
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleWaitStateTimeoutReached(_:)), userInfo: nil, repeats: false)
        let waitForStateAttempt = WaitForStateAttempt(state: state, completion: completion, timer: timer)
        waitForStateAttempts.update(with: waitForStateAttempt)
    }
    
    @available(iOS, deprecated: 13.0)
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
    
    // MARK: Utilities
    
    private func getWaitForStateAttempt(for timer: Timer) -> WaitForStateAttempt? {
        return waitForStateAttempts.filter { $0.timer == timer }.last
    }
}

// MARK: Timers handling.
extension PeripheralManager {
    @objc private func handleWaitStateTimeoutReached(_ timer: Timer) {
        Logger.debug("ble wait for state timeout reached.")
        if let attempt = getWaitForStateAttempt(for: timer), attempt.isValid {
            attempt.invalidate()
            attempt.completion(state)
            waitForStateAttempts.remove(attempt)
            Logger.debug("Invalidated wait for state attempt: \(attempt).")
            Logger.debug("Wait for state attempts: \(waitForStateAttempts).")
        }
    }
}

// MARK: CBPeripheralManager delegate.
extension PeripheralManager: CBPeripheralManagerDelegateType {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManagerType) {
        Logger.debug("peripheral manager updated state: \(state)")
        
        var toRemove: Set<WaitForStateAttempt> = []
        waitForStateAttempts.filter({ $0.isValid && $0.state == state }).forEach {
            Logger.debug("Wait for state attempt success.")
            $0.completion(state)
            $0.invalidate()
            toRemove.insert($0)
            Logger.debug("Invalidated wait for state attempt: \($0).")
        }
        waitForStateAttempts.subtract(toRemove)
        
        bluetoothStateUpdate?(state)
        
        NotificationCenter.default.post(name: PeripheralManagerNotification.stateChanged.notificationName,
                                        object: self,
                                        userInfo: ["state": state])
        
        Logger.debug("Wait for state attempts: \(waitForStateAttempts).")
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didAdd service: CBServiceType, error: Error?) {
        if let attempt = addServiceAttempts.filter({ $0.service.uuid.uuidString == service.uuid.uuidString }).first {
            if let error = error {
                attempt.completion(.failure(PeripheralManagerError.cbError(error)))
            }
            else {
                let service = Service(with: service)
                attempt.completion(.success(service))
            }
            addServiceAttempts.remove(attempt)
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManagerType, error: Error?) {
        if let error = error {
            startAdvertisingCompletion?(.failure(PeripheralManagerError.cbError(error)))
        }
        else {
            startAdvertisingCompletion?(.success(()))
        }
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManagerType) {
        readyToUpdateCallback?()
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didReceiveRead request: CBATTRequest) {
        readRequestCallback?(request)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didReceiveWrite requests: [CBATTRequest]) {
        writeRequestsCallback?(requests)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, willRestoreState dict: [String : Any]) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didSubscribeTo characteristic: CBCharacteristicType) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristicType) { }
    
    @available(iOS 11.0, *)
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didOpen channel: CBL2CAPChannel?, error: Error?) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) { }
}

// MARK: Public Support.
public extension PeripheralManager {
    
    enum PeripheralManagerError: Error {
        case cbError(Error)
    }
    
    enum PeripheralManagerNotification: String {
        case stateChanged = "it.able.peripheralmanager.statechangednotification"
        
        var notificationName: Notification.Name {
            return Notification.Name(rawValue)
        }
    }

    enum ManagerNotification: String {
        case bluetoothStateChanged = "it.able.centralmanager.bluetoothstatechangednotification"
        
        var notificationName: Notification.Name {
            return Notification.Name(rawValue)
        }
    }
}

// MARK: Private Support.
private extension PeripheralManager {
    
    struct WaitForStateAttempt: Hashable {
        var state: ManagerState
        var completion: WaitForStateCompletion
        var timer: Timer
        var isValid: Bool {
            return timer.isValid
        }
        
        func invalidate() {
            timer.invalidate()
        }
        
        static func == (lhs: WaitForStateAttempt, rhs: WaitForStateAttempt) -> Bool {
            return lhs.timer == rhs.timer
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(timer.hashValue)
        }
    }
    
    struct AddServiceAttempt: Hashable {
        private (set) var service: CBMutableService
        private (set) var completion: AddServiceCompletion
        
        static func == (lhs: AddServiceAttempt, rhs: AddServiceAttempt) -> Bool {
            return lhs.hashValue == rhs.hashValue
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(service.hashValue)
        }
    }
}

// MARK: Aliases.
public extension PeripheralManager {
    typealias BluetoothStateUpdate = ((ManagerState) -> Void)
    typealias WaitForStateCompletion = ((ManagerState) -> (Void))
    typealias AddServiceCompletion = ((Result<Service, PeripheralManagerError>) -> Void)
    typealias StartAdvertisingCompletion = ((Result<Void, PeripheralManagerError>) -> (Void))
    typealias ReadyToUpdateSubscribersCallback = (() -> Void)
    typealias ReadRequestCallback = ((CBATTRequest) -> Void)
    typealias WriteRequestsCallback = (([CBATTRequest]) -> Void)
}

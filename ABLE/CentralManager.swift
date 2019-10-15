//
//  Created by Alessio Orlando on 09/01/17.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

public class CentralManager: NSObject {

    public var bluetoothStateUpdate: BluetoothStateUpdate?

    public var allPeripherals: Set<Peripheral> {
        return foundPeripherals.union(cachedPeripherals)
    }
    
    public static var bluetoothChangedNotification: Notification.Name {
        return ManagerNotification.bluetoothStateChanged.notificationName
    }
    
    public private (set) var cbCentralManager: CBCentralManagerType
    public private (set) var centralQueue: DispatchQueue
    public private (set) var isScanning: Bool = false
    
    public private (set) var knownPeripherals: Set<UUID> = []
    public private (set) var foundPeripherals: Set<Peripheral> = []
    public private (set) var cachedPeripherals: Set<Peripheral> = []
    
    private var userDefaults: UserDefaults
    
    private var waitForStateAttempts: Set<WaitForStateAttempt> = []
    private var scanUpdate: ScanUpdate?
    private var scanAttempt: ScanAttempt?
    private var connectionAttempts: Set<ConnectionAttempt> = []
    private var connectionInfos: Set<ConnectionInfo> = []
    private var disconnectionRequests: Set<DisconnectionRequest> = []
    private var connectionEventCallback: ConnectionEventCallback?
    private var ancsUpdateCallback: AncsAuthUpdateCallback?
    
    private var cbDelegateProxy: CBCentralManagerDelegateProxy?
    
    public init(with centralManager: CBCentralManagerType,
                queue: DispatchQueue?,
                options: [String : Any]? = nil,
                userDefaults: UserDefaults = UserDefaults.standard,
                stateUpdate: BluetoothStateUpdate? = nil) {
        self.centralQueue = queue ?? DispatchQueue.main
        self.cbCentralManager = centralManager
        self.userDefaults = userDefaults
        self.bluetoothStateUpdate = stateUpdate
        
        super.init()
        
        retrieveCachedPeripherals()
        cbCentralManager.cbDelegate = self
    }
    
    public convenience init(queue: DispatchQueue?,
                            options: [String : Any]? = nil,
                            userDefaults: UserDefaults = UserDefaults.standard,
                            stateUpdate: BluetoothStateUpdate? = nil) {
        let manager = CBCentralManager(delegate: nil, queue: queue, options: options)
        self.init(with: manager, queue: queue, options: options, userDefaults: userDefaults, stateUpdate: stateUpdate)
        self.cbDelegateProxy = CBCentralManagerDelegateProxy(withTarget: self)
        manager.delegate = cbDelegateProxy
    }
    
    public var state: ManagerState {
        return cbCentralManager.managerState
    }
    
    @available(iOS 13.0, *)
    public var authorization: ManagerAuthorization {
        return cbCentralManager.managerAuthorization
    }
    
    public func waitForPoweredOn(withTimeout timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        wait(for: .poweredOn, timeout: timeout, completion: completion)
    }
    
    public func wait(for state: ManagerState, timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        if self.state == state {
            completion(self.state)
            return
        }
        
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleWaitStateTimeoutReached(_:)), userInfo: nil, repeats: false)
        let waitForStateAttempt = WaitForStateAttempt(state: state, completion: completion, timer: timer)
        waitForStateAttempts.update(with: waitForStateAttempt)
    }
    
    public func scanForPeripherals(withServices services: [CBUUID]? = nil,
                                   options: [String : Any]? = nil,
                                   update: ScanUpdate? = nil,
                                   timeoutInterval: TimeInterval? = nil,
                                   timeoutCompletion: ScanTimeout? = nil) {
        scanAttempt?.timer.invalidate()
        scanAttempt = nil
        
        scanUpdate = update
        
        Logger.debug("Attempt to start a new ble scan.")
        guard cbCentralManager.managerState == .poweredOn else {
            //timeoutCompletion?(.failure(CentralManagerError.bluetoothNotAvailable(state)))
            return
        }
        
        if let timeoutInterval = timeoutInterval,
            let timeoutCompletion = timeoutCompletion {
            let timer = Timer.scheduledTimer(timeInterval: timeoutInterval,
                                             target: self,
                                             selector: #selector(handleScanTimeoutReached(_:)),
                                             userInfo: nil,
                                             repeats: false)
            let scanAttempt = ScanAttempt(completion: timeoutCompletion, timer: timer)
            self.scanAttempt = scanAttempt
        }
        
        cbCentralManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
        Logger.debug("ble scan started with services: \(String(describing: services)).")
    }
    
    /// Stop the current BLE scan.
    public func stopScan() {
        cbCentralManager.stopScan()
        scanAttempt?.timer.invalidate()
        scanAttempt = nil
        isScanning = false
        Logger.debug("ble scan stopped.")
    }
    
    public func connect(to peripheral: Peripheral,
                        options: [String : Any]? = nil,
                        attemptTimeout: TimeInterval? = nil,
                        connectionTimeout: TimeInterval? = nil,
                        completion: @escaping ConnectionCompletion)
    {
        let connectionAttempt = ConnectionAttempt(with: peripheral, connectionTimeout: connectionTimeout, completion: completion)
        connectionAttempts.update(with: connectionAttempt)

        if let timeout = attemptTimeout {
            delay(timeout, queue: centralQueue) { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let attempt = strongSelf.connectionAttempts.filter({ $0 === connectionAttempt }).last {
                    completion(.failure(CentralManagerError.connectionTimeoutReached))
                    strongSelf.connectionAttempts.remove(attempt)
                    strongSelf.disconnect(from: peripheral)
                }
            }
        }

        cbCentralManager.connect(peripheral.cbPeripheral, options: options)
    }
    
    public func disconnect(from peripheral: Peripheral, completion: DisconnectionCompletion? = nil) {
        if let completion = completion {
            let disconnectionRequest = DisconnectionRequest(peripheral: peripheral, completion: completion)
            disconnectionRequests.update(with: disconnectionRequest)
        }
        if let connectionInfo = getConnectionInfo(for: peripheral) {
            connectionInfo.timer?.invalidate()
            connectionInfos.remove(connectionInfo)
        }
        
        cbCentralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
        Logger.debug("ble disconnected from peripheral: \(peripheral.cbPeripheral).")
    }
    
    @available(iOS 13.0, *)
    public func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]? = nil,
                                            callback: @escaping ConnectionEventCallback) {
        connectionEventCallback = callback
        cbCentralManager.registerForConnectionEvents(options: options)
        Logger.debug("registered for connection events with options: \(String(describing: options))")
    }
    
    @available(iOS 13.0, *)
    public func startReceivingAncsAuthUpdates(update: @escaping AncsAuthUpdateCallback) {
        self.ancsUpdateCallback = update
    }
    
    private func disconnectAll() {
        Logger.debug("ble disconnect from all peripherals.")
        allPeripherals.forEach { disconnect(from: $0) }
    }
    
    private func peripheral(for cbPeripheral: CBPeripheralType) -> Peripheral? {
        return allPeripherals.filter { $0.cbPeripheral.identifier == cbPeripheral.identifier }.last
    }
    
    private func writeKnownPeripherals() {
        let uuidsArray = Array(knownPeripherals).map { $0.uuidString }
        userDefaults.set(uuidsArray, forKey: UserDefaultsKeys.knownPeripheral.rawValue)
    }
    
    private func readKnownPeripherals() -> Set<UUID> {
        let uuidStrings = userDefaults.stringArray(forKey: UserDefaultsKeys.knownPeripheral.rawValue) ?? []
        let uuids = Set(uuidStrings.map { UUID(uuidString: $0)! })
        return uuids
    }
    
    deinit {
        Logger.debug("ble manager deinit: disconnected from all peripherals.")
        disconnectAll()
    }
    
    private func getConnectionAttempt(for peripheral: Peripheral) -> ConnectionAttempt? {
        return connectionAttempts.filter { $0.peripheral == peripheral }.last
    }
    
    private func getDisconnectionRequest(for peripheral: Peripheral) -> DisconnectionRequest? {
        return disconnectionRequests.filter { $0.peripheral == peripheral }.last
    }
    
    private func getConnectionInfo(for peripheral: Peripheral) -> ConnectionInfo? {
        return connectionInfos.filter { $0.peripheral == peripheral }.last
    }
    
    private func getConnectionInfo(for timer: Timer) -> ConnectionInfo? {
        return connectionInfos.filter { $0.timer == timer }.last
    }
    
    private func getWaitForStateAttempt(for timer: Timer) -> WaitForStateAttempt? {
        return waitForStateAttempts.filter { $0.timer == timer }.last
    }
    
    private func addConnectionInfo(for peripheral: Peripheral, timeout: TimeInterval?) {
        if let existingConnectionInfo = getConnectionInfo(for: peripheral) {
            existingConnectionInfo.timer?.invalidate()
            connectionInfos.remove(existingConnectionInfo)
        }
        var timer: Timer? = nil
        if let timeout = timeout, timeout > 0 {
            timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleConnectionTimeoutReached(_:)), userInfo: nil, repeats: false)
        }
        let connectionInfo = ConnectionInfo(peripheral: peripheral, timer: timer, startDate: Date())
        connectionInfos.insert(connectionInfo)
    }
    
    private func clearAllPeripherals() {
        foundPeripherals = []
        cachedPeripherals = []
    }
    
    private func retrieveCachedPeripherals() {
        knownPeripherals = readKnownPeripherals()
        cachedPeripherals = Set(cbCentralManager.retrievePeripherals(withIdentifiers: Array(knownPeripherals)).map { Peripheral(with: $0) })
    }
    
    private func reset() {
        Logger.debug("reset central initiated.")
        clearAllPeripherals()
        retrieveCachedPeripherals()
    }
}

// MARK: Timers handling.
private extension CentralManager {
    @objc func handleWaitStateTimeoutReached(_ timer: Timer) {
        Logger.debug("ble wait for state timeout reached.")
        if let attempt = getWaitForStateAttempt(for: timer), attempt.isValid {
            attempt.invalidate()
            attempt.completion(state)
            waitForStateAttempts.remove(attempt)
            Logger.debug("Invalidated wait for state attempt: \(attempt).")
            Logger.debug("Wait for state attempts: \(waitForStateAttempts).")
        }
    }
    
    @objc func handleConnectionTimeoutReached(_ timer: Timer) {
        let connectionInfo = getConnectionInfo(for: timer)!
        connectionInfo.timer?.invalidate()
        connectionInfos.remove(connectionInfo)
        disconnect(from: connectionInfo.peripheral)
    }
    
    @objc func handleScanTimeoutReached(_ timer: Timer) {
        Logger.debug("ble scan timeout reached.")
        if let attempt = scanAttempt, attempt.timer.isValid {
            attempt.timer.invalidate()
            stopScan()
            let connectionsArray = Array<Peripheral>(foundPeripherals)
            attempt.completion(.success(connectionsArray))
        }
    }
}

// MARK: CBCentralManager delegate.
extension CentralManager: CBCentralManagerDelegateType {
    public func centralManager(_ central: CBCentralManagerType,
                               didDiscover peripheral: CBPeripheralType,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        Logger.debug("central discovered peripheral: \(peripheral)")
        
        let peripheral = Peripheral(with: peripheral, advertisements: advertisementData, RSSI: RSSI.intValue)
        
        knownPeripherals.insert(peripheral.cbPeripheral.identifier)
        writeKnownPeripherals()
        
        let removed = cachedPeripherals.remove(peripheral)
        Logger.debug("Removed from cached peripherals: \(String(describing: removed))")
        
        foundPeripherals.update(with: peripheral)
        assert(foundPeripherals.isDisjoint(with: cachedPeripherals), "found peripherals and cached peripherals MUST be disjoint.")
        
        scanUpdate?(peripheral)
    }
    
    public func centralManager(_ central: CBCentralManagerType, willRestoreState dict: [String : Any]) { }
    
    public func centralManager(_ central: CBCentralManagerType, didDisconnectPeripheral peripheral: CBPeripheralType, error: Error?) {
        if let peripheral = self.peripheral(for: peripheral),
            let attempt = getDisconnectionRequest(for: peripheral) {
            disconnectionRequests.remove(attempt)
            attempt.completion(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManagerType, didFailToConnect peripheral: CBPeripheralType, error: Error?) {
        Logger.debug("Failed to connect to peripheral: \(peripheral), error: \(String(describing: error))")
        knownPeripherals.remove(peripheral.identifier)
        writeKnownPeripherals()
        if let peripheral = self.peripheral(for: peripheral),
            let attempt = getConnectionAttempt(for: peripheral) {
            connectionAttempts.remove(attempt)
            attempt.completion(.failure(CentralManagerError.connectionFailed(error)))
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManagerType) {
        Logger.debug("ble updated state: \(state)")
        
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
        
        NotificationCenter.default.post(name: ManagerNotification.bluetoothStateChanged.notificationName,
                                        object: self,
                                        userInfo: ["state": state])
        
        Logger.debug("Wait for state attempts: \(waitForStateAttempts).")
    }
    
    public func centralManager(_ central: CBCentralManagerType, didConnect peripheral: CBPeripheralType) {
        Logger.debug("ble did connect to peripheral: \(peripheral).")
        Logger.debug("peripherals: \(allPeripherals).")
        Logger.debug("connection attempts: \(connectionAttempts).")

        if let peripheral = self.peripheral(for: peripheral),
            let attempt = getConnectionAttempt(for: peripheral) {
            connectionAttempts.remove(attempt)
            addConnectionInfo(for: peripheral, timeout: attempt.connectionTimeout)
            attempt.completion(.success(peripheral))
        }
    }
    
    public func centralManager(_ central: CBCentralManagerType,
                               connectionEventDidOccur event: CBConnectionEvent,
                               for peripheral: CBPeripheralType) {
        
        let peripheral = Peripheral(with: peripheral)
        connectionEventCallback?(ConnectionEvent(event: event, peripheral: peripheral))
        
        Logger.debug("connection event did occur: \(event), peripheral: \(peripheral)")
    }
}

// MARK: Private Support.
private extension CentralManager {
    
    enum UserDefaultsKeys: String {
        case knownPeripheral = "it.able.centralmanager.knownPeripheralKey"
    }
        
    class ConnectionAttempt: Hashable {
        private (set) var peripheral: Peripheral
        private (set) var completion: ConnectionCompletion
        private (set) var connectionTimeout: TimeInterval? = nil
        
        init(with peripheral: Peripheral, connectionTimeout: TimeInterval? = nil, completion: @escaping ConnectionCompletion) {
            self.peripheral = peripheral
            self.completion = completion
            self.connectionTimeout = connectionTimeout
        }
        
        static func == (lhs: ConnectionAttempt, rhs: ConnectionAttempt) -> Bool {
            return lhs.peripheral == rhs.peripheral
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(peripheral.hashValue)
        }
    }
    
    struct DisconnectionRequest: Hashable {
        private (set) var peripheral: Peripheral
        private (set) var completion: DisconnectionCompletion
        
        static func == (lhs: DisconnectionRequest, rhs: DisconnectionRequest) -> Bool {
            return lhs.peripheral == rhs.peripheral
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(peripheral.hashValue)
        }
    }
    
    struct ConnectionInfo: Hashable {
        private (set) var peripheral: Peripheral
        private (set) var timer: Timer?
        private (set) var startDate: Date
        
        static func == (lhs: ConnectionInfo, rhs: ConnectionInfo) -> Bool {
            return lhs.peripheral == rhs.peripheral
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(peripheral.hashValue)
        }
    }
    
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
    
    struct ScanAttempt {
        var completion: ScanTimeout
        var timer: Timer
    }
}

// MARK: Public Support.
public extension CentralManager {
    enum CentralManagerError: Error {
        case connectionFailed(Error?)
        case bluetoothNotAvailable(ManagerState)
        case connectionTimeoutReached
    }
    
    enum ManagerNotification: String {
        case bluetoothStateChanged = "it.able.centralmanager.bluetoothstatechangednotification"
        
        var notificationName: Notification.Name {
            return Notification.Name(rawValue)
        }
    }
}

// MARK: Aliases.
public extension CentralManager {
    typealias BluetoothStateUpdate = ((ManagerState) -> Void)
    typealias WaitForStateCompletion = ((ManagerState) -> Void)
    typealias ScanUpdate = ((Peripheral) -> Void)
    typealias ScanTimeout = ((Result<[Peripheral], CentralManagerError>) -> Void)
    typealias ConnectionCompletion = ((Result<Peripheral, CentralManagerError>) -> Void)
    typealias DisconnectionCompletion = ((Peripheral) -> Void)
    typealias ConnectionEvent = (event: CBConnectionEvent, peripheral: Peripheral)
    typealias ConnectionEventCallback = ((ConnectionEvent) -> Void)
    typealias AncsAuthUpdateCallback = ((Peripheral) -> Void)
}

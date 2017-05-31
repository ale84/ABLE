//
//  CentralManager.swift
//  aBLE
//
//  Created by Alessio Orlando on 09/01/17.
//  Copyright © 2017 aBLE. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

/// BLE Manager delegate.
protocol CentralManagerDelegate: class {
    
    func didUpdateBluetoothState(_ state: CentralManager.BluetoothState, from central: CentralManager)
    func didDiscoverPeripheral(_ peripheral: Peripheral, from central: CentralManager)
}

/* TODO:
 - Supporto per retrieve di connessioni già connesse al sistema su inizialiazzazione.
 - Vedere come gestire possibilità di errore di connessione a periferica cachata dovuto a cambio di UUID della periferica.
 - Ampliare il delegato.
 - Definire livelli di accesso alle varie componenti.
 - Chiamare tutti i metodi della central sulla queue specificata su init.
 */
class CentralManager: NSObject {
    
    /// BLE error.
    enum BLEError: Error {
        case connectionFailed(Error?)
        case bluetoothNotAvailable(CentralManager.BluetoothState)
        case connectionTimeoutReached
    }
    
    /// Bluetooth state. Mirrors CBManagerState of CoreBluetooth framework.
    enum BluetoothState: Int {
        case poweredOff
        case poweredOn
        case resetting
        case unauthorized
        case unknown
        case unsupported
        
        @available(iOS 10.0, *)
        init(with state: CBManagerState) {
            switch state {
            case .poweredOff:
                self = .poweredOff
            case .poweredOn:
                self = .poweredOn
            case .resetting:
                self = .resetting
            case .unauthorized:
                self = .unauthorized
            case .unknown:
                self = .unknown
            case .unsupported:
                self = .unsupported
            }
        }
        
        // For iOS < 10 support.
        init(with rawValue: Int) {
            switch rawValue {
            case 1:
                self = .resetting
            case 2:
                self = .unsupported
            case 3: // CBCentralManagerState.unauthorized :
                self = .unauthorized
            case 4: // CBCentralManagerState.poweredOff:
                self = .poweredOff
            case 5: //CBCentralManagerState.poweredOn:
                self = .poweredOn
            default:
                self = .unknown
            }
        }
    }
    
    fileprivate enum ManagerNotification: String {
        case bluetoothStateChanged = "it.able.centralmanager.bluetoothstatechangednotification"
        
        var notificationName: Notification.Name {
            return Notification.Name(rawValue)
        }
    }
    
    fileprivate enum UserDefaultsKeys: String {
        case knownPeripheral = "it.able.centralmanager.knownPeripheralKey"
    }
    
    // MARK: Nested types.
    
    fileprivate struct ConnectionAttempt: Hashable {
        private (set) var peripheral: Peripheral
        private (set) var completion: ConnectionCompletion
        fileprivate var connectionTimeout: TimeInterval? = nil
        
        static func == (lhs: ConnectionAttempt, rhs: ConnectionAttempt) -> Bool {
            return lhs.peripheral.hashValue == rhs.peripheral.hashValue
        }
        
        var hashValue: Int {
            return peripheral.hashValue
        }
    }
    
    fileprivate struct ConnectionInfo: Hashable {
        fileprivate (set) var peripheral: Peripheral
        fileprivate (set) var timer: Timer?
        fileprivate (set) var startDate: Date
        
        static func == (lhs: ConnectionInfo, rhs: ConnectionInfo) -> Bool {
            return lhs.peripheral.hashValue == rhs.peripheral.hashValue
        }
        
        fileprivate var hashValue: Int {
            return peripheral.hashValue
        }
    }
    
    fileprivate struct WaitForStateAttempt {
        var state: BluetoothState
        var completion: WaitForStateCompletion
        var timer: Timer
        var isValid: Bool {
            return timer.isValid
        }
        
        func invalidate() {
            timer.invalidate()
        }
    }
    
    fileprivate struct ScanAttempt {
        var completion: ScanCompletion
        var timer: Timer
    }
    
    // MARK: Aliases.
    
    typealias ConnectionCompletion = ((Result<Peripheral>) -> Void)
    typealias ScanCompletion = ((Result<[Peripheral]>) -> Void)
    typealias WaitForStateCompletion = ((BluetoothState) -> Void)
    
    // MARK: -.
    
    fileprivate var userDefaults: UserDefaults
    
    fileprivate var connectionAttempts: Set<ConnectionAttempt> = []
    fileprivate var connectionInfos: Set<ConnectionInfo> = []
    
    fileprivate (set) var centralManager: CBCentralManager
    fileprivate (set) var centralQueue: DispatchQueue
    weak var delegate: CentralManagerDelegate?
    
    fileprivate (set) var isScanning: Bool = false
    
    fileprivate (set) var knownPeripherals: Set<UUID> = []
    fileprivate (set) var foundPeripherals: Set<Peripheral> = []
    fileprivate (set) var cachedPeripherals: Set<Peripheral> = []
    var allPeripherals: Set<Peripheral> {
        return foundPeripherals.union(cachedPeripherals)
    }
    
    static var bluetoothChangedNotification: Notification.Name {
        return ManagerNotification.bluetoothStateChanged.notificationName
    }
    
    fileprivate var waitForStateAttempt: WaitForStateAttempt?
    fileprivate var scanAttempt: ScanAttempt?
    
    init(withDelegate delegate: CentralManagerDelegate? = nil, queue: DispatchQueue?, options: [String : Any]? = nil, userDefaults: UserDefaults = UserDefaults.standard) {
        self.centralQueue = queue ?? DispatchQueue.main
        centralManager = CBCentralManager(delegate: nil, queue: queue, options: options)
        self.userDefaults = userDefaults
        self.delegate = delegate
        super.init()
        knownPeripherals = readKnownPeripherals()
        cachedPeripherals = Set(centralManager.retrievePeripherals(withIdentifiers: Array(knownPeripherals)).map { Peripheral(with: $0) })
        centralManager.delegate = self
    }
    
    /// Current bluetooth state.
    var bluetoothState: BluetoothState {
        if #available(iOS 10.0, *) {
            return BluetoothState(with: centralManager.state)
        }
        else {
            // Fallback on earlier versions
            return BluetoothState(with: centralManager.state.rawValue)
        }
    }
    
    func wait(for state: BluetoothState, timeout: TimeInterval = 3, completion: @escaping WaitForStateCompletion) {
        if bluetoothState == state {
            completion(bluetoothState)
            return
        }
        let timer = Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(handleWaitStateTimeoutReached(_:)), userInfo: nil, repeats: false)
        waitForStateAttempt = WaitForStateAttempt(state: state, completion: completion, timer: timer)
    }
    
    func scanForPeripherals(withServices services: [CBUUID]? = nil, timeout:(interval: TimeInterval, completion: ScanCompletion)? = nil, options: [String : Any]? = nil) {
        scanAttempt?.timer.invalidate()
        scanAttempt = nil
        
        Logger.debug("Attempt to start a new ble scan.")
        guard centralManager.state == .poweredOn else {
            timeout?.completion(.failure(BLEError.bluetoothNotAvailable(bluetoothState)))
            return
        }
        
        if let timeout = timeout {
            let timer = Timer.scheduledTimer(timeInterval: timeout.interval, target: self, selector: #selector(handleScanTimeoutReached(_:)), userInfo: nil, repeats: false)
            let scanAttempt = ScanAttempt(completion: timeout.completion, timer: timer)
            self.scanAttempt = scanAttempt
        }
        
        centralManager.scanForPeripherals(withServices: services, options: options)
        isScanning = true
        Logger.debug("ble scan started with services: \(services).")
    }
    
    /// Stop the current BLE scan.
    func stopScan() {
        centralManager.stopScan()
        scanAttempt?.timer.invalidate()
        scanAttempt = nil
        isScanning = false
        Logger.debug("ble scan stopped.")
    }
    
    func connect(to peripheral: Peripheral, options: [String : Any]? = nil, attemptTimeout: TimeInterval? = nil, connectionTimeout: TimeInterval? = nil, completion: @escaping ConnectionCompletion) {
        
        let connectionAttempt = ConnectionAttempt(peripheral: peripheral, completion: completion, connectionTimeout: connectionTimeout)
        connectionAttempts.update(with: connectionAttempt)
        
        if let timeout = attemptTimeout {
            delay(timeout) { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let attempt = self?.getConnectionAttempt(for: peripheral) {
                    completion(.failure(BLEError.connectionTimeoutReached))
                    strongSelf.connectionAttempts.remove(attempt)
                    strongSelf.disconnect(from: peripheral)
                }
            }
        }
        
        centralManager.connect(peripheral.cbPeripheral, options: options)
    }
    
    func disconnect(from peripheral: Peripheral) {
        if let connectionInfo = getConnectionInfo(for: peripheral) {
            connectionInfo.timer?.invalidate()
            connectionInfos.remove(connectionInfo)
        }
        centralManager.cancelPeripheralConnection(peripheral.cbPeripheral)
        Logger.debug("ble disconnected from peripheral: \(peripheral.cbPeripheral).")
    }
    
    fileprivate func disconnectAll() {
        Logger.debug("ble disconnect from all peripherals.")
        allPeripherals.forEach { disconnect(from: $0) }
    }
    
    fileprivate func peripheral(for cbPeripheral: CBPeripheral) -> Peripheral? {
        return allPeripherals.filter { $0.cbPeripheral == cbPeripheral }.last
    }
    
    fileprivate func writeKnownPeripherals() {
        let uuidsArray = Array(knownPeripherals).map { $0.uuidString }
        userDefaults.set(uuidsArray, forKey: UserDefaultsKeys.knownPeripheral.rawValue)
    }
    
    fileprivate func readKnownPeripherals() -> Set<UUID> {
        let uuidStrings = userDefaults.stringArray(forKey: UserDefaultsKeys.knownPeripheral.rawValue) ?? []
        let uuids = Set(uuidStrings.map { UUID(uuidString: $0)! })
        return uuids
    }
    
    deinit {
        Logger.debug("ble manager deinit: disconnected from all peripherals.")
        disconnectAll()
    }
    
    fileprivate func getConnectionAttempt(for peripheral: Peripheral) -> ConnectionAttempt? {
        return connectionAttempts.filter { $0.peripheral == peripheral }.last
    }
    
    fileprivate func getConnectionInfo(for peripheral: Peripheral) -> ConnectionInfo? {
        return connectionInfos.filter { $0.peripheral == peripheral }.last
    }
    
    fileprivate func getConnectionInfo(for timer: Timer) -> ConnectionInfo? {
        return connectionInfos.filter { $0.timer == timer }.last
    }
    
    fileprivate func addConnectionInfo(for peripheral: Peripheral, timeout: TimeInterval?) {
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
}

// MARK: Timers handling.
extension CentralManager {
    @objc fileprivate func handleWaitStateTimeoutReached(_ timer: Timer) {
        if let attempt = waitForStateAttempt, attempt.isValid {
            attempt.invalidate()
            attempt.completion(bluetoothState)
        }
    }
    
    @objc fileprivate func handleConnectionTimeoutReached(_ timer: Timer) {
        let connectionInfo = getConnectionInfo(for: timer)!
        connectionInfo.timer?.invalidate()
        connectionInfos.remove(connectionInfo)
        disconnect(from: connectionInfo.peripheral)
    }
    
    @objc fileprivate func handleScanTimeoutReached(_ timer: Timer) {
        Logger.debug("ble scan timeout reached.")
        if let attempt = scanAttempt, attempt.timer.isValid {
            attempt.timer.invalidate()
            stopScan()
            let connectionsArray = Array<Peripheral>(foundPeripherals)
            centralQueue.async {
                attempt.completion(.success(connectionsArray))
            }
        }
    }
}

extension CentralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Logger.debug("ble updated state: \(bluetoothState)")
        delegate?.didUpdateBluetoothState(bluetoothState, from: self)
        NotificationCenter.default.post(name: ManagerNotification.bluetoothStateChanged.notificationName, object: self, userInfo: ["state": bluetoothState])
        if let attempt = waitForStateAttempt, attempt.isValid {
            attempt.completion(bluetoothState)
            attempt.invalidate()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let peripheral = Peripheral(with: peripheral, advertisements: advertisementData, RSSI: RSSI.intValue)
        knownPeripherals.insert(peripheral.cbPeripheral.identifier)
        writeKnownPeripherals()
        if foundPeripherals.insert(peripheral).inserted {
            delegate?.didDiscoverPeripheral(peripheral, from: self)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Logger.debug("ble did connect to peripheral: \(peripheral).")
        if let peripheral = self.peripheral(for: peripheral),
            let attempt = getConnectionAttempt(for: peripheral) {
            connectionAttempts.remove(attempt)
            addConnectionInfo(for: peripheral, timeout: attempt.connectionTimeout)
            attempt.completion(.success(peripheral))
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        knownPeripherals.remove(peripheral.identifier)
        writeKnownPeripherals()
        if let peripheral = self.peripheral(for: peripheral),
            let attempt = getConnectionAttempt(for: peripheral) {
            connectionAttempts.remove(attempt)
            attempt.completion(.failure(BLEError.connectionFailed(error)))
        }
    }
}

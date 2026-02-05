//
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public class CentralManager: NSObject {

    public var bluetoothStateUpdate: BluetoothStateUpdate?

    public var allPeripherals: Set<Peripheral> {
        foundPeripherals.union(cachedPeripherals)
    }
    
    public static var bluetoothChangedNotification: Notification.Name {
        ManagerNotification.bluetoothStateChanged.notificationName
    }
    
    /// Indicates weather an AsyncStream-based BLE scan is active.
    /// State is internally managed by the stream lifecycle.
    public internal(set) var isScanning: Bool = false
    
    public private(set) var cbCentralManager: CBCentralManagerType
    public private(set) var centralQueue: DispatchQueue
    
    public private(set) var knownPeripherals: Set<UUID> = []
    public private(set) var foundPeripherals: Set<Peripheral> = []
    public private(set) var cachedPeripherals: Set<Peripheral> = []
    
    public var ancsUpdateCallback: AncsAuthUpdateCallback? {
        get { _ancsUpdateCallback }
        set {
            _ancsUpdateCallback = newValue
            attachAncsLegacyBridge()
        }
    }
    
    private var userDefaults: UserDefaults

    private var cbDelegateProxy: CBCentralManagerDelegateProxy?
    
    // MARK: - Async stream support
    internal let scanCoordinator = ScanCoordinator<Peripheral>()
    internal let managerStateCoordinator = ManagerStateCoordinator(initial: .unknown)
    internal let connectionCoordinator = ConnectionCoordinator()
    internal let disconnectionCoordinator = DisconnectionCoordinator()
    internal let connectionEventsCoordinator = ConnectionEventsCoordinator()
    internal let ancsAuthUpdatesCoordinator = AncsAuthUpdatesCoordinator()

    internal var _connectionEventCallback: ConnectionEventCallback?
    internal var _ancsUpdateCallback: AncsAuthUpdateCallback?
    
    internal var connectionEventsBridgeTask: Task<Void, Never>?
    internal var ancsBridgeTask: Task<Void, Never>?

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
        
        Task {
            await managerStateCoordinator.update(state)
        }

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
    
    private func addPeripheral(_ peripheral: Peripheral) {
        knownPeripherals.insert(peripheral.cbPeripheral.identifier)
        writeKnownPeripherals()
        
        let removed = cachedPeripherals.remove(peripheral)
        Logger.debug("Removed from cached peripherals: \(String(describing: removed))")
        
        foundPeripherals.update(with: peripheral)
        assert(foundPeripherals.isDisjoint(with: cachedPeripherals), "found peripherals and cached peripherals MUST be disjoint.")
    }
    
    private func disconnectAll() {
        Logger.debug("ble disconnect from all peripherals.")
        allPeripherals.forEach { disconnect(from: $0) }
    }
    
    internal func peripheral(for cbPeripheral: CBPeripheralType) -> Peripheral? {
        allPeripherals.filter { $0.cbPeripheral.identifier == cbPeripheral.identifier }.last
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
        connectionEventsBridgeTask?.cancel()
        ancsBridgeTask?.cancel()
        Logger.debug("ble manager deinit: disconnected from all peripherals.")
        disconnectAll()
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

// MARK: CBCentralManager delegate.
extension CentralManager: CBCentralManagerDelegateType {
    public func centralManager(_ central: CBCentralManagerType,
                               didDiscover peripheral: CBPeripheralType,
                               advertisementData: [String : Any],
                               rssi RSSI: NSNumber) {
        Logger.debug("central discovered peripheral: \(peripheral)")

        let peripheral = Peripheral(with: peripheral, advertisements: advertisementData, RSSI: RSSI.intValue)
        addPeripheral(peripheral)

        Task {
            await scanCoordinator.yield(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManagerType, willRestoreState dict: [String : Any]) { }
    
    public func centralManager(_ central: CBCentralManagerType,
                               didDisconnectPeripheral cbPeripheral: CBPeripheralType,
                               error: Error?) {
        let id = cbPeripheral.identifier
        let p = self.peripheral(for: cbPeripheral) ?? Peripheral(with: cbPeripheral)

        Task {
            // fail-safe: if it is a pending connection, terminate it
            await connectionCoordinator.fail(
                peripheralID: id,
                error: CentralManagerError.connectionFailed(error)
            )

            // complete disconnect pending if present
            if let error {
                await disconnectionCoordinator.fail(peripheralID: id, error: error)
            } else {
                await disconnectionCoordinator.succeed(peripheralID: id, peripheral: p)
            }
        }
    }

    public func centralManager(_ central: CBCentralManagerType, didFailToConnect cbPeripheral: CBPeripheralType, error: Error?) {
        Logger.debug("Failed to connect to peripheral: \(cbPeripheral), error: \(String(describing: error))")

        Task {
            await connectionCoordinator.fail(
                peripheralID: cbPeripheral.identifier,
                error: CentralManagerError.connectionFailed(error)
            )
        }
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManagerType) {
        Logger.debug("ble updated state: \(state)")
        
        bluetoothStateUpdate?(state)
        
        NotificationCenter.default.post(name: ManagerNotification.bluetoothStateChanged.notificationName,
                                        object: self,
                                        userInfo: ["state": state])
                
        Task { await managerStateCoordinator.update(state) }
    }
    
    public func centralManager(_ central: CBCentralManagerType, didConnect cbPeripheral: CBPeripheralType) {
        Logger.debug("ble did connect to peripheral: \(cbPeripheral).")

        let p = self.peripheral(for: cbPeripheral) ?? Peripheral(with: cbPeripheral)

        Task {
            await connectionCoordinator.succeed(peripheralID: cbPeripheral.identifier, peripheral: p)
        }
    }
    
    public func centralManager(_ central: CBCentralManagerType,
                               connectionEventDidOccur event: CBConnectionEvent,
                               for cbPeripheral: CBPeripheralType) {

        Logger.debug("connection event did occur: \(event), peripheral: \(cbPeripheral)")

        let p: Peripheral
        if let existing = self.peripheral(for: cbPeripheral) {
            p = existing
        } else {
            let created = Peripheral(with: cbPeripheral)
            addPeripheral(created)
            p = created
        }

        let payload: ConnectionEvent = (event: event, peripheral: p)

        Task {
            await connectionEventsCoordinator.yield(payload)
        }
    }
    
    public func centralManager(_ central: CBCentralManagerType,
                               didUpdateANCSAuthorizationFor cbPeripheral: CBPeripheralType) {
        Logger.debug("did update ANCS authorization for peripheral: \(cbPeripheral)")

        guard let p = self.peripheral(for: cbPeripheral) else {
            return
        }

        Task {
            await ancsAuthUpdatesCoordinator.yield(p)
        }
    }
}

// MARK: Async streams
public extension CentralManager {

    var connectionEventsStream: AsyncStream<ConnectionEvent> {
        connectionEventsCoordinator.stream()
    }

    var ancsAuthUpdatesStream: AsyncStream<Peripheral> {
        ancsAuthUpdatesCoordinator.stream()
    }
}

// MARK: Attach helpers.
internal extension CentralManager {

    func attachConnectionEventsLegacyBridge() {
        connectionEventsBridgeTask?.cancel()
        guard _connectionEventCallback != nil else { return }

        connectionEventsBridgeTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.connectionEventsStream {
                self._connectionEventCallback?(event)
            }
        }
    }

    func attachAncsLegacyBridge() {
        ancsBridgeTask?.cancel()
        guard _ancsUpdateCallback != nil else { return }

        ancsBridgeTask = Task { [weak self] in
            guard let self else { return }
            for await p in self.ancsAuthUpdatesStream {
                self._ancsUpdateCallback?(p)
            }
        }
    }
}

// MARK: Private Support.
private extension CentralManager {
    
    enum UserDefaultsKeys: String {
        case knownPeripheral = "it.able.centralmanager.knownPeripheralKey"
    }
}

// MARK: Public Support.
public extension CentralManager {
    enum CentralManagerError: Error {
        case connectionFailed(Error?)
        case bluetoothNotAvailable(ManagerState)
        case connectionTimeoutReached
        case waitForStateTimeout(desired: ManagerState, lastState: ManagerState)
        case cancelled
        case connectAlreadyInProgress
        case connectAttemptTimedOut
        case connectCancelled
        case disconnectAlreadyInProgress
        case disconnectCancelled
        case disconnectFail(Error?)
        case disconnectAttemptTimedOut
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

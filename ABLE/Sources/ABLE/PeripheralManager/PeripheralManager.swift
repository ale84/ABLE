//
//  Created by Alessio Orlando on 15/05/17.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class PeripheralManager: NSObject {
    
    public var state: ManagerState {
        cbPeripheralManager.managerState
    }
    
    public var isAdvertising: Bool {
        cbPeripheralManager.isAdvertising
    }
    
    // MARK: - Legacy callbacks (auto-bridged from streams)

    public var bluetoothStateUpdate: BluetoothStateUpdate? {
        get { _bluetoothStateUpdate }
        set { _bluetoothStateUpdate = newValue }
    }

    public var readRequestCallback: ReadRequestCallback? {
        get { _readRequestCallback }
        set {
            _readRequestCallback = newValue
            attachReadRequestsLegacyBridge()
        }
    }

    public var writeRequestsCallback: WriteRequestsCallback? {
        get { _writeRequestsCallback }
        set {
            _writeRequestsCallback = newValue
            attachWriteRequestsLegacyBridge()
        }
    }

    public var readyToUpdateCallback: ReadyToUpdateSubscribersCallback? {
        get { _readyToUpdateCallback }
        set {
            _readyToUpdateCallback = newValue
            attachReadyToUpdateLegacyBridge()
        }
    }
    
    private(set) var cbPeripheralManager: CBPeripheralManagerType
    
    private var addServiceCompletion: AddServiceCompletion?
    private var startAdvertisingCompletion: StartAdvertisingCompletion?
    
    private var cbPeripheralManagerDelegateProxy: CBPeripheralManagerDelegateProxy?
    
    // MARK: Async api support.
    internal let managerStateCoordinator = ManagerStateCoordinator()
    internal let addServiceCoordinator = AddServiceCoordinator()
    internal let startAdvertisingCoordinator = StartAdvertisingCoordinator()
    internal let readyToUpdateSubscribersCoordinator = ReadyToUpdateSubscribersCoordinator()
    internal let readRequestsCoordinator = ReadRequestsCoordinator()
    internal let writeRequestsCoordinator = WriteRequestsCoordinator()

    internal var readRequestsBridgeTask: Task<Void, Never>?
    internal var writeRequestsBridgeTask: Task<Void, Never>?
    internal var readyToUpdateBridgeTask: Task<Void, Never>?
    
    internal var _bluetoothStateUpdate: BluetoothStateUpdate?
    internal var _readRequestCallback: ReadRequestCallback?
    internal var _writeRequestsCallback: WriteRequestsCallback?
    internal var _readyToUpdateCallback: ReadyToUpdateSubscribersCallback?

    public init(with peripheralManager: CBPeripheralManagerType,
                queue: DispatchQueue?,
                options: [String : Any]? = nil,
                stateUpdate: BluetoothStateUpdate? = nil) {
        cbPeripheralManager = peripheralManager
        _bluetoothStateUpdate = stateUpdate
        
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
    
    public func remove(_ service: CBMutableService) {
        cbPeripheralManager.remove(service)
    }
    
    public func removeAllServices() {
        cbPeripheralManager.removeAllServices()
    }
    
    public func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        cbPeripheralManager.respond(to: request, withResult: result)
    }
    
    public func setDesiredConnectionLatency(_ latency: CBPeripheralManagerConnectionLatency, for central: CBCentral) {
        cbPeripheralManager.setDesiredConnectionLatency(latency, for: central)
    }
    
    deinit {
        readRequestsBridgeTask?.cancel()
        writeRequestsBridgeTask?.cancel()
        readyToUpdateBridgeTask?.cancel()

        Task { [managerStateCoordinator] in await managerStateCoordinator.finish() }
        Task { [readRequestsCoordinator] in await readRequestsCoordinator.finish() }
        Task { [writeRequestsCoordinator] in await writeRequestsCoordinator.finish() }
        Task { [readyToUpdateSubscribersCoordinator] in await readyToUpdateSubscribersCoordinator.finish() }
    }
}

// MARK: CBPeripheralManager delegate.
extension PeripheralManager: CBPeripheralManagerDelegateType {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManagerType) {
        Logger.debug("peripheral manager updated state: \(state)")
        
        bluetoothStateUpdate?(state)
        
        NotificationCenter.default.post(
            name: PeripheralManagerNotification.stateChanged.notificationName,
            object: self,
            userInfo: ["state": state]
        )
        
        Task { [weak self] in
            guard let self else { return }
            await self.managerStateCoordinator.yield(self.state)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didAdd service: CBServiceType, error: Error?) {
        let uuid = service.uuid

        Task { [weak self] in
            guard let self else { return }

            if let error {
                await self.addServiceCoordinator.fail(
                    serviceUUID: uuid,
                    error: PeripheralManagerError.cbError(error)
                )
            } else {
                await self.addServiceCoordinator.succeed(
                    serviceUUID: uuid,
                    service: Service(with: service)
                )
            }
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManagerType, error: Error?) {
        Task { [weak self] in
            guard let self else { return }

            if let error {
                await self.startAdvertisingCoordinator.fail(
                    error: PeripheralManagerError.cbError(error)
                )
            } else {
                await self.startAdvertisingCoordinator.succeed()
            }
        }
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManagerType) {
        Task { [weak self] in
            guard let self else { return }
            await self.readyToUpdateSubscribersCoordinator.yieldReady()
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManagerType,
        didReceiveRead request: CBATTRequestType
    ) {
        let wrapped = ATTRequest(request)
        Task {
            await readRequestsCoordinator.yield(wrapped)
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManagerType,
        didReceiveWrite requests: [CBATTRequestType]
    ) {
        let wrapped = requests.map { ATTRequest($0) }
        Task {
            await writeRequestsCoordinator.yield(wrapped)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, willRestoreState dict: [String : Any]) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didSubscribeTo characteristic: CBCharacteristicType) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristicType) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didOpen channel: CBL2CAPChannel?, error: Error?) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) { }
    
    public func peripheralManager(_ peripheral: CBPeripheralManagerType, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) { }
}

// MARK: Public Support.
public extension PeripheralManager {
    
    enum PeripheralManagerError: Error {
        case cbError(Error)
        
        case cancelled
        case waitForStateTimeout(desired: ManagerState, lastState: ManagerState)
        
        case addServiceReplaced(serviceUUID: CBUUID)
        case addServiceCancelled(serviceUUID: CBUUID)
        case addServiceTimeout(serviceUUID: CBUUID, lastState: ManagerState)
        
        case advertisingReplaced
        case advertisingCancelled
        case advertisingTimeout(lastState: ManagerState)
        
        case updateValueCancelled
        case updateValueTimeout(lastState: ManagerState)
    }
    
    enum PeripheralManagerNotification: String {
        case stateChanged = "it.able.peripheralmanager.statechangednotification"
        
        var notificationName: Notification.Name {
            Notification.Name(rawValue)
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
    typealias ReadRequestCallback = ((ATTRequest) -> Void)
    typealias WriteRequestsCallback = (([ATTRequest]) -> Void)
}

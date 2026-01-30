//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

public final class CBPeripheralMock: CBPeripheralType {

    public var discoverServicesBehaviour: DiscoverServicesBehaviour = .success(with: [], after: 0)
    public var discoverCharacteristicsBehaviour: DiscoverCharacteristicsBehaviour = .failure
    public var readValueBehaviour: ReadValueBehaviour = .success
    public var writeValueBehaviour: WriteValueBehaviour = .success
    public var notifyBehaviour: NotifyBehaviour = .success
    public var readRSSIBehaviour: ReadRSSIBehaviour = .success
    public var readDescriptorBehaviour: ReadDescriptorBehaviour = .success
    public var writeDescriptorBehaviour: WriteDescriptorBehaviour = .success
    public var discoverDescriptorsBehaviour: DiscoverDescriptorsBehaviour = .success(with: [], after: 0)
    public var discoverIncludedServicesBehaviour: DiscoverIncludedServicesBehaviour = .success(after: 0)

    public var cbDelegate: CBPeripheralDelegateType?

    public var name: String?
    public var state: CBPeripheralState = .connected
    public var canSendWriteWithoutResponse: Bool = false
    public var identifier: UUID = UUID()
    public var cbServices: [CBServiceType]? = []
    public var ancsAuthorized: Bool = false

    // Scheduled tasks (cancellable, no runloop dependency).
    private var scheduledTasks: [UUID: Task<Void, Never>] = [:]

    private let scheduledTasksLock = NSLock()

    public init() {}

    deinit {
        scheduledTasksLock.lock()
        let tasks = Array(scheduledTasks.values)
        scheduledTasks.removeAll()
        scheduledTasksLock.unlock()

        tasks.forEach { $0.cancel() }
    }

    // MARK: - API

    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {
        switch discoverServicesBehaviour {
        case .success(let services, let interval):
            schedule(after: interval) { [weak self] in
                guard let self else { return }
                self.cbServices = services
                self.cbDelegate?.peripheral(self, didDiscoverServices: nil)
            }

        case .failure:
            cbDelegate?.peripheral(self, didDiscoverServices: DiscoverServicesError.discoveryFailed)
        }
    }

    public func discoverIncludedServices(_ includedServiceUUIDs: [CBUUID]?, for service: CBServiceType) {
        switch discoverIncludedServicesBehaviour {
        case .success(let interval):
            schedule(after: interval) { [weak self] in
                guard let self else { return }
                // The "service" instance already contains cbIncludedServices (set by the test),
                // so Peripheral can map them when handling the delegate callback.
                self.cbDelegate?.peripheral(self, didDiscoverIncludedServicesFor: service, error: nil)
            }

        case .failure:
            cbDelegate?.peripheral(self,
                                   didDiscoverIncludedServicesFor: service,
                                   error: DiscoverIncludedServicesError.discoveryFailed)
        }
    }

    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBServiceType) {
        switch discoverCharacteristicsBehaviour {
        case .success(let serviceWithCharacteristics, let interval):
            schedule(after: interval) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.peripheral(self,
                                           didDiscoverCharacteristicsFor: serviceWithCharacteristics,
                                           error: nil)
            }

        case .failure:
            cbDelegate?.peripheral(self,
                                   didDiscoverCharacteristicsFor: service,
                                   error: DiscoverCharacteristicError.discoveryFailed)
        }
    }

    public func discoverDescriptors(for characteristic: CBCharacteristicType) {
        switch discoverDescriptorsBehaviour {
        case .success(let descriptors, let interval):
            // Reflect CBCharacteristic.descriptors as CoreBluetooth would.
            (characteristic as? CBCharacteristicMock)?.descriptors = descriptors

            schedule(after: interval) { [weak self] in
                guard let self else { return }
                self.cbDelegate?.peripheral(self, didDiscoverDescriptorsFor: characteristic, error: nil)
            }

        case .failure:
            cbDelegate?.peripheral(self, didDiscoverDescriptorsFor: characteristic, error: DiscoverDescriptorsError.discoveryFailed)
        }
    }

    public func readValue(for characteristic: CBCharacteristicType) {
        switch readValueBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didUpdateValueFor: characteristic, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didUpdateValueFor: characteristic, error: ReadValueError.readFailed)
        }
    }

    public func writeValue(_ data: Data,
                           for characteristic: CBCharacteristicType,
                           type: CBCharacteristicWriteType) {
        switch writeValueBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didWriteValueFor: characteristic, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didWriteValueFor: characteristic, error: WriteValueError.writeFailed)
        }
    }

    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristicType) {
        // Mirror CoreBluetooth behavior: the characteristic's notifying state is updated
        // before the delegate callback is delivered.
        (characteristic as? CBCharacteristicMock)?.isNotifying = enabled

        switch notifyBehaviour {
        case .success:
            cbDelegate?.peripheral(self,
                                   didUpdateNotificationStateFor: characteristic,
                                   error: nil)

            // When enabling notifications, CoreBluetooth often delivers an initial value update.
            if enabled {
                cbDelegate?.peripheral(self,
                                       didUpdateValueFor: characteristic,
                                       error: nil)
            }

        case .failure:
            cbDelegate?.peripheral(self,
                                   didUpdateNotificationStateFor: characteristic,
                                   error: NotifyError.updateStateFailure)
        }
    }

    public func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int { 100 }

    public func readRSSI() {
        switch readRSSIBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didReadRSSI: NSNumber(value: -30), error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didReadRSSI: NSNumber(value: 0), error: ReadRSSIError.readFailed)
        }
    }

    public func readValue(for descriptor: any CBDescriptorType) {
        // CoreBluetooth delegates use CBDescriptor, so we need a concrete instance here.
        guard let cbDescriptor = descriptor as? CBDescriptor else {
            assertionFailure("Descriptor must be a CBDescriptor to trigger CoreBluetooth delegate callbacks.")
            return
        }

        switch readDescriptorBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didUpdateValueFor: cbDescriptor, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didUpdateValueFor: cbDescriptor, error: ReadDescriptorError.readFailed)
        }
    }

    public func writeValue(_ data: Data, for descriptor: any CBDescriptorType) {
        // CoreBluetooth delegates use CBDescriptor, so we need a concrete instance here.
        guard let cbDescriptor = descriptor as? CBDescriptor else {
            assertionFailure("Descriptor must be a CBDescriptor to trigger CoreBluetooth delegate callbacks.")
            return
        }

        switch writeDescriptorBehaviour {
        case .success:
            cbDelegate?.peripheral(self, didWriteValueFor: cbDescriptor, error: nil)
        case .failure:
            cbDelegate?.peripheral(self, didWriteValueFor: cbDescriptor, error: WriteDescriptorError.writeFailed)
        }
    }

    public func readValue(for descriptor: CBDescriptor) { }
    public func writeValue(_ data: Data, for descriptor: CBDescriptor) { }
    public func openL2CAPChannel(_ PSM: CBL2CAPPSM) { }

    // MARK: - Scheduling

    private func schedule(after seconds: TimeInterval, _ action: @escaping @Sendable () -> Void) {
        let id = UUID()
        let task = Task { [weak self] in
            if seconds > 0 {
                let nanos = UInt64(max(0, seconds) * 1_000_000_000)
                do { try await Task.sleep(nanoseconds: nanos) } catch {
                    self?.removeTask(for: id)
                    return
                }
            }

            guard !Task.isCancelled else {
                self?.removeTask(for: id)
                return
            }

            action()
            self?.removeTask(for: id)
        }

        storeTask(task, for: id)
    }
    
    private func storeTask(_ task: Task<Void, Never>, for id: UUID) {
        scheduledTasksLock.lock()
        scheduledTasks[id] = task
        scheduledTasksLock.unlock()
    }

    private func removeTask(for id: UUID) {
        scheduledTasksLock.lock()
        scheduledTasks[id] = nil
        scheduledTasksLock.unlock()
    }
}

// MARK: - Behaviours

extension CBPeripheralMock {
    public enum DiscoverServicesBehaviour {
        case success(with: [CBServiceType], after: TimeInterval)
        case failure
    }

    public enum DiscoverCharacteristicsBehaviour {
        case success(with: CBServiceType, after: TimeInterval)
        case failure
    }
    
    public enum DiscoverDescriptorsBehaviour {
        case success(with: [CBDescriptor], after: TimeInterval)
        case failure
    }
    
    public enum DiscoverIncludedServicesBehaviour {
        case success(after: TimeInterval)
        case failure
    }

    public enum ReadValueBehaviour { case success, failure }
    public enum WriteValueBehaviour { case success, failure }
    public enum NotifyBehaviour { case success, failure }
    public enum ReadRSSIBehaviour { case success, failure }
    public enum ReadDescriptorBehaviour { case success, failure }
    public enum WriteDescriptorBehaviour { case success, failure }
}

// MARK: - Errors

extension CBPeripheralMock {
    public enum DiscoverServicesError: Error { case discoveryFailed }
    public enum DiscoverCharacteristicError: Error { case discoveryFailed }
    public enum ReadValueError: Error { case readFailed }
    public enum WriteValueError: Error { case writeFailed }
    public enum NotifyError: Error { case updateStateFailure }
    public enum ReadRSSIError: Error { case readFailed }
    public enum ReadDescriptorError: Error { case readFailed }
    public enum WriteDescriptorError: Error { case writeFailed }
    public enum DiscoverDescriptorsError: Error { case discoveryFailed }
    public enum DiscoverIncludedServicesError: Error { case discoveryFailed }
}

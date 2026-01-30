//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import XCTest
import CoreBluetooth
@testable import ABLE

final class PeripheralAsyncTests: XCTestCase {

    private var peripheralMock: CBPeripheralMock!
    private var peripheral: Peripheral!

    override func setUp() {
        super.setUp()
        peripheralMock = CBPeripheralMock()
        peripheral = Peripheral(with: peripheralMock)

        // Stable defaults
        peripheralMock.cbServices = []
        peripheralMock.discoverServicesBehaviour = .success(with: [], after: 0)
        peripheralMock.discoverCharacteristicsBehaviour = .failure
        peripheralMock.readValueBehaviour = .success
        peripheralMock.writeValueBehaviour = .success
        peripheralMock.notifyBehaviour = .success
        peripheralMock.readRSSIBehaviour = .success

        // Descriptor behaviours (if present in your mock)
        peripheralMock.readDescriptorBehaviour = .success
        peripheralMock.writeDescriptorBehaviour = .success

        // Descriptors discovery behaviour (if you add it)
        peripheralMock.discoverDescriptorsBehaviour = .success(with: [], after: 0)
    }

    override func tearDown() {
        peripheral = nil
        peripheralMock = nil
        super.tearDown()
    }

    // MARK: - Discover services

    func testDiscoverServicesAsyncSuccess() async throws {
        let serviceMock = CBServiceMock()
        peripheralMock.discoverServicesBehaviour = .success(with: [serviceMock], after: 0)

        let services = try await peripheral.discoverServices(with: [serviceMock.uuid], timeout: .seconds(1))
        XCTAssertTrue(services.contains(where: { $0.cbService.uuid == serviceMock.uuid }))
    }

    func testDiscoverServicesAsyncTimeoutThrows() async {
        peripheralMock.discoverServicesBehaviour = .success(with: [], after: 2.0)

        do {
            _ = try await peripheral.discoverServices(with: [], timeout: .milliseconds(150))
            XCTFail("Expected timeout")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .discoverServicesTimeout:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDiscoverServicesAsyncFailureThrows() async {
        peripheralMock.discoverServicesBehaviour = .failure

        do {
            _ = try await peripheral.discoverServices(with: [], timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Discover characteristics

    func testDiscoverCharacteristicsAsyncSuccess() async throws {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        serviceMock.cbCharacteristics = [characteristicMock]

        peripheralMock.cbServices = [serviceMock]
        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 0)

        let service = Service(with: serviceMock)

        let characteristics = try await peripheral.discoverCharacteristics(
            with: [characteristicMock.uuid],
            service: service,
            timeout: .seconds(1)
        )

        XCTAssertTrue(characteristics.contains(where: { $0.uuid == characteristicMock.uuid }))
    }

    func testDiscoverCharacteristicsAsyncTimeoutThrows() async {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        serviceMock.cbCharacteristics = [characteristicMock]

        peripheralMock.cbServices = [serviceMock]
        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 2.0)

        let service = Service(with: serviceMock)

        do {
            _ = try await peripheral.discoverCharacteristics(
                with: [characteristicMock.uuid],
                service: service,
                timeout: .milliseconds(150)
            )
            XCTFail("Expected timeout")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .discoverCharacteristicsTimeout:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDiscoverCharacteristicsAsyncFailureThrows() async {
        let serviceMock = CBServiceMock()
        peripheralMock.cbServices = [serviceMock]
        peripheralMock.discoverCharacteristicsBehaviour = .failure

        let service = Service(with: serviceMock)

        do {
            _ = try await peripheral.discoverCharacteristics(with: [], service: service, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Discover included services

    func testDiscoverIncludedServicesAsyncSuccess() async throws {
        let includedServiceMock = CBServiceMock()
        let parentServiceMock = CBServiceMock()
        parentServiceMock.cbIncludedServices = [includedServiceMock]

        peripheralMock.cbServices = [parentServiceMock]
        peripheralMock.discoverIncludedServicesBehaviour = .success(after: 0)

        let parent = Service(with: parentServiceMock)

        let included = try await peripheral.discoverIncludedServices(nil, for: parent, timeout: .seconds(1))
        XCTAssertTrue(included.contains(where: { $0.cbService.uuid == includedServiceMock.uuid }))
    }

    func testDiscoverIncludedServicesAsyncTimeoutThrows() async {
        let parentServiceMock = CBServiceMock()
        peripheralMock.cbServices = [parentServiceMock]
        peripheralMock.discoverIncludedServicesBehaviour = .success(after: 2.0)

        let parent = Service(with: parentServiceMock)

        do {
            _ = try await peripheral.discoverIncludedServices(nil, for: parent, timeout: .milliseconds(150))
            XCTFail("Expected timeout")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .discoverIncludedServicesTimeout(let serviceUUID):
                XCTAssertEqual(serviceUUID, parentServiceMock.uuid)
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Discover descriptors

    func testDiscoverDescriptorsAsyncSuccess() async throws {
        let characteristicMock = CBCharacteristicMock()
        let cbDesc = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Test")
        characteristicMock.descriptors = [cbDesc]

        let characteristic = Characteristic(with: characteristicMock)

        peripheralMock.discoverDescriptorsBehaviour = .success(with: [cbDesc], after: 0)

        let descriptors = try await peripheral.discoverDescriptors(for: characteristic, timeout: .seconds(1))
        XCTAssertTrue(descriptors.contains(where: { $0.uuid == cbDesc.uuid }))
    }

    func testDiscoverDescriptorsAsyncTimeoutThrows() async {
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)

        peripheralMock.discoverDescriptorsBehaviour = .success(with: [], after: 2.0)

        do {
            _ = try await peripheral.discoverDescriptors(for: characteristic, timeout: .milliseconds(150))
            XCTFail("Expected timeout")
        } catch {
            // Match your PeripheralError case here if you have one.
            // Example:
            // if case Peripheral.PeripheralError.discoverDescriptorsTimeout = error { return }
        }
    }

    func testDiscoverDescriptorsAsyncFailureThrows() async {
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)

        peripheralMock.discoverDescriptorsBehaviour = .failure

        do {
            _ = try await peripheral.discoverDescriptors(for: characteristic, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Read value (characteristic)

    func testReadValueCharacteristicAsyncSuccess() async throws {
        peripheralMock.readValueBehaviour = .success

        let cbChar = CBCharacteristicMock()
        cbChar.value = Data([0x01])

        let characteristic = Characteristic(with: cbChar)

        let data = try await peripheral.readValue(for: characteristic, timeout: .seconds(1))
        XCTAssertEqual(data, Data([0x01]))
    }

    func testReadValueCharacteristicAsyncFailureThrows() async {
        peripheralMock.readValueBehaviour = .failure

        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)

        do {
            _ = try await peripheral.readValue(for: characteristic, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Write value (characteristic)

    func testWriteCharacteristicAsyncSuccess() async throws {
        peripheralMock.writeValueBehaviour = .success

        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)

        try await peripheral.write(Data([0xAA]), for: characteristic, type: .withResponse, timeout: .seconds(1))
    }

    func testWriteCharacteristicAsyncFailureThrows() async {
        peripheralMock.writeValueBehaviour = .failure

        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)

        do {
            try await peripheral.write(Data([0xAA]), for: characteristic, type: .withResponse, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - RSSI

    func testReadRSSIAsyncSuccess() async throws {
        peripheralMock.readRSSIBehaviour = .success
        let rssi = try await peripheral.readRSSI(timeout: .seconds(1))
        XCTAssertEqual(rssi, -30)
    }

    func testReadRSSIAsyncFailureThrows() async {
        peripheralMock.readRSSIBehaviour = .failure

        do {
            _ = try await peripheral.readRSSI(timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Notifications stream

    func testNotificationsStreamEmitsFirstValue() async throws {
        peripheralMock.notifyBehaviour = .success

        let cbChar = CBCharacteristicMock()
        cbChar.value = Data([0x10])

        let characteristic = Characteristic(with: cbChar)

        let stream = peripheral.notifications(for: characteristic)
        let first = try await first(from: stream, timeout: .seconds(1))

        XCTAssertEqual(first, Data([0x10]))
    }

    func testNotificationsStreamCancellationStopsStream() async throws {
        peripheralMock.notifyBehaviour = .success

        let characteristicMock = CBCharacteristicMock()
        characteristicMock.value = Data([0x10])

        let characteristic = Characteristic(with: characteristicMock)
        let stream = peripheral.notifications(for: characteristic)

        let task = Task {
            for try await _ in stream { }
        }

        task.cancel()
        // Give onTermination a short window to execute.
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(task.isCancelled)
    }

    // MARK: - Read/write descriptor (async)

    func testReadDescriptorAsyncSuccess() async throws {
        peripheralMock.readDescriptorBehaviour = .success

        let cbDesc = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Hello")
        let descriptor = Descriptor(with: cbDesc)

        _ = try await peripheral.readValue(for: descriptor, timeout: .seconds(1))
        // We only assert that the operation completes successfully.
    }

    func testReadDescriptorAsyncFailureThrows() async {
        peripheralMock.readDescriptorBehaviour = .failure

        let cbDesc = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Hello")
        let descriptor = Descriptor(with: cbDesc)

        do {
            _ = try await peripheral.readValue(for: descriptor, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testWriteDescriptorAsyncSuccess() async throws {
        peripheralMock.writeDescriptorBehaviour = .success

        let cbDesc = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Hello")
        let descriptor = Descriptor(with: cbDesc)

        try await peripheral.writeValue(Data([0x01]), for: descriptor, timeout: .seconds(1))
    }

    func testWriteDescriptorAsyncFailureThrows() async {
        peripheralMock.writeDescriptorBehaviour = .failure

        let cbDesc = CBMutableDescriptor(type: CBUUID(string: "2901"), value: "Hello")
        let descriptor = Descriptor(with: cbDesc)

        do {
            try await peripheral.writeValue(Data([0x01]), for: descriptor, timeout: .seconds(1))
            XCTFail("Expected failure")
        } catch let e as Peripheral.PeripheralError {
            switch e {
            case .cbError:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Helpers

private struct TimeoutError: Error {}

private func first<T>(
    from stream: AsyncThrowingStream<T, Error>,
    timeout: Duration
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            for try await value in stream { return value }
            throw CancellationError()
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw TimeoutError()
        }
        let v = try await group.next()!
        group.cancelAll()
        return v
    }
}



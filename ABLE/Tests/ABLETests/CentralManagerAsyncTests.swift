//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import XCTest
@testable import ABLE

final class CentralManagerAsyncTests: XCTestCase {
    
    private var centralMock: CBCentralManagerMock!
    private var central: CentralManager!
    
    override func setUp() {
        super.setUp()
        centralMock = CBCentralManagerMock()
        central = CentralManager(with: centralMock, queue: DispatchQueue.main)
        
        // defaults
        centralMock.waitForPoweredOnBehaviour = .alreadyPoweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 0)
        centralMock.disconnectionBehaviour = .success
        centralMock.peripherals = []
        centralMock.managerState = .poweredOff
    }
    
    override func tearDown() {
        central = nil
        centralMock = nil
        super.tearDown()
    }
    
    func testWaitForPoweredOnAsyncImmediate() async throws {
        centralMock.waitForPoweredOnBehaviour = .alreadyPoweredOn
        try await central.waitForPoweredOn(timeout: .seconds(1))
        XCTAssertEqual(central.state, .poweredOn)
    }
    
    func testWaitForPoweredOnAsyncAfterDelay() async throws {
        centralMock.waitForPoweredOnBehaviour = .poweredOn(after: 0.2)
        let state = try await central.wait(for: .poweredOn, timeout: .seconds(1))
        XCTAssertEqual(state, .poweredOn)
    }
    
    func testWaitForPoweredOnAsyncTimeout() async {
        centralMock.waitForPoweredOnBehaviour = .poweredOn(after: 2.0)
        
        do {
            _ = try await central.wait(for: .poweredOn, timeout: .seconds(0.2))
            XCTFail("Expected timeout")
        } catch {}
    }
    
    func testScanStreamEmitsPeripherals() async throws {
        centralMock.managerState = .poweredOn
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        centralMock.peripherals = [Peripheral(with: pMock)]
        
        let stream = central.scan(services: nil, options: nil)
        let firstPeripheral = try await first(from: stream, timeout: .seconds(1))
        
        XCTAssertEqual(firstPeripheral.cbPeripheral.identifier, pMock.identifier)
    }
    
    func testScanForDurationReturnsFoundPeripherals() async {
        centralMock.managerState = .poweredOn
        
        let p1 = CBPeripheralMock(); p1.name = "P1"
        let p2 = CBPeripheralMock(); p2.name = "P2"
        centralMock.peripherals = [Peripheral(with: p1), Peripheral(with: p2)]
        
        let found = await central.scanForDuration(duration: .milliseconds(100))
        XCTAssertEqual(found.count, 2)
    }
    
    func testScanForDurationReturnsEmptyWhenNothingFound() async {
        centralMock.managerState = .poweredOn
        centralMock.peripherals = []
        
        let found = await central.scanForDuration(duration: .milliseconds(100))
        XCTAssertTrue(found.isEmpty)
    }
    
    func testScanStreamCancellationStopsScan() async throws {
        centralMock.managerState = .poweredOn
        centralMock.peripherals = [] // no events
        
        let stream = central.scan()
        let task = Task {
            for await _ in stream { }
        }
        
        task.cancel()
        // leave a moment to allow for onTermination start
        try? await Task.sleep(for: .milliseconds(50))
        
        XCTAssertFalse(central.isScanning)
    }
    
    // MARK: - Connect (async)
    
    func testConnectAsyncSuccess() async throws {
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 0.1)
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        
        // Ensure the CentralManager "owns" the peripheral instance (matches production behavior).
        central.centralManager(centralMock, didDiscover: pMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        let peripheral = Peripheral(with: pMock)
        let connected = try await central.connect(
            to: peripheral,
            options: nil,
            attemptTimeout: .seconds(1),
            connectionTimeout: nil
        )
        
        XCTAssertEqual(connected.cbPeripheral.identifier, pMock.identifier)
    }
    
    func testConnectAsyncAttemptTimeoutThrows() async {
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 1.0) // connect happens too late
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        central.centralManager(centralMock, didDiscover: pMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        let peripheral = Peripheral(with: pMock)
        
        do {
            _ = try await central.connect(
                to: peripheral,
                options: nil,
                attemptTimeout: .milliseconds(150),
                connectionTimeout: nil
            )
            XCTFail("Expected connectAttemptTimedOut")
        } catch let e as CentralManager.CentralManagerError {
            switch e {
            case .connectAttemptTimedOut:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testConnectAsyncFailureThrows() async {
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .failure
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        central.centralManager(centralMock, didDiscover: pMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        let peripheral = Peripheral(with: pMock)
        
        do {
            _ = try await central.connect(
                to: peripheral,
                options: nil,
                attemptTimeout: .seconds(1),
                connectionTimeout: nil
            )
            XCTFail("Expected connectionFailed")
        } catch let e as CentralManager.CentralManagerError {
            switch e {
            case .connectionFailed:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testConnectAsyncBluetoothNotAvailableThrows() async {
        centralMock.managerState = .poweredOff
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        let peripheral = Peripheral(with: pMock)
        
        do {
            _ = try await central.connect(to: peripheral, attemptTimeout: .seconds(1), connectionTimeout: nil)
            XCTFail("Expected bluetoothNotAvailable")
        } catch let e as CentralManager.CentralManagerError {
            switch e {
            case .bluetoothNotAvailable(let state):
                XCTAssertEqual(state, .poweredOff)
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Disconnect (async)
    
    func testDisconnectAsyncSuccess() async throws {
        centralMock.managerState = .poweredOn
        centralMock.disconnectionBehaviour = .success
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        
        // Ensure the CentralManager "owns" the peripheral instance.
        central.centralManager(centralMock, didDiscover: pMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        let peripheral = Peripheral(with: pMock)
        
        let disconnected = try await central.disconnect(from: peripheral, timeout: .seconds(1))
        XCTAssertEqual(disconnected.cbPeripheral.identifier, pMock.identifier)
    }
    
    func testDisconnectAsyncTimeoutThrows() async {
        centralMock.managerState = .poweredOn
        centralMock.disconnectionBehaviour = .successAfter(seconds: 1.0) // too late for our timeout
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        central.centralManager(centralMock, didDiscover: pMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        let peripheral = Peripheral(with: pMock)
        
        do {
            _ = try await central.disconnect(from: peripheral, timeout: .milliseconds(150))
            XCTFail("Expected disconnectAttemptTimedOut")
        } catch let e as CentralManager.CentralManagerError {
            switch e {
            case .disconnectAttemptTimedOut:
                break
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testDisconnectAsyncBluetoothNotAvailableThrows() async {
        centralMock.managerState = .poweredOff
        
        let pMock = CBPeripheralMock()
        pMock.name = "Fake"
        let peripheral = Peripheral(with: pMock)
        
        do {
            _ = try await central.disconnect(from: peripheral, timeout: .seconds(1))
            XCTFail("Expected bluetoothNotAvailable")
        } catch let e as CentralManager.CentralManagerError {
            switch e {
            case .bluetoothNotAvailable(let state):
                XCTAssertEqual(state, .poweredOff)
            default:
                XCTFail("Unexpected error: \(e)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Connection events (new API)
    
    func testRegisterForConnectionEventsNewAPIEmitsLegacyCallback() {
        // This test uses the legacy callback bridge because the new API only registers
        // and does not currently expose an async stream in the snippet you provided.
        centralMock.connectionEventBehaviour = .generateEvent(event: .peerConnected, after: 0.1)
        
        let exp = expectation(description: "Should receive connection event callback")
        
        central.registerForConnectionEvents(options: nil) { event in
            XCTAssertEqual(event.event, .peerConnected)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 1.0)
    }
    
    func testConnectionEventsStreamEmits() async throws {
        centralMock.connectionEventBehaviour = .generateEvent(event: .peerConnected, after: 0.1)

        // Important: CoreBluetooth generates events only after registration.
        central.registerForConnectionEvents(options: nil)

        let stream = central.connectionEvents()
        let event = try await first(from: stream, timeout: .seconds(1))

        XCTAssertEqual(event.event, .peerConnected)
        XCTAssertEqual(event.peripheral.cbPeripheral.name, "ConnectionEventTest")
    }    
}

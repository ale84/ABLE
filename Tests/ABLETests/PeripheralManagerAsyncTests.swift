//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import XCTest
import CoreBluetooth
@testable import ABLE

final class PeripheralManagerAsyncTests: XCTestCase {

    private var cbPeripheralManager: CBPeripheralManagerMock!
    private var peripheralManager: PeripheralManager!

    override func setUp() {
        super.setUp()
        cbPeripheralManager = CBPeripheralManagerMock()
        peripheralManager = PeripheralManager(with: cbPeripheralManager, queue: .main)
    }

    override func tearDown() {
        peripheralManager = nil
        cbPeripheralManager = nil
        super.tearDown()
    }

    // MARK: - wait(for:)

    func testWaitForPoweredOnReturnsImmediatelyWhenAlreadyPoweredOn() async throws {
        cbPeripheralManager.managerState = .poweredOn
        try await peripheralManager.waitForPoweredOn(timeout: .seconds(3))
    }

    func testWaitForStateCompletesOnStateUpdate() async throws {
        cbPeripheralManager.stateBehaviour = .transition(from: .poweredOff, to: .poweredOn, after: 0.2)

        let state = try await peripheralManager.wait(for: .poweredOn, timeout: .seconds(3))
        XCTAssertEqual(state, .poweredOn)
    }

    func testStateStreamEmitsUpdates() async throws {
        let box = AsyncIteratorBox(peripheralManager.stateStream())

        _ = try await next(from: box, timeout: .seconds(3))

        cbPeripheralManager.stateBehaviour = .transition(from: .poweredOff, to: .poweredOn, after: 0.2)

        while true {
            let v = try await next(from: box, timeout: .seconds(1))
            if v == .poweredOn { break }
        }
    }

    func testWaitForStateTimesOut() async {
        cbPeripheralManager.stateBehaviour = .already(.poweredOff)

        do {
            _ = try await peripheralManager.wait(for: .poweredOn, timeout: .milliseconds(500))
            XCTFail("Expected timeout")
        } catch {
            // If you expose a specific error (recommended), switch on it here.
            // Otherwise this is fine: we only assert it throws.
        }
    }

    // MARK: - updateValueWhenReady

    func testUpdateValueWhenReadyReturnsImmediatelyIfUpdateReturnsTrue() async throws {
        cbPeripheralManager.updateValueBehaviour = .alwaysReady

        let characteristic = CBMutableCharacteristic(
            type: CBUUID(),
            properties: [.notify, .read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        try await peripheralManager.updateValueWhenReady(
            Data([0x01]),
            for: characteristic,
            onSubscribedCentrals: nil,
            timeout: .seconds(3)
        )
    }

    func testUpdateValueWhenReadySuspendsUntilReadySignal() async throws {
        cbPeripheralManager.updateValueBehaviour = .notReadyThenReady(after: 0.2)

        let characteristic = CBMutableCharacteristic(
            type: CBUUID(),
            properties: [.notify, .read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        try await peripheralManager.updateValueWhenReady(
            Data([0x01]),
            for: characteristic,
            onSubscribedCentrals: nil,
            timeout: .seconds(3)
        )
    }

    func testReadyToUpdateSubscribersStreamEmits() async throws {
        cbPeripheralManager.updateValueBehaviour = .notReadyThenReady(after: 0.2)

        let characteristic = CBMutableCharacteristic(
            type: CBUUID(),
            properties: [.notify, .read, .write],
            value: nil,
            permissions: [.readable, .writeable]
        )

        // Start an update that will return false and trigger "ready" later.
        Task {
            _ = cbPeripheralManager.updateValue(Data([0x01]), for: characteristic, onSubscribedCentrals: nil)
        }

        // Stream should emit a readiness signal.
        _ = try await first(from: peripheralManager.readyToUpdateSubscribersStream, timeout: .seconds(3))
    }

    // MARK: - Requests streams

    func testReadRequestsStreamEmitsRequest() async throws {
        let cbChar = CBMutableCharacteristic(
            type: CBUUID(),
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )

        let stream = peripheralManager.readRequestsStream

        cbPeripheralManager.emitReadRequest(
            characteristic: cbChar,
            value: Data([0x01]),
            after: 0.05
        )

        let req = try await first(from: stream, timeout: .seconds(3))

        XCTAssertEqual(req.value, Data([0x01]))
        XCTAssertEqual(req.characteristic.uuid, cbChar.uuid)
    }

    func testWriteRequestsStreamEmitsRequestsArray() async throws {
        let cbChar = CBMutableCharacteristic(
            type: CBUUID(),
            properties: [.write],
            value: nil,
            permissions: [.writeable]
        )

        let stream = peripheralManager.writeRequestsStream

        cbPeripheralManager.emitWriteRequests(
            characteristic: cbChar,
            values: [Data([0xAA]), Data([0xBB])],
            after: 0.05
        )

        let reqs = try await first(from: stream, timeout: .seconds(3))

        XCTAssertEqual(reqs.count, 2)
        XCTAssertEqual(reqs[0].characteristic.uuid, cbChar.uuid)
        XCTAssertEqual(reqs[0].value, Data([0xAA]))
        XCTAssertEqual(reqs[1].value, Data([0xBB]))
    }
}

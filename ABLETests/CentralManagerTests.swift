//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import XCTest
@testable import ABLE

class CentralManagerTests: XCTestCase {
    
    let centralMock = CBCentralManagerMock()
    
    lazy var central: CentralManager = {
        return CentralManager(with: centralMock, queue: DispatchQueue.main)
    }()
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        centralMock.waitForPoweredOnBehaviour = .alreadyPoweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 0)
        centralMock.disconnectionBehaviour = .success
        super.tearDown()
    }
    
    func testWaitForPoweredOnSuccess() {
        centralMock.waitForPoweredOnBehaviour = .alreadyPoweredOn
        
        let expectation = XCTestExpectation(description: "state should be powered on in the completion.")
        central.waitForPoweredOn(withTimeout: 3) { (state) in
            XCTAssert(state == .poweredOn, "state should be powered on.")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testWaitForPoweredOnSuccessAfterInterval() {
        centralMock.waitForPoweredOnBehaviour = .poweredOn(after: 2)
        
        let expectation = XCTestExpectation(description: "state should be powered on in the completion.")
        central.waitForPoweredOn(withTimeout: 3) { (state) in
            XCTAssert(state == .poweredOn, "state should be powered on.")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testWaitForPoweredOnFailure() {
        centralMock.waitForPoweredOnBehaviour = .poweredOn(after: 4)
        
        let expectation = XCTestExpectation(description: "state should not be powered on in the completion.")
        central.waitForPoweredOn(withTimeout: 3) { (state) in
            XCTAssert(state != .poweredOn, "state should be powered on.")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testScanTimeout() {
        let expectation = XCTestExpectation(description: "Scan should timeout after 3 seconds.")

        centralMock.managerState = .poweredOn
        
        central.scanForPeripherals(withServices: nil, timeoutInterval: 3.0) { result in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3.0)

    }
    
    func testConnectToPeripheralSuccess() {
        let peripheralMock = CBPeripheralMock()
        peripheralMock.name = "Fake"
        
        let expectation = XCTestExpectation(description: "Central should connect peripheral with success.")
        
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 0)
        
        let peripheral = Peripheral(with: peripheralMock)
        
        centralMock.peripherals = [peripheral]
        
        central.centralManager(centralMock, didDiscover: peripheralMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        central.connect(to: peripheral) { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testConnectToPeripheralAfterInterval() {
        let peripheralMock = CBPeripheralMock()
        peripheralMock.name = "Fake"
        
        let expectation = XCTestExpectation(description: "Central should connect peripheral with success.")
        
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 2)
        
        let peripheral = Peripheral(with: peripheralMock)
        centralMock.peripherals = [peripheral]
        
        central.centralManager(centralMock, didDiscover: peripheralMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        central.connect(to: peripheral) { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testConnectToPeripheralTimeoutFailure() {
        let peripheralMock = CBPeripheralMock()
        peripheralMock.name = "Fake"
        
        let expectation = XCTestExpectation(description: "Connection attempt should time out.")
        
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .success(after: 3)
        
        let peripheral = Peripheral(with: peripheralMock)
        centralMock.peripherals = [peripheral]
        
        central.centralManager(centralMock, didDiscover: peripheralMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        central.connect(to: peripheral, attemptTimeout: 2) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testConnectToPeripheralFailure() {
        let peripheralMock = CBPeripheralMock()
        peripheralMock.name = "Fake"
        
        let expectation = XCTestExpectation(description: "Connection attempt should time out.")
        
        centralMock.managerState = .poweredOn
        centralMock.peripheralConnectionBehaviour = .failure
        
        let peripheral = Peripheral(with: peripheralMock)
        centralMock.peripherals = [peripheral]
        
        central.centralManager(centralMock, didDiscover: peripheralMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        central.connect(to: peripheral, attemptTimeout: 2) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    func testDisconnectFromPeripheral() {
        let peripheralMock = CBPeripheralMock()
        peripheralMock.name = "Fake"
        
        let expectation = XCTestExpectation(description: "Peripheral should disconnect from central.")
        
        centralMock.managerState = .poweredOn
        centralMock.disconnectionBehaviour = .success
        
        let peripheral = Peripheral(with: peripheralMock)
        centralMock.peripherals = [peripheral]
        
        central.centralManager(centralMock, didDiscover: peripheralMock, advertisementData: [:], rssi: NSNumber(value: 0))
        
        central.disconnect(from: peripheral) { _ in
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    @available(iOS 13.0, *)
    func testRegisterForConnectionEvents() {
        centralMock.connectionEventBehaviour = .generateEvent(event: .peerConnected, after: 2)
        
        let expectation = XCTestExpectation(description: "Central should produce a connection event after the specified time interval has passed.")
        
        central.registerForConnectionEvents { (event) in
            XCTAssert(event.event == .peerConnected, "state should be powered on.")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.5)
    }
}

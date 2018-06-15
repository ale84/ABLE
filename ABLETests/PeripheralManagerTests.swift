//
//  PeripheralManagerTests.swift
//  ABLETests
//
//  Created by Alessio Orlando on 15/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import XCTest
@testable import ABLE
import CoreBluetooth

class PeripheralManagerTests: XCTestCase {
    
    let cbPeripheralManager = CBPeripheralManagerMock()
    lazy var peripheralManager: PeripheralManager = {
        return PeripheralManager(with: cbPeripheralManager, queue: DispatchQueue.main)
    }()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testAddServiceSuccess() {
        cbPeripheralManager.addServiceBehaviour = .success
        
        let expectation = XCTestExpectation(description: "PeripheralManager add service should succeed.")
        
        let service = CBMutableService(type: CBUUID(), primary: true)
        peripheralManager.add(service) { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testAddServiceFailure() {
        cbPeripheralManager.addServiceBehaviour = .failure
        
        let expectation = XCTestExpectation(description: "PeripheralManager add service should fail.")
        
        let service = CBMutableService(type: CBUUID(), primary: true)
        peripheralManager.add(service) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }

    func testStartAdvertisingSuccess() {
        cbPeripheralManager.startAdvertiseBehaviour = .success
        
        let expectation = XCTestExpectation(description: "PeripheralManager start advertise should succeed.")
        
        peripheralManager.startAdvertising { (result) -> (Void) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testAdvertisingFailure() {
        cbPeripheralManager.startAdvertiseBehaviour = .failure
        
        let expectation = XCTestExpectation(description: "PeripheralManager start advertise should fail.")
        
        peripheralManager.startAdvertising { (result) -> (Void) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
}

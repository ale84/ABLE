//
//  PeripheralTests.swift
//  ABLETests
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import XCTest
@testable import ABLE
import CoreBluetooth

class PeripheralTests: XCTestCase {
    
    let peripheralMock = CBPeripheralMock()

    lazy var peripheral: Peripheral = {
        return Peripheral(with: peripheralMock)
    }()
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        peripheralMock.cbServices = []
    }
    
    func testDiscoverServicesSuccess() {
        let serviceMock = CBServiceMock()
        
        peripheralMock.discoverServicesBehaviour = .success(with: [serviceMock], after: 0)
        
        let expectation = XCTestExpectation(description: "Peripheral should discover services with success.")
        
        peripheral.discoverServices(with: [serviceMock.uuid], timeout: 3) { (result) in
            guard case .success(_) = result,
                let discoveredService = self.peripheral.discoveredServices.first,
                discoveredService.cbService.uuid == serviceMock.uuid else {
                    XCTAssertTrue(false)
                    return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.1)
    }
    
    func testDiscoverServicesTimeout() {
        peripheralMock.discoverServicesBehaviour = .success(with: [], after: 5)

        let expectation = XCTestExpectation(description: "Peripheral services discovery should time out.")

        peripheral.discoverServices(with: [], timeout: 3) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }

    func testDiscoverServicesFailure() {
        peripheralMock.discoverServicesBehaviour = .failure

        let expectation = XCTestExpectation(description: "Peripheral services discovery should fail with an error.")

        peripheral.discoverServices(with: [], timeout: 3) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 4)
    }
    
    func testDiscoverCharacteristicSuccess() {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        
        serviceMock.cbCharacteristics = [characteristicMock]
        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 0)
        peripheralMock.cbServices = [serviceMock]
        
        let expectation = XCTestExpectation(description: "Peripheral should discover characteristics with success.")
        
        let service = Service(with: serviceMock)
        //peripheral.discoveredServices = [service]
        
        peripheral.discoverCharacteristics(with: [characteristicMock.uuid], service: service, timeout: 2) { (result) in
            guard case .success(_) = result,
                let discoveredCharacteristic = service.characteristics.first,
                discoveredCharacteristic.uuid == characteristicMock.uuid else {
                    XCTAssertTrue(false)
                    return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.1)
    }
    
    func testDiscoverCharacteristicTimeout() {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        
        serviceMock.cbCharacteristics = [characteristicMock]
        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 5)
        peripheralMock.cbServices = [serviceMock]
        
        let expectation = XCTestExpectation(description: "Peripheral discover characteristics should time out.")
        
        let service = Service(with: serviceMock)
        //peripheral.discoveredServices = [service]
        
        peripheral.discoverCharacteristics(with: [characteristicMock.uuid], service: service, timeout: 2) { (result) in
            guard case .failure(let error) = result, case Peripheral.PeripheralError.timeoutReached = error else {
                    XCTAssertTrue(false)
                    return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.1)
    }
    
    func testDiscoverCharacteristicFailure() {
        
        peripheralMock.discoverCharacteristicsBehaviour = .failure
        
        let expectation = XCTestExpectation(description: "Peripheral discover characteristics should fail with an error.")
        
        let serviceMock = CBServiceMock()
        let service = Service(with: serviceMock)
        peripheralMock.cbServices = [serviceMock]
        
        peripheral.discoverCharacteristics(with: [], service: service, timeout: 5) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.1)
    }
    
    func testReadValueSuccess() {
        peripheralMock.readValueBehaviour = .success
        
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation = XCTestExpectation(description: "Peripheral read value should succeed.")

        peripheral.readValue(for: characteristic) { (result) in
            guard case .success(_) = result else {
                    XCTAssertTrue(false)
                    return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testReadValueFailure() {
        peripheralMock.readValueBehaviour = .failure
        
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation = XCTestExpectation(description: "Peripheral read value should fail.")
        
        peripheral.readValue(for: characteristic) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testWriteValueSuccess() {
        peripheralMock.writeValueBehaviour = .success
        
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation = XCTestExpectation(description: "Peripheral write value should succeed.")
        
        peripheral.write(Data(), for: characteristic, type: .withResponse) { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testWriteValueFailure() {
        peripheralMock.writeValueBehaviour = .failure
        
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation = XCTestExpectation(description: "Peripheral write value should fail.")
        
        peripheral.write(Data(), for: characteristic, type: .withResponse) { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testSetNotifyOnSuccess() {
        peripheralMock.notifyBehaviour = .success
        
        let characteristicMock = CBCharacteristicMock()
        characteristicMock.isNotifying = true
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation1 = XCTestExpectation(description: "Peripheral set notify should succeed.")
        let expectation2 = XCTestExpectation(description: "Peripheral should notify update value.")

        peripheral.setNotifyValue(true, for: characteristic, updateState: { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation1.fulfill()
        }) { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation2.fulfill()
        }
        
        wait(for: [expectation1, expectation2], timeout: 0.5)
    }
    
    func testSetNotifyFailure() {
        peripheralMock.notifyBehaviour = .failure
        
        let characteristicMock = CBCharacteristicMock()
        let characteristic = Characteristic(with: characteristicMock)
        
        let expectation = XCTestExpectation(description: "Peripheral set notify should fail.")
        
        peripheral.setNotifyValue(true, for: characteristic, updateState: { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }) { _ in }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testReadRSSISuccess() {
        peripheralMock.readRSSIBehaviour = .success
        
        let expectation = XCTestExpectation(description: "Peripheral read RSSI should succeed.")
        
        peripheral.readRSSI { (result) in
            guard case .success(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testReadRSSIFailure() {
        peripheralMock.readRSSIBehaviour = .failure
        
        let expectation = XCTestExpectation(description: "Peripheral read RSSI should fail.")
        
        peripheral.readRSSI { (result) in
            guard case .failure(_) = result else {
                XCTAssertTrue(false)
                return
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
}

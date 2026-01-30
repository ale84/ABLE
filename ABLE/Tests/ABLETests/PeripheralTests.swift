//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
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
        peripheralMock.cbServices = []
        peripheralMock.discoverServicesBehaviour = .success(with: [], after: 0)
        peripheralMock.discoverCharacteristicsBehaviour = .failure
        peripheralMock.readValueBehaviour = .success
        peripheralMock.writeValueBehaviour = .success
        peripheralMock.notifyBehaviour = .success
        peripheralMock.readRSSIBehaviour = .success
        super.tearDown()
    }
    
    func testDiscoverServicesSuccess() {
        let serviceMock = CBServiceMock()
        peripheralMock.discoverServicesBehaviour = .success(with: [serviceMock], after: 0)

        let expectation = XCTestExpectation(description: "Peripheral should discover services with success.")

        peripheral.discoverServices(with: [serviceMock.uuid], timeout: 3) { result in
            guard case .success(let services) = result else {
                XCTFail("Expected success.")
                return
            }

            XCTAssertTrue(services.contains(where: { $0.cbService.uuid == serviceMock.uuid }))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDiscoverServicesTimeout() {
        peripheralMock.discoverServicesBehaviour = .success(with: [], after: 5)

        let expectation = XCTestExpectation(description: "Peripheral services discovery should time out.")

        peripheral.discoverServices(with: [], timeout: 3) { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure.")
                return
            }

            switch error {
            case .discoverServicesTimeout:
                expectation.fulfill()
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 4.0)
    }

    func testDiscoverServicesFailure() {
        peripheralMock.discoverServicesBehaviour = .failure

        let expectation = XCTestExpectation(description: "Peripheral services discovery should fail with an error.")

        peripheral.discoverServices(with: [], timeout: 3) { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure.")
                return
            }

            switch error {
            case .cbError:
                expectation.fulfill()
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 4.0)
    }
    
    func testDiscoverCharacteristicSuccess() {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        serviceMock.cbCharacteristics = [characteristicMock]

        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 0)
        peripheralMock.cbServices = [serviceMock]

        let expectation = XCTestExpectation(description: "Peripheral should discover characteristics with success.")

        let service = Service(with: serviceMock)

        peripheral.discoverCharacteristics(with: [characteristicMock.uuid], service: service, timeout: 2) { result in
            guard case .success(let characteristics) = result else {
                XCTFail("Expected success.")
                return
            }

            XCTAssertTrue(characteristics.contains(where: { $0.uuid == characteristicMock.uuid }))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
    
    func testDiscoverCharacteristicTimeout() {
        let characteristicMock = CBCharacteristicMock()
        let serviceMock = CBServiceMock()
        serviceMock.cbCharacteristics = [characteristicMock]

        peripheralMock.discoverCharacteristicsBehaviour = .success(with: serviceMock, after: 5)
        peripheralMock.cbServices = [serviceMock]

        let expectation = XCTestExpectation(description: "Peripheral discover characteristics should time out.")

        let service = Service(with: serviceMock)

        peripheral.discoverCharacteristics(with: [characteristicMock.uuid], service: service, timeout: 2) { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure.")
                return
            }

            switch error {
            case .discoverCharacteristicsTimeout:
                expectation.fulfill()
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 3.0)
    }
    
    func testDiscoverCharacteristicFailure() {
        peripheralMock.discoverCharacteristicsBehaviour = .failure

        let expectation = XCTestExpectation(description: "Peripheral discover characteristics should fail with an error.")

        let serviceMock = CBServiceMock()
        let service = Service(with: serviceMock)
        peripheralMock.cbServices = [serviceMock]

        peripheral.discoverCharacteristics(with: [], service: service, timeout: 5) { result in
            guard case .failure(let error) = result else {
                XCTFail("Expected failure.")
                return
            }

            switch error {
            case .cbError:
                expectation.fulfill()
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 2.0)
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
        
        wait(for: [expectation], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSetNotifyOnSuccess() {
        peripheralMock.notifyBehaviour = .success
        
        let characteristicMock = CBCharacteristicMock()
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
        
        wait(for: [expectation1, expectation2], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
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
        
        wait(for: [expectation], timeout: 1.0)
    }
}

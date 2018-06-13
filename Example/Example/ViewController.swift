//
//  ViewController.swift
//  Example
//
//  Created by Alessio Orlando on 31/05/17.
//  Copyright © 2017 Alessio Orlando. All rights reserved.
//

import UIKit
import ABLE
import CoreBluetooth

class ViewController: UIViewController {

    var central: CentralManager!
    var peripheralManager: PeripheralManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager(queue: DispatchQueue.main)
        
        // Wait for powered on state to begin using the central, specifying the desired timeout. You can also set yourself as delegate to receive all state change notification if you need to.
        central.waitForPoweredOn(withTimeout: 6.0) { (state) in
            guard state == .poweredOn else {
                return
            }

            self.central.scanForPeripherals(withServices: nil, timeout: (interval: 6.0, completion: { result in
                switch result {
                case .success(let peripherals):
                    print("found peripherals: \(peripherals)")
                    // Connect to peripheral...
                case .failure(let error):
                    print("scan error: \(error)")
                    // Handle error.
                }
            }))
        }

        peripheralManager = PeripheralManager(queue: DispatchQueue.main)

        peripheralManager.waitForPoweredOn(withTimeout: 6.0) { (state) in
            guard state == .poweredOn else {
                return
            }

            let service = CBMutableService(type: CBUUID(string: "DE036077-4293-4768-B9EF-66429B46A3CB"), primary: true)
            self.peripheralManager.add(service) { (result) in
                switch result {
                case .success(let service):
                    print("added service: \(service)")

                    // Start advertising.
                    self.peripheralManager.startAdvertising { (result) in
                        print("advertising result: \(result)")
                    }
                case .failure(let error):
                    print("add service failure: \(error)")
                }
            }
        }
    }
}


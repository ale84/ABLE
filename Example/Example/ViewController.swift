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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager(queue: DispatchQueue.main)

        // Wait for powered on state to begin using the central, specifying the desired timeout. You can also set yourself as delegate to receive all state change notification if you need to.
        central.wait(for: .poweredOn, timeout: 6.0) { (state) in
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

        let peripheralManager = PeripheralManager(queue: DispatchQueue.main)

        peripheralManager.wait(for: .poweredOn, timeout: 6.0) { (state) in
            guard state == .poweredOn else {
                return
            }

            let service = CBMutableService(type: CBUUID(string: "My service UUID."), primary: true)
            peripheralManager.add(service) { (result) in
                switch result {
                case .success(let service):
                    print("added service: \(service)")

                    // Start advertising.
                    peripheralManager.startAdvertising { (result) in
                        print("advertising result: \(result)")
                    }
                case .failure(let error):
                    print("add service failure: \(error)")
                }
            }
        }
    }
}


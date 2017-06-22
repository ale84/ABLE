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
    var customQueue: DispatchQueue = DispatchQueue(label: "com.ABLE.Example.customQueue")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central = CentralManager(queue: customQueue)
        
        central.wait(for: .poweredOn) { (central) in
            //print("ble state is \(self.central.bluetoothState)")
            if #available(iOS 10.0, *) {
                dispatchPrecondition(condition: .onQueue(self.customQueue))
            }
            else {
                print("dispatchPrecondition is unavailable.")
            }
            
            self.central.scanForPeripherals(withServices: [CBUUID(string: "86433301-4227-4F53-BCCC-3DAD9DA9129C")], timeout: (interval: 10.0, completion: { result in
                if #available(iOS 10.0, *) {
                    dispatchPrecondition(condition: .onQueue(self.customQueue))
                }
                else {
                    // Fallback on earlier versions
                }
                print("scan result: \(result)")
            }))
        }
    }

}


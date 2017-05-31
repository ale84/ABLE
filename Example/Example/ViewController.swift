//
//  ViewController.swift
//  Example
//
//  Created by Alessio Orlando on 31/05/17.
//  Copyright © 2017 Alessio Orlando. All rights reserved.
//

import UIKit
import ABLE

class ViewController: UIViewController {

    var central: CentralManager = CentralManager(queue: DispatchQueue.main)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        central.wait(for: .poweredOn) { (central) in
            print("ble state is \(self.central.bluetoothState)")
        }
    }

}


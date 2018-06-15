//
//  Characteristic.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class Characteristic {
    public var uuid: CBUUID {
        return cbCharacteristic.uuid
    }
    
    private(set) var cbCharacteristic: CBCharacteristicType
    
    init(with cbCharacteristic: CBCharacteristicType) {
        self.cbCharacteristic = cbCharacteristic
    }
}
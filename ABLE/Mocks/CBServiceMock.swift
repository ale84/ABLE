//
//  CBServiceMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

class CBServiceMock: CBServiceType {
    var cbCharacteristics: [CBCharacteristicType]?
    
    var isPrimary: Bool
    
    var characteristics: [CBCharacteristic]?
    
    var uuid: CBUUID
    
    init(with id: CBUUID = CBUUID(), isPrimary: Bool = true, characteristics: [CBCharacteristic]? = nil) {
        self.uuid = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}

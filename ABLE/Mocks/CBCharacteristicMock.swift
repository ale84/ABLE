//
//  CBCharacteristicMock.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBCharacteristicMock: CBCharacteristicType {
    public var value: Data?
    
    public var descriptors: [CBDescriptor]?
    
    public var properties: CBCharacteristicProperties
    
    public var isNotifying: Bool = false
    
    public var uuid: CBUUID
    
    public init(with id: CBUUID = CBUUID(), properties: CBCharacteristicProperties = []) {
        self.uuid = id
        self.properties = properties
    }
}

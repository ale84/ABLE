//
//  CBCharacteristicType.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBCharacteristicType: CBAttributeType {
    var value: Data? { get }
    var descriptors: [CBDescriptor]? { get }
    var properties: CBCharacteristicProperties { get }
    var isNotifying: Bool { get }
}

extension CBCharacteristic: CBCharacteristicType { }

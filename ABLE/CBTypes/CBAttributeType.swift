//
//  CBAttributeType.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBAttributeType {
    var uuid: CBUUID { get }
}

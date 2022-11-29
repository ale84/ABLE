//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBServiceType: CBAttributeType {
    var isPrimary: Bool { get }
    var cbCharacteristics: [CBCharacteristicType]? { get }
}

extension CBService: CBServiceType {
    public var cbCharacteristics: [CBCharacteristicType]? {
        return characteristics
    }
}


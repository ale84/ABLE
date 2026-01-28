//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class CBServiceMock: CBServiceType {
    
    public var isPrimary: Bool
    
    public var characteristics: [CBCharacteristic]?
    
    public var uuid: CBUUID
    
    public var cbIncludedServices: [any CBServiceType]?
    
    public var cbCharacteristics: [CBCharacteristicType]?
    
    public init(with id: CBUUID = CBUUID(), isPrimary: Bool = true, characteristics: [CBCharacteristic]? = nil) {
        self.uuid = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}

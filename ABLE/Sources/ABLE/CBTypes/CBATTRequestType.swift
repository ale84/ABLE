//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public protocol CBATTRequestType: AnyObject {
    var characteristic: CBCharacteristic { get }
    var cbCentral: CBCentralType { get }
    var value: Data? { get set }
    var offset: Int { get }

    /// Access to the underlying CBATTRequest when available (production).
    /// In tests it can be nil.
    var underlying: CBATTRequest? { get }
}

extension CBATTRequest: CBATTRequestType {
    
    public var cbCentral: CBCentralType { self.central }
    public var underlying: CBATTRequest? { self }
}


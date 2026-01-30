//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public final class CBATTRequestMock: CBATTRequestType {
    public let characteristic: CBCharacteristic
    public let cbCentral: CBCentralType
    public var value: Data?
    public let offset: Int
    public let underlying: CBATTRequest? = nil

    public init(
        characteristic: CBCharacteristic,
        cbCentral: CBCentralType = CBCentralMock(),
        value: Data? = nil,
        offset: Int = 0
    ) {
        self.characteristic = characteristic
        self.cbCentral = cbCentral
        self.value = value
        self.offset = offset
    }
}


//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public struct ATTRequest {
    public let characteristic: Characteristic
    public let centralID: UUID
    public let value: Data?
    public let offset: Int

    /// Used only if you want to call respond() on a real request.
    internal let underlying: CBATTRequest?

    init(_ request: CBATTRequestType) {
        self.characteristic = Characteristic(with: request.characteristic)
        self.centralID = request.cbCentral.identifier
        self.value = request.value
        self.offset = request.offset
        self.underlying = request.underlying
    }
}


//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public class Service {
    public var uuid: CBUUID { cbService.uuid }
    public var characteristics: [Characteristic] {
        cbService.cbCharacteristics?.map { Characteristic(with: $0) } ?? []
    }
    public var includedServices: [Service] {
        cbService.cbIncludedServices?.map { Service(with: $0) } ?? []
    }

    internal let cbService: CBServiceType
    init(with cbService: CBServiceType) { self.cbService = cbService }
}

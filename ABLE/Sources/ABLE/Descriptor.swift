//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public final class Descriptor {
    public var uuid: CBUUID { cbDescriptor.uuid }
    internal let cbDescriptor: CBDescriptorType

    init(with cbDescriptor: CBDescriptorType) {
        self.cbDescriptor = cbDescriptor
    }
}



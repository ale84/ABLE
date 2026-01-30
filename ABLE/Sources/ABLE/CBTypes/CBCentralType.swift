//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public protocol CBCentralType: AnyObject {
    var identifier: UUID { get }
}

extension CBCentral: CBCentralType {}



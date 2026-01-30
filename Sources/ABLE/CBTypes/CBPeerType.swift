//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBPeerType {
    var identifier: UUID { get }
}

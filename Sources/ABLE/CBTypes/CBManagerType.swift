//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBManagerType {
    var managerState: ManagerState { get }
}

extension CBManager: CBManagerType {
    public var managerState: ManagerState {
        return ManagerState.init(with: state)
    }
}

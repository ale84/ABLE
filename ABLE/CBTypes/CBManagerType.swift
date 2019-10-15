//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CBManagerType {
    var managerState: ManagerState { get }
    
    @available(iOS 13.0, *)
    var managerAuthorization: ManagerAuthorization { get }
}

extension CBManager: CBManagerType {
    public var managerState: ManagerState {
        return ManagerState.init(with: state)
    }
    
    @available(iOS 13.0, *)
    public var managerAuthorization: ManagerAuthorization {
        return ManagerAuthorization(authorization: authorization)
    }
}

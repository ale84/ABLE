//
//  CBManagerType.swift
//  ABLE
//
//  Created by Alessio Orlando on 07/06/18.
//  Copyright © 2018 Alessio Orlando. All rights reserved.
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

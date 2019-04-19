//
//  Support.swift
//  ABLE
//
//  Created by Alessio Orlando on 15/05/17.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public enum ManagerState: Int {
    case poweredOff
    case poweredOn
    case resetting
    case unauthorized
    case unknown
    case unsupported
    
    @available(iOS 10.0, *)
    public init(with state: CBManagerState) {
        switch state {
        case .poweredOff:
            self = .poweredOff
        case .poweredOn:
            self = .poweredOn
        case .resetting:
            self = .resetting
        case .unauthorized:
            self = .unauthorized
        case .unknown:
            self = .unknown
        case .unsupported:
            self = .unsupported
        @unknown default:
            self = .unknown
        }
    }
    
    // For iOS < 10 support.
    public init(with rawValue: Int) {
        switch rawValue {
        case 1:
            self = .resetting
        case 2:
            self = .unsupported
        case 3: // CBCentralManagerState.unauthorized :
            self = .unauthorized
        case 4: // CBCentralManagerState.poweredOff:
            self = .poweredOff
        case 5: //CBCentralManagerState.poweredOn:
            self = .poweredOn
        default:
            self = .unknown
        }
    }
}

/// Delays the execution of a given closure.
///
/// - Parameters:
///   - delay: Delay time in seconds.
///   - closure: A closure.
func delay(_ delay:Double, queue: DispatchQueue = DispatchQueue.main, closure:@escaping ()->()) {
    queue.asyncAfter(
        deadline: .now() + delay, execute: closure)
}

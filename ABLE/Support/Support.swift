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
}

public enum ManagerAuthorization: Int {
    case allowedAlways
    case denied
    case notDetermined
    case restricted
}

public extension ManagerAuthorization {
    init(authorization: CBManagerAuthorization) {
        switch authorization {
        case .allowedAlways:
            self = .allowedAlways
        case .denied:
            self = .denied
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        @unknown default:
            fatalError("Unhandled enum case: \(authorization)")
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

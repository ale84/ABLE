//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import CoreBluetooth

public extension CentralManager {

    func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]? = nil) {
        cbCentralManager.registerForConnectionEvents(options: options)
        Logger.debug("registered for connection events with options: \(String(describing: options))")
    }
    
    // MARK: legacy api.
    func registerForConnectionEvents(options: [CBConnectionEventMatchingOption : Any]? = nil,
                                            callback: @escaping ConnectionEventCallback) {
        _connectionEventCallback = callback
        attachConnectionEventsLegacyBridge()
        cbCentralManager.registerForConnectionEvents(options: options)
        Logger.debug("registered for connection events with options: \(String(describing: options))")
    }

}


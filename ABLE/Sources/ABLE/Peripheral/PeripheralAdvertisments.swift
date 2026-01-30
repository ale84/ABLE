//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import CoreBluetooth

public struct PeripheralAdvertisements {
    
    let advertisements: [String : Any]
    
    public var localName: String? {
        advertisements[CBAdvertisementDataLocalNameKey] as? String
    }
    
    public var manufactuereData: Data? {
        advertisements[CBAdvertisementDataManufacturerDataKey] as? Data
    }
    
    public var txPower: NSNumber? {
        advertisements[CBAdvertisementDataTxPowerLevelKey] as? NSNumber
    }
    
    public var isConnectable: NSNumber? {
        advertisements[CBAdvertisementDataIsConnectable] as? NSNumber
    }
    
    public var serviceUUIDs: [CBUUID]? {
        advertisements[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
    }
    
    public var serviceData: [CBUUID : Data]? {
        advertisements[CBAdvertisementDataServiceDataKey] as? [CBUUID : Data]
    }
    
    public var overflowServiceUUIDs: [CBUUID]? {
        advertisements[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
    }
    
    public var solicitedServiceUUIDs: [CBUUID]? {
        advertisements[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
    }
}



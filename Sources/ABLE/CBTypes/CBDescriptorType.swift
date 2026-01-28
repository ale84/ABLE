//
//  Created by Alessio on 28/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import CoreBluetooth

public protocol CBDescriptorType: AnyObject, CBAttributeType {
    var uuid: CBUUID { get }
    var value: Any? { get }
}

extension CBDescriptor: CBDescriptorType { }



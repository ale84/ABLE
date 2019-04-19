//
//  Service.swift
//  ABLE
//
//  Created by Alessio Orlando on 14/06/18.
//  Copyright © 2019 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public class Service {
    public var uuid: CBUUID {
        return cbService.uuid
    }
    public var characteristics: [Characteristic] {
        return cbService.cbCharacteristics?.map { Characteristic(with: $0) } ?? []
    }
    
    private(set) var cbService: CBServiceType
    
    init(with cbService: CBServiceType) {
        self.cbService = cbService
    }
}

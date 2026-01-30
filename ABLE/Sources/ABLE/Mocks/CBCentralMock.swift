//
//  Created by Alessio on 30/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation

public final class CBCentralMock: CBCentralType {
    public let identifier: UUID
    public init(id: UUID = UUID()) {
        self.identifier = id
    }
}

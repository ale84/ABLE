//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

public extension PeripheralManager {

    var readRequestsStream: AsyncStream<ATTRequest> {
        readRequestsCoordinator.stream()
    }

    var writeRequestsStream: AsyncStream<[ATTRequest]> {
        writeRequestsCoordinator.stream()
    }
    
    func attachReadRequestsLegacyBridge() {
        readRequestsBridgeTask?.cancel()
        guard _readRequestCallback != nil else { return }

        readRequestsBridgeTask = Task { [weak self] in
            guard let self else { return }
            for await req in self.readRequestsStream {
                self._readRequestCallback?(req)
            }
        }
    }

    func attachWriteRequestsLegacyBridge() {
        writeRequestsBridgeTask?.cancel()
        guard _writeRequestsCallback != nil else { return }

        writeRequestsBridgeTask = Task { [weak self] in
            guard let self else { return }
            for await reqs in self.writeRequestsStream {
                self._writeRequestsCallback?(reqs)
            }
        }
    }

    func attachReadyToUpdateLegacyBridge() {
        readyToUpdateBridgeTask?.cancel()
        guard _readyToUpdateCallback != nil else { return }

        readyToUpdateBridgeTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.readyToUpdateSubscribersStream {
                self._readyToUpdateCallback?()
            }
        }
    }
}




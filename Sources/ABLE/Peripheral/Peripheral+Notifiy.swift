//
//  Created by Alessio on 27/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation

public extension Peripheral {

    func notifications(for characteristic: Characteristic) -> AsyncThrowingStream<Data, Error> {
          let uuid = characteristic.uuid
          return notifyCoordinator.stream(
              characteristicUUID: uuid,
              onStart: { [weak self] in
                  guard let self else { return }
                  self.cbPeripheral.setNotifyValue(true, for: characteristic.cbCharacteristic)
              },
              onStop: { [weak self] in
                  guard let self else { return }
                  self.cbPeripheral.setNotifyValue(false, for: characteristic.cbCharacteristic)
              }
          )
      }
    
    func setNotifyValue(
        _ enabled: Bool,
        for characteristic: Characteristic,
        updateState: @escaping SetNotifyUpdateStateCompletion,
        updateValue: @escaping SetNotifyUpdateValueCallback
    ) {
        let uuid = characteristic.uuid

        if enabled {
            Task { [weak self] in
                guard let self else { return }

                await self.notifyCoordinator.registerLegacy(
                    characteristicUUID: uuid,
                    replace: true,
                    updateState: updateState,
                    updateValue: updateValue
                )

                self.cbPeripheral.setNotifyValue(true, for: characteristic.cbCharacteristic)
            }
        } else {
            // stop: best-effort
            Task { [weak self] in
                guard let self else { return }
                await self.notifyCoordinator.unregister(characteristicUUID: uuid)
            }
            cbPeripheral.setNotifyValue(false, for: characteristic.cbCharacteristic)
            updateState(.success(()))
        }
    }

}

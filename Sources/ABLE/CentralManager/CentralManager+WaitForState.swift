//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation

public extension CentralManager {

    func waitForPoweredOn(timeout: Duration = .seconds(3)) async throws {
        _ = try await wait(for: .poweredOn, timeout: timeout)
    }

    func wait(for desired: ManagerState, timeout: Duration = .seconds(3)) async throws -> ManagerState {
        let current = state
        if current == desired { return current }

        let stream = stateProducer.stream()

        do {
            return try await withThrowingTaskGroup(of: ManagerState.self) { group in
                group.addTask { [desired] in
                    for await newState in stream {
                        if newState == desired { return newState }
                    }
                    return current
                }

                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw CentralManagerError.waitForStateTimeout(desired: desired, lastState: self.state)
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch is CancellationError {
            throw CentralManagerError.cancelled
        }
    }
}

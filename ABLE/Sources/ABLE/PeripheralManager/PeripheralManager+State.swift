//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

// TODO: CentralManager and PeripheralManager share almost identical state-handling logic
// (ManagerStateCoordinator wiring, stateStream, wait(for:timeout:)).
// This was intentionally duplicated to keep behavior explicit while stabilizing
// async state semantics and race conditions.
// Consider extracting a shared abstraction once the API is fully stabilized.

import Foundation
import CoreBluetooth

public extension PeripheralManager {

    var state: ManagerState {
        cbPeripheralManager.managerState
    }
    
    func stateStream(includeCurrent: Bool = true) -> AsyncStream<ManagerState> {
        managerStateCoordinator.stream(includeCurrent: includeCurrent)
    }

    func waitForPoweredOn(timeout: Duration = .seconds(3)) async throws {
        _ = try await wait(for: .poweredOn, timeout: timeout)
    }

    func wait(for desired: ManagerState, timeout: Duration = .seconds(3)) async throws -> ManagerState {
        let stream = managerStateCoordinator.stream(includeCurrent: true)

        do {
            return try await withThrowingTaskGroup(of: ManagerState.self) { group in
                group.addTask { [desired] in
                    for await newState in stream {
                        if newState == desired { return newState }
                    }
                    throw PeripheralManagerError.cancelled
                }

                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw PeripheralManagerError.waitForStateTimeout(desired: desired, lastState: self.state)
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch is CancellationError {
            throw PeripheralManagerError.cancelled
        }
    }

    // Legacy bridge
    func waitForPoweredOn(withTimeout timeout: TimeInterval = 3,
                          completion: @escaping WaitForStateCompletion) {
        wait(for: .poweredOn, timeout: timeout, completion: completion)
    }

    func wait(for desired: ManagerState,
              timeout: TimeInterval = 3,
              completion: @escaping WaitForStateCompletion) {
        Task {
            do {
                let _ = try await wait(
                    for: desired,
                    timeout: .milliseconds(Int(timeout * 1000))
                )
                completion(desired)
            } catch {
                completion(self.state)
            }
        }
    }
}

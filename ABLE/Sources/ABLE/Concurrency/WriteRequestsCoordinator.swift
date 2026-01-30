//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation
import CoreBluetooth

actor WriteRequestsCoordinator {

    private var continuations: [UUID: AsyncStream<[ATTRequest]>.Continuation] = [:]
    private var isFinished = false

    nonisolated func stream() -> AsyncStream<[ATTRequest]> {
        AsyncStream { continuation in
            let id = UUID()

            Task { [weak self] in
                guard let self else { return }
                await self.addContinuation(continuation, id: id)
            }

            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    guard let self else { return }
                    await self.removeContinuation(id: id)
                }
            }
        }
    }

    private func addContinuation(_ continuation: AsyncStream<[ATTRequest]>.Continuation, id: UUID) {
        guard !isFinished else {
            continuation.finish()
            return
        }
        continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    func yield(_ requests: [ATTRequest]) {
        guard !isFinished else { return }
        for (_, c) in continuations {
            c.yield(requests)
        }
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true
        for (_, c) in continuations {
            c.finish()
        }
        continuations.removeAll()
    }
}




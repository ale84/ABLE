//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import Foundation


actor ManagerStateCoordinator {
    private var continuations: [UUID: AsyncStream<ManagerState>.Continuation] = [:]
    private var isFinished = false
    private var lastState: ManagerState

    init(initial: ManagerState) {
        self.lastState = initial
    }

    func getCurrent() -> ManagerState { lastState }

    func update(_ newValue: ManagerState) {
        guard !isFinished else { return }
        guard newValue != lastState else { return }

        lastState = newValue
        for c in continuations.values {
            c.yield(newValue)
        }
    }

    nonisolated func stream(includeCurrent: Bool = true) -> AsyncStream<ManagerState> {
        AsyncStream { continuation in
            let id = UUID()

            Task { [weak self] in
                guard let self else { return }
                await self.addContinuation(continuation, id: id, replay: includeCurrent)
            }

            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    guard let self else { return }
                    await self.removeContinuation(id: id)
                }
            }
        }
    }

    private func addContinuation(
        _ continuation: AsyncStream<ManagerState>.Continuation,
        id: UUID,
        replay: Bool
    ) {
        guard !isFinished else {
            continuation.finish()
            return
        }

        continuations[id] = continuation

        if replay {
            continuation.yield(lastState)
        }
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    func finish() {
        guard !isFinished else { return }
        isFinished = true

        for c in continuations.values {
            c.finish()
        }
        continuations.removeAll()
    }
}

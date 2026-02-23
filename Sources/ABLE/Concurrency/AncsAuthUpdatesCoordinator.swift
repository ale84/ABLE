//
//  Created by Alessio on 29/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation

actor AncsAuthUpdatesCoordinator {

    private var continuations: [UUID: AsyncStream<Peripheral>.Continuation] = [:]
    private var isFinished = false

    nonisolated func stream() -> AsyncStream<Peripheral> {
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

    private func addContinuation(_ continuation: AsyncStream<Peripheral>.Continuation, id: UUID) {
        guard !isFinished else {
            continuation.finish()
            return
        }
        continuations[id] = continuation
    }

    private func removeContinuation(id: UUID) {
        continuations[id] = nil
    }

    func yield(_ peripheral: Peripheral) {
        guard !isFinished else { return }
        for (_, c) in continuations {
            c.yield(peripheral)
        }
    }

    func finishAll() {
        guard !isFinished else { return }
        isFinished = true
        for (_, c) in continuations { c.finish() }
        continuations.removeAll()
    }
}



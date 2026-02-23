//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

actor ScanCoordinator<Element> {

    private var continuation: AsyncStream<Element>.Continuation?
    private var isStreamFinished = false

    /// Creates a stream. Replaces a previous stream if it exists.
    nonisolated func stream(
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) -> AsyncStream<Element> {

        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { return }
                await self.replaceContinuation(continuation)
                onStart()
            }

            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    guard let self else { return }
                    await self.stopCurrentStream()
                    onStop()
                }
            }
        }
    }

    private func replaceContinuation(_ newContinuation: AsyncStream<Element>.Continuation) {
        // terminate previous stream
        if continuation != nil, !isStreamFinished {
            continuation?.finish()
        }

        continuation = newContinuation
        isStreamFinished = false
    }

    func yield(_ element: Element) {
        guard !isStreamFinished else { return }
        continuation?.yield(element)
    }

    func stopCurrentStream() {
        guard continuation != nil else { return }
        isStreamFinished = true
        continuation?.finish()
        continuation = nil
    }

    func finishAll() {
        stopCurrentStream()
    }
}

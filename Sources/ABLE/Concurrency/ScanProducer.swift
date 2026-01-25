//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

actor ScanProducer<Element> {

    private var continuation: AsyncStream<Element>.Continuation?
    private var isFinished = false

    /// Crea uno stream. Se esiste già uno stream attivo, viene terminato.
    nonisolated func stream(
        onStart: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) -> AsyncStream<Element> {

        AsyncStream { continuation in
            // 1) Registra la nuova continuation *dentro l’actor* e invalida la precedente.
            Task { [weak self] in
                guard let self else { return }
                await self.replaceContinuation(continuation)
                onStart()
            }

            // 2) Termination = cleanup bidirezionale (chiude stream + ferma BLE)
            continuation.onTermination = { @Sendable _ in
                Task { [weak self] in
                    guard let self else { return }
                    await self.finish()
                    onStop()
                }
            }
        }
    }

    /// Termina lo stream attuale e imposta la nuova continuation come attiva.
    private func replaceContinuation(_ newContinuation: AsyncStream<Element>.Continuation) {
        // Termina l'eventuale stream precedente
        if continuation != nil, !isFinished {
            continuation?.finish()
        }

        // Attiva il nuovo stream
        continuation = newContinuation
        isFinished = false
    }

    func yield(_ element: Element) {
        guard !isFinished else { return }
        continuation?.yield(element)
    }

    func finish() {
        guard continuation != nil else { return }
        isFinished = true
        continuation?.finish()
        continuation = nil
    }
}

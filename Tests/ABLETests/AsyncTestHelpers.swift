//
//  Created by Alessio on 02/02/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import XCTest

enum AsyncTestError: Error {
    case timeout
    case sequenceFinished
}

/// Returns the first element from an AsyncSequence, optionally matching a predicate, with a timeout.
func first<S: AsyncSequence>(
    from sequence: S,
    timeout: Duration,
    where predicate: ((S.Element) -> Bool)? = nil
) async throws -> S.Element {
    try await withThrowingTaskGroup(of: S.Element.self) { group in

        group.addTask {
            for try await value in sequence {
                if predicate?(value) ?? true { return value }
            }
            throw AsyncTestError.sequenceFinished
        }

        group.addTask {
            try await Task.sleep(for: timeout)
            throw AsyncTestError.timeout
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

actor AsyncIteratorBox<S: AsyncSequence> {
    private var iterator: S.AsyncIterator

    init(_ sequence: S) {
        self.iterator = sequence.makeAsyncIterator()
    }

    func next() async throws -> S.Element? {
        var it = iterator                
        let value = try await it.next()
        iterator = it
        return value
    }
}

func next<T>(
    from box: AsyncIteratorBox<AsyncStream<T>>,
    timeout: Duration
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            guard let value = try await box.next() else {
                throw AsyncTestError.sequenceFinished
            }
            return value
        }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw AsyncTestError.timeout
        }

        let v = try await group.next()!
        group.cancelAll()
        return v
    }
}


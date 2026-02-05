# ABLE
[![CI](https://github.com/ale84/ABLE/actions/workflows/ci.yml/badge.svg)](https://github.com/ale84/ABLE/actions/workflows/ci.yml)

**Modern Swift Concurrency–first BLE library for iOS**

ABLE is a lightweight wrapper around **CoreBluetooth** that provides:

- Async / await–first API
- Deterministic concurrency (no delegate spaghetti)
- Explicit timeouts and cancellation
- Testable architecture (no CoreBluetooth types in actors)
- Legacy closure-based APIs still supported (bridged internally)

The async APIs are the **source of truth**.  
Legacy APIs are implemented as a compatibility layer on top.

---

## Philosophy

ABLE is designed around a **unidirectional, deterministic flow**:

```
CoreBluetooth delegate
        ↓
Coordinator actor
        ↓
async function / AsyncStream
```

Key principles:

- No `Timer` in core logic (only `Task.sleep`)
- Replace semantics for concurrent operations
- Explicit cancellation and timeout handling
- CoreBluetooth types kept **outside** actors
- Fully mockable for unit testing

---

## Swift 6 Concurrency Notes

ABLE adopts Swift Concurrency extensively and currently targets **Swift 5.9+**.

Full Swift 6 concurrency compliance is partially limited by the fact that  
**CoreBluetooth is not yet fully annotated for `Sendable` and actor isolation**.  
For this reason, some Swift 6 diagnostics related to `Sendable` conformance are  
intentionally relaxed using:

```swift
@preconcurrency import CoreBluetooth
````

CoreBluetooth objects are **explicitly confined** within the library and never  
treated as `Sendable`.

### Planned Improvements

- Evaluate migrating `Peripheral` to an actor-based model to fully isolate  
  CoreBluetooth state.
- Refine async streams to expose fully `Sendable` payloads where appropriate.
- Remove remaining Swift 6 concurrency warnings once CoreBluetooth becomes  
  concurrency-annotated or when a larger API refactor is justified.

These changes are considered **non-breaking internal refactors** and are tracked  
as future improvements rather than current blockers.

---

## Installation

### Swift Package Manager (recommended)

```swift
.package(url: "https://github.com/ale84/ABLE", .upToNextMajor(from: "1.0.0")),
```

> Carthage and CocoaPods are no longer supported.

---

## CentralManager (async)

```swift
let central = CentralManager(queue: .main)

// Observe bluetooth state
Task {
    for await state in central.stateStream() {
        print("Central state:", state)
    }
}

// Wait for poweredOn
try await central.waitForPoweredOn(timeout: .seconds(6))

// Scan for peripherals
for await peripheral in central.scan(services: nil) {
    print("Discovered:", peripheral.name ?? "Unknown")
}
```

Available async APIs include:

- `stateStream()`
- `waitForPoweredOn()`
- `scan(services:) -> AsyncStream<Peripheral>`
- `connect(_:)`
- `disconnect(_:)`
- connection events stream

---

## PeripheralManager (async)

```swift
let peripheralManager = PeripheralManager(queue: .main)

// Observe state
Task {
    for await state in peripheralManager.stateStream() {
        print("PeripheralManager state:", state)
    }
}

// Wait for poweredOn
try await peripheralManager.waitForPoweredOn(timeout: .seconds(6))

// Create and add a service
let service = CBMutableService(
    type: CBUUID(string: "DE036077-4293-4768-B9EF-66429B46A3CB"),
    primary: true
)

try await peripheralManager.add(service)

// Start advertising
try await peripheralManager.startAdvertising()

// Handle events
Task {
    for await _ in peripheralManager.readyToUpdateSubscribersStream {
        print("Ready to update subscribers")
    }
}

Task {
    for await request in peripheralManager.readRequestsStream {
        print("Read request:", request)
    }
}
```

---

## Peripheral (async)

```swift
// Read value
let data = try await peripheral.readValue(for: characteristic)

// Write value
try await peripheral.write(Data(), for: characteristic)

// Notifications
for try await value in peripheral.notifications(for: characteristic) {
    print("Notified value:", value)
}
```

---

## Legacy APIs

All original closure-based APIs are still available:

```swift
central.waitForPoweredOn(withTimeout: 3) { state in
    ...
}

peripheral.setNotifyValue(
    true,
    for: characteristic,
    updateState: { result in
        ...
    },
    updateValue: { result in
        ...
    }
)
```

Internally, **legacy APIs are bridged to async implementations**.  
No duplicate logic, no divergence in behavior.

---

## Example App

A minimal SwiftUI example app is included in the repository:

```
Examples/
 └─ ABLEExample
```

The example demonstrates:

- CentralManager async scan
- PeripheralManager async advertising
- State observation via `AsyncStream`
- Structured concurrency (no delegate usage)

The example is intentionally minimal and focused on API usage.

---

## Testing

ABLE is fully unit-tested.

- CoreBluetooth types are abstracted behind protocols
- Deterministic mocks for CentralManager and PeripheralManager
- Async APIs tested with `AsyncStream` helpers
- No reliance on runloops or timers

The mock implementations are reusable for client-side testing.

---

## Requirements

- iOS 16+
- Swift 5.9+
- Swift Concurrency

---

## License

MIT

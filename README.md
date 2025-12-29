# ABLE
[![CI](https://github.com/ale84/ABLE/actions/workflows/ci.yml/badge.svg)](https://github.com/ale84/ABLE/actions/workflows/ci.yml)

BLE library for iOS.

This lightweight library is a wrapper around the CoreBluetooth api, which adds support for closures to ease handling all ble operations.

Additionaly, this library supports specifying custom timeouts for all ble operation, which is not possibile by default with CoreBluetooth.

A few other utility functions are provided as well.

# Usage
You can use CentralManager or PeripheralManager objects just as you would with CoreBluetooth to perform your operations, as most api mirrors those of CoreBluetooth.

# CentralManager
This is an example of how you can use a CentralManager to perform Central role tasks:
```swift
central = CentralManager(queue: DispatchQueue.main)

// Wait for powered on state to begin using the central, specifying the desired timeout.
central.waitForPoweredOn(withTimeout: 6.0) { (state) in
    guard state == .poweredOn else {
        return
    }

    self.central.scanForPeripherals(withServices: nil, timeoutInterval: 6.0) { result in
        switch result {
        case .success(let peripherals):
            print("timeout reached: \(peripherals)")
        // Connect to peripheral...
        case .failure(let error):
            print("scan error: \(error)")
            // Handle error.
        }
    }
}
```
# PeripheralManager
This is an example of how you can use a PeripheralManager to perform Peripheral role tasks:
```swift
let peripheralManager = PeripheralManager(queue: DispatchQueue.main)

peripheralManager.waitForPoweredOn(withTimeout: 6.0) { (state) in
    guard state == .poweredOn else {
        return
    }

    let service = CBMutableService(type: CBUUID(string: "DE036077-4293-4768-B9EF-66429B46A3CB"), primary: true)
    peripheralManager.add(service) { (result) in
        switch result {
        case .success(let service):
            print("added service: \(service)")

            // Start advertising.
            peripheralManager.startAdvertising { (result) in
                print("advertising result: \(result)")
            }
        case .failure(let error):
            print("add service failure: \(error)")
        }
    }
}
```
# Installation

### Swift Package Manager
For Swift Package Manager, add the following package to your Package.swift file.
```
.package(url: "https://github.com/ale84/ABLE", .upToNextMajor(from: "0.9.0")),
```

### Carthage
If you're using [Carthage](https://github.com/Carthage/Carthage) you can add a dependency on ABLE by adding it to your Cartfile:
```
github "ale84/ABLE"
```

### CocoaPods
Add the following entry to your Podfile:
```rb
pod 'ABLE'
```

# Tests
A full set of unit tests for the library is implemented by mocking the main CoreBluetooth classes.

You can use the mocks provided with the library for your own logic tests, or you can write your own mocks if you need further customization.

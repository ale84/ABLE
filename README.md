# ABLE
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
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

// Wait for powered on state to begin using the central, specifying the desired timeout. You can also set yourself as delegate to receive all state change notification if you need to.
central.wait(for: .poweredOn, timeout: 6.0) { (state) in
    guard state == .poweredOn else {
        return
    }

    self.central.scanForPeripherals(withServices: nil, timeout: (interval: 6.0, completion: { result in
        switch result {
        case .success(let peripherals):
            print("found peripherals: \(peripherals)")
            // Connect to peripheral...
        case .failure(let error):
            print("scan error: \(error)")
            // Handle error.
        }
    }))
}
```
# PeripheralManager
This is an example of how you can use a PeripheralManager to perform Peripheral role tasks:
```swift
let peripheralManager = PeripheralManager(queue: DispatchQueue.main)

peripheralManager.wait(for: .poweredOn, timeout: 6.0) { (state) in
    guard state == .poweredOn else {
        return
    }

    let service = CBMutableService(type: CBUUID(string: "My service UUID."), primary: true)
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
If you're using [Carthage](https://github.com/Carthage/Carthage) you can add a dependency on ABLE by adding it to your Cartfile:
```
github "ale84/ABLE"
```

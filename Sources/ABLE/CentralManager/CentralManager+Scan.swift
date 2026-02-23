//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

// MARK: - Scan API (AsyncStream based)
public extension CentralManager {
    
    func scan(
        services: [CBUUID]? = nil,
        options: [String: Any]? = nil
    ) -> AsyncStream<Peripheral> {

        scanCoordinator.stream(
            onStart: { [weak self] in
                guard let self else { return }

                // Stop previous scan if present
                self.stopCoreBluetoothScan()

                Logger.debug("Attempt to start BLE scan (async).")

                guard self.cbCentralManager.managerState == .poweredOn else {
                    Logger.debug("BLE not powered on, scan not started.")
                    return
                }

                self.cbCentralManager.scanForPeripherals(withServices: services, options: options)
                self.isScanning = true
                Logger.debug("BLE scan started (async) with services: \(String(describing: services)).")
            },
            onStop: { [weak self] in
                guard let self else { return }
                Task { await self.stopScanAsync() } // qui sì: stop + finish stream
            }
        )
    }

    func scanForDuration(
        services: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        duration: Duration
    ) async -> [Peripheral] {
        
        var results: [Peripheral] = []
        let stream = scan(services: services, options: options)
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await p in stream {
                    results.append(p)
                }
            }
            
            group.addTask { [weak self] in
                guard let self else { return }
                do { try await Task.sleep(for: duration) } catch { return }
                await self.stopScanAsync()
            }
            
            // wait for the stream to end (stopScanAsync ter)
            await group.next()
            group.cancelAll()
        }
        
        return results
    }
    
    func stopScan() {
        Task { [weak self] in
            await self?.stopScanAsync()
        }
    }
    
    internal func stopCoreBluetoothScan() {
        cbCentralManager.stopScan()
        isScanning = false
        Logger.debug("ble scan stopped (CoreBluetooth only).")
    }

    internal func stopScanAsync() async {
        stopCoreBluetoothScan()
        await scanCoordinator.stopCurrentStream()
    }
    
    // MARK: Legacy api
    func scanForPeripherals(withServices services: [CBUUID]? = nil,
                            options: [String : Any]? = nil,
                            update: ScanUpdate? = nil,
                            timeoutInterval: TimeInterval? = nil,
                            timeoutCompletion: ScanTimeout? = nil) {
        
        Task { [weak self] in
            guard let self else { return }
            
            // stop previous scan
            await self.stopScanAsync()
            
            Logger.debug("Attempt to start a new ble scan (legacy -> async).")
            
            guard self.cbCentralManager.managerState == .poweredOn else {
                Logger.debug("BLE not powered on, scan not started.")
                return
            }
            
            let stream = self.scan(services: services, options: options)
            
            // consumer: keep delivering updates until scan stops
            let consumerTask = Task {
                for await p in stream {
                    update?(p)
                }
            }
            
            // If no duration requested: keep running until stopScan() is called.
            guard let timeoutInterval, let timeoutCompletion else {
                // legacy behaviour: no timeoutCompletion => infinite scan + updates
                // consumerTask will end when stopScanAsync() finishes the stream
                return
            }
            
            // duration scan
            do {
                let nanos = UInt64(max(0, timeoutInterval) * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                // cancelled: stop scan and exit
                consumerTask.cancel()
                await self.stopScanAsync()
                return
            }
            
            await self.stopScanAsync()
            consumerTask.cancel()
            
            // return peripherals found up to now
            let results = Array(self.foundPeripherals)
            timeoutCompletion(.success(results))
        }
    }
    
}

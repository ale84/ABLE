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

                Task {
                    await self.stopScanAsync()

                    Logger.debug("Attempt to start BLE scan (async).")

                    guard self.cbCentralManager.managerState == .poweredOn else {
                        Logger.debug("BLE not powered on, scan not started.")
                        return
                    }

                    self.cbCentralManager.scanForPeripherals(withServices: services, options: options)
                    self.isScanning = true
                    Logger.debug("BLE scan started (async) with services: \(String(describing: services)).")
                }
            },
            onStop: { [weak self] in
                guard let self else { return }
                Task { await self.stopScanAsync() }
            }
        )
    }

    func stopScan() {
        Task { [weak self] in
            await self?.stopScanAsync()
        }
    }

    internal func stopScanAsync() async {
        cbCentralManager.stopScan()

        isScanning = false
        Logger.debug("ble scan stopped.")
        
        await scanCoordinator.stopCurrentStream()
    }
    
    // Legacy api
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

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in


                    group.addTask {
                        for await p in stream {
                            update?(p)
                        }
                    }

                    // optional timeout
                    if let timeoutInterval, let timeoutCompletion {
                        group.addTask { [weak self] in
                            guard let self else { return }
                            try await Task.sleep(nanoseconds: UInt64(timeoutInterval * 1_000_000_000))
                            
                            await self.stopScanAsync()
                            
                            let connectionsArray = Array<Peripheral>(foundPeripherals)
                            timeoutCompletion(.success(connectionsArray))
                        }
                    }

                    // wait: if there's timeout, scan stops when it ends; if not, it remains active until somebody calls stopScan()
                    _ = try await group.next()
                    group.cancelAll()
                }
            } catch is CancellationError {
                // if somebody cancels scan, stop task
                await self.stopScanAsync()
            } catch {
                await self.stopScanAsync()
            }
        }
    }

}

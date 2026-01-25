//
//  Created by Alessio on 25/01/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import CoreBluetooth

// MARK: - Scan API (AsyncStream based)

public extension CentralManager {
    
    /// Stream di periferiche scoperte durante una scansione BLE.
    /// La scansione parte all’inizio dello stream e termina automaticamente
    /// quando lo stream viene cancellato o termina.
    func scan(
        services: [CBUUID]? = nil,
        options: [String: Any]? = nil
    ) -> AsyncStream<Peripheral> {
        
        scanProducer.stream(
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
    
    
    /// Effettua una singola scansione e restituisce le periferiche trovate.
    /// La scansione termina automaticamente allo scadere del timeout.
    func scanOnce(
        services: [CBUUID]? = nil,
        options: [String: Any]? = nil,
        timeout: Duration
    ) async throws -> [Peripheral] {
        
        var peripherals: [Peripheral] = []
        
        let stream = scan(services: services, options: options)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            // Task consumer
            group.addTask {
                for await peripheral in stream {
                    peripherals.append(peripheral)
                }
            }
            
            // Task timeout
            group.addTask {
                try await Task.sleep(for: timeout)
                throw CentralManagerError.connectionTimeoutReached
            }
            
            // Appena uno dei due termina → cancel
            try await group.next()
            group.cancelAll()
        }
        
        return peripherals
    }
}

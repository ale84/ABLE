//
//  Created by Alessio on 02/02/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//


import Foundation
import Combine
import ABLE
import CoreBluetooth

@MainActor
final class ExampleModel: ObservableObject {

    // MARK: - UI state

    struct PeripheralRow {
        let id: String
        let name: String
    }

    @Published var discoveredPeripherals: [PeripheralRow] = []
    @Published var isScanning: Bool = false
    @Published var isAdvertising: Bool = false
    @Published var centralStateText: String = "—"
    @Published var peripheralStateText: String = "—"
    @Published var lastError: String?
    @Published var peripheralLogLastLine: String?

    // MARK: - ABLE

    private let central: CentralManager
    private let peripheralManager: PeripheralManager

    // MARK: - Task handles

    // State observers (long-lived)
    private var centralStateTask: Task<Void, Never>?
    private var peripheralStateTask: Task<Void, Never>?

    // Central flow
    private var centralTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    // Peripheral flow
    private var peripheralTask: Task<Void, Never>?
    private var readyTask: Task<Void, Never>?
    private var readReqTask: Task<Void, Never>?
    private var writeReqTask: Task<Void, Never>?

    // MARK: - Init / Deinit

    init() {
        central = CentralManager(queue: .main)
        peripheralManager = PeripheralManager(queue: .main)
        startStateObservers()
    }

    deinit {
        centralStateTask?.cancel()
        peripheralStateTask?.cancel()
        centralTask?.cancel()
        scanTask?.cancel()
        peripheralTask?.cancel()
        readyTask?.cancel()
        readReqTask?.cancel()
        writeReqTask?.cancel()
    }

    // MARK: - State observers

    private func startStateObservers() {
        centralStateTask?.cancel()
        peripheralStateTask?.cancel()

        centralStateTask = Task {
            for await state in central.stateStream() {
                centralStateText = "\(state)"
            }
        }

        peripheralStateTask = Task {
            for await state in peripheralManager.stateStream() {
                peripheralStateText = "\(state)"
            }
        }
    }

    // MARK: - Central flow

    func startCentralFlow() {
        lastError = nil
        discoveredPeripherals = []

        centralTask?.cancel()
        scanTask?.cancel()

        centralTask = Task {
            do {
                _ = try await central.waitForPoweredOn(timeout: .seconds(6))

                isScanning = true
                let stream = central.scan(services: nil)

                scanTask = Task {
                    for await peripheral in stream {
                        let name = peripheral.name ?? "Unknown"
                        let id = peripheral.cbPeripheral.identifier.uuidString

                        if !discoveredPeripherals.contains(where: { $0.id == id }) {
                            discoveredPeripherals.append(.init(id: id, name: name))
                        }
                    }
                    isScanning = false
                }

                try await Task.sleep(nanoseconds: 6_000_000_000)
                stopCentralFlow()

            } catch is CancellationError {
                // ok
            } catch {
                lastError = "Central flow error: \(error)"
                isScanning = false
            }
        }
    }

    func stopCentralFlow() {
        scanTask?.cancel()
        scanTask = nil

        centralTask?.cancel()
        centralTask = nil

        central.stopScan()
        isScanning = false
    }

    // MARK: - Peripheral flow

    func startPeripheralFlow() {
        lastError = nil

        peripheralTask?.cancel()
        readyTask?.cancel()
        readReqTask?.cancel()
        writeReqTask?.cancel()

        peripheralTask = Task {
            do {
                _ = try await peripheralManager.waitForPoweredOn(timeout: .seconds(6))

                let service = CBMutableService(
                    type: CBUUID(string: "DE036077-4293-4768-B9EF-66429B46A3CB"),
                    primary: true
                )

                _ = try await peripheralManager.add(service)
                try await peripheralManager.startAdvertising()

                isAdvertising = true
                peripheralLogLastLine = "Advertising started"

                readyTask = Task {
                    for await _ in peripheralManager.readyToUpdateSubscribersStream {
                        peripheralLogLastLine = "Ready to update subscribers"
                    }
                }

                readReqTask = Task {
                    for await req in peripheralManager.readRequestsStream {
                        peripheralLogLastLine = "Read request: \(req)"
                    }
                }

                writeReqTask = Task {
                    for await req in peripheralManager.writeRequestsStream {
                        peripheralLogLastLine = "Write request: \(req)"
                    }
                }

            } catch is CancellationError {
                // ok
            } catch {
                lastError = "Peripheral flow error: \(error)"
                isAdvertising = false
            }
        }
    }

    func stopPeripheralFlow() {
        peripheralTask?.cancel()
        peripheralTask = nil

        readyTask?.cancel(); readyTask = nil
        readReqTask?.cancel(); readReqTask = nil
        writeReqTask?.cancel(); writeReqTask = nil

        peripheralManager.stopAdvertising()
        isAdvertising = false
        peripheralLogLastLine = "Advertising stopped"
    }
}


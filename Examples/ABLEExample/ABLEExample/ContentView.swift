//
//  Created by Alessio on 02/02/26
//  Copyright © 2026 Alessio Orlando. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = ExampleModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Central (async)") {
                    LabeledContent("State", value: model.centralStateText)

                    HStack {
                        Button("Start scan") { model.startCentralFlow() }
                            .disabled(model.isScanning)

                        Button("Stop") { model.stopCentralFlow() }
                            .disabled(!model.isScanning)
                    }

                    if model.discoveredPeripherals.isEmpty {
                        Text("No peripherals yet…")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.discoveredPeripherals, id: \.id) { p in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.name)
                                Text(p.id)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("PeripheralManager (async)") {
                    LabeledContent("State", value: model.peripheralStateText)
                    LabeledContent("Advertising", value: model.isAdvertising ? "ON" : "OFF")

                    HStack {
                        Button("Start advertising") { model.startPeripheralFlow() }
                            .disabled(model.isAdvertising)

                        Button("Stop") { model.stopPeripheralFlow() }
                            .disabled(!model.isAdvertising)
                    }

                    if let msg = model.peripheralLogLastLine {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = model.lastError {
                    Section("Last error") {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("ABLE Example")
        }
    }
}

#Preview {
    ContentView()
}

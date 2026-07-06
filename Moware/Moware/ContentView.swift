//
//  ContentView.swift
//  Moware
//
//  Created by Anant Sharma on 7/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = NexusCentralManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Moware")
                    .font(.largeTitle.bold())

                ForEach(0..<NexusProtocol.maxConnectedPeripherals, id: \.self) { slot in
                    if slot < manager.orderedDevices.count {
                        CorePanelView(device: manager.orderedDevices[slot])
                    } else {
                        CorePanelView.placeholder
                    }
                }
            }
            .padding()
        }
        .task {
            manager.startScanning()
        }
    }
}

#Preview {
    ContentView()
}

//
//  ContentView.swift
//  Moware
//
//  Created by Anant Sharma on 7/6/26.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = NexusCentralManager()
    @State private var showDevicePanel = false

    private var connectedCount: Int {
        manager.devices.values.filter(\.phase.isConnected).count
    }

    private var statusColor: Color {
        switch connectedCount {
        case 2...: .green
        case 1: .orange
        default: .red
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        if manager.orderedDevices.isEmpty {
                            Text("Open the devices panel to connect a core")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(manager.orderedDevices) { device in
                                CorePanelView(device: device)
                            }
                        }

                        AvatarView(assembler: manager.bodyFrameAssembler)

                        BodyFrameView(assembler: manager.bodyFrameAssembler)
                    }
                    .padding()
                }
                .navigationTitle("Moware")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showDevicePanel = true
                        } label: {
                            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                                .foregroundStyle(statusColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .task {
                manager.startScanning()
            }

            Color.black.opacity(showDevicePanel ? 0.3 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(showDevicePanel)
                .onTapGesture { showDevicePanel = false }

            DevicePanel(manager: manager, isPresented: $showDevicePanel)
                .frame(maxWidth: 320)
                .offset(x: showDevicePanel ? 0 : -320)
        }
        .animation(.easeInOut, value: showDevicePanel)
    }
}

private struct DevicePanel: View {
    let manager: NexusCentralManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Devices")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(manager.orderedDevices) { device in
                        DeviceRow(device: device, manager: manager)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(.ultraThinMaterial)
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct DeviceRow: View {
    let device: CoreDeviceState
    let manager: NexusCentralManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    if device.isPaired {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                    }
                }
                Text(device.phase.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch device.phase {
            case .discovered, .disconnected:
                Button("Connect") {
                    manager.connect(device.id)
                }
                .buttonStyle(.bordered)
            default:
                Button("Disconnect", role: .destructive) {
                    manager.disconnect(device.id)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(7)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
}

import MyRAMSyncCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: MultipeerSyncController

    var body: some View {
        NavigationStack {
            List {
                Section("Local Changes") {
                    TextField("Note text", text: $controller.noteText, axis: .vertical)
                    Button("Save Note") {
                        controller.save(entityType: .note, entityID: "demo-note", text: controller.noteText)
                    }

                    TextField("Folder name", text: $controller.folderName)
                    Button("Save Folder") {
                        controller.save(entityType: .folder, entityID: "demo-folder", text: controller.folderName)
                    }

                    TextField("Pinned highlight", text: $controller.pinnedHighlight, axis: .vertical)
                    Button("Save Pinned Highlight") {
                        controller.save(entityType: .pinnedHighlight, entityID: "demo-pin", text: controller.pinnedHighlight)
                    }
                }

                Section("Connection") {
                    LabeledContent("Device", value: controller.localPeerName)
                    LabeledContent("Status", value: controller.connectionSummary)
                    LabeledContent("Queued Changes", value: "\(controller.pendingChangeCount)")

                    Button("Manual Sync") {
                        controller.flushPendingChanges()
                    }
                    .disabled(controller.connectedPeers.isEmpty)
                }

                Section("Nearby Devices") {
                    if controller.availablePeers.isEmpty {
                        Text("No nearby devices")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(controller.availablePeers) { peer in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(peer.displayName)
                                Text(peer.isTrusted ? "Trusted" : "New device")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(peer.isTrusted ? "Reconnect" : "Pair") {
                                controller.invite(peer)
                            }
                        }
                    }
                }

                Section("Received Records") {
                    ForEach(controller.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.headline)
                            Text(record.value)
                            Text(record.updatedAt.formatted(date: .abbreviated, time: .standard))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("MyRAM Sync Test")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        controller.refreshRecords()
                    }
                }
            }
        }
    }
}

import MyRAMSyncCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: MultipeerSyncController
    @FocusState private var focusedField: EditableField?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        section("Local Changes") {
                            changeEditor(
                                title: "Note",
                                text: $controller.noteText,
                                field: .note,
                                minHeight: max(120, proxy.size.height * 0.22),
                                saveTitle: "Save Note"
                            ) {
                                controller.save(entityType: .note, entityID: "demo-note", text: controller.noteText)
                            }

                            changeEditor(
                                title: "Folder",
                                text: $controller.folderName,
                                field: .folder,
                                minHeight: 48,
                                saveTitle: "Save Folder"
                            ) {
                                controller.save(entityType: .folder, entityID: "demo-folder", text: controller.folderName)
                            }

                            changeEditor(
                                title: "Pinned Highlight",
                                text: $controller.pinnedHighlight,
                                field: .pinnedHighlight,
                                minHeight: max(96, proxy.size.height * 0.16),
                                saveTitle: "Save Highlight"
                            ) {
                                controller.save(entityType: .pinnedHighlight, entityID: "demo-pin", text: controller.pinnedHighlight)
                            }
                        }

                        section("Connection") {
                            LabeledContent("Device", value: controller.localPeerName)
                            LabeledContent("Status", value: controller.connectionSummary)
                            LabeledContent("Queued Changes", value: "\(controller.pendingChangeCount)")

                            Button("Manual Sync") {
                                controller.flushPendingChanges()
                            }
                            .buttonStyle(.bordered)
                            .disabled(controller.connectedPeers.isEmpty)
                        }

                        section("Nearby Devices") {
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
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        section("Received Records") {
                            if controller.records.isEmpty {
                                Text("No records synced yet")
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(controller.records) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                                        .font(.headline)
                                    Text(record.value)
                                    Text(record.updatedAt.formatted(date: .abbreviated, time: .standard))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("MyRAM Sync Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        controller.refreshRecords()
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func changeEditor(
        title: String,
        text: Binding<String>,
        field: EditableField,
        minHeight: CGFloat,
        saveTitle: String,
        save: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(saveTitle) {
                    focusedField = nil
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            TextField(title, text: text, axis: .vertical)
                .focused($focusedField, equals: field)
                .lineLimit(1...8)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
        }
    }
}

private enum EditableField: Hashable {
    case note
    case folder
    case pinnedHighlight
}

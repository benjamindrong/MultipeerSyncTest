import SyncCore
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
                                title: "Item",
                                text: $controller.itemText,
                                entityType: .item,
                                entityID: "demo-item",
                                field: .item,
                                minHeight: max(120, proxy.size.height * 0.22),
                                saveTitle: "Save Item"
                            )

                            changeEditor(
                                title: "Collection",
                                text: $controller.collectionName,
                                entityType: .collection,
                                entityID: "demo-collection",
                                field: .collection,
                                minHeight: 48,
                                saveTitle: "Save Collection"
                            )

                            changeEditor(
                                title: "Marker",
                                text: $controller.marker,
                                entityType: .marker,
                                entityID: "demo-marker",
                                field: .marker,
                                minHeight: max(96, proxy.size.height * 0.16),
                                saveTitle: "Save Marker"
                            )
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

                        section("Preserved Conflicts") {
                            if controller.conflicts.isEmpty {
                                Text("No preserved conflicts")
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(controller.conflicts) { conflict in
                                conflictRow(conflict)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    .padding(16)
                }
                .background(Color(.systemGroupedBackground))
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Sync Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        controller.refreshRecords()
                        controller.refreshConflicts()
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
        entityType: SyncEntityType,
        entityID: String,
        field: EditableField,
        minHeight: CGFloat,
        saveTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(saveTitle) {
                    focusedField = nil
                    controller.save(entityType: entityType, entityID: entityID, text: text.wrappedValue)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Delete") {
                    focusedField = nil
                    controller.delete(entityType: entityType, entityID: entityID, text: text.wrappedValue)
                }
                .buttonStyle(.bordered)
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

    private func conflictRow(_ conflict: SyncTextConflictVersion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflict.entityType.rawValue) / \(conflict.fieldID)")
                        .font(.subheadline.weight(.semibold))
                    Text(conflict.remoteOperation == .delete ? "Remote delete preserved" : "Remote edit preserved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(conflict.preservedAt.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Remote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(conflict.remoteText.isEmpty ? "Empty text" : conflict.remoteText)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Local")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(conflict.localText.isEmpty ? "Empty text" : conflict.localText)
                    .textSelection(.enabled)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    Button("Copy Remote") {
                        controller.copyConflict(conflict)
                    }
                    Button("Restore Remote") {
                        controller.restoreConflict(conflict)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reviewed") {
                        controller.markConflictReviewed(conflict)
                    }
                }
                VStack(alignment: .leading) {
                    Button("Copy Remote") {
                        controller.copyConflict(conflict)
                    }
                    Button("Restore Remote") {
                        controller.restoreConflict(conflict)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reviewed") {
                        controller.markConflictReviewed(conflict)
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum EditableField: Hashable {
    case item
    case collection
    case marker
}

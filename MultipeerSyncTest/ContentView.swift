import NearbySyncCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: MultipeerSyncController
    @FocusState private var editorIsFocused: Bool
    @State private var selectedDraft = EditableDraft.item
    private let contentSpacing: CGFloat = 14

    private var selectedText: Binding<String> {
        switch selectedDraft {
        case .item:
            $controller.itemText
        case .collection:
            $controller.collectionName
        case .marker:
            $controller.marker
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    Group {
                        if proxy.size.width >= 700 {
                            wideContent
                        } else {
                            compactContent
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, horizontalPadding(for: proxy.size.width))
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Sync Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        controller.refreshRecords()
                        controller.refreshConflicts()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.body)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        editorIsFocused = false
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .dynamicTypeSize(.medium ... .large)
    }

    private var compactContent: some View {
        VStack(spacing: contentSpacing) {
            localChangeSection
            StatusSection(controller: controller)
                .frame(maxWidth: .infinity)
            NearbyDevicesSection(controller: controller)
                .frame(maxWidth: .infinity)
            ConflictsSection(controller: controller)
                .frame(maxWidth: .infinity)
            RecordsSection(controller: controller)
                .frame(maxWidth: .infinity)
        }
    }

    private var wideContent: some View {
        Grid(alignment: .top, horizontalSpacing: contentSpacing, verticalSpacing: contentSpacing) {
            GridRow {
                localChangeSection
                    .frame(maxWidth: .infinity)
                StatusSection(controller: controller)
                    .frame(maxWidth: .infinity)
            }

            GridRow {
                NearbyDevicesSection(controller: controller)
                    .frame(maxWidth: .infinity)
                ConflictsSection(controller: controller)
                    .frame(maxWidth: .infinity)
            }

            GridRow {
                RecordsSection(controller: controller)
                    .gridCellColumns(2)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var localChangeSection: some View {
        LocalChangeSection(
            selectedDraft: $selectedDraft,
            text: selectedText,
            editorIsFocused: $editorIsFocused,
            save: saveSelectedDraft,
            delete: deleteSelectedDraft
        )
        .frame(maxWidth: .infinity)
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width >= 700 ? 24 : 16
    }

    private func saveSelectedDraft() {
        editorIsFocused = false
        controller.save(
            entityType: selectedDraft.entityType,
            entityID: selectedDraft.entityID,
            text: selectedText.wrappedValue
        )
    }

    private func deleteSelectedDraft() {
        editorIsFocused = false
        controller.delete(
            entityType: selectedDraft.entityType,
            entityID: selectedDraft.entityID,
            text: selectedText.wrappedValue
        )
    }
}

private struct LocalChangeSection: View {
    @Binding var selectedDraft: EditableDraft
    @Binding var text: String
    var editorIsFocused: FocusState<Bool>.Binding
    let save: () -> Void
    let delete: () -> Void

    var body: some View {
        GroupBox(label: Label("Local Change", systemImage: "square.and.pencil")) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Type", selection: $selectedDraft) {
                    ForEach(EditableDraft.allCases) { draft in
                        Text(draft.title).tag(draft)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)

                TextEditor(text: $text)
                    .focused(editorIsFocused)
                    .frame(height: 92)
                    .font(.body)
                    .padding(6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12))
                    )

                VStack(spacing: 8) {
                    Button(action: save) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Save \(selectedDraft.title)")
                        }
                        .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button(role: .destructive, action: delete) {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                            Text("Delete \(selectedDraft.title)")
                        }
                        .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct StatusSection: View {
    @ObservedObject var controller: MultipeerSyncController

    var body: some View {
        GroupBox(label: Label("Connection Status", systemImage: "wifi")) {
            VStack(spacing: 0) {
                InfoRow(label: "Device", value: controller.localPeerName, icon: "iphone")
                Divider()
                InfoRow(
                    label: "Status",
                    value: controller.connectionSummary,
                    icon: "dot.radiowaves.left.and.right",
                    valueColor: controller.connectedPeers.isEmpty ? .orange : .green
                )
                Divider()
                InfoRow(
                    label: "Queued",
                    value: "\(controller.pendingChangeCount)",
                    icon: "tray.and.arrow.up",
                    valueColor: controller.pendingChangeCount > 0 ? .red : .secondary
                )

                Button {
                    controller.flushPendingChanges()
                } label: {
                    Label("Manual Sync", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.medium))
                .disabled(controller.connectedPeers.isEmpty)
                .padding(.top, 8)
            }
            .padding(.top, 6)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .frame(width: 92, alignment: .leading)

            Spacer(minLength: 8)

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

private struct NearbyDevicesSection: View {
    @ObservedObject var controller: MultipeerSyncController

    var body: some View {
        GroupBox(label: Label("Nearby Devices", systemImage: "antenna.radiowaves.left.and.right")) {
            if controller.availablePeers.isEmpty {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Scanning for peers...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(controller.availablePeers.enumerated()), id: \.element.id) { index, peer in
                        if index > 0 { Divider() }
                        PeerRow(peer: peer) {
                            controller.invite(peer)
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct PeerRow: View {
    let peer: DiscoveredPeer
    let invite: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "iphone")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(peer.isTrusted ? "Trusted" : "New device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(peer.isTrusted ? "Reconnect" : "Pair", action: invite)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.vertical, 8)
    }
}

private struct ConflictsSection: View {
    @ObservedObject var controller: MultipeerSyncController

    var body: some View {
        GroupBox(label: Label("Preserved Conflicts", systemImage: "exclamationmark.triangle")) {
            if controller.conflicts.isEmpty {
                Text("No preserved conflicts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(controller.conflicts.enumerated()), id: \.element.id) { index, conflict in
                        if index > 0 { Divider() }
                        ConflictRow(conflict: conflict, controller: controller)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct ConflictRow: View {
    let conflict: SyncTextConflictVersion
    @ObservedObject var controller: MultipeerSyncController
    @State private var isEditing = false
    @State private var editedText = ""

    private var currentText: String {
        controller.currentText(for: conflict)
    }

    private var otherText: String {
        controller.otherText(for: conflict)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(conflict.entityType.rawValue.capitalized, systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Merged Result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $editedText)
                        .frame(minHeight: 92)
                        .font(.subheadline)
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.secondary.opacity(0.12))
                        )
                }
            } else {
                conflictTextBlock(title: "Local Version", text: currentText)
                conflictTextBlock(title: "Version to Sync", text: otherText)
                conflictTextBlock(title: "Merged Result", text: otherText)
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    conflictActions
                }
                VStack(alignment: .leading) {
                    conflictActions
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 10)
    }

    private func conflictTextBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text.isEmpty ? "Empty text" : text)
                .font(.subheadline)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var conflictActions: some View {
        Group {
            if isEditing {
                Button("Save Merged Result") {
                    controller.applyEditedConflict(conflict, text: editedText)
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel") {
                    editedText = otherText
                    isEditing = false
                }
            } else {
                Button("Edit Merged Result") {
                    editedText = otherText
                    isEditing = true
                }
                .disabled(conflict.remoteOperation == .delete)

                Button("Copy Version to Sync") {
                    controller.copyConflict(conflict)
                }

                Button("Use Version to Sync") {
                    controller.applyEditedConflict(conflict, text: otherText)
                }
                .buttonStyle(.borderedProminent)

                Button("Keep Local") {
                    controller.markConflictReviewed(conflict)
                }
            }
        }
    }
}

private struct RecordsSection: View {
    @ObservedObject var controller: MultipeerSyncController

    var body: some View {
        GroupBox(label: Label("Synced Records", systemImage: "tray.and.arrow.down")) {
            if controller.records.isEmpty {
                Text("No records synced yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(controller.records.prefix(20).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Divider() }
                        RecordRow(record: record)
                    }
                }
                .padding(.top, 6)
            }
        }
    }
}

private struct RecordRow: View {
    let record: DisplayedRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(record.value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

private enum EditableDraft: String, CaseIterable, Identifiable {
    case item
    case collection
    case marker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .item:
            "Item"
        case .collection:
            "Collection"
        case .marker:
            "Marker"
        }
    }

    var entityType: SyncEntityType {
        switch self {
        case .item:
            .item
        case .collection:
            .collection
        case .marker:
            .marker
        }
    }

    var entityID: String {
        switch self {
        case .item:
            "demo-item"
        case .collection:
            "demo-collection"
        case .marker:
            "demo-marker"
        }
    }
}

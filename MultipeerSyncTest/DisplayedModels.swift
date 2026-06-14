import MultipeerConnectivity
import MyRAMSyncCore
import Foundation

struct DiscoveredPeer: Identifiable {
    let peerID: MCPeerID
    let deviceID: String
    let displayName: String
    var isTrusted: Bool

    var id: String { deviceID }
}

struct DisplayedRecord: Identifiable {
    let id: String
    let title: String
    let value: String
    let updatedAt: Date

    init(record: MyRAMSyncRecord) {
        id = "\(record.entityType.rawValue)-\(record.entityID)"
        title = record.entityType.rawValue
        value = String(data: record.payload, encoding: .utf8) ?? "<binary>"
        updatedAt = record.updatedAt
    }
}

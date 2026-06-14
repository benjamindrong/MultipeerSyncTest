import Foundation

public enum MyRAMSyncEntityType: String, Codable, CaseIterable, Sendable {
    case note
    case folder
    case pinnedHighlight
}

public enum MyRAMSyncOperation: String, Codable, Sendable {
    case upsert
    case delete
}

public struct MyRAMSyncChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let entityType: MyRAMSyncEntityType
    public let entityID: String
    public let operation: MyRAMSyncOperation
    public let payload: Data
    public let updatedAt: Date
    public let originDeviceID: String

    public init(
        id: UUID = UUID(),
        entityType: MyRAMSyncEntityType,
        entityID: String,
        operation: MyRAMSyncOperation,
        payload: Data,
        updatedAt: Date,
        originDeviceID: String
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.operation = operation
        self.payload = payload
        self.updatedAt = updatedAt
        self.originDeviceID = originDeviceID
    }
}

public struct MyRAMSyncEnvelope: Codable, Equatable, Sendable {
    public let senderDeviceID: String
    public let sentAt: Date
    public let changes: [MyRAMSyncChange]

    public init(senderDeviceID: String, sentAt: Date = Date(), changes: [MyRAMSyncChange]) {
        self.senderDeviceID = senderDeviceID
        self.sentAt = sentAt
        self.changes = changes
    }
}

public struct MyRAMSyncRecord: Equatable, Sendable {
    public let entityType: MyRAMSyncEntityType
    public let entityID: String
    public var payload: Data
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(
        entityType: MyRAMSyncEntityType,
        entityID: String,
        payload: Data,
        updatedAt: Date,
        isDeleted: Bool = false
    ) {
        self.entityType = entityType
        self.entityID = entityID
        self.payload = payload
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}

public struct MyRAMSyncApplyResult: Equatable, Sendable {
    public var appliedChangeIDs: [UUID]
    public var ignoredDuplicateIDs: [UUID]
    public var ignoredStaleIDs: [UUID]

    public init(
        appliedChangeIDs: [UUID] = [],
        ignoredDuplicateIDs: [UUID] = [],
        ignoredStaleIDs: [UUID] = []
    ) {
        self.appliedChangeIDs = appliedChangeIDs
        self.ignoredDuplicateIDs = ignoredDuplicateIDs
        self.ignoredStaleIDs = ignoredStaleIDs
    }
}

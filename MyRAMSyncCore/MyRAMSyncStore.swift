import Foundation

public protocol MyRAMSyncStore: AnyObject, Sendable {
    func record(for entityType: MyRAMSyncEntityType, entityID: String) async -> MyRAMSyncRecord?
    func apply(_ change: MyRAMSyncChange) async -> Bool
    func allRecords() async -> [MyRAMSyncRecord]
}

public actor InMemoryMyRAMSyncStore: MyRAMSyncStore {
    private var records: [RecordKey: MyRAMSyncRecord] = [:]

    public init(seedRecords: [MyRAMSyncRecord] = []) {
        for record in seedRecords {
            records[RecordKey(type: record.entityType, id: record.entityID)] = record
        }
    }

    public func record(for entityType: MyRAMSyncEntityType, entityID: String) -> MyRAMSyncRecord? {
        records[RecordKey(type: entityType, id: entityID)]
    }

    public func apply(_ change: MyRAMSyncChange) -> Bool {
        let key = RecordKey(type: change.entityType, id: change.entityID)

        if let existing = records[key], existing.updatedAt > change.updatedAt {
            return false
        }

        records[key] = MyRAMSyncRecord(
            entityType: change.entityType,
            entityID: change.entityID,
            payload: change.payload,
            updatedAt: change.updatedAt,
            isDeleted: change.operation == .delete
        )
        return true
    }

    public func allRecords() -> [MyRAMSyncRecord] {
        records.values.sorted {
            if $0.entityType.rawValue == $1.entityType.rawValue {
                return $0.entityID < $1.entityID
            }
            return $0.entityType.rawValue < $1.entityType.rawValue
        }
    }
}

private struct RecordKey: Hashable {
    let type: MyRAMSyncEntityType
    let id: String
}

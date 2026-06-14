import Foundation

public actor MyRAMSyncQueue {
    private var pendingChanges: [MyRAMSyncChange] = []
    private var appliedChangeIDs: Set<UUID> = []

    public init() {}

    public func enqueue(_ change: MyRAMSyncChange) {
        pendingChanges.append(change)
    }

    public func enqueue(_ changes: [MyRAMSyncChange]) {
        pendingChanges.append(contentsOf: changes)
    }

    public func pendingBatch(limit: Int = 100) -> [MyRAMSyncChange] {
        Array(pendingChanges.prefix(limit))
    }

    public func markSent(_ sentChanges: [MyRAMSyncChange]) {
        let sentIDs = Set(sentChanges.map(\.id))
        pendingChanges.removeAll { sentIDs.contains($0.id) }
    }

    public func hasApplied(_ changeID: UUID) -> Bool {
        appliedChangeIDs.contains(changeID)
    }

    public func markApplied(_ changeID: UUID) {
        appliedChangeIDs.insert(changeID)
    }

    public func pendingCount() -> Int {
        pendingChanges.count
    }
}

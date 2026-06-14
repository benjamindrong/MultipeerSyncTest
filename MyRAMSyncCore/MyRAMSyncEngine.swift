import Foundation

public final class MyRAMSyncEngine: @unchecked Sendable {
    public let deviceID: String
    private let store: MyRAMSyncStore
    private let queue: MyRAMSyncQueue

    public init(deviceID: String, store: MyRAMSyncStore, queue: MyRAMSyncQueue = MyRAMSyncQueue()) {
        self.deviceID = deviceID
        self.store = store
        self.queue = queue
    }

    public func recordLocalChange(
        entityType: MyRAMSyncEntityType,
        entityID: String,
        operation: MyRAMSyncOperation = .upsert,
        payload: Data,
        updatedAt: Date = Date()
    ) async -> MyRAMSyncChange {
        let change = MyRAMSyncChange(
            entityType: entityType,
            entityID: entityID,
            operation: operation,
            payload: payload,
            updatedAt: updatedAt,
            originDeviceID: deviceID
        )

        _ = await store.apply(change)
        await queue.enqueue(change)
        return change
    }

    public func nextEnvelope(limit: Int = 100) async -> MyRAMSyncEnvelope? {
        let changes = await queue.pendingBatch(limit: limit)
        guard !changes.isEmpty else { return nil }
        return MyRAMSyncEnvelope(senderDeviceID: deviceID, changes: changes)
    }

    public func markEnvelopeSent(_ envelope: MyRAMSyncEnvelope) async {
        await queue.markSent(envelope.changes)
    }

    public func applyIncomingEnvelope(_ envelope: MyRAMSyncEnvelope) async -> MyRAMSyncApplyResult {
        var result = MyRAMSyncApplyResult()

        for change in envelope.changes {
            if await queue.hasApplied(change.id) {
                result.ignoredDuplicateIDs.append(change.id)
                continue
            }

            await queue.markApplied(change.id)
            let didApply = await store.apply(change)

            if didApply {
                result.appliedChangeIDs.append(change.id)
            } else {
                result.ignoredStaleIDs.append(change.id)
            }
        }

        return result
    }

    public func pendingChangeCount() async -> Int {
        await queue.pendingCount()
    }

    public func records() async -> [MyRAMSyncRecord] {
        await store.allRecords()
    }
}

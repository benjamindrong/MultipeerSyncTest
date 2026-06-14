import XCTest
@testable import MyRAMSyncCore

final class MyRAMSyncCoreTests: XCTestCase {
    func testLocalChangeIsQueuedAndStored() async {
        let store = InMemoryMyRAMSyncStore()
        let engine = MyRAMSyncEngine(deviceID: "device-a", store: store)
        let payload = Data("hello".utf8)

        let change = await engine.recordLocalChange(
            entityType: .note,
            entityID: "note-1",
            payload: payload,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let records = await engine.records()
        let envelope = await engine.nextEnvelope()

        XCTAssertEqual(change.entityID, "note-1")
        XCTAssertEqual(records.first?.payload, payload)
        XCTAssertEqual(envelope?.changes, [change])
    }

    func testSentEnvelopeClearsQueue() async {
        let store = InMemoryMyRAMSyncStore()
        let engine = MyRAMSyncEngine(deviceID: "device-a", store: store)

        _ = await engine.recordLocalChange(
            entityType: .folder,
            entityID: "folder-1",
            payload: Data("Inbox".utf8)
        )

        let envelope = await engine.nextEnvelope()
        XCTAssertEqual(await engine.pendingChangeCount(), 1)

        await engine.markEnvelopeSent(XCTUnwrap(envelope))

        XCTAssertEqual(await engine.pendingChangeCount(), 0)
    }

    func testDuplicateIncomingChangeIsNotAppliedTwice() async {
        let store = InMemoryMyRAMSyncStore()
        let engine = MyRAMSyncEngine(deviceID: "device-b", store: store)
        let change = MyRAMSyncChange(
            entityType: .pinnedHighlight,
            entityID: "pin-1",
            operation: .upsert,
            payload: Data("Pinned".utf8),
            updatedAt: Date(timeIntervalSince1970: 200),
            originDeviceID: "device-a"
        )
        let envelope = MyRAMSyncEnvelope(senderDeviceID: "device-a", changes: [change])

        let firstResult = await engine.applyIncomingEnvelope(envelope)
        let secondResult = await engine.applyIncomingEnvelope(envelope)

        XCTAssertEqual(firstResult.appliedChangeIDs, [change.id])
        XCTAssertEqual(secondResult.ignoredDuplicateIDs, [change.id])
    }

    func testNewestUpdatedAtWinsConflict() async {
        let store = InMemoryMyRAMSyncStore()
        let engine = MyRAMSyncEngine(deviceID: "device-b", store: store)
        let newerChange = MyRAMSyncChange(
            entityType: .note,
            entityID: "note-1",
            operation: .upsert,
            payload: Data("newer".utf8),
            updatedAt: Date(timeIntervalSince1970: 300),
            originDeviceID: "device-a"
        )
        let olderChange = MyRAMSyncChange(
            entityType: .note,
            entityID: "note-1",
            operation: .upsert,
            payload: Data("older".utf8),
            updatedAt: Date(timeIntervalSince1970: 250),
            originDeviceID: "device-c"
        )

        _ = await engine.applyIncomingEnvelope(MyRAMSyncEnvelope(senderDeviceID: "device-a", changes: [newerChange]))
        let staleResult = await engine.applyIncomingEnvelope(MyRAMSyncEnvelope(senderDeviceID: "device-c", changes: [olderChange]))

        let record = await store.record(for: .note, entityID: "note-1")
        XCTAssertEqual(record?.payload, Data("newer".utf8))
        XCTAssertEqual(staleResult.ignoredStaleIDs, [olderChange.id])
    }

    func testQueuedChangesRemainAvailableForCatchUpBeforeSendAck() async {
        let store = InMemoryMyRAMSyncStore()
        let engine = MyRAMSyncEngine(deviceID: "device-a", store: store)

        _ = await engine.recordLocalChange(entityType: .note, entityID: "note-1", payload: Data("one".utf8))
        _ = await engine.recordLocalChange(entityType: .folder, entityID: "folder-1", payload: Data("two".utf8))

        let reconnectEnvelope = await engine.nextEnvelope()

        XCTAssertEqual(reconnectEnvelope?.changes.count, 2)
        XCTAssertEqual(await engine.pendingChangeCount(), 2)
    }
}

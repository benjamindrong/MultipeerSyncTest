import Combine
import MultipeerConnectivity
import SyncCore
import SwiftUI

@MainActor
final class MultipeerSyncController: NSObject, ObservableObject {
    @Published var itemText = ""
    @Published var collectionName = ""
    @Published var marker = ""
    @Published private(set) var availablePeers: [DiscoveredPeer] = []
    @Published private(set) var connectedPeers: [String] = []
    @Published private(set) var records: [DisplayedRecord] = []
    @Published private(set) var pendingChangeCount = 0

    let localPeerName: String

    private let serviceType = "generic-sync"
    private let peerID: MCPeerID
    private let trustedPeerStore = UserDefaultsTrustedPeerStore(key: "generic.sync.trustedPeers")
    private let syncStore = InMemorySyncStore()
    private let syncEngine: SyncEngine
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private lazy var debouncedSender = DebouncedChangeSender { [weak self] in
        await self?.sendPendingChanges()
    }

    override init() {
        let deviceName = DeviceIdentity.currentDisplayName()
        let storedDeviceID = DeviceIdentity.currentDeviceID()
        let peer = MCPeerID(displayName: "\(deviceName)|\(storedDeviceID)")

        localPeerName = deviceName
        peerID = peer
        syncEngine = SyncEngine(deviceID: storedDeviceID, store: syncStore)
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)

        super.init()

        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        refreshRecords()
    }

    var connectionSummary: String {
        connectedPeers.isEmpty ? "Disconnected" : connectedPeers.joined(separator: ", ")
    }

    func invite(_ peer: DiscoveredPeer) {
        browser.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 12)
    }

    func save(entityType: SyncEntityType, entityID: String, text: String) {
        Task {
            guard let data = text.data(using: .utf8) else { return }
            _ = await syncEngine.recordLocalChange(
                entityType: entityType,
                entityID: entityID,
                payload: data,
                updatedAt: Date()
            )
            await updatePendingCount()
            refreshRecords()
            debouncedSender.schedule()
        }
    }

    func flushPendingChanges() {
        debouncedSender.flushNow()
    }

    func refreshRecords() {
        Task {
            let syncRecords = await syncEngine.records()
            records = syncRecords.map(DisplayedRecord.init(record:))
        }
    }

    private func sendPendingChanges() async {
        guard !session.connectedPeers.isEmpty else {
            await updatePendingCount()
            return
        }

        guard let envelope = await syncEngine.nextEnvelope() else {
            await updatePendingCount()
            return
        }

        do {
            let data = try JSONEncoder().encode(envelope)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            await syncEngine.markEnvelopeSent(envelope)
        } catch {
            // Keep the queue intact so reconnect/manual sync can retry.
        }

        await updatePendingCount()
    }

    private func updatePendingCount() async {
        pendingChangeCount = await syncEngine.pendingChangeCount()
    }

    private func rememberTrustedPeer(_ peerID: MCPeerID) {
        let identity = PeerIdentity(peerID: peerID)
        trustedPeerStore.trust(TrustedPeer(id: identity.deviceID, displayName: identity.displayName))
        trustedPeerStore.markSeen(peerID: identity.deviceID)
        updateAvailableTrustState()
    }

    private func updateAvailableTrustState() {
        availablePeers = availablePeers.map { peer in
            var updated = peer
            updated.isTrusted = trustedPeerStore.contains(peerID: peer.deviceID)
            return updated
        }
    }
}

extension MultipeerSyncController: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            connectedPeers = session.connectedPeers.map { PeerIdentity(peerID: $0).displayName }

            if state == .connected {
                rememberTrustedPeer(peerID)
                await sendPendingChanges()
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard let envelope = try? JSONDecoder().decode(SyncEnvelope.self, from: data) else { return }
            _ = await syncEngine.applyIncomingEnvelope(envelope)
            rememberTrustedPeer(peerID)
            refreshRecords()
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}

extension MultipeerSyncController: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in
            rememberTrustedPeer(peerID)
            invitationHandler(true, session)
        }
    }
}

extension MultipeerSyncController: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            let identity = PeerIdentity(peerID: peerID)
            guard !availablePeers.contains(where: { $0.deviceID == identity.deviceID }) else { return }

            let discoveredPeer = DiscoveredPeer(
                peerID: peerID,
                deviceID: identity.deviceID,
                displayName: identity.displayName,
                isTrusted: trustedPeerStore.contains(peerID: identity.deviceID)
            )
            availablePeers.append(discoveredPeer)

            if discoveredPeer.isTrusted {
                invite(discoveredPeer)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            let identity = PeerIdentity(peerID: peerID)
            availablePeers.removeAll { $0.deviceID == identity.deviceID }
        }
    }
}

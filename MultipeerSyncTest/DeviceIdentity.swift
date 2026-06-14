import Foundation
import MultipeerConnectivity
#if canImport(UIKit)
import UIKit
#endif

enum DeviceIdentity {
    static func currentDeviceID() -> String {
        let key = "generic.sync.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }

    static func currentDisplayName() -> String {
        #if canImport(UIKit)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Mac"
        #endif
    }
}

struct PeerIdentity {
    let displayName: String
    let deviceID: String

    init(peerID: MCPeerID) {
        let parts = peerID.displayName.split(separator: "|", maxSplits: 1).map(String.init)
        displayName = parts.first ?? peerID.displayName
        deviceID = parts.count > 1 ? parts[1] : peerID.displayName
    }
}

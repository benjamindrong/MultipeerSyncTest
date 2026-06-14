import SwiftUI

@main
struct MultipeerSyncTestApp: App {
    @StateObject private var controller = MultipeerSyncController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
        }
    }
}

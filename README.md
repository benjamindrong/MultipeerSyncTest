# MultipeerSyncTest

Minimal MultipeerConnectivity test app for proving nearby change-based synchronization without cloud services or external servers.

## Scope

- Manual nearby device pairing.
- Remember previously trusted devices.
- Automatically reconnect to trusted devices when both apps are active.
- Maintain live synchronization while connected.
- Queue change-based sync messages while disconnected.
- Perform catch-up synchronization after reconnecting.
- Prevent duplicate application of already-synchronized changes.
- Resolve conflicts with the newest `updatedAt` timestamp.

## Project Layout

- `SyncCore`: reusable sync module shared by the test app and any host application that needs local change synchronization.
- `MultipeerSyncTest`: SwiftUI app using MultipeerConnectivity for local peer discovery, pairing, reconnect, and message delivery.
- `SyncCoreTests`: focused tests for queueing, replay prevention, catch-up, and timestamp conflict behavior.

## Manual Verification

- Verify live synchronization between iPhone and iPad.
- Verify live synchronization between iPhone and Mac Catalyst.
- Verify synchronization remains stable during extended connected sessions.
- Verify reconnect and catch-up synchronization after a connection interruption.

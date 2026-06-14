# MyRAM-MultipeerSyncTest

Minimal MultipeerConnectivity test app for proving nearby MyRAM synchronization before wiring the behavior into the production app.

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

- `MyRAMSyncCore`: reusable sync module intended for use by both MyRAM and this test app.
- `MultipeerSyncTest`: SwiftUI app using MultipeerConnectivity for local peer discovery, pairing, reconnect, and message delivery.
- `MyRAMSyncCoreTests`: focused tests for queueing, replay prevention, catch-up, and timestamp conflict behavior.

## Manual Verification

- Verify live synchronization between iPhone and iPad.
- Verify live synchronization between iPhone and Mac Catalyst.
- Verify synchronization remains stable during extended connected sessions.
- Verify reconnect and catch-up synchronization after a connection interruption.

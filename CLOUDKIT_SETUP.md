# Signed-device integration checks

## Xcode capabilities

Use the existing development team and `iCloud.BonkersBonk.BrainDump` container. The app targets retain CloudKit, CloudDocuments, the iCloud container identifiers, and remote-notification background mode. Record sync uses the private database and the `BrainDumpThoughts` custom zone.

Both the BrainDump app and its embedded BrainDumpShare extension need the registered App Group `group.BonkersBonk.BrainDump`. Enable it for both App IDs and regenerate development/distribution profiles through Xcode's signing controls. The extension bundle ID is `BonkersBonk.BrainDump.Share`. Its version and build numbers match the containing app.

Unsigned simulator builds intentionally do not start CloudKit because CKContainer can trap when the required signed entitlements are absent. Their Sync screen explains that local mode. No cloud performance or delivery guarantee is inferred from simulator tests.

## CloudKit schema

The development database uses two record types:

| Record type | Fields |
| --- | --- |
| `Thought` | `payload` (Bytes), `asset_0` through `asset_9` (Asset) |
| `Category` | `payload` (Bytes) |

Thought IDs are the record names; category record names use `category:<integer ID>`. Status tombstones propagate completion, deletion, and restoration without physically deleting cloud records. Asset slots match attachment positions; removed references are cleared on the next record save.

Initialize and inspect these fields in the development environment using a signed app. Before distribution, promote the compatible schema to production in CloudKit Console. Test development and production builds separately; the successful unsigned build does not perform provisioning or schema deployment.

## Required device verification

1. Install a signed build on two devices signed into the same test iCloud account. Back up existing thoughts before upgrading.
2. Verify legacy thoughts, categories, completed thoughts, and recently deleted thoughts migrate intact.
3. Capture and edit offline; reconnect and check that both devices converge without duplicate thoughts.
4. Edit the same thought independently on both devices, then reconnect. Confirm the losing text is preserved as a recovered thought.
5. Add screenshots and links; confirm previews and full images appear on the other device. Remove attachments and verify the updated record has cleared asset references.
6. Complete, delete, restore, and retag thoughts while the other device is offline. Check that stale data does not resurrect deleted thoughts.
7. Sign out or switch the test iCloud account. Confirm sync pauses, local thoughts remain available, and resuming requires the explicit account choice in Sync and backups.
8. Share images from Photos and URLs from Safari; verify queued captures import once when BrainDump opens, including after an interrupted import.
9. Speak “Hey Siri, add to Brain Dump”, follow the dictation prompt, and verify a durable inbox thought. Check language, locked-device, and offline behaviour supported by Siri.
10. Use Instruments on a real device to measure scrolling, sphere rendering, memory during screenshot import, background activity, and energy use. Test larger libraries and accessibility text sizes.

Cloud scheduling depends on system conditions. Record changes save locally immediately and wait for iCloud when unavailable. Backups remain a separate portable recovery path.

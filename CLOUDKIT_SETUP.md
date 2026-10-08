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

On 6 October 2026, the schema was deployed through CloudKit Console to Production for `iCloud.BonkersBonk.BrainDump`. Console confirmed “The schema is deployed to Production”; production lists Category with 7 fields and Thought with 17 fields, including all ten attachment slots. The new types have no public-database role grants; existing Users permissions were preserved. Signed-device production sync and upgrade validation below remain required.

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

## Upgrade compatibility and release gate

An in-place update retains the `BonkersBonk.BrainDump` bundle identifier and migrates `SavedTileTexts`, `SavedTileIds`, `SavedTileTags`, `SavedTags`, `CompletedTiles`, and `DeletedTiles` into `thoughts-v1.json`. Original defaults remain untouched. Existing category IDs, names, colours, and tile assignments are retained; Pro's capture limit does not truncate an existing library. Later launches load the durable database rather than remigrating old defaults.

The baseline version used iCloud Documents `.bdu`/`.bdp` backup files, not the new CloudKit zone. Record sync does not import those files automatically. Keep old cloud backups intact and use Backups → Restore backup to select an older file; prefer Merge when retaining current thoughts. A reinstall or another device with only an old backup is a separate restore case, not an in-place upgrade.

Before release, install the previously distributed build on a signed device, create and rename categories, assign tiles, archive/delete examples, and save an old iCloud backup. Update that installation without uninstalling. Compare IDs, content, counts, categories, and assignments, relaunch offline, then verify convergence on a second signed device. Repeat with more than 25 active tiles and without a Pro entitlement. Confirm old backups remain accessible and restorable. Simulator tests cannot certify the production CloudKit schema or this end-to-end upgrade.

Recovery now requeues the entire retained collection when its zone is missing, clears obsolete server metadata/assets before recreating records, and schedules local edits made during an upload again. Account-change pauses persist across relaunches.

## Immediate sync and home status

The 7 October TestFlight crash (incident C605408C-A88F-4725-B0D1-C31EB178BDBD) trapped in `CKSyncEngine.sendChanges` because a task scheduled from delegate processing inherited CloudKit's callback context. Manual sync now enters through a detached task, with service bookkeeping still on the main actor. Validate the next signed build with edits during uploads, conflict recovery, repeated Sync now taps, and foreground sync; unsigned simulator checks cannot exercise this CloudKit assertion.

Every durable local change requests a serialized send/fetch pass. Launch and foreground entry also request a pass, including on an empty device. Registering for remote notifications enables CKSyncEngine's automatic subscription-driven downloads; no polling timer is used. The top-right home control shows orange for waiting/unavailable/paused, a spinner during sync, and green after a successful pass with no pending local records. Tap it for the detailed status and Sync now. Green reflects this device's latest successful check, not confirmation that another device has received the records.

Validate using the next TestFlight build on both devices with the same iCloud account: keep both apps open, capture/edit/category-assign/complete/delete on either device, and check convergence in both directions. Repeat with the iPad initially empty, offline changes and foreground return. Capture the Sync screen's exact error if orange persists. Production delivery still requires signed-device validation.

## Cloud environment recovery

Sync state, record change tags, attachment acknowledgements, and queued uploads must belong to the same CloudKit environment. Xcode development and TestFlight production builds share the app's local container when installed over one another, but their cloud databases are separate. Older builds did not record this boundary, so a green status with zero pending records could reflect acknowledgements from the other environment.

The environment-aware upgrade discards only obsolete cloud bookkeeping once for an untracked or changed environment, queues every retained thought/category (including tombstones), and starts fetching without the previous change tokens. Local content and category IDs are preserved. The signed embedded provisioning profile determines the environment when present; the distribution fallback is Production, and Debug's fallback is Development. Account-change pauses still block recovery.

Sync and backups now shows environment, active tile count, pending upload count, session upload/download counts, and the last successful manual check. Rebuild iCloud sync repeats the bookkeeping recovery explicitly without deleting local content or cloud records. Counts include category/archive/tombstone records and repeated changes, so they are not an active-tile cloud inventory.

A device diagnostic read on 6 October confirmed retained local thoughts, zero pending changes, and existing cloud acknowledgements. This confirms local acknowledgement state, not that those records exist in Production. Both devices were reported to be on TestFlight with the same iCloud account. The environment-boundary defect is fixed in source; the actual production cause and two-device recovery still require the next TestFlight build on both devices.

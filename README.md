# BrainDump

BrainDump is a living brain for quickly capturing thoughts and organising them later. Thoughts remain square tiles in both the rotating sphere and the focused category view. Selecting a tile brings its category forward; long press turns the thought towards the user and opens a larger, readable tile.

## Current architecture

- `ContentView.swift`: sphere/category navigation, stable thought-ID selection, gestures, training, and settings integration. It reads records directly rather than maintaining parallel arrays of IDs, text, and categories.
- `ThoughtModels.swift` / `ThoughtStore.swift`: local-first records, categories, attachments, archives, migration, and durable atomic JSON storage in Application Support. UserDefaults holds preferences; old thought defaults remain untouched as a migration recovery source.
- `CloudSyncService.swift`: private CloudKit records with CKSyncEngine, pending changes and persisted engine state, attachment assets with unchanged-image fields left untouched, conflict recovery, and an explicit pause/resume path for iCloud account changes.
- `TileViews.swift` / `CategoryHeader.swift`: readable square previews, independent fill/border colours, thumbnail loading, bounded category rows, and accessible category navigation. Native scroll alignment has one selection binding.
- `ThoughtFocusView.swift` / `ThoughtDetailView.swift`: full text, image zoom, links, category selection, appearance overrides, editing, completion, and deletion. Concurrent editor saves preserve both versions.
- `AttachmentStore.swift`: bounded photo file transfer, off-main ImageIO validation/downsampling, metadata removal, and safe filenames. Images are stored before records reference them.
- `BrainDumpIntents.swift`: Siri and Shortcuts capture into the Brain Dump inbox.
- `BrainDumpShare/` / `CaptureInbox.swift`: Share Sheet capture of text, images, and URLs via an App Group queue. The extension commits each job atomically; only the app writes its database. Stable job IDs prevent duplicate imports after a retry.
- `BackupService.swift` / `BackupSettingsView.swift`: portable version-4 backups including images and appearance; older `.bdu`/`.bdp` JSON remains readable. Import validation precedes an atomic record/category commit.
- `BackgroundViews.swift` / `SphereGeometry.swift` / `SphereTypes.swift`: decorative rendering and sphere mathematics. Animation stops when inactive or Reduce Motion requires it; Low Power Mode reduces animation work.

The app supports iOS 18.6+, iPhone and iPad. There are no third-party dependencies. The repository retains its original GitHub name, ParkingLotV3.

## Behaviour

Capture with +, the Share Sheet, Photos, web links, or the Add to Brain Dump Siri shortcut. Each thought can contain up to ten image/link attachments. Selected photos are bounded at 30 MB and 100 million pixels, converted to metadata-free PNG, and capped at 4096 pixels on their longest edge. Image zoom makes screenshot content readable. Photos are never added automatically from the library.

Tile and border colours are independently customisable at device-default, category, and individual-thought levels. Category and individual settings sync; device defaults remain local. Text contrast is chosen automatically, previews respect Dynamic Type, and full text is available through long press or the accessible Open Thought action.

The category browser retains tiles, stable selection, and a remembered position for each category. Completion moves a thought into the restorable archive. Deletion keeps it in Recently Deleted for 30 days; hidden tombstones remain for sync convergence. Search and duplicate tools remain available. Training uses temporary demo thoughts and never overwrites real captures.

CloudKit handles record changes separately from recovery backups. Text conflicts are preserved as recovered thoughts. Files, retries, queued changes, and explicit account-switch handling are independent of the visible screen. Unsigned simulator builds run locally; signed-device cloud verification is required. See `CLOUDKIT_SETUP.md`.

## Validation and remaining device checks

Meaningful tests cover legacy migration, archive/tombstone retention, corrupt database protection, edit conflicts, first saves, backup round trips and category collisions, invalid images and paths, and the Siri capture path. UI tests cover repeated category scrolling, long press/full-text/dismissal, and capturing a new thought into its category.

A Release iPhone compilation and simulator tests use Xcode 27.0 with signing disabled. These checks do not verify spoken Siri recognition, Share Sheet behaviour in Safari/Photos on a signed phone, actual iCloud delivery between devices, or battery consumption. Those require the signed-device checklist in `CLOUDKIT_SETUP.md`. Local JSON writes are synchronous for durability; large-library profiling remains necessary before claiming production performance.

## Recovery checkpoints

The original working base is committed on `TrainingOnAppStartUp` and tagged `braindump-baseline-2026-10-06`. The rebuild lives on `codex/living-brain-rebuild`.

To inspect the original without replacing this checkout:

```sh
git worktree add ../BrainDump-baseline braindump-baseline-2026-10-06
```

Git protects code and project assets. Export a BrainDump backup separately to protect device thoughts and attachments.

See `AGENTS.md` for development principles and official references, and `STATUS.md` for current verification results.

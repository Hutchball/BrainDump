# BrainDump

BrainDump is an iPhone and iPad productivity app for getting thoughts out of your head quickly and organising them later. Each thought is a coloured tile on an interactive sphere. The Brain button opens the unsorted Brain Dump category so users can clear their inbox by tagging or completing thoughts.

## Core experience

- Drag to rotate the sphere with momentum; pinch to adjust its size.
- Add a thought, tap a tile to enter its tag's focused list, and explicitly select Edit to change text.
- Scroll the focused list to select a tile; swipe horizontally to cycle populated tags.
- Use the default Brain Dump, Things to do, Movies to watch, Books to read, and Websites to check categories, plus up to 20 custom tags.
- Complete thoughts into a restorable archive or delete them into Recently Deleted, purged after 30 days on launch.
- Search active thought text, identify duplicates by normalised text and tag, customise backgrounds and haptics, and replay guided training.
- Opt into a local nightly reminder at 20:30 when unsorted thoughts remain. Notification taps open the Brain Dump list.

## Implementation fundamentals

`BrainDumpApp.swift` launches `ContentView` and installs the notification delegate. `ContentView.swift` (7,258 lines at this baseline) contains the main state, gestures, sphere maths, persistence, backup operations, training, settings, and supporting views. It uses SwiftUI with UIKit bridges for document picking and keyboard handling, Combine for observation, QuartzCore for momentum, and CryptoKit for backup fingerprints. There are no third-party package dependencies in the project.

Thoughts are held in parallel arrays of texts, tag IDs, and UUID strings, with a separate tile count. UserDefaults stores these arrays, tags, preferences, and JSON-encoded archives. `Item.swift` is a SwiftData template model; the running app does not configure a model container or use it for thought storage.

The sphere distributes points using a golden-angle spiral, rotates them with quaternions, and projects them into SwiftUI tile positions. Momentum uses a CADisplayLink requesting 120 fps. Focused lists use LazyVStack, scroll selection, and depth effects. The Space background updates star shimmer every half second.

Backups are version-3 JSON documents exported as `.bdu`; `.bdp` and legacy ParkingLot names remain recognised. Import can merge or replace data. iCloud Drive writes a latest backup and retains up to five timestamped backups, with a six-second debounce and utility-queue file operations. Explicit upload and restore decisions use content fingerprints and prompts. This is file backup, rather than a record-based CloudKit synchronisation engine. CSV export is exposed in the debug menu.

Training uses temporary demo data and snapshots existing user state for replay. Training edits are excluded from normal thought persistence. Finishing first-launch training creates six starter tiles.

## Baseline review — 6 October 2026

The app target supports iOS 18.6 and later, on iPhone and iPad; test targets specify iOS 18.7. Some iOS 26 glass effects have availability guards. The GitHub repository retains its original `ParkingLotV3` name, while this snapshot records the local BrainDump rename.

Areas to review in subsequent work, without changing behaviour in this baseline:

- Split the large view file and introduce a single thought model to avoid parallel-array and count inconsistencies.
- Add meaningful coverage for persistence, import/restore, archives, training, and notification routing. Current unit coverage is a placeholder; UI tests launch the app and measure launch performance.
- Audit VoiceOver labels, Dynamic Type, Reduce Motion, contrast, and gesture alternatives. Tiles currently use fixed sizing and fonts that shrink to 8 points.
- Profile sphere rendering and repeated save operations; review background/inactive lifecycle handling and recurring animation callbacks. The scene-phase handler currently handles returning active but does not explicitly stop momentum on becoming inactive.
- The debug CPU number is calculated from memory size plus randomness, so it is not a performance measurement.
- Review cloud write coordination: routine automatic backups do not run the explicit upload conflict check. Review invalid import feedback and preservation of archives when active data is empty.
- Recheck the filtered-list stacking and snapping issues recorded in the earlier `STATUS.md`; they have not been verified visually in this review.

See `AGENTS.md` for development principles and official Apple and Swift references.

Validation: Debug build for the generic iOS Simulator succeeded using Xcode 27.0 with code signing disabled. Xcode emitted only an App Intents metadata warning because the app has no AppIntents dependency. No simulator interaction, device testing, or functional test run was performed.

## Returning to this baseline

The snapshot is on branch `TrainingOnAppStartUp`, tagged `braindump-baseline-2026-10-06`. For a separate recovery checkout, use `git worktree add ../BrainDump-baseline braindump-baseline-2026-10-06`. Git preserves project files, not thoughts stored on a device; export an app backup separately when those need protection.

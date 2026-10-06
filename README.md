# BrainDump

BrainDump is a living brain for quickly capturing thoughts and organising them later. Thoughts remain square tiles in both the rotating sphere and the focused category view. Tapping a categorised tile opens every tile in that category in a vertically scrollable view, starting at the tapped thought. Tapping an Unsorted tile opens the same Brain Dump sorting queue as the brain icon, starting at that thought; long press turns the thought towards the user and opens a larger, readable tile.

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

The app supports iOS 18.6+, iPhone and iPad. There are no third-party dependencies. The repository is [Hutchball/BrainDump](https://github.com/Hutchball/BrainDump).

## Behaviour

The home sphere assigns thoughts to shuffled, evenly spaced positions independently of category or creation order. These assignments stay stable while browsing and editing; additions and removals update the layout. Vertical category lists retain their existing order.

Settings → Options → Appearance → Sphere edge blur controls a subtle softening of tiles in the sphere’s outer band. The band and blur radius follow sphere size. Selected and inline capture tiles, category lists, and Increased Contrast remain crisp. The setting is stored locally; device rendering and energy impact still require Instruments profiling.

Onboarding starts with six temporary DEMO tiles in each available category, using category colours. The ordered exercises cover sphere dragging, opening a category, scrolling, changing a tile’s category, completion, tapping Plus, writing a nonempty first tile, swiping categories, deep viewing, and returning home. The training panel uses a 35% black background and the same lower position on the home sphere and in category view, below the category heading. The final home panel explains quick capture and later sorting. On first run, the user’s capture autosaves to the real library and survives finishing or backgrounding; replay captures remain temporary. Empty captures never advance the exercise. Finish Training is enabled only on the final home panel.

Opening a category brings its visible tiles in from a fixed circular staging ring outside the screen. The sphere first moves its tiles out to the same ring before category entry. Closing flies category tiles back out, then restores the sphere by animating its tiles inward from the ring. Category changes wait for the outgoing animation to be fully removed before positioning and animating the next collection. Incoming animations also finish before interaction resumes. Lazy rows keep offscreen thoughts unmaterialised, and ring positions require no ongoing animation or background work. Native scroll positioning centres the selected thought before entry; category order and remembered selection remain stable. Reduce Motion switches immediately. Pending animation completions are invalidated when the app becomes inactive.

Tap + for a real blank Unsorted tile brought to the front of the sphere, with the keyboard ready to type directly inside it. The user stays on the sphere throughout capture; no card or sheet opens. Empty or whitespace-only captures with no attachments shrink away when dismissed and are not retained as thoughts. Text saves after a short typing pause and immediately when the app becomes inactive or Done is tapped. New sphere captures start Unsorted; + inside a category creates and edits a tile in that category without leaving the collection. Done or backgrounding ends inline editing, retaining the current category when capturing there. The brain button or an Unsorted tile opens the Unsorted inbox with a pinned horizontal category list; choosing a category sends the tile flying out (unless Reduce Motion is enabled) and advances to the next unsorted thought without dismissing the picker. Sorting dismisses to the sphere when the last Unsorted thought is assigned. With an empty inbox, the brain button gives two brief negative haptic taps and stays on the sphere.

Capture with +, the Share Sheet, Photos, web links, or the Add to Brain Dump Siri shortcut. Each thought can contain up to ten image/link attachments. Selected photos are bounded at 30 MB and 100 million pixels, converted to metadata-free PNG, and capped at 4096 pixels on their longest edge. Image zoom makes screenshot content readable. Photos are never added automatically from the library.

Categorised tiles inherit their category swatch by default, consistently across the sphere, category view, full-text view, and editor. New tiles arrive with a brief spring and halo; dismissal releases the tile with a gentle sphere turn. Reduce Motion skips these effects, and Low Power Mode skips the halo. Debug → Create 100 Test Tiles adds 100 meaningful examples across Unsorted and existing categories (tasks, films, books and websites) without replacing saved thoughts. Category borders default to a dark shade of the fill. Tile borders use stronger contrasting outlines: 4 points normally and 6 points when selected.

Tile and border colours are independently customisable at device-default, category, and individual-thought levels. Category and individual settings sync; device defaults remain local. Text contrast is chosen automatically, previews respect Dynamic Type, and full text is available through long press or the accessible Open Thought action.

Swipe sideways or use the category-header arrows to browse populated categories, including from Unsorted. Returning to Unsorted restores the sorting picker. The category browser retains tiles, stable selection, and a remembered position for each category. Completion turns the tile green, brings it forward through the screen, and fades it into the restorable archive. Reduce Motion completes immediately. Deletion keeps it in Recently Deleted for 30 days; hidden tombstones remain for sync convergence. Search and duplicate tools remain available. Training uses temporary demo thoughts and never overwrites real captures.

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

Settings uses one native page with single-column navigation. About & Privacy shows the actual bundle version/build, a data-handling summary, and braindumpfeedback@cakesquared.co.uk for feedback. The published Privacy Policy is https://cakesquared.co.uk/privacy-policy.html; the website link is https://cakesquared.co.uk.

## BrainDump Pro

Free supports 25 active tiles; monthly or lifetime Pro unlocks unlimited tiles. The purchase screen uses localized StoreKit prices, checks free-trial eligibility, verifies purchases, listens for entitlement changes, and supports restore. Existing thoughts remain readable and editable after expiration. See `PRO_SETUP.md` for the new product IDs, £2.99 monthly / £6.99 lifetime UK pricing, and one-month trial setup. `BrainDumpPro.storekit` supplies local test products; the App Store products must still be created and submitted in App Store Connect.

## Voice capture

Say “Siri, add to BrainDump”, then give the book title or thought when Siri asks. The intent runs without opening the app and saves an active Unsorted tile (category ID 0), available in the sphere next time the app is shown. Free capture respects the 25-active-tile limit. Apple’s App Shortcut metadata processor rejects arbitrary String parameters in trigger phrases, so “add [any book title] to BrainDump” is not advertised as a supported one-shot phrase. Spoken recognition still needs validation on a signed device.

Categories in Settings use adaptive text on rounded grouped-background cards. Each swatch previews the saved tile fill and border, including appearance overrides. New categories have native tile and border colour pickers and a preview; the border automatically darkens the tile colour until manually customised. Category name and both colours are committed together.


## Future Apple Vision Pro development

Vision Pro is deferred from the current release because it has not been tested. Keep this submission focused on iPhone and iPad and disable compatible iPhone/iPad availability on Apple Vision Pro in App Store Connect. Revisit the sphere as a spatial collection of thoughts: prototype native visionOS presentation, gaze and pinch selection, comfortable tile depth and text readability, accessible alternatives to dragging/long press, keyboard capture, and category navigation. Validate on Vision Pro hardware, including persistence, CloudKit, purchases, onboarding, frame performance and energy use, before enabling distribution.

## App Store screenshot capture

Debug builds support an isolated realistic screenshot library with `--living-brain-fixture --app-store-screenshots`. Use `--screenshot-view=home`, `capture`, `books`, `films`, `sort`, or `full` to stage the corresponding view. The fixture uses a temporary store and does not change the saved library; screenshot setup is excluded from Release builds. The exported assets and reproducible AppKit layout renderer are in `/Users/paulhutch/Desktop/App Media/BrainDump App Store`. See that folder’s README for upload sizes and Apple’s current screenshot specifications.

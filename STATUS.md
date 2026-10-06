# BrainDump rebuild status

Updated: 6 October 2026

## Submission readiness preparation — 6 October 2026

Added app/Share extension privacy manifests, with app-only UserDefaults reason CA92.1, no tracking and no developer-collected data in the audited implementation. Removed planned/hardcoded fallback prices and clarified Pro product labels. Both targets retain verified no-non-exempt-encryption declarations. Sphere blur is unchanged at the owner's request.

Release generic iPhone build passed with signing disabled; both manifests are included and parse correctly in the built app/extension. The public privacy page responds over HTTPS. RELEASE_SUBMISSION.md contains review notes, a proposed BrainDump-specific policy addition and outstanding App Store Connect/signed-device checks. No App Store upload, product configuration, public policy publication or production CloudKit deployment was performed.

## Strict training and demo identification — 6 October 2026

Training now gates unrelated controls and follows rotation, category opening, scrolling, category assignment, completion, nonempty inline capture, category change, and full-thought reading/dismissal in order. Finish Training is disabled until the final reading exercise completes, with a matching handler guard. Empty practice capture does not advance. Demo tiles display DEMO, including new practice captures, with demo-specific VoiceOver labels; the reading view is titled Demo thought. Temporary records stay separate from the saved library.

Simulator build and the complete training UI regression passed, covering early disabled actions/Finish, empty capture without advancement, demo accessibility labels, every exercise, and final completion. The scroll check accommodates either starting end of the shuffled category.

## Empty capture crash correction — 6 October 2026

Fixed an invalid-geometry path during removal: a cached shuffled sphere slot can briefly exceed the reduced thought count, producing a negative square-root input. Sphere point generation now bounds transitional slots and protects the square root. Capture release also compacts slot membership in the same transaction as draft removal.

The simulator test build compiled; the finite-geometry regression and eight repeated empty sphere capture/dismissal cycles passed. The existing category whitespace UI test remains blocked by missing keyboard focus, including after explicitly tapping the editor; it did not reach dismissal. Physical iPhone reproduction and retesting remain required to confirm this correction addresses the reported crash.

Implemented on `codex/living-brain-rebuild`:

- Direct record-based views and stable-ID selection; no authoritative parallel UI arrays.
- Native category tile scrolling with one alignment/selection system, remembered category position, and bounded row geometry.
- Square tiles retained in category mode, larger selected tiles, readable previews, independent fill/border colours, and full-thought long press.
- Global/category/thought appearance controls; image thumbnails, zoom, links, and explicit paste.
- Safe selected-image transfer and validation, bounded off-main processing, Share Sheet queue, and Siri/App Shortcuts.
- Durable local migration, record-level CKSyncEngine sync, archives/tombstones, conflict recovery, and account-switch pause/resume.
- Version-4 rich backups and backwards-compatible legacy restore.
- Reduced recurring animation work and removal of simulated CPU percentages.

Verification:

- Debug simulator build: passed.
- Release generic iPhone build with signing disabled: passed.
- 19 meaningful unit tests: migration, storage, conflicts, backups, attachment validation, and Siri capture.
- 3 focused UI tests: category scrolling, expanded thought, and new capture.
- Signed-device cloud delivery, App Group provisioning, spoken Siri, Share Sheet integration, and Instruments profiling remain required; see `CLOUDKIT_SETUP.md`.

The original code remains recoverable using `braindump-baseline-2026-10-06`.

## Quick capture and deferred sorting — 6 October 2026

Restored blank Unsorted capture with automatic saving and dismissal back into the sphere. The brain button opens only uncategorised tiles, keeps the horizontal category picker pinned, and animates assigned tiles out before advancing (immediate with Reduce Motion).

Unsigned simulator build passed. QA simulator UI checks passed for capture and later inbox retrieval, backgrounding without Save, repeated scrolling, full-text opening, and the pinned picker after assignment. The picker check passed on a targeted rerun after adding a stable category-button accessibility identifier. The initial iOS 27 simulator runner stalled during launch; the iOS 26.5 QA simulator completed the checks. Real-device animation and battery checks remain outstanding.

## Capture stays in the sphere — 6 October 2026

Removed the separate quick-capture sheet. + now creates a real Unsorted sphere tile, brings it forward, focuses inline text entry, and keeps surrounding tiles visible. Done or backgrounding saves and releases that same tile into the sphere. Training uses the same inline capture. Updated AGENTS.md and README.md to make this interaction an explicit product requirement.

Final unsigned simulator build passed. QA simulator UI tests passed for inline typing, Done followed by inbox retrieval, and backgrounding without manually saving. Fixed the tile accessibility identifier overriding the editing field during validation.

## Category colours, capture animation, and inbox completion — 6 October 2026

Categorised thoughts inherit their category swatch consistently unless explicit appearance overrides exist; Unsorted retains its device defaults. Cached category swatches avoid repeated colour conversion during sphere animation. Debug → Create 100 Test Tiles now appends 100 thoughts distributed across Unsorted and existing categories with one atomic commit. Capture uses a brief spring arrival and halo, followed by a gentle sphere turn on release; Reduce Motion skips effects and Low Power Mode skips the halo.

Sorting returns to the sphere after the final assignment. With no Unsorted thoughts, the brain button stays on the sphere and requests two short negative haptic impacts (subject to the user’s Haptics setting). Blank or whitespace-only captures with no attachments remain transient and shrink away on dismissal; cleared autosaved captures are removed from the inbox with hidden deletion markers for sync convergence.

Final simulator test build passed: all 10 ThoughtStore tests and four targeted UI tests passed, covering blank disposal, normal capture and later retrieval, background saving, and sorting completion/empty-inbox navigation. A separate Unsorted-tile entry test also passed. Haptic feel and animation polish still need review on a physical device.

## Shuffled sphere, native settings and completion — 6 October 2026

Sphere layout now caches shuffled thought-ID slot assignments independently of record/category order and uses the same mapping for capture and focus. Native Settings replaces the duplicate custom sheet panel; settings navigation uses NavigationStack to avoid iPad split panes. About & Privacy includes actual bundle version/build, copyright year, feedback at braindumpfeedback@cakesquared.co.uk, the owner-provided https://cakesquared.co.uk/privacy-policy.html policy link, and https://cakesquared.co.uk website link. Default category borders are dark shades of their fills; explicit border overrides remain intact.

Completion turns tiles green, zooms them forward and fades them out before archiving. This also applies to the full-text tile; Reduce Motion completes without the effect. Simulator build and targeted UI checks passed for shuffled-sphere capture, completion/removal, and the single Settings page with feedback/version/build/privacy navigation. The Settings test waits for the outgoing sorting panel before tapping its control. Actual haptic feel, iPad presentation and animation appearance still need device review.

## Pro preparation — 6 October 2026

Added StoreKit monthly/lifetime purchase flow, verified entitlement refresh/update handling, restore, localized prices, introductory-trial eligibility, and a 25-active-tile free creation limit. Prepared new v2 product IDs and BrainDumpPro.storekit; see PRO_SETUP.md. Generic simulator build succeeded. All 11 ThoughtStoreTests passed on iPhone 18 Pro simulator, including free-limit/data-preservation coverage. App Store Connect creation and StoreKit purchase/trial/restore/refund tests remain required; no real purchase was performed.

## iCloud and upgrade audit — 6 October 2026

- All 23 BrainDumpTests passed on the iPhone 17 / iOS 27 simulator. Added coverage for an 80-active-tile legacy upgrade retaining stable IDs, category assignments, custom/default category names and colours, deleted records, untouched legacy defaults, and durable relaunch state. Existing libraries above the free limit remain editable.
- Release generic iOS build passed with signing disabled, including the device-specific CloudKit path.
- Fixed requeueing of edits made during successful uploads, recreation of missing cloud records/zones with cleared obsolete metadata, and stale-engine callbacks after account resume. Unknown account changes now persist the sync pause.
- Added older-backup guidance in Backups and an in-place upgrade release gate in CLOUDKIT_SETUP.md. The former iCloud Documents backups are distinct from CloudKit record sync and are not automatically imported.
- Not yet verified: live signed-device/production CloudKit delivery and upgrading an installed distributed build without uninstalling. The automated checks support data preservation but do not certify these external integration checks.

## iCloud environment recovery (6 October 2026)

Added environment-aware sync bookkeeping migration, non-destructive manual sync rebuild, and visible upload/download diagnostics after a report of a green sync light with an empty iPad. Release compilation succeeded. Production delivery is not certified by local compilation or simulator storage tests; validate the updated build on both TestFlight devices.


## Onboarding update — 6 October 2026

- Added six demo thoughts per available category, revised the ordered training panels, and separated tapping Plus from entering a nonempty first capture.
- First-run captures use normal durable autosave; replay captures remain temporary. Added explicit return-home practice and the final quick-capture/later-sort guidance.
- Training banner now starts below the category heading in category view.
- Unsigned Debug simulator build passed. The ordered onboarding UI test passed on the iPhone 17 / iOS 27.0 simulator, including empty-capture retry and instruction/heading separation. First-run capture retention has been reviewed in code; signed-device and first-run relaunch checks remain manual.


## Apple Vision Pro deferral — 6 October 2026

Owner requested Vision Pro be held from submission until tested. Native visionOS 1.0 remains a Prepare for Submission draft. The roadmap in README.md preserves a future spatial sphere experience and device-validation requirements. Compatible iPhone/iPad availability was turned off in App Store Connect; verify this setting remains off before release.

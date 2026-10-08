# BrainDump development guidance

Build a polished, responsive iOS app that follows Apple's Human Interface Guidelines, uses efficient code, and minimises battery consumption. Preserve the quick capture and visual thought-organising experience.

Prefer native controls and platform conventions. Support VoiceOver, Dynamic Type, Reduce Motion, clear contrast, and comfortable touch targets. Measure performance with Instruments on real devices; do not infer CPU usage from the debug display. Keep expensive work off the main thread, cancel unnecessary work, and pause decorative animation when inactive or when accessibility and power settings require it.

Protect saved thoughts and backup compatibility when changing persistence. Review the architecture overview in `README.md` before implementation. Keep changes focused and verify the affected behaviour.

The GitHub repository is [Hutchball/BrainDump](https://github.com/Hutchball/BrainDump). Use BrainDump for branding and export filenames. Preserve legacy backup type identifiers for compatibility.

## Official references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Required reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Privacy manifest preparation](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [Encryption export declarations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)

- [Apple design](https://developer.apple.com/design/)
- [Design resources](https://developer.apple.com/design/resources/)
- [Get started with design](https://developer.apple.com/design/get-started/)
- [What's new in design](https://developer.apple.com/design/whats-new/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Design tips](https://developer.apple.com/design/tips/)
- [The Swift Programming Language](https://docs.swift.org/swift-book/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple SDK API design](https://developer.apple.com/documentation/apple_sdk_guidelines/api-design)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [UIKit](https://developer.apple.com/documentation/uikit/)
- [AppKit, for future native Mac work](https://developer.apple.com/documentation/appkit)
- [Accessibility](https://developer.apple.com/documentation/accessibility)
- [Improving app performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance)
- [Instruments](https://developer.apple.com/documentation/xcode/instruments)
- [UserNotifications](https://developer.apple.com/documentation/usernotifications)
- [FileManager](https://developer.apple.com/documentation/foundation/filemanager)
- [Testing](https://developer.apple.com/documentation/testing)
- [XCTest](https://developer.apple.com/documentation/xctest)

## Rebuild integration references

- [App Intents](https://developer.apple.com/documentation/appintents)
- [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-4b4w9)
- [CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)
- [PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)
- [Core Transferable](https://developer.apple.com/documentation/coretransferable)
- [Image I/O](https://developer.apple.com/documentation/imageio)

Use the record store as the source of truth. Select thoughts by stable ID; do not reintroduce parallel mutable arrays or competing scroll snap drivers. Keep sync and portable backup separate. Check `CLOUDKIT_SETUP.md` before signed-device validation or distribution.

## Product vision: capture now, organise later

Training must follow the ordered practice flow and enable Finish Training only after all exercises are complete. Keep unrelated actions disabled during each step. Empty practice captures do not advance training. Mark all temporary training tiles visibly with DEMO, including new captures, and identify demo thoughts for VoiceOver. Temporary training exercises must never change the saved library. On first-run onboarding, the explicitly requested first nonempty user capture is real, autosaves normally, and survives training; replay captures remain temporary.

The sphere is the main home screen: a visual collection of the user's thoughts.

- **Quick capture:** + creates a real blank Unsorted tile (category ID 0) directly in the sphere, brings it to the front, and focuses text entry inside the tile. The sphere stays visible: no sheet, card, form, or separate capture screen. Save nonempty content automatically while typing pauses and before the app becomes inactive. Blank or whitespace-only captures with no attachments are transient: Done discards them with a shrink-to-nothing animation, creating no saved thought. Clearing an already autosaved new capture also removes it from the inbox; preserve hidden sync deletion markers where needed. Done or backgrounding ends inline editing and releases that same tile back into the sphere. Capture asks for no category; the user can immediately leave the app.
- **Browse a category:** tapping a categorised tile in the sphere opens that entire category as a vertically scrollable collection of tiles, starting at the tapped thought. Preserve stable selection and each category's remembered scroll position. Closing returns to the sphere.
- **Sort the Brain Dump:** tapping either the brain icon on the home screen or any Unsorted tile opens the same vertically scrollable Unsorted queue. When entered through a tile, start with that thought. Keep the horizontal category list pinned at the bottom so the user can sort thoughts one by one.
- **Assign a category:** the selected tile flies out of the sorting queue because it is no longer Unsorted; advance to the next Unsorted thought and keep the category list available. The thought remains saved and is available in the sphere and its assigned category. Reduce Motion uses an immediate transition. When the last Unsorted thought is assigned, automatically dismiss sorting to the sphere. If no Unsorted thoughts exist, tapping the brain button keeps the sphere visible and gives two brief negative haptic taps.

Keep quick capture separate from the full editor's category, appearance, and attachment controls. Do not turn initial capture into an organisation form or make sorting require reopening a picker for each thought.

Category swatches determine categorised tile colours unless an explicit category or individual appearance override is set. Keep colour inheritance consistent in the sphere, category view, full thought, and editor. Use brief creation and release animations with a small sphere turn; honour Reduce Motion and avoid looping capture effects. The developer test fixture adds 100 thoughts distributed over Unsorted and existing categories in one atomic save, preserving existing thoughts.

Use dark category borders by default (a darker shade of the category fill). Use prominent, contrasting tile borders (4 points normally, 6 points when selected), retaining explicit border overrides. Developer example thoughts should have meaningful category-specific content: actions for Things to do, film titles for Movies to watch, book titles for Books to read, websites for Websites to check, and uncategorised ideas for Unsorted.

Allow horizontal category swipes and category-header arrows from Unsorted as well as other categories. Moving to a categorised collection hides the sorting picker; returning to Unsorted restores it. Vertical scrolling remains for thoughts, and horizontal swipes within the bottom category picker scroll its choices.

Shuffle thought-to-position assignments in the home sphere independently of record order and category. Cache the assignments for stable browsing and editing; only update layout membership when thoughts are added or removed. Keep the evenly spaced sphere geometry and use the same slot mapping when bringing a tile forward. Do not shuffle vertical category lists.

Settings must use a single native page inside its presentation, with single-column navigation on iPhone and iPad. Show actual bundle version/build in About and use braindumpfeedback@cakesquared.co.uk for feedback and privacy contact. Published policy and website links must come from the owner; do not invent URLs.

Owner-provided privacy policy: https://cakesquared.co.uk/privacy-policy.html. Website: https://cakesquared.co.uk. Use these links in About & Privacy.

Completing a thought turns its tile green, then enlarges it toward the user and fades it out as though it passes through the screen. Archive it after the brief effect and advance selection. Use the same effect in the full-text tile; Reduce Motion completes immediately.

Category capture: + in a category keeps the collection open and creates a tile in that category. Background taps dismiss the category; scrolling must not dismiss it. Sphere tile taps must centre the exact tapped thought in its category.

## Purchase references

- [StoreKit Product and introductory-offer eligibility](https://developer.apple.com/documentation/storekit/product)
- [Verified current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)

Pro proposal: £2.99 monthly with a one-month introductory free trial, or £6.99 lifetime. Free supports 25 active tiles; both Pro products unlock unlimited active tiles. See PRO_SETUP.md for the prepared product IDs and StoreKit validation checklist. Use App Store localized prices and verified eligibility in the production screen.

## Category terminology

Use “category” and “categories” throughout visible copy, VoiceOver labels, training, and exports. Legacy tag-named persistence keys and backup fields remain compatible; do not change their encoded names solely for terminology cleanup.

Tile sheen uses a static gradient below content, controlled by Settings → Options → Appearance → Tile sheen & gradient. Increased Contrast uses solid fills. Do not add looping shimmer, blur, or per-frame highlight calculations. Profile enabled/disabled on real devices before claiming a measured energy impact.

- [Improving rendering efficiency](https://developer.apple.com/documentation/xcode/improving-your-app-s-rendering-efficiency)

Top-right lighting is an independent local Appearance toggle. Simulate an offscreen source with a fixed scene wash and static tile shading in the existing gradient pass. Increased Contrast disables both decorative lighting and sheen. Keep lighting independent of sphere rotation; avoid animated light tracking and additional per-tile shadows.

## iCloud upgrade validation references

- [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)
- [Apple CloudKit sync-engine sample](https://github.com/apple/sample-cloudkit-sync-engine)

Preserve the production bundle identifier, legacy defaults, category IDs, and tile assignments across upgrades. Validate in-place updates from the distributed build on signed devices; distinguish older iCloud Documents backups from CloudKit record sync. Never apply a new purchase limit by truncating an existing library.

- [CKSyncEngine immediate fetch](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/fetchchanges(_:))
- [CKSyncEngine delegate callback ordering](https://developer.apple.com/documentation/cloudkit/cksyncenginedelegate-1q7g8)

Never invoke manual CloudKit send/fetch operations in an inherited delegate callback task context. Use a detached task boundary before manual sync; `Task.yield()` and ordinary `Task` creation do not clear task-local callback context. Keep store and sync bookkeeping on the main actor.
- [Registering for remote notifications](https://developer.apple.com/documentation/uikit/uiapplication/registerforremotenotifications())

- [StoreKit localized product information](https://developer.apple.com/documentation/storekit/product)
- [Implementing introductory offers](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app)

- [Troubleshooting sandbox purchase availability](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)


## Future platform scope

Keep Apple Vision Pro excluded from distribution until explicitly revisited and tested. Track the future spatial sphere experience in README.md. Compatible iPhone/iPad app availability is controlled separately in App Store Connect; iOS-only build settings do not constitute an opt-out.

- [visionOS development](https://developer.apple.com/visionos/)
- [Manage Apple Vision Pro availability](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)

## Category settings interaction

Require Edit mode before renaming existing categories. Show explicit trash buttons for custom categories and use native List reordering within each default/custom section. Preserve stable IDs and saved display order.

- [SwiftUI list reordering](https://developer.apple.com/documentation/swiftui/dynamicviewcontent/onmove(perform:))
- [SwiftUI EditMode](https://developer.apple.com/documentation/swiftui/editmode)

## Expanded tile interaction

Each accepted dismissal uses the same single heavy impact as opening, respecting the Haptics setting. Ignore repeated dismissal gestures during the transition without additional impacts.

Long press uses a single heavy impact and a finite 180° horizontal flip with enlargement. Exchange preview/full content only at the edge-on midpoint; a second long press, a tap outside the enlarged tile, or the grey X at its bottom centre reverses to the original tile. Taps inside the tile must not dismiss it. Place the trash icon after the Delete label. Keep the enlarged tile square, with a 16-point gap at the constrained screen edges and a maximum side of 620 points. Keep full content centred, attachments in saved order, and overflow scrollable. Reveal Complete and Delete with a brief fade only after opening finishes; reserve their space during the flip. Keep the returning small face visible until dismissal to avoid a full-size flash. Expanded text starts at 24 points and scales with Dynamic Type. Reduce Motion skips the flip and action fade; backgrounding invalidates pending animation completions.

- [SwiftUI 3D rotation](https://developer.apple.com/documentation/swiftui/view/rotation3deffect(_:axis:anchor:anchorz:perspective:))
- [Impact feedback](https://developer.apple.com/documentation/uikit/uiimpactfeedbackgenerator)

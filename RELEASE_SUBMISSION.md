# BrainDump submission preparation

## Prepared in the app

- App privacy manifest declares app-only UserDefaults access (`CA92.1`), no tracking, and no developer-collected data. The Share extension has its own manifest and does not directly use required-reason APIs. App Group sharing uses files, not shared UserDefaults. Source review found file-size reads, not file-timestamp/disk-capacity reads, and no system-boot-time or active-keyboard queries.
- Both targets declare no non-exempt encryption. Apple platform encryption remains in use; SHA-256 is a hash, not encryption.
- Purchase options use App Store product prices. No hardcoded or planned prices appear when products are unavailable. Monthly and lifetime product names, restore, privacy and EULA links remain visible.
- Sphere edge blur is unchanged.

## App Review notes draft

BrainDump is a personal thought-capture and organisation app. No app account or login is required. First-time users complete an interactive demo using temporary tiles marked DEMO; these do not change their saved library. Follow the instructions to rotate the sphere, open and scroll a category, assign a category, complete a thought, capture a nonempty practice thought, switch categories, and open/close a full thought. Finish Training becomes enabled after the final exercise.

Tap + to capture text directly in a tile. Done saves nonempty captures; empty captures are discarded. The brain button opens the Unsorted sorting queue. Long press opens a full thought. Settings contains appearance, backup, privacy, and BrainDump Pro options.

Free supports 25 active thoughts. BrainDump Pro monthly subscription and lifetime non-consumable both unlock unlimited active thoughts. Existing saved thoughts remain accessible if a subscription ends. Purchases and restore use StoreKit. Optional sync uses the user's private iCloud CloudKit database; local capture works without iCloud.

Review contact: braindumpfeedback@cakesquared.co.uk.

Before copying these notes to App Store Connect, verify the submitted products and production sync on the actual signed build.

## Proposed public policy addition

The existing public privacy page responds successfully over HTTPS, but describes CakeSquared apps generally. Add this BrainDump-specific section to the owner-managed page before submission:

> BrainDump stores your thoughts, categories, preferences and selected attachments on your device. Optional iCloud synchronisation stores supported thoughts, categories and attachments in your private Apple CloudKit database so they can be available on your other devices. CakeSquared does not operate a server that receives this content. Apple handles iCloud and App Store services under its own privacy policies.
>
> Photos and shared content are added only when you choose them. Imported images are processed to remove metadata. Portable backups can include your thoughts and attachments; you choose where to save or share them. BrainDump does not include advertising, tracking or third-party analytics. App Store purchases are processed by Apple; we do not receive payment-card details.
>
> You can edit or delete thoughts within BrainDump and turn off reminders in Settings. Deleted thoughts remain recoverable in Recently Deleted for 30 days. Hidden deletion records may be retained to prevent deleted thoughts returning through sync. Backups you have exported are separate copies and must be removed from their saved locations separately. If you contact us for support, we receive the information you choose to send and can delete support correspondence on request. Contact braindumpfeedback@cakesquared.co.uk.

This draft has not been published. Keep the owner-provided policy URL: https://cakesquared.co.uk/privacy-policy.html.

## Platform scope

The current release is for iPhone and iPad. Apple Vision Pro is deferred until tested. The Xcode targets already list only `iphoneos iphonesimulator` and device families `1,2`; compatible iOS availability on Vision Pro is a separate App Store Connect setting. Ensure “Make this app available on Apple Vision Pro” is off before submission. Preserve Vision Pro as a future development target in README.md. App Store Connect already contains a separate visionOS 1.0 draft marked Prepare for Submission; leave that draft unsubmitted until testing is complete.

## Final external checks

1. Create/verify the products listed in PRO_SETUP.md, subscription group/free trial, localisations, review screenshots, agreements and tax/banking status. Submit the products with the app when required. Validate purchase, trial eligibility, restore, expiry and revocation on a signed sandbox device.
2. Complete CLOUDKIT_SETUP.md: production schema, distribution App Group capabilities, two-device sync and in-place upgrade without uninstalling. Exercise Photos/Safari sharing and Siri.
3. Validate a signed archive in Xcode Organizer. Check the generated privacy report. Choose a build number greater than the last uploaded build; the last App Store Connect build was not available locally.
4. Complete App Store privacy answers based on actual developer access. The audited app sends no content/analytics to a CakeSquared server, so a no-data-collected answer is proposed for the app, subject to confirming the final release has no added SDKs/data flows. Private user iCloud storage is distinct from developer collection. Support correspondence and the website are covered by the public policy.
5. Add real screenshots, accurate support/privacy URLs, the standard Apple EULA link in the description if using that EULA, and the review notes above. Verify age/content declarations. Check iPad, largest Dynamic Type sizes and VoiceOver on the signed build.

Production CloudKit schema deployment was completed and verified in Console on 6 October 2026; see CLOUDKIT_SETUP.md. No app upload or website publication was performed during the earlier submission preparation. Monthly product creation and free-trial setup were performed on 6 October 2026; see PRO_SETUP.md for verified progress and remaining items. App Store Connect currently lists the app as Brain-Dump, and the local Git remote points to Hutchball/BrainDump.

## References

- [Required reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

- [Manage compatible app availability on Apple Vision Pro](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-of-iphone-and-ipad-apps-on-apple-vision-pro/)

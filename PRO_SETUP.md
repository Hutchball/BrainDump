# BrainDump Pro setup

Product IDs (new products; no legacy entitlement migration is assumed):

| Product ID | App Store type | UK price | Offer |
| --- | --- | --- | --- |
| `BonkersBonk.BrainDump.pro.monthly.v2` | Auto-renewable subscription, one month | £2.99/month | One-month free introductory trial |
| `BonkersBonk.BrainDump.pro.lifetime.v2` | Non-consumable | £6.99 once | None |

Both unlock unlimited active tiles. Free users have 25 active tiles. Completing or deleting a tile makes room; existing thoughts, sync, backup recovery, and conflict recovery are retained regardless of entitlement. Restore and archive recovery do not discard saved records. Share jobs over the limit remain queued. Developer fixtures bypass the limit.

## App Store Connect

Both IDs have been created under the existing BrainDump app in App Store Connect. Monthly is in the BrainDump Pro group with a one-month free trial. UK prices and English (U.K.) localizations are saved. Add actual review screenshots and submit the products with the app for public release. Repository product definitions alone do not configure App Store Connect. Confirm any legacy purchase entitlement policy before shipping; old IDs are currently not recognised.

## Local purchase testing

The shared BrainDump scheme now selects `BrainDumpPro.storekit` under Run → Options automatically. Run from Xcode to see both purchase buttons and exercise local purchases without payment. It contains both products, UK prices and the free trial. Local product data is separate from App Store Connect.

Debug builds also show **Unlock Pro for testing** in the Pro panel. This persists across launches; switch it off to restore the free limit without deleting thoughts. The control and entitlement override are excluded from Release builds. Advanced → Debug is also compiled only in Debug builds. The shared scheme archives with Release, so both TestFlight and App Store archives omit these developer controls; a saved `debugProUnlock` preference is ignored in Release. `ProStoreTests` verifies unlocking beyond 25 tiles, persistence, entitlement refresh, and returning to Free while retaining the library.

Exercise monthly trial, renewal, cancellation, expiration, lifetime purchase, pending approval, restoration and refund/revocation. Verify trial text only appears for eligible subscribers, the 26th active free tile opens Pro, editing remains possible, and expiring Pro never deletes existing tiles. Repeat on a signed device using App Store sandbox before distribution.

References: [StoreKit testing setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode), [introductory offers](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app), [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements).

The purchase page always shows Monthly and Lifetime in that order, including while StoreKit loads or is unavailable. Prices come from StoreKit; unavailable products cannot be purchased. The one-month trial is shown only after eligibility and the configured offer are verified.

## TestFlight sandbox purchases

TestFlight uses Apple’s sandbox automatically; purchases do not charge testers. The Xcode `.storekit` file and Debug unlock switch do not configure TestFlight products. Create both exact product IDs above in App Store Connect with pricing, localizations and the monthly trial; complete the Paid Apps Agreement and required business information.

Both plans remain visible when Pro is active. Purchase buttons remain available for verified sandbox entitlements so testers can exercise Apple’s purchase sheet; production entitlements disable purchases to avoid redundant purchases. Apple still determines ownership and trial eligibility. To repeat a first purchase or trial, clear the Sandbox Apple Account’s purchase history using Apple’s sandbox controls and refresh the page. Turning off the Debug override cannot revoke a verified Apple entitlement.

- [Testing purchases in TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testing-subscriptions-and-in-app-purchases-in-testflight)
- [Testing with sandbox](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)
- [Troubleshooting sandbox product availability](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)

## Version 1.0 preparation

App and Share extension now use marketing version 1.0 and build 1. The unsigned Release iPhone build passed, and the generated app Info.plist confirms version 1.0 (1). App Store Connect already has iOS version 1.0 in Prepare for Submission. Upload has not been performed by this change.

## App Store Connect progress — 6 October 2026

Verified in the signed-in App Store Connect UI for Brain-Dump (app Apple ID `6759315059`):

- Created BrainDump Pro subscription group `22447611`.
- Created monthly subscription Apple ID `6819778274`, exact product ID `BonkersBonk.BrainDump.pro.monthly.v2`, duration one month.
- Saved UK price £2.99 with Apple-calculated prices for 175 storefronts.
- Verified current introductory offer: Free for the first month, 175 countries or regions, 6 October 2026 through No End Date.
- Saved worldwide availability and English (U.K.) product name/description.
- Saved reviewer notes explaining Settings → Meet BrainDump Pro and restore.
- Verified English (U.K.) group display name BrainDump Pro after unlocking the Mac.

Lifetime non-consumable is now created (Apple ID `6819777388`, product ID `BonkersBonk.BrainDump.pro.lifetime.v2`). Verified after reloading: English (U.K.) name and description, worldwide availability, reviewer notes and UK £6.99 current pricing across 175 storefronts. Group localization is verified.

Verified the Paid Apps Agreement, bank account and tax forms are Active in App Store Connect. Both products remain Prepare for Submission. Remaining: add actual in-app purchase review screenshots for App Review, upload the version 1.0 build, and validate signed TestFlight purchases. No product was submitted to App Review and no new app build was uploaded during this setup.

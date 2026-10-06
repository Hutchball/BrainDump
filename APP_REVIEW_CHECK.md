# Quick App Store readiness check — 6 October 2026

The current home/empty state and temporary demo sphere were inspected in the iPhone simulator. The overall presentation is coherent, with clear controls and DEMO identification. The owner prefers the existing sphere blur; it is unchanged. This was not a complete iPad, Dynamic Type, VoiceOver or signed-device review.

## Verified

- Release generic iPhone build passes with signing disabled.
- App and Share extension declare `ITSAppUsesNonExemptEncryption = NO`; the built property lists were checked. Source inspection found Apple CloudKit/system services and SHA-256 hashing for stable recovery identifiers, without custom encryption or third-party libraries. This means no non-exempt encryption, rather than no encryption anywhere.
- Purchase UI contains restore, localized loaded-product prices, renewal text, trial eligibility checks, privacy and standard Apple EULA links. Debug purchase bypass is excluded from Release.
- Existing simulator regression checks cover the complete strict training flow and repeated empty capture dismissal.
- Follow-up readiness work added valid privacy manifests to both targets, verified in the Release app and embedded extension. App-only UserDefaults access uses approved reason CA92.1. There is no tracking or developer content collection in the audited implementation.
- Removed planned/hardcoded price fallback and clarified product labels; prices remain sourced from StoreKit.
- The public privacy page was successfully retrieved directly over HTTPS. A BrainDump-specific addition and App Review notes are prepared in RELEASE_SUBMISSION.md.

## Resolve before submission

1. **Privacy declarations:** The manifest issue is resolved locally. Check the generated archive privacy report and complete accurate App Store Connect privacy answers.
2. **Purchase readiness:** Confirm both v2 products are configured/submitted in App Store Connect and exercise purchase/restore on a signed sandbox device. Repository setup notes are not evidence that the live products exist.
3. **CloudKit and upgrades:** Validate production schema, signed App Group provisioning, two-device sync, sharing and an in-place update from the distributed build. See CLOUDKIT_SETUP.md.
4. **Privacy policy detail:** The policy URL is reachable. Publish the prepared BrainDump-specific policy addition on the owner-managed website.
5. **Submission metadata:** Check privacy answers, screenshots, review notes explaining training and the free limit, and a new build number against the last uploaded build. App Store Connect was not inspected.

The design appears suitable for submission after these readiness items are resolved; this check cannot guarantee Apple approval.

## Official references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [UserDefaults privacy manifest requirement](https://developer.apple.com/documentation/foundation/userdefaults)
- [Required reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Encryption export declarations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)

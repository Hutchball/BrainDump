# BrainDump development guidance

Build a polished, responsive iOS app that follows Apple's Human Interface Guidelines, uses efficient code, and minimises battery consumption. Preserve the quick capture and visual thought-organising experience.

Prefer native controls and platform conventions. Support VoiceOver, Dynamic Type, Reduce Motion, clear contrast, and comfortable touch targets. Measure performance with Instruments on real devices; do not infer CPU usage from the debug display. Keep expensive work off the main thread, cancel unnecessary work, and pause decorative animation when inactive or when accessibility and power settings require it.

Protect saved thoughts and backup compatibility when changing persistence. Review the architecture overview in `README.md` before implementation. Keep changes focused and verify the affected behaviour.

## Official references

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

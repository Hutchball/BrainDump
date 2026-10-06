# BrainDump Status

Last updated: 2026-01-14

## What we changed recently
- Refactored `ContentView` into helper view builders to fix Swift type-check timeouts and improve compile stability.
- Fixed selection shadowing bugs and other compile errors.
- Removed parallax CoreMotion; added subtle star shimmer using `TimelineView`.
- Drag behavior now tracks finger closely and supports “throw” momentum (looser tuning applied).
- Filtered tag view enhancements:
  - Tag header with infinite horizontal paging and pulsing chevrons.
  - Header made larger/lower; chevrons moved closer.
  - Horizontal swipe anywhere on list cycles tags.
  - Selected tile scrolls to center with bounce; list snaps to centered tile.
  - Cylinder effect on list tiles (scale/opacity/spacing taper) with stronger visibility.
  - Centered tile selection is enforced by scroll snapping; selection updates as the list scrolls.
  - Tap outside tiles in filtered view returns to normal view (unless keyboard is up).
  - When keyboard is up, first tap dismisses keyboard only.
- Buttons visibility:
  - Settings and plus buttons hidden while in tag filter view.
  - Tag picker is only shown when the change-tag button is toggled; tap outside hides it.
- Editing behavior:
  - Tiles only show a `TextField` when edit button is pressed.
  - Filtered list taps don’t open keyboard; only edit button does.
  - Keyboard dismisses when `isEditingTile` becomes false.

## Known issues / open items
- In filtered list, stacking/z-index may still allow a tile below to appear in front. Last attempt: set high z-index for selected tile in `computeLayout()` and in `CylinderTileRow`.
- Scroll snapping and animations are tuned but may still feel a bit jarring; can adjust spring values further.
- Warning remains for deprecated `onChange(of:perform:)` in a couple places (not yet cleaned up).

## Key files
- `BrainDump/ContentView.swift`

## Next steps (if we resume)
- Revisit filtered list z-index to guarantee centered tile always in front (potentially compute z-index from scroll position + selection).
- Optionally add app icon if user supplies 1024x1024 PNG.
- Clean up deprecated `onChange` warnings.

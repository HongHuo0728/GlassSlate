# Native SwiftUI layout checks

These images are generated on macOS with NSHostingView and the actual shared SwiftUI views. They are layout evidence, not iPhone or iPad screenshots, Xcode Canvas acceptance records, or touch tests. Liquid Glass compositing cannot be fully assessed with this offscreen method.

## Version 1.0.1

Run `python3 Scripts/render_layouts.py` from the project root. It uses the installed macOS SDK and does not download or launch an iOS simulator. Temporary compilation output stays under `build/LayoutPreviews/`.

The `1.0.1/` directory contains iPhone portrait and landscape layouts, a 744 pt iPad portrait layout, dark iPad landscape, a 600 pt narrow window, and a large-type environment. The sidebar uses the actual DrawerView with sample projects and records. Native macOS typography, List behavior, and controls can differ from iOS.

The three Clap images capture the actual ClapperView before a programmatic trigger, approximately 45 ms after it, and after reopening. The triggered image shows a closed arm. The reopened image matches the initial rest image. This checks the shared keyframe animation, not real tap or long-press delivery on iOS.

## Archived 1.0.0 previews

The top-level Classic-* files are retained from 1.0.0. The Settings image uses a volume-control layout proxy; new-project images approximate the popover background without the iOS arrow. Classic-History-Actions-* documents the old custom classic menu that was removed in 1.0.1 and is not part of the current UI.

Actual glass appearance, native menu presentation, touch gestures, audio, and platform-specific text sizes need signed-device checks. See [QA](../docs/QA.md).

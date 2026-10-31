#!/usr/bin/env python3
"""Render shared SwiftUI classic layouts on macOS without any iOS simulator."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
scratch = root / 'build/LayoutPreviews'
scratch.mkdir(parents=True, exist_ok=True)
sources = sorted((root / 'GlassSlate/Models').glob('*.swift'))
sources += sorted((root / 'GlassSlate/Persistence').glob('*.swift'))
sources += [root / 'GlassSlate/Services/SlateHaptics.swift']
sources += [root / 'GlassSlate/Views' / name for name in [
    'GlassStyle.swift', 'ClapperView.swift', 'SlateStageView.swift', 'HistoryCard.swift',
    'NameEditorPopover.swift', 'DrawerView.swift']]
sources += [root / 'Previews/RenderLayouts.swift']
subprocess.run(['xcrun', 'swiftc', '-swift-version', '6', '-parse-as-library',
                '-module-cache-path', str(scratch / 'ModuleCache'), '-o', str(scratch / 'render'),
                *map(str, sources)], check=True, cwd=root)
subprocess.run([str(scratch / 'render'), str(root / 'Previews/1.0.1')], check=True, cwd=root)

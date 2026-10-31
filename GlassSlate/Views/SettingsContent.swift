import SwiftUI

struct SettingsContent<Volume: View>: View {
    @Bindable var settings: SettingsStore
    let customSound: Bool
    let version: String
    var liveStatus: String = ""
    var showHeader = true
    let done: () -> Void
    let openLanguage: () -> Void
    let importSound: () -> Void
    let previewSound: () -> Void
    let restoreSound: () -> Void
    @ViewBuilder let volume: () -> Volume
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body: some View {
        VStack(spacing: 0) {
            if showHeader { HStack(alignment: .center) {
                Text("Settings").font(.largeTitle.bold())
                Spacer(minLength: 16)
                Button("Done", action: done).buttonStyle(SlateActionStyle(compact: true))
            }.padding(20).staggeredEntrance(0) }
            ScrollView {
                VStack(spacing: 16) {
                    SettingsGroup("Appearance", icon: "circle.lefthalf.filled") {
                        HStack(spacing: 8) {
                            ForEach(Appearance.allCases) { appearance in
                                Button { settings.appearance = appearance; SlateHaptics.selection() } label: {
                                    VStack(spacing: 7) {
                                        Image(systemName: appearance == .system ? "circle.lefthalf.filled" : appearance == .light ? "sun.max" : "moon")
                                        Text(LocalizedStringKey(appearance.rawValue)).lineLimit(1).minimumScaleFactor(0.7)
                                    }.frame(maxWidth: .infinity).padding(.vertical, 3)
                                        .overlay(alignment: .topTrailing) {
                                            Image(systemName: "checkmark.circle.fill").font(.caption2)
                                                .opacity(settings.appearance == appearance ? 1 : 0)
                                        }
                                }.buttonStyle(SlateActionStyle(prominent: settings.appearance == appearance, compact: true, roundedRectangle: true))
                                    .accessibilityAddTraits(settings.appearance == appearance ? .isSelected : [])
                            }
                        }.animation(reduced ? nil : .snappy(duration: 0.2), value: settings.appearance)
                        Divider().padding(.vertical, 2)
                        Toggle("Liquid Glass", isOn: $settings.liquidGlassEnabled).toggleStyle(SlateToggleStyle()).tint(.blue)
                        explanation("Changes apply after restarting GlassSlate. Off uses a separately designed frosted and matte interface inspired by iOS 18.")
                        if settings.restartRequired {
                            Label("Restart required", systemImage: "arrow.clockwise").font(.footnote.weight(.medium)).foregroundStyle(.orange)
                        }
                    }.staggeredEntrance(1)
                    SettingsGroup("Shooting", icon: "film") {
                        Toggle("Auto-increment Take", isOn: $settings.autoIncrement).toggleStyle(SlateToggleStyle()).tint(.blue)
                        explanation("After saving a snapshot, numeric Takes advance by one. 009 becomes 010; 02B stays 02B.")
                        Divider().padding(.vertical, 2)
                        Toggle("Haptics", isOn: $settings.haptics).toggleStyle(SlateToggleStyle()).tint(.blue)
                        explanation("Tactile feedback for fields, controls, drawers, saves and deletion, with a firm impact at clap contact.")
                    }.staggeredEntrance(2)
                    SettingsGroup("Live Activities", icon: "platter.filled.bottom.iphone") {
                        Toggle("Live Activities", isOn: $settings.liveActivitiesEnabled).toggleStyle(SlateToggleStyle()).tint(.blue)
                        explanation("Clap from the Lock Screen or an expanded Dynamic Island. Availability and duration are controlled by iOS.")
                        if !liveStatus.isEmpty { Text(verbatim: liveStatus).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                    }.staggeredEntrance(3)
                    SettingsGroup("Language", icon: "globe") {
                        explanation("Follows your device language. To choose English or Simplified Chinese for GlassSlate, open the native App settings.")
                        Button(action: openLanguage) { Label("Open App Settings", systemImage: "arrow.up.right").frame(maxWidth: .infinity) }
                            .buttonStyle(SlateActionStyle())
                    }.staggeredEntrance(3)
                    SettingsGroup("Sound", icon: "speaker.wave.2") {
                        HStack {
                            Image(systemName: "waveform").foregroundStyle(.blue).frame(width: 24)
                            Text(customSound ? "Custom sound" : "Classic clap").font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        if typeSize.isAccessibilitySize {
                            VStack(spacing: 10) { soundButtons }
                        } else { HStack(spacing: 10) { soundButtons } }
                        Button(action: restoreSound) { Label("Restore classic sound", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity) }
                            .buttonStyle(SlateActionStyle())
                        explanation("WAV and M4A recommended. Up to 30 seconds and 50 MB. Imported audio is copied onto this device.")
                        Divider().padding(.vertical, 2)
                        Text("System output volume").font(.subheadline.weight(.semibold))
                        volume().frame(height: 38).padding(.horizontal, 4)
                        explanation("Use this system control to adjust volume. Check Bluetooth and wired output. Clap playback can sound even in Silent Mode. GlassSlate never changes system volume automatically.")
                    }.staggeredEntrance(4)
                    Text(verbatim: "GlassSlate · \(version)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 10).staggeredEntrance(5)
                }.frame(maxWidth: 640).padding(.horizontal, 20).padding(.bottom, 24).frame(maxWidth: .infinity)
            }.scrollBounceBehavior(.basedOnSize)
        }
        .background { SlateBackground() }
        .onChange(of: settings.liveActivitiesEnabled) { _, _ in SlateHaptics.selection() }
        .onChange(of: settings.autoIncrement) { _, _ in SlateHaptics.selection() }
        .onChange(of: settings.haptics) { _, enabled in if enabled { SlateHaptics.prepare(); SlateHaptics.selection() } }
    }
    @ViewBuilder private var soundButtons: some View {
        Button(action: importSound) { Label("Import sound", systemImage: "folder").lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity) }
            .buttonStyle(SlateActionStyle())
        Button(action: previewSound) { Label("Preview", systemImage: "play.fill").lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity) }
            .buttonStyle(SlateActionStyle())
    }
    private func explanation(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.footnote).foregroundStyle(.secondary).lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}
private struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder let content: () -> Content
    init(_ title: LocalizedStringKey, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.icon = icon; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            content()
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).glassPanel(radius: 32)
    }
}

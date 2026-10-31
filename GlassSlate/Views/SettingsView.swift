import MediaPlayer
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var audio: ClapAudioService
    let liveActivity: LiveActivityService
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var importing = false
    @State private var message: String?
    @State private var isRestartNotice = false
    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "—") (\(info["CFBundleVersion"] as? String ?? "—"))"
    }
    var body: some View {
        Group {
            if style == .liquidGlass {
                NavigationStack {
                    content(showHeader: false)
                        .navigationTitle("Settings").navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                // The system toolbar supplies the glass background once.
                                Button("Done") { dismiss() }.buttonBorderShape(.capsule)
                            }
                        }
                }
            } else { content(showHeader: true) }
        }
            .presentationBackground(.clear).presentationDragIndicator(.visible)
            .onChange(of: settings.liquidGlassEnabled) { _, _ in
                SlateHaptics.selection()
                if settings.restartRequired {
                    isRestartNotice = true
                    message = String(localized: "Close GlassSlate from the App Switcher, then reopen it to apply the new interface. Your slates and settings are kept.")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
                switch result {
                case .success(let url): perform { try audio.importSound(from: url) }
                case .failure(let failure):
                    if (failure as NSError).code != NSUserCancelledError {
                        isRestartNotice = false
                        message = String(localized: "Could not import audio. Choose a playable local file.")
                        SlateHaptics.error()
                    }
                }
            }
            .alert(isRestartNotice ? "Restart required" : "Unable to complete action",
                   isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) { message = nil }
            } message: { Text(verbatim: message ?? "") }
            .onChange(of: audio.notice, initial: true) { _, notice in
                if let notice { isRestartNotice = false; message = notice; audio.clearNotice() }
            }
    }
    private func content(showHeader: Bool) -> some View {
        SettingsContent(settings: settings, customSound: audio.customName != nil, version: version,
                        liveStatus: liveActivity.status, showHeader: showHeader,
                        done: { dismiss() }, openLanguage: openLanguage,
                        importSound: { importing = true }, previewSound: { perform { try audio.play() } },
                        restoreSound: { perform { try audio.restoreDefault() } }) { SystemVolumeView() }
    }
    private func openLanguage() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url) { accepted in
            if !accepted {
                isRestartNotice = false
                message = String(localized: "Could not open Settings. Open GlassSlate in the Settings app.")
            }
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); SlateHaptics.success() }
        catch {
            isRestartNotice = false
            message = (error as? AudioError)?.localizedDescription ?? String(localized: "Could not import or play audio. Check the file and audio output.")
            SlateHaptics.error()
        }
    }
}
private struct SystemVolumeView: UIViewRepresentable {
    @Environment(\.slateVisualStyle) private var style
    @Environment(\.colorScheme) private var scheme
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> MPVolumeView { MPVolumeView(frame: .zero) }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        guard context.coordinator.style != style || context.coordinator.scheme != scheme else { return }
        context.coordinator.style = style; context.coordinator.scheme = scheme
        if style == .classic {
            uiView.setVolumeThumbImage(context.coordinator.thumb, for: .normal)
            uiView.setMinimumVolumeSliderImage(context.coordinator.minimumTrack, for: .normal)
            uiView.setMaximumVolumeSliderImage(scheme == .dark ? context.coordinator.darkTrack : context.coordinator.lightTrack, for: .normal)
        } else {
            uiView.setVolumeThumbImage(nil, for: .normal)
            uiView.setMinimumVolumeSliderImage(nil, for: .normal)
            uiView.setMaximumVolumeSliderImage(nil, for: .normal)
        }
    }
    @MainActor final class Coordinator {
        var style: SlateVisualStyle?
        var scheme: ColorScheme?
        lazy var thumb = UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30)).image { renderer in
            renderer.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            UIColor.white.setFill(); UIBezierPath(ovalIn: CGRect(x: 3, y: 3, width: 24, height: 24)).fill()
        }
        lazy var minimumTrack = Self.track(.systemBlue)
        lazy var darkTrack = Self.track(UIColor(white: 0.3, alpha: 1))
        lazy var lightTrack = Self.track(UIColor(white: 0.83, alpha: 1))
        private static func track(_ color: UIColor) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: 6, height: 4)).image { _ in
                color.setFill(); UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 6, height: 4), cornerRadius: 2).fill()
            }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2))
        }
    }
}

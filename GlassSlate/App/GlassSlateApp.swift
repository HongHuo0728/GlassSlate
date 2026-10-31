import SwiftUI

@main struct GlassSlateApp: App {
    var body: some Scene {
        WindowGroup { BootstrapView() }
    }
}

private struct BootstrapView: View {
    @State private var runtime = SlateRuntime.shared
    private var settings: SettingsStore { runtime.settings }
    @State private var failure: String?

    var body: some View {
        Group {
            if let repository = runtime.repository, let audio = runtime.audio {
                MainSlateView(repository: repository, audio: audio, settings: settings, liveActivity: runtime.liveActivity)
            } else {
                ZStack {
                    SlateBackground()
                    VStack(spacing: 20) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("GlassSlate").font(.title.bold())
                        if let failure {
                            Text("Your saved data could not be opened. It has not been erased.")
                            Text(failure).font(.caption).textSelection(.enabled)
                            Button("Retry") { Task { await load() } }.buttonStyle(SlateActionStyle(prominent: true))
                        } else { ProgressView() }
                    }
                    .padding(28).glassPanel().padding()
                }
            }
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .environment(\.slateVisualStyle, settings.activeVisualStyle)
        .task { if runtime.repository == nil { await load() } }
    }

    private func load() async {
        do {
            try await runtime.prepare()
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}

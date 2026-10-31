import AppIntents
import Foundation

struct ClapSlateIntent: LiveActivityIntent, AudioPlaybackIntent {
    static var title: LocalizedStringResource { "Clap slate" }
    static var description: IntentDescription { "Mark a take, save its slate and play the selected clap sound." }
    static var supportedModes: IntentModes { .background }
    static var isDiscoverable: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }
    @MainActor func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        // These protocols route execution to the app process. Never report success in an extension fallback.
        try requireAppProcess()
        #else
        do { try await SlateRuntime.shared.remoteClap() }
        catch {
            await SlateRuntime.shared.liveActivity.showFailure(error.localizedDescription)
            throw error
        }
        #endif
        return .result()
    }
}

#if WIDGET_EXTENSION
private func requireAppProcess() throws { throw SlateIntentError.openApp }
#endif

enum SlateIntentError: LocalizedError {
    case openApp, disabled
    var errorDescription: String? {
        switch self {
        case .openApp: String(localized: "Open GlassSlate once before using the clap button.")
        case .disabled: String(localized: "Live Activities are turned off in GlassSlate.")
        }
    }
}

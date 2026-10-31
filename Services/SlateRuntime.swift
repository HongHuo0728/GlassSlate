import Foundation
import Observation

/// Live Activity intents and the foreground UI share these exact objects in the app process.
@MainActor @Observable final class SlateRuntime {
    static let shared = SlateRuntime()
    let settings = SettingsStore()
    let liveActivity = LiveActivityService()
    private(set) var repository: SlateRepository?
    private(set) var audio: ClapAudioService?
    private var preparation: Task<Void, Error>?
    func prepare() async throws {
        if repository != nil && audio != nil { return }
        if let preparation { try await preparation.value; return }
        let task = Task { @MainActor [self] in
            let store = try await SlateRepository(container: SlateRepository.makeContainer())
            let sound = try ClapAudioService()
            repository = store; audio = sound
        }
        preparation = task
        do { try await task.value; preparation = nil }
        catch { preparation = nil; throw error }
    }
    func remoteClap() async throws {
        try await prepare()
        guard settings.liveActivitiesEnabled else { throw SlateIntentError.disabled }
        guard let repository, let audio else { throw SlateIntentError.openApp }
        try audio.activate(force: true)
        let (_, write) = try repository.startClap(autoIncrement: settings.autoIncrement, soundName: audio.soundIdentifier)
        var playbackFailure: Error?
        do { try audio.playImmediate(); SlateHaptics.clap() } catch { playbackFailure = error }
        _ = try await write.value
        await liveActivity.sync(values: repository.draft, enabled: settings.liveActivitiesEnabled, allowStart: false)
        if let playbackFailure { throw playbackFailure }
    }
}

import AVFoundation
import Foundation
import Observation

@MainActor @Observable final class ClapAudioService {
    private(set) var customName: String?
    private(set) var notice: String?
    private var player: AVAudioPlayer?
    private var voices: [AVAudioPlayer] = []
    private var nextVoice = 0
    var isPlaying: Bool { voices.contains { $0.isPlaying } }
    private var sessionActive = false
    private var observers: [NSObjectProtocol] = []
    private let defaults: UserDefaults
    private let folder: URL
    private let defaultURL: URL
    var soundIdentifier: String { customName ?? "default-clap.wav" }

    init(defaults: UserDefaults = .standard) throws {
        self.defaults = defaults
        guard let resource = Bundle.main.url(forResource: "default-clap", withExtension: "wav") else {
            throw AudioError.missingDefault
        }
        defaultURL = resource
        folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true).appendingPathComponent("Sounds", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        customName = defaults.string(forKey: "customSound")
        try prepareWithFallback()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let kind = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self else { return }
                if kind == AVAudioSession.InterruptionType.began.rawValue {
                    self.sessionActive = false
                    self.voices.forEach { $0.stop() }
                } else {
                    do { try self.prepareWithFallback(); try self.activate() }
                    catch { self.notice = String(localized: "Audio is unavailable. Please try again.") }
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.voices.forEach { $0.stop() }
                do { try self?.prepareWithFallback() }
                catch { self?.notice = String(localized: "Audio is unavailable. Please try again.") }
            }
        })
    }

    private func decodedPlayer(url: URL) throws -> AVAudioPlayer {
        let candidate = try AVAudioPlayer(contentsOf: url)
        guard candidate.duration > 0, candidate.duration <= 30 else { throw AudioError.invalidFile }
        candidate.volume = 1
        candidate.prepareToPlay()
        return candidate
    }

    private func install(url: URL, first: AVAudioPlayer? = nil) throws {
        var loaded: [AVAudioPlayer] = []
        if let first { loaded.append(first) }
        while loaded.count < 4 { loaded.append(try decodedPlayer(url: url)) }
        voices.forEach { $0.stop() }
        voices = loaded; player = loaded.first; nextVoice = 0
    }

    private func prepareWithFallback() throws {
        if let name = customName {
            do {
                guard name == URL(fileURLWithPath: name).lastPathComponent else { throw AudioError.invalidFile }
                try install(url: folder.appendingPathComponent(name))
                return
            } catch {
                customName = nil
                defaults.removeObject(forKey: "customSound")
                notice = String(localized: "Custom sound is missing or damaged. Using the classic sound.")
            }
        }
        try install(url: defaultURL)
    }

    func activate(force: Bool = false) throws {
        guard force || !sessionActive else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        sessionActive = true
    }

    /// Zero intentional scheduling delay. A predecoded voice is available while the last clap rings out.
    func playImmediate() throws {
        guard sessionActive, !voices.isEmpty else { throw AudioError.playback }
        let voice = voices[nextVoice % voices.count]
        nextVoice = (nextVoice + 1) % voices.count
        voice.pause(); voice.currentTime = 0
        guard voice.play() else { throw AudioError.playback }
    }

    func warmUp() {
        do { try activate(); player?.prepareToPlay() }
        catch { notice = String(localized: "Audio is unavailable. Please try again.") }
    }

    func play(activateSession: Bool = true) throws {
        if activateSession { try activate() }
        if player == nil { try prepareWithFallback() }
        player?.currentTime = 0
        guard player?.play() == true else { throw AudioError.playback }
    }

    func suspend() {
        voices.forEach { $0.stop() }
        sessionActive = false
        do { try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        catch { notice = String(localized: "Audio session could not be released.") }
    }

    func importSound(from source: URL) throws {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
        guard let bytes = attributes[.size] as? NSNumber, bytes.intValue > 0,
              bytes.intValue <= 50 * 1024 * 1024 else { throw AudioError.invalidFile }
        let safeExtension = source.pathExtension.lowercased().filter { $0.isASCII && $0.isLetter || $0.isNumber }
        let name = UUID().uuidString + "." + (safeExtension.isEmpty ? "audio" : safeExtension)
        let destination = folder.appendingPathComponent(name)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            let candidate = try decodedPlayer(url: destination)
            let oldName = customName
            try install(url: destination, first: candidate)
            customName = name
            defaults.set(name, forKey: "customSound")
            if let oldName { removeOwnedFile(oldName) }
        } catch {
            removeOwnedFile(name)
            throw error
        }
    }

    func restoreDefault() throws {
        let candidate = try decodedPlayer(url: defaultURL)
        let oldName = customName
        try install(url: defaultURL, first: candidate)
        customName = nil
        defaults.removeObject(forKey: "customSound")
        if let oldName { removeOwnedFile(oldName) }
    }

    private func removeOwnedFile(_ name: String) {
        guard name == URL(fileURLWithPath: name).lastPathComponent else { return }
        let url = folder.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { try FileManager.default.removeItem(at: url) }
        catch { notice = String(localized: "An unused sound file could not be removed.") }
    }

    func clearNotice() { notice = nil }
}

enum AudioError: LocalizedError {
    case missingDefault, invalidFile, playback
    var errorDescription: String? {
        switch self {
        case .missingDefault: String(localized: "The bundled clap sound could not be found.")
        case .invalidFile: String(localized: "Choose a playable audio file up to 30 seconds and 50 MB.")
        case .playback: String(localized: "The sound could not play. Check your audio output.")
        }
    }
}

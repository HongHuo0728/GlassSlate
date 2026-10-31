/// Playback may lose its audio session or decoded voices after Siri, calls, or media-service resets.
/// The normal path does no recovery work. A failed attempt rebuilds once, then reports any real error.
enum PlaybackRecovery {
    static func perform(activate: () throws -> Void, start: () throws -> Void,
                        recover: () throws -> Void) throws {
        do { try activate(); try start() }
        catch { try recover(); try activate(); try start() }
    }
}

import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import SlateCore
#else
@testable import GlassSlate
#endif

struct PlaybackRecoveryTests {
    @Test func nextClapReactivatesAnInterruptedSessionWithoutRebuildingHealthyVoices() throws {
        var active = true
        var activations = 0
        var plays = 0
        var rebuilds = 0
        func clap() throws {
            try PlaybackRecovery.perform(activate: {
                if !active { active = true; activations += 1 }
            }, start: {
                #expect(active); plays += 1
            }, recover: { rebuilds += 1 })
        }
        try clap()
        active = false // Siri has interrupted and released the session.
        try clap()
        try clap()
        #expect(plays == 3)
        #expect(activations == 1)
        #expect(rebuilds == 0)
    }

    @Test func invalidatedVoiceRebuildsOnceAndRetriesTheSameClap() throws {
        var stale = true
        var starts = 0
        var rebuilds = 0
        try PlaybackRecovery.perform(activate: {}, start: {
            starts += 1
            if stale { throw CocoaError(.coderReadCorrupt) }
        }, recover: { rebuilds += 1; stale = false })
        #expect(starts == 2)
        #expect(rebuilds == 1)
    }

    @Test func transientActivationFailureRecoversBeforeStartingPlayback() throws {
        var activations = 0
        var plays = 0
        var rebuilt = false
        try PlaybackRecovery.perform(activate: {
            activations += 1
            if !rebuilt { throw CocoaError(.executableRuntimeMismatch) }
        }, start: { plays += 1 }, recover: { rebuilt = true })
        #expect(activations == 2)
        #expect(plays == 1)
    }

    @Test func persistentFailureIsReportedAfterOneRecoveryAttempt() {
        var activations = 0
        var rebuilds = 0
        #expect(throws: (any Error).self) {
            try PlaybackRecovery.perform(activate: { activations += 1; throw CocoaError(.executableRuntimeMismatch) },
                                         start: { Issue.record("Playback must not start before session activation") },
                                         recover: { rebuilds += 1 })
        }
        #expect(activations == 2)
        #expect(rebuilds == 1)
    }
}

import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable import SlateCore
#else
@testable import GlassSlate
#endif

struct SlateRepositoryTests {
    @Test func takePolicyPreservesIdentifiers() {
        for (input, expected) in [("1", "2"), ("009", "010"), ("99", "100"), ("0", "1"),
                                   ("A001", "A001"), ("02B", "02B"), ("1A", "1A"), ("", ""),
                                   (" 1", " 1"), ("1.0", "1.0"), ("-1", "-1"), ("１２", "１２"),
                                   ("18446744073709551615", "18446744073709551615")] {
            #expect(SlateValues.nextTake(input) == expected)
        }
    }

    @Test @MainActor func snapshotBeforeIncrementAndRestoreIsIndependent() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        var draft = SlateValues()
        draft.production = "测试 / Production"
        draft.roll = "A001"; draft.scene = "1A"; draft.shot = "02B"; draft.take = "009"
        draft.director = "导演"; draft.cameraman = "Camera"; draft.date = Date(timeIntervalSince1970: 100)
        try await store.saveDraft(draft)
        let time = Date(timeIntervalSince1970: 200)
        let record = try await store.clap(autoIncrement: true, soundName: "custom.wav", now: time)
        #expect(record.values == draft)
        #expect(record.createdAt == time)
        #expect(record.soundName == "custom.wav")
        #expect(store.draft.take == "010")
        try await store.restore(record)
        #expect(store.draft == draft)
        var changed = store.draft; changed.production = "Changed"
        try await store.saveDraft(changed)
        #expect(store.records.first?.values.production == "测试 / Production")
    }

    @Test @MainActor func diskPersistenceDeletionUndoAndSort() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("test.store")
        var removed: HistorySnapshot?
        var expectedDraft = SlateValues()
        do {
            let store = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
            var draft = store.draft; draft.take = "02B"; draft.production = "Persisted"
            draft.roll = "A001"; draft.scene = "1A"; draft.shot = "02B"
            draft.director = "导演"; draft.cameraman = "Camera operator"
            draft.date = Date(timeIntervalSince1970: 86400)
            expectedDraft = draft
            try await store.saveDraft(draft)
            for index in 0..<12 {
                try await store.clap(autoIncrement: true, soundName: "default", now: Date(timeIntervalSince1970: Double(index)))
            }
            #expect(store.draft.take == "02B")
            #expect(store.draft == expectedDraft)
            #expect(store.records.count == 12)
            removed = store.records[4]
            try await store.delete(id: store.records[4].id)
        }
        do {
            let store = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
            #expect(store.records.count == 11)
            #expect(store.draft.production == "Persisted")
            #expect(store.draft.take == "02B")
            let removed = try #require(removed)
            #expect(!store.records.contains { $0.id == removed.id })
            try await store.undoDelete(removed)
            try await store.undoDelete(removed)
            #expect(store.records.count == 12)
            #expect(store.records.map(\.createdAt) == store.records.map(\.createdAt).sorted(by: >))
        }
        let reopened = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        #expect(reopened.records.count == 12)
        #expect(reopened.draft == expectedDraft)
    }

    @Test @MainActor func disabledIncrementAndEmptyValues() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        var draft = store.draft; draft.take = "007"; draft.production = ""
        try await store.saveDraft(draft)
        let first = try await store.clap(autoIncrement: false, soundName: "default")
        #expect(store.draft.take == "007")
        #expect(first.values.production.isEmpty)
        let second = try await store.clap(autoIncrement: false, soundName: "default")
        #expect(first.id != second.id)
        try await store.delete(id: first.id)
        try await store.delete(id: first.id)
        #expect(store.records.count == 1)
        #expect(store.records.first?.id == second.id)
    }

    @Test @MainActor func corruptDraftFailsWithoutResettingStore() async throws {
        let container = try SlateRepository.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(SlateDraft(payload: Data("invalid".utf8)))
        try context.save()
        await #expect(throws: (any Error).self) { try await SlateRepository(container: container) }
        let retained = try context.fetch(FetchDescriptor<SlateDraft>())
        #expect(retained.first?.payload == Data("invalid".utf8))
    }
}

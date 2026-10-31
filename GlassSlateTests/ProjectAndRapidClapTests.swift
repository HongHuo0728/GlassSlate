import Foundation
import Testing
#if SWIFT_PACKAGE
@testable import SlateCore
#else
@testable import GlassSlate
#endif

struct ProjectAndRapidClapTests {
    @Test @MainActor func rapidTapsReserveUniqueTakesAndPersistEverySnapshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("rapid.store")
        let store = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        var draft = store.draft; draft.take = "001"
        try await store.saveDraft(draft)
        var operations: [Task<HistorySnapshot, Error>] = []
        var reserved: [String] = []
        for index in 1...50 {
            let (snapshot, operation) = try store.startClap(autoIncrement: true, soundName: "default", now: Date(timeIntervalSince1970: Double(index)))
            reserved.append(snapshot.values.take); operations.append(operation)
        }
        #expect(store.pendingClaps == 50)
        #expect(store.draft.take == "051")
        #expect(reserved == (1...50).map { String(format: "%03d", $0) })
        for operation in operations { _ = try await operation.value }
        #expect(store.pendingClaps == 0)
        #expect(store.records.count == 50)
        #expect(Set(store.records.map(\.id)).count == 50)
        let reopened = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        #expect(reopened.draft.take == "051")
        #expect(reopened.records.map(\.values.take) == reserved.reversed())
    }

    @Test @MainActor func projectGroupingAndRenameSurviveReopeningWithoutChangingSlateFields() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("projects.store")
        let store = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        var draft = store.draft; draft.production = "Original film"; draft.take = "02B"
        try await store.saveDraft(draft)
        let record = try await store.clap(autoIncrement: true, soundName: "default")
        let project = try await store.createProject(name: "  我的项目  ")
        #expect(project.name == "我的项目")
        try await store.move(id: record.id, projectID: project.id)
        try await store.rename(id: record.id, name: "  Opening shot  ")
        try await store.setExpanded(id: project.id, expanded: false)
        let reopened = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        let saved = try #require(reopened.records.first)
        #expect(saved.displayName == "Opening shot")
        #expect(saved.values == draft)
        #expect(saved.projectID == project.id)
        #expect(reopened.projects.first?.isExpanded == false)
        try await reopened.restore(saved)
        #expect(reopened.draft.production == "Original film")
        try await reopened.move(id: record.id, projectID: nil)
        #expect(reopened.records.first?.projectID == nil)
        try await reopened.rename(id: record.id, name: "")
        #expect(reopened.records.first?.title == "Original film")
    }

    @Test @MainActor func deleteUndoRestoresNameAndFolder() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        let record = try await store.clap(autoIncrement: false, soundName: "default")
        let project = try await store.createProject(name: "Project")
        try await store.move(id: record.id, projectID: project.id)
        try await store.rename(id: record.id, name: "Saved title")
        let snapshot = try #require(store.records.first)
        try await store.delete(id: record.id)
        try await store.undoDelete(snapshot)
        #expect(store.records.first == snapshot)
    }

    @Test @MainActor func invalidProjectDoesNotMoveOrRenameRecord() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        let record = try await store.clap(autoIncrement: false, soundName: "default")
        await #expect(throws: SlateStorageError.self) { try await store.move(id: record.id, projectID: UUID()) }
        #expect(store.records.first == record)
        #expect(!store.isSaving)
        await #expect(throws: SlateStorageError.self) { try await store.createProject(name: "  ") }
        #expect(store.projects.isEmpty)
    }
}

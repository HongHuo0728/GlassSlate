import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable import SlateCore
#else
@testable import GlassSlate
#endif

struct Version101Tests {
    @Test(arguments: [ProjectDeletionMode.keepSlates, .deleteSlates])
    @MainActor func projectDeletionAndUndoPersistAtomically(_ mode: ProjectDeletionMode) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("project.store")
        let store = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        let project = try await store.createProject(name: "拍摄项目 🎬")
        let other = try await store.createProject(name: "Keep this project")
        var members: [HistorySnapshot] = []
        for index in 0..<4 {
            let record = try await store.clap(autoIncrement: true, soundName: "custom.wav", now: Date(timeIntervalSince1970: Double(index)))
            if index < 2 {
                try await store.move(id: record.id, projectID: project.id)
                try await store.rename(id: record.id, name: "Named \(index)")
                members.append(try #require(store.records.first { $0.id == record.id }))
            } else if index == 2 { try await store.move(id: record.id, projectID: other.id) }
        }
        try await store.setExpanded(id: project.id, expanded: false)
        let before = store.records
        let draft = store.draft
        let deletion = try await store.deleteProject(id: project.id, mode: mode)
        #expect(Set(deletion.records.map(\.id)) == Set(members.map(\.id)))
        #expect(!deletion.project.isExpanded)
        #expect(store.projects.map(\.id) == [other.id])
        #expect(store.records.count == (mode == .keepSlates ? 4 : 2))
        #expect(!store.records.contains { $0.projectID == project.id })
        #expect(store.draft == draft)
        let reopened = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        #expect(reopened.records == store.records)
        #expect(reopened.projects == store.projects)
        try await reopened.undoProjectDelete(deletion)
        try await reopened.undoProjectDelete(deletion)
        #expect(reopened.records == before)
        #expect(reopened.projects.count == 2)
        #expect(reopened.projects.first?.isExpanded == false)
        let verified = try await SlateRepository(container: SlateRepository.makeContainer(url: url))
        #expect(verified.records == before)
        #expect(verified.draft == draft)
        #expect(verified.projects == reopened.projects)
    }

    @Test @MainActor func undoKeptProjectPreservesLaterMovesNamesAndDeletions() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        let original = try await store.createProject(name: "Original")
        let destination = try await store.createProject(name: "Destination")
        let first = try await store.clap(autoIncrement: true, soundName: "default")
        let second = try await store.clap(autoIncrement: true, soundName: "default")
        for id in [first.id, second.id] { try await store.move(id: id, projectID: original.id) }
        let deleted = try await store.deleteProject(id: original.id, mode: .keepSlates)
        try await store.move(id: first.id, projectID: destination.id)
        try await store.rename(id: first.id, name: "Edited after deletion")
        try await store.delete(id: second.id)
        try await store.undoProjectDelete(deleted)
        #expect(store.records.count == 1)
        #expect(store.records.first?.projectID == destination.id)
        #expect(store.records.first?.displayName == "Edited after deletion")
    }

    @Test @MainActor func deletedSlateReturnsToUnfiledWhenItsProjectIsGone() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        let folder = try await store.createProject(name: "Temporary")
        let record = try await store.clap(autoIncrement: false, soundName: "default")
        try await store.move(id: record.id, projectID: folder.id)
        let snapshot = try #require(store.records.first)
        try await store.delete(id: snapshot.id)
        let deleted = try await store.deleteProject(id: folder.id, mode: .deleteSlates)
        #expect(deleted.records.isEmpty)
        try await store.undoDelete(snapshot)
        #expect(store.records.first?.id == snapshot.id)
        #expect(store.records.first?.projectID == nil)
        try await store.undoProjectDelete(deleted)
        #expect(store.projects.first?.id == folder.id)
    }

    @Test @MainActor func openingLegacyOrphanedRecordRepairsMembershipWithoutLosingData() async throws {
        let container = try SlateRepository.makeContainer(inMemory: true)
        let context = ModelContext(container)
        var record = HistorySnapshot(id: UUID(), createdAt: .now, values: SlateValues(), soundName: "custom.wav")
        record.projectID = UUID(); record.displayName = "Keep my title"
        context.insert(SlateRecord(snapshot: record, payload: try JSONEncoder().encode(record.values)))
        try context.save()
        let store = try await SlateRepository(container: container)
        #expect(store.records.first?.id == record.id)
        #expect(store.records.first?.displayName == record.displayName)
        #expect(store.records.first?.projectID == nil)
        let reopened = try await SlateRepository(container: container)
        #expect(reopened.records == store.records)
    }

    @Test @MainActor func fieldSaveMergesWithClapsAndOtherFields() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        try await store.saveField(.text(.production, "Original"))
        try await store.saveField(.text(.director, "Director"))
        let (_, write) = try store.startClap(autoIncrement: true, soundName: "default")
        await #expect(throws: SlateStorageError.self) { try await store.saveField(.text(.production, "Too early")) }
        _ = try await write.value
        try await store.saveField(.text(.production, "Edited while remote clap advanced Take"))
        #expect(store.draft.take == "2")
        #expect(store.draft.director == "Director")
        #expect(store.records.first?.values.production == "Original")
        let date = Date(timeIntervalSince1970: 12345)
        try await store.saveField(.date(date))
        #expect(store.draft.date == date)
        #expect(store.draft.take == "2")
    }

    #if DEBUG
    @Test(arguments: [ProjectDeletionMode.keepSlates, .deleteSlates])
    @MainActor func projectDeleteAndUndoRollBackAfterStorageFailure(_ mode: ProjectDeletionMode) async throws {
        let container = try SlateRepository.makeContainer(inMemory: true)
        let store = try await SlateRepository(container: container)
        let project = try await store.createProject(name: "Recoverable")
        let record = try await store.clap(autoIncrement: true, soundName: "default")
        try await store.move(id: record.id, projectID: project.id)
        let original = store.records
        await store.failNextSaveForTesting()
        await #expect(throws: (any Error).self) { try await store.deleteProject(id: project.id, mode: mode) }
        #expect(store.records == original)
        #expect(store.projects == [project])
        let afterFailure = try await SlateRepository(container: container)
        #expect(afterFailure.records == original)
        #expect(afterFailure.projects == [project])
        let deletion = try await store.deleteProject(id: project.id, mode: mode)
        let remaining = store.records
        await store.failNextSaveForTesting()
        await #expect(throws: (any Error).self) { try await store.undoProjectDelete(deletion) }
        #expect(store.projects.isEmpty)
        #expect(store.records == remaining)
        let failedUndo = try await SlateRepository(container: container)
        #expect(failedUndo.projects.isEmpty)
        #expect(failedUndo.records == remaining)
        try await store.undoProjectDelete(deletion)
        #expect(store.records == original)
    }

    @Test @MainActor func failedRapidClapBatchResetsReservationAndAllowsRetry() async throws {
        let store = try await SlateRepository(container: SlateRepository.makeContainer(inMemory: true))
        await store.failNextSaveForTesting()
        let (_, first) = try store.startClap(autoIncrement: true, soundName: "default")
        let (_, second) = try store.startClap(autoIncrement: true, soundName: "default")
        for task in [first, second] { await #expect(throws: (any Error).self) { try await task.value } }
        #expect(!store.isSaving)
        #expect(store.draft.take == "1")
        #expect(store.records.isEmpty)
        let retry = try await store.clap(autoIncrement: true, soundName: "default")
        #expect(retry.values.take == "1")
        #expect(store.draft.take == "2")
    }
    #endif

    @Test func undoDeadlineAndLayoutBreakpoints() {
        let record = HistorySnapshot(id: UUID(), createdAt: .now, values: SlateValues(), soundName: "default")
        let now = Date(timeIntervalSince1970: 100)
        let notice = DeletionNotice(.slate(record), now: now)
        #expect(notice.canUndo(at: now.addingTimeInterval(4.999)))
        #expect(!notice.canUndo(at: now.addingTimeInterval(5)))
        #expect(!notice.canUndo(at: now.addingTimeInterval(100)))
        for width: CGFloat in [744, 768, 820, 1024, 1180, 1366] {
            #expect(HistoryLayout.usesSidebar(isPad: true, width: width))
            #expect(!HistoryLayout.usesSidebar(isPad: false, width: width))
            #expect(width - HistoryLayout.sidebarWidth - 36 >= 400)
        }
        for width: CGFloat in [320, 375, 600, 743] { #expect(!HistoryLayout.usesSidebar(isPad: true, width: width)) }
    }

    @Test func slowEdgeDragsUseCurrentPortraitAndLandscapeBounds() {
        for width: CGFloat in [390, 844, 852, 1024] {
            #expect(DrawerGesturePolicy.startsAtEdge(x: 1, width: width, opening: true))
            #expect(DrawerGesturePolicy.startsAtEdge(x: width - 1, width: width, opening: false))
            #expect(!DrawerGesturePolicy.startsAtEdge(x: width / 2, width: width, opening: false))
        }
        #expect(DrawerGesturePolicy.shouldBeginOpening(velocityX: 1, velocityY: 0.1))
        #expect(DrawerGesturePolicy.shouldBegin(velocityX: -1, velocityY: 0.1))
        #expect(!DrawerGesturePolicy.shouldBeginOpening(velocityX: 1, velocityY: 2))
        #expect(!DrawerGesturePolicy.shouldBegin(velocityX: 1, velocityY: 0))
    }
}

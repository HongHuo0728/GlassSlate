import Foundation
import Observation
import SwiftData

private struct StoredState: Sendable {
    let draft: SlateValues
    let records: [HistorySnapshot]
    let projects: [ProjectFolder]
}

@ModelActor private actor SlatePersistence {
    #if DEBUG
    private var failNextSave = false
    func failNextSaveForTesting() { failNextSave = true }
    #endif
    private func workingDraft() throws -> SlateDraft {
        if let current = try modelContext.fetch(FetchDescriptor<SlateDraft>()).first { return current }
        let draft = SlateDraft(payload: try JSONEncoder().encode(SlateValues()))
        modelContext.insert(draft)
        return draft
    }
    func load() throws -> StoredState {
        modelContext.autosaveEnabled = false
        let draft = try workingDraft()
        let value = try JSONDecoder().decode(SlateValues.self, from: draft.payload)
        let stored = try modelContext.fetch(FetchDescriptor<SlateRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        var records = try stored.map {
            HistorySnapshot(id: $0.id, createdAt: $0.createdAt,
                            values: try JSONDecoder().decode(SlateValues.self, from: $0.payload), soundName: $0.soundName,
                            displayName: $0.displayName, projectID: $0.projectID)
        }
        let projects = try modelContext.fetch(FetchDescriptor<SlateProject>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { ProjectFolder(id: $0.id, name: $0.name, createdAt: $0.createdAt, isExpanded: $0.isExpanded) }
        let validIDs = Set(projects.map(\.id))
        for index in records.indices {
            if let id = records[index].projectID, !validIDs.contains(id) {
                records[index].projectID = nil
                stored[index].projectID = nil
            }
        }
        try save()
        return StoredState(draft: value, records: records, projects: projects)
    }
    private func save() throws {
        do {
            #if DEBUG
            if failNextSave {
                failNextSave = false
                throw CocoaError(.fileWriteOutOfSpace)
            }
            #endif
            try modelContext.save()
        } catch { modelContext.rollback(); throw error }
    }
    func saveDraft(_ value: SlateValues) throws {
        let payload = try JSONEncoder().encode(value)
        let draft = try workingDraft()
        draft.payload = payload; draft.updatedAt = .now
        try save()
    }
    func storeClap(_ snapshot: HistorySnapshot, next: SlateValues) throws {
        let record = SlateRecord(snapshot: snapshot, payload: try JSONEncoder().encode(snapshot.values))
        let payload = try JSONEncoder().encode(next)
        let draft = try workingDraft()
        modelContext.insert(record)
        draft.payload = payload; draft.updatedAt = snapshot.createdAt
        try save()
    }
    private func record(id: UUID) throws -> SlateRecord? {
        try modelContext.fetch(FetchDescriptor<SlateRecord>(predicate: #Predicate { $0.id == id })).first
    }
    func delete(id: UUID) throws {
        guard let record = try record(id: id) else { return }
        modelContext.delete(record); try save()
    }
    func undoDelete(_ snapshot: HistorySnapshot) throws -> HistorySnapshot {
        if let existing = try record(id: snapshot.id) { return try snapshotFor(existing) }
        var restored = snapshot
        if let id = restored.projectID, try project(id: id) == nil { restored.projectID = nil }
        modelContext.insert(SlateRecord(snapshot: restored, payload: try JSONEncoder().encode(restored.values)))
        try save()
        return restored
    }
    func rename(id: UUID, name: String?) throws {
        guard let record = try record(id: id) else { return }
        record.displayName = name; try save()
    }
    func move(id: UUID, projectID: UUID?) throws {
        if let projectID {
            guard let project = try modelContext.fetch(FetchDescriptor<SlateProject>(predicate: #Predicate { $0.id == projectID })).first else {
                throw SlateStorageError.missingProject
            }
            project.isExpanded = true
        }
        guard let record = try record(id: id) else { return }
        record.projectID = projectID; try save()
    }
    func createProject(_ folder: ProjectFolder) throws {
        modelContext.insert(SlateProject(id: folder.id, name: folder.name, createdAt: folder.createdAt, isExpanded: folder.isExpanded))
        try save()
    }
    func expand(id: UUID, expanded: Bool) throws {
        guard let project = try modelContext.fetch(FetchDescriptor<SlateProject>(predicate: #Predicate { $0.id == id })).first else { return }
        project.isExpanded = expanded; try save()
    }
    private func project(id: UUID) throws -> SlateProject? {
        try modelContext.fetch(FetchDescriptor<SlateProject>(predicate: #Predicate { $0.id == id })).first
    }
    private func snapshotFor(_ record: SlateRecord) throws -> HistorySnapshot {
        HistorySnapshot(id: record.id, createdAt: record.createdAt,
                        values: try JSONDecoder().decode(SlateValues.self, from: record.payload),
                        soundName: record.soundName, displayName: record.displayName, projectID: record.projectID)
    }
    func deleteProject(id: UUID, mode: ProjectDeletionMode) throws -> ProjectDeletionSnapshot {
        guard let folder = try project(id: id) else { throw SlateStorageError.missingProject }
        let members = try modelContext.fetch(FetchDescriptor<SlateRecord>(predicate: #Predicate { $0.projectID == id }))
        let snapshot = ProjectDeletionSnapshot(
            project: ProjectFolder(id: folder.id, name: folder.name, createdAt: folder.createdAt, isExpanded: folder.isExpanded),
            records: try members.map(snapshotFor), mode: mode)
        for record in members {
            switch mode {
            case .keepSlates: record.projectID = nil
            case .deleteSlates: modelContext.delete(record)
            }
        }
        modelContext.delete(folder)
        try save()
        return snapshot
    }
    func undoProjectDelete(_ snapshot: ProjectDeletionSnapshot) throws -> [HistorySnapshot] {
        guard try project(id: snapshot.project.id) == nil else { return [] }
        do {
            let folder = snapshot.project
            modelContext.insert(SlateProject(id: folder.id, name: folder.name, createdAt: folder.createdAt, isExpanded: folder.isExpanded))
            var restored: [HistorySnapshot] = []
            for member in snapshot.records {
                if let existing = try record(id: member.id) {
                    // A user's subsequent move takes precedence over restoring old membership.
                    if existing.projectID == nil { existing.projectID = folder.id }
                    restored.append(try snapshotFor(existing))
                } else if snapshot.mode == .deleteSlates {
                    modelContext.insert(SlateRecord(snapshot: member, payload: try JSONEncoder().encode(member.values)))
                    restored.append(member)
                }
            }
            try save()
            return restored
        } catch { modelContext.rollback(); throw error }
    }
}

enum SlateStorageError: LocalizedError {
    case operationInProgress, missingProject, emptyName
    var errorDescription: String? {
        switch self {
        case .operationInProgress: String(localized: "A save is still in progress. Please try again.")
        case .missingProject: String(localized: "This project is no longer available.")
        case .emptyName: String(localized: "Enter a project name.")
        }
    }
}

@MainActor @Observable final class SlateRepository {
    private(set) var draft: SlateValues
    private(set) var records: [HistorySnapshot]
    private(set) var projects: [ProjectFolder]
    private(set) var pendingClaps = 0
    private var manualWrite = false
    var isSaving: Bool { manualWrite || pendingClaps > 0 }
    private let persistence: SlatePersistence
    private var committedDraft: SlateValues
    private var clapTail: Task<HistorySnapshot, Error>?
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema([SlateDraft.self, SlateRecord.self, SlateProject.self])
        let configuration: ModelConfiguration
        if let url { configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none) }
        else { configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none) }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
    init(container: ModelContainer) async throws {
        let worker = await Task.detached { SlatePersistence(modelContainer: container) }.value
        let state = try await worker.load()
        persistence = worker; draft = state.draft; committedDraft = state.draft
        records = state.records; projects = state.projects
    }
    private func beginWrite() throws {
        guard !isSaving else { throw SlateStorageError.operationInProgress }
        manualWrite = true
    }
    func saveDraft(_ value: SlateValues) async throws {
        try beginWrite(); defer { manualWrite = false }
        try await persistence.saveDraft(value)
        draft = value; committedDraft = value
    }
    func saveField(_ edit: SlateFieldEdit) async throws {
        // Merge only the field being edited into the latest draft, including remote claps.
        try await saveDraft(edit.applying(to: draft))
    }

    /// Reserve the current Take synchronously. Every tap gets a distinct snapshot, even while earlier taps save.
    /// Disk operations are serialized in tap order; no animation or fixed debounce gates this queue.
    func startClap(autoIncrement: Bool, soundName: String, now: Date = .now) throws -> (HistorySnapshot, Task<HistorySnapshot, Error>) {
        guard !manualWrite else { throw SlateStorageError.operationInProgress }
        let frozen = draft
        let snapshot = HistorySnapshot(id: UUID(), createdAt: now, values: frozen, soundName: soundName)
        var next = frozen
        if autoIncrement { next.take = SlateValues.nextTake(next.take) }
        draft = next
        pendingClaps += 1
        let previous = clapTail
        let writer = persistence
        let operation = Task { @MainActor [self] () throws -> HistorySnapshot in
            defer {
                pendingClaps -= 1
                if pendingClaps == 0 { clapTail = nil; draft = committedDraft }
            }
            if let previous { _ = try await previous.value }
            try await writer.storeClap(snapshot, next: next)
            committedDraft = next
            records.append(snapshot); records.sort { $0.createdAt > $1.createdAt }
            return snapshot
        }
        clapTail = operation
        return (snapshot, operation)
    }
    @discardableResult func clap(autoIncrement: Bool, soundName: String, now: Date = .now) async throws -> HistorySnapshot {
        let (_, operation) = try startClap(autoIncrement: autoIncrement, soundName: soundName, now: now)
        return try await operation.value
    }
    func restore(_ record: HistorySnapshot) async throws { try await saveDraft(record.values) }
    func delete(id: UUID) async throws {
        try beginWrite(); defer { manualWrite = false }
        try await persistence.delete(id: id); records.removeAll { $0.id == id }
    }
    func undoDelete(_ snapshot: HistorySnapshot) async throws {
        guard !records.contains(where: { $0.id == snapshot.id }) else { return }
        try beginWrite(); defer { manualWrite = false }
        let restored = try await persistence.undoDelete(snapshot)
        records.append(restored); records.sort { $0.createdAt > $1.createdAt }
    }
    func rename(id: UUID, name: String) async throws {
        try beginWrite(); defer { manualWrite = false }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = clean.isEmpty ? nil : clean
        try await persistence.rename(id: id, name: title)
        if let index = records.firstIndex(where: { $0.id == id }) { records[index].displayName = title }
    }
    @discardableResult func createProject(name: String) async throws -> ProjectFolder {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw SlateStorageError.emptyName }
        try beginWrite(); defer { manualWrite = false }
        let folder = ProjectFolder(id: UUID(), name: clean, createdAt: .now, isExpanded: true)
        try await persistence.createProject(folder)
        projects.append(folder)
        return folder
    }
    func setExpanded(id: UUID, expanded: Bool) async throws {
        try beginWrite(); defer { manualWrite = false }
        try await persistence.expand(id: id, expanded: expanded)
        if let index = projects.firstIndex(where: { $0.id == id }) { projects[index].isExpanded = expanded }
    }
    func move(id: UUID, projectID: UUID?) async throws {
        try beginWrite(); defer { manualWrite = false }
        try await persistence.move(id: id, projectID: projectID)
        if let index = records.firstIndex(where: { $0.id == id }) { records[index].projectID = projectID }
        if let index = projects.firstIndex(where: { $0.id == projectID }) { projects[index].isExpanded = true }
    }
    @discardableResult func deleteProject(id: UUID, mode: ProjectDeletionMode) async throws -> ProjectDeletionSnapshot {
        try beginWrite(); defer { manualWrite = false }
        let snapshot = try await persistence.deleteProject(id: id, mode: mode)
        projects.removeAll { $0.id == id }
        if mode == .deleteSlates { records.removeAll { $0.projectID == id } }
        else {
            for index in records.indices where records[index].projectID == id { records[index].projectID = nil }
        }
        return snapshot
    }
    func undoProjectDelete(_ snapshot: ProjectDeletionSnapshot) async throws {
        guard !projects.contains(where: { $0.id == snapshot.project.id }) else { return }
        try beginWrite(); defer { manualWrite = false }
        let restored = try await persistence.undoProjectDelete(snapshot)
        projects.append(snapshot.project); projects.sort { $0.createdAt < $1.createdAt }
        for record in restored {
            if let index = records.firstIndex(where: { $0.id == record.id }) { records[index] = record }
            else { records.append(record) }
        }
        records.sort { $0.createdAt > $1.createdAt }
    }
    #if DEBUG
    func failNextSaveForTesting() async { await persistence.failNextSaveForTesting() }
    #endif
}

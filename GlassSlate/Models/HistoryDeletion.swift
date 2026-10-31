import Foundation

enum ProjectDeletionMode: Sendable { case keepSlates, deleteSlates }

struct ProjectDeletionSnapshot: Sendable {
    let project: ProjectFolder
    let records: [HistorySnapshot]
    let mode: ProjectDeletionMode
}

enum HistoryDeletion: Sendable {
    case slate(HistorySnapshot)
    case project(ProjectDeletionSnapshot)

    var isProject: Bool {
        if case .project = self { return true }
        return false
    }
}

struct DeletionNotice: Sendable {
    let id = UUID()
    let deletion: HistoryDeletion
    let expiresAt: Date
    init(_ deletion: HistoryDeletion, now: Date = .now) {
        self.deletion = deletion
        expiresAt = now.addingTimeInterval(5)
    }
    func canUndo(at now: Date) -> Bool { now < expiresAt }
}

enum SlateFieldEdit: Sendable {
    case text(SlateField, String)
    case date(Date)

    func applying(to draft: SlateValues) -> SlateValues {
        var value = draft
        switch self {
        case .text(let field, let text): value[field] = text
        case .date(let date): value.date = date
        }
        return value
    }
}

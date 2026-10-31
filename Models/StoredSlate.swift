import Foundation
import SwiftData

@Model final class SlateDraft {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date
    init(payload: Data, updatedAt: Date = .now) {
        self.key = "working-draft"
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model final class SlateRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var payload: Data
    var soundName: String
    var displayName: String? = nil
    var projectID: UUID? = nil
    init(snapshot: HistorySnapshot, payload: Data) {
        id = snapshot.id
        createdAt = snapshot.createdAt
        self.payload = payload
        soundName = snapshot.soundName
        displayName = snapshot.displayName
        projectID = snapshot.projectID
    }
}

@Model final class SlateProject {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var isExpanded: Bool
    init(id: UUID = UUID(), name: String, createdAt: Date = .now, isExpanded: Bool = true) {
        self.id = id; self.name = name; self.createdAt = createdAt; self.isExpanded = isExpanded
    }
}

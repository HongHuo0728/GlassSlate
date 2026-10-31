import Foundation

enum SlateField: String, CaseIterable, Identifiable, Sendable {
    case production = "Production", roll = "Roll", scene = "Scene", shot = "Shot"
    case take = "Take", director = "Director", cameraman = "Cameraman", date = "Date"
    var id: String { rawValue }
}

struct SlateValues: Codable, Equatable, Sendable {
    var production = ""
    var roll = ""
    var scene = ""
    var shot = ""
    var take = "1"
    var director = ""
    var cameraman = ""
    var date = Date()

    subscript(field: SlateField) -> String {
        get {
            switch field {
            case .production: production
            case .roll: roll
            case .scene: scene
            case .shot: shot
            case .take: take
            case .director: director
            case .cameraman: cameraman
            case .date: date.formatted(date: .numeric, time: .omitted)
            }
        }
        set {
            switch field {
            case .production: production = newValue
            case .roll: roll = newValue
            case .scene: scene = newValue
            case .shot: shot = newValue
            case .take: take = newValue
            case .director: director = newValue
            case .cameraman: cameraman = newValue
            case .date: break
            }
        }
    }

    /// Only ASCII decimal identifiers are incremented. Preserve leading zeroes and all other formats.
    static func nextTake(_ value: String) -> String {
        guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
              let number = UInt64(value), number < UInt64.max else { return value }
        let result = String(number + 1)
        return String(repeating: "0", count: max(0, value.count - result.count)) + result
    }
}

struct HistorySnapshot: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let values: SlateValues
    let soundName: String
    var displayName: String? = nil
    var projectID: UUID? = nil
    var title: String { displayName ?? (values.production.isEmpty ? String(localized: "Untitled production") : values.production) }
}

struct ProjectFolder: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var isExpanded: Bool
}

import ActivityKit
import Foundation

struct SlateActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var production: String
        var scene: String
        var shot: String
        var take: String
        var message: String?
        var updatedAt: Date
    }
    var name: String = "GlassSlate"
}

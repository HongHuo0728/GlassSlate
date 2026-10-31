import Foundation

enum ActivityPayloadText {
    /// Bound by UTF-8 bytes, preserving scalar boundaries even for combining marks and emoji.
    static func limited(_ value: String, bytes limit: Int) -> String {
        var result = String.UnicodeScalarView()
        var used = 0
        for scalar in value.unicodeScalars {
            let count = String(scalar).utf8.count
            guard used + count <= limit else { break }
            result.append(scalar); used += count
        }
        return String(result)
    }
}

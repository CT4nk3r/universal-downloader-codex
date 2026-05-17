import Foundation

enum ProgressLineSanitizer {
    static func sanitize(_ raw: String, maxLength: Int = 72) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Working..." }

        let noTags = trimmed.replacingOccurrences(
            of: #"^(?:\s*\[[^\]]+\]\s*)+"#,
            with: "",
            options: .regularExpression
        )
        let singleLine = noTags.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        guard singleLine.count > maxLength else { return singleLine }
        guard maxLength > 3 else { return String(singleLine.prefix(maxLength)) }
        return String(singleLine.prefix(maxLength - 3)) + "..."
    }
}

import Foundation
import SwiftData

/// Two lines from Claude about one Project's day (S-020, S-021).
/// One per Project and day: Summarize Again replaces it.
@Model
final class Summary {
    var project: String = ""
    /// Local midnight of the day it describes.
    var day: Date = Date.now
    var text: String = ""
    /// Tokens the summary cost (from Claude Code's reply).
    var tokens: Int = 0
    var createdAt: Date = Date.now

    init(project: String, day: Date, text: String, tokens: Int) {
        self.project = project
        self.day = day
        self.text = text
        self.tokens = tokens
    }
}

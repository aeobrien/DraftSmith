import Foundation

struct TranscriptStore: Sendable {
    func save(text: String, annotationUUID: UUID) throws {
        let directory = AppDirectories.transcriptDirectory(for: annotationUUID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-") // Avoid colons in filenames
        let fileURL = directory.appendingPathComponent("\(timestamp).txt")

        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func load(annotationUUID: UUID) throws -> [String] {
        let directory = AppDirectories.transcriptDirectory(for: annotationUUID)
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }

        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )

        return try files
            .filter { $0.pathExtension == "txt" }
            .sorted { a, b in
                let dateA = try a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let dateB = try b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return dateA > dateB
            }
            .map { try String(contentsOf: $0, encoding: .utf8) }
    }
}

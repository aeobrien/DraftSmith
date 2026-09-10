import Foundation

enum AppDirectories {
    private static let fileManager = FileManager.default

    static var appSupport: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(AppConstants.appSupportDirectoryName, isDirectory: true)
        ensureDirectory(at: url)
        return url
    }

    static var projects: URL {
        appSupport.appendingPathComponent("Projects", isDirectory: true)
    }

    static var audio: URL {
        appSupport.appendingPathComponent("Audio", isDirectory: true)
    }

    static var transcripts: URL {
        appSupport.appendingPathComponent("Transcripts", isDirectory: true)
    }

    static var styleMemory: URL {
        appSupport.appendingPathComponent("StyleMemory", isDirectory: true)
    }

    static var styleCapsules: URL {
        styleMemory.appendingPathComponent("StyleCapsules", isDirectory: true)
    }

    static var prompts: URL {
        appSupport.appendingPathComponent("Prompts", isDirectory: true)
    }

    static var caches: URL {
        appSupport.appendingPathComponent("Caches", isDirectory: true)
    }

    static var runtime: URL {
        appSupport.appendingPathComponent("Runtime", isDirectory: true)
    }

    static var logs: URL {
        appSupport.appendingPathComponent("Logs", isDirectory: true)
    }

    static func audioDirectory(for annotationUUID: UUID) -> URL {
        audio.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
    }

    static func transcriptDirectory(for annotationUUID: UUID) -> URL {
        transcripts.appendingPathComponent(annotationUUID.uuidString, isDirectory: true)
    }

    static func createAllDirectories() {
        let directories = [
            projects, audio, transcripts, styleMemory, styleCapsules,
            prompts, caches, runtime, logs
        ]
        for dir in directories {
            ensureDirectory(at: dir)
        }
    }

    private static func ensureDirectory(at url: URL) {
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

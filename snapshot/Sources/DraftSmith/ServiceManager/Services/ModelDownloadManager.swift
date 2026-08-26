import Foundation
import MLXLLM
import MLXLMCommon
import WhisperKit

@Observable
@MainActor
final class ModelDownloadManager {
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var currentDownloadDescription: String = ""
    private(set) var error: DraftSmithError?

    private var setupCompleteMarker: URL {
        AppDirectories.runtime.appendingPathComponent(".setup_complete")
    }

    var needsInitialSetup: Bool {
        !FileManager.default.fileExists(atPath: setupCompleteMarker.path)
    }

    func downloadModels(recommendation: ModelRecommendation) async {
        isDownloading = true
        downloadProgress = 0
        error = nil

        do {
            AppDirectories.createAllDirectories()

            // Phase 1: Download LLM model (0% – 60%)
            currentDownloadDescription = "Downloading language model..."
            let config = recommendation.modelConfiguration
            _ = try await LLMModelFactory.shared.loadContainer(
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress.fractionCompleted * 0.60
                    let pct = Int(progress.fractionCompleted * 100)
                    self?.currentDownloadDescription = "Downloading language model... \(pct)%"
                }
            }

            // Phase 2: Download Java runtime (60% – 72%)
            downloadProgress = 0.60
            try await downloadJRE()

            // Phase 3: Download LanguageTool (72% – 90%)
            downloadProgress = 0.72
            try await downloadLanguageTool()

            // Phase 4: Download WhisperKit model (90% – 100%)
            downloadProgress = 0.90
            try await downloadWhisperModel()

            downloadProgress = 1.0
            currentDownloadDescription = "Setup complete"

            // Mark setup as done so dialog doesn't reappear
            try Data().write(to: setupCompleteMarker)
        } catch {
            self.error = .llmLoadFailed(error.localizedDescription)
            currentDownloadDescription = "Download failed: \(error.localizedDescription)"
        }

        isDownloading = false
    }

    func skipDownload() {
        // Mark as complete so the dialog doesn't show again
        try? Data().write(to: setupCompleteMarker)
        isDownloading = false
        downloadProgress = 0
        currentDownloadDescription = ""
    }

    // MARK: - Java Runtime Download

    // Adoptium Temurin JRE — portable, no installer needed
    // This URL redirects to the latest JRE 21 tarball for macOS aarch64
    private static let jreURL = URL(
        string: "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jre/hotspot/normal/eclipse?project=jdk"
    )!

    private func downloadJRE() async throws {
        let jreDir = AppDirectories.runtime.appendingPathComponent("jre")
        let javaBin = jreDir.appendingPathComponent("bin/java")

        // Skip if already installed
        if FileManager.default.fileExists(atPath: javaBin.path) {
            downloadProgress = 0.72
            currentDownloadDescription = "Java runtime already installed"
            return
        }

        currentDownloadDescription = "Downloading Java runtime (~50 MB)..."

        let tempDir = FileManager.default.temporaryDirectory
        let tarPath = tempDir.appendingPathComponent("temurin-jre-\(UUID().uuidString).tar.gz")

        // Download the tarball (URL redirects to actual file)
        let (downloadedURL, _) = try await URLSession.shared.download(from: Self.jreURL)
        try FileManager.default.moveItem(at: downloadedURL, to: tarPath)

        downloadProgress = 0.68
        currentDownloadDescription = "Extracting Java runtime..."

        // Extract using tar
        let extractDir = tempDir.appendingPathComponent("jre-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        try await runProcess(
            "/usr/bin/tar",
            arguments: ["xzf", tarPath.path, "-C", extractDir.path]
        )

        // Find the extracted JRE directory (e.g., jdk-21.0.x-jre/Contents/Home)
        let contents = try FileManager.default.contentsOfDirectory(
            at: extractDir, includingPropertiesForKeys: nil
        )
        guard let jdkDir = contents.first(where: { $0.lastPathComponent.hasPrefix("jdk-") }) else {
            throw DraftSmithError.languageToolStartFailed(
                "Could not find JRE directory in archive"
            )
        }

        // Adoptium tarballs on macOS have Contents/Home structure
        let homeDir = jdkDir.appendingPathComponent("Contents/Home")
        let sourceDir = FileManager.default.fileExists(atPath: homeDir.path) ? homeDir : jdkDir

        // Move to runtime directory
        if FileManager.default.fileExists(atPath: jreDir.path) {
            try FileManager.default.removeItem(at: jreDir)
        }
        try FileManager.default.moveItem(at: sourceDir, to: jreDir)

        // Verify java binary exists
        guard FileManager.default.fileExists(atPath: javaBin.path) else {
            throw DraftSmithError.languageToolStartFailed(
                "java binary not found after extraction"
            )
        }

        downloadProgress = 0.72
        currentDownloadDescription = "Java runtime installed"

        // Cleanup
        try? FileManager.default.removeItem(at: tarPath)
        try? FileManager.default.removeItem(at: extractDir)
    }

    // MARK: - LanguageTool Download

    private static let languageToolURL = URL(
        string: "https://languagetool.org/download/LanguageTool-stable.zip"
    )!

    private func downloadLanguageTool() async throws {
        let ltDir = AppDirectories.runtime.appendingPathComponent("LanguageTool")
        let serverJar = ltDir.appendingPathComponent("languagetool-server.jar")

        // Skip if already installed
        if FileManager.default.fileExists(atPath: serverJar.path) {
            downloadProgress = 0.90
            currentDownloadDescription = "Grammar engine already installed"
            return
        }

        currentDownloadDescription = "Downloading grammar engine (~250 MB)..."

        let tempDir = FileManager.default.temporaryDirectory
        let zipPath = tempDir.appendingPathComponent("LanguageTool-stable-\(UUID().uuidString).zip")

        // Download the ZIP
        let (downloadedURL, _) = try await URLSession.shared.download(
            from: Self.languageToolURL
        )
        try FileManager.default.moveItem(at: downloadedURL, to: zipPath)

        downloadProgress = 0.88
        currentDownloadDescription = "Extracting grammar engine..."

        // Extract using macOS built-in ditto
        let extractDir = tempDir.appendingPathComponent("lt-extract-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        try await runProcess(
            "/usr/bin/ditto",
            arguments: ["-xk", zipPath.path, extractDir.path]
        )

        // Find the extracted LanguageTool-X.X directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: extractDir, includingPropertiesForKeys: nil
        )
        guard let ltExtracted = contents.first(where: {
            $0.lastPathComponent.hasPrefix("LanguageTool-")
        }) else {
            throw DraftSmithError.languageToolStartFailed(
                "Could not find LanguageTool directory in archive"
            )
        }

        // Move to runtime directory
        if FileManager.default.fileExists(atPath: ltDir.path) {
            try FileManager.default.removeItem(at: ltDir)
        }
        try FileManager.default.moveItem(at: ltExtracted, to: ltDir)

        // Verify the JAR exists
        guard FileManager.default.fileExists(atPath: serverJar.path) else {
            throw DraftSmithError.languageToolStartFailed(
                "languagetool-server.jar not found after extraction"
            )
        }

        downloadProgress = 0.90
        currentDownloadDescription = "Grammar engine installed"

        // Cleanup temp files
        try? FileManager.default.removeItem(at: zipPath)
        try? FileManager.default.removeItem(at: extractDir)
    }

    // MARK: - WhisperKit Model Download

    private func downloadWhisperModel() async throws {
        // WhisperKit caches models in ~/Library/Caches/com.argmaxinc.whisperkit/
        let whisperCacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/com.argmaxinc.whisperkit")

        // Check if a model is already cached
        if FileManager.default.fileExists(atPath: whisperCacheDir.path) {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: whisperCacheDir.path)) ?? []
            if !contents.isEmpty {
                downloadProgress = 1.0
                currentDownloadDescription = "Speech recognition model already installed"
                return
            }
        }

        currentDownloadDescription = "Downloading speech recognition model..."

        // Creating a WhisperKit instance triggers model download and caching
        let config = WhisperKitConfig(model: "base.en")
        _ = try await WhisperKit(config)

        downloadProgress = 1.0
        currentDownloadDescription = "Speech recognition model installed"
    }

    // MARK: - Process Helper

    private func runProcess(_ executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: DraftSmithError.languageToolStartFailed(
                        "Process \(executable) failed (exit code \(process.terminationStatus))"
                    ))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

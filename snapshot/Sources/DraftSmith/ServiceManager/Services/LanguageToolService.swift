import Foundation

actor LanguageToolService: ManagedServiceProtocol {
    let kind: ServiceKind = .languageTool
    private(set) var state: ServiceState = .idle

    private var process: Process?
    private let client: LanguageToolClient
    private var healthCheckRetryCount = 0
    private let maxRetries = AppConstants.maxHealthCheckRetries

    init(client: LanguageToolClient = LanguageToolClient()) {
        self.client = client
    }

    func start() async throws {
        state = .loading(progress: 0)

        // Look for LanguageTool server JAR in Runtime directory
        let runtimeDir = AppDirectories.runtime
        let serverJar = runtimeDir.appendingPathComponent("LanguageTool/languagetool-server.jar")

        guard FileManager.default.fileExists(atPath: serverJar.path) else {
            state = .error("Not installed – place LanguageTool in \(runtimeDir.path)/LanguageTool/")
            throw DraftSmithError.languageToolStartFailed("Server JAR not found. Download LanguageTool from languagetool.org and place languagetool-server.jar in \(runtimeDir.path)/LanguageTool/")
        }

        // Find bundled JRE or system Java
        let javaPath = findJavaExecutable()
        guard let javaPath = javaPath else {
            state = .error("Java runtime not found")
            throw DraftSmithError.languageToolStartFailed("No Java runtime found")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: javaPath)
        process.arguments = [
            "-cp", serverJar.path,
            "org.languagetool.server.HTTPServer",
            "--port", "8081",
            "--allow-origin", "*"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
        } catch {
            state = .error("Failed to start process")
            throw DraftSmithError.languageToolStartFailed(error.localizedDescription)
        }

        state = .loading(progress: 0.3)

        // Poll until the server is responsive
        var attempts = 0
        let maxAttempts = 30
        while attempts < maxAttempts {
            try await Task.sleep(for: .seconds(1))
            if await client.isAvailable() {
                state = .ready
                healthCheckRetryCount = 0
                return
            }
            attempts += 1
            state = .loading(progress: Double(attempts) / Double(maxAttempts))
        }

        state = .error("Server failed to start within timeout")
        throw DraftSmithError.languageToolStartFailed("Server did not become responsive within \(maxAttempts) seconds")
    }

    func stop() async {
        state = .unloading
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        state = .idle
    }

    func healthCheck() async -> Bool {
        let available = await client.isAvailable()
        if !available {
            healthCheckRetryCount += 1
            if healthCheckRetryCount >= maxRetries {
                state = .error("Health check failed after \(maxRetries) retries")
            }
        } else {
            healthCheckRetryCount = 0
            if !state.isReady {
                state = .ready
            }
        }
        return available
    }

    func check(
        text: String,
        enabledRules: [String] = [],
        disabledRules: [String] = [],
        enabledCategories: [String] = [],
        disabledCategories: [String] = [],
        level: String = "default"
    ) async throws -> LanguageToolResponse {
        guard state.isReady else {
            throw DraftSmithError.languageToolNotRunning
        }
        return try await client.check(
            text: text,
            enabledRules: enabledRules,
            disabledRules: disabledRules,
            enabledCategories: enabledCategories,
            disabledCategories: disabledCategories,
            level: level
        )
    }

    // MARK: - Private

    private func findJavaExecutable() -> String? {
        // Check bundled JRE first
        let bundledJRE = AppDirectories.runtime
            .appendingPathComponent("jre/bin/java")
        if FileManager.default.fileExists(atPath: bundledJRE.path) {
            return bundledJRE.path
        }

        // Check JAVA_HOME
        if let javaHome = ProcessInfo.processInfo.environment["JAVA_HOME"] {
            let javaPath = "\(javaHome)/bin/java"
            if FileManager.default.fileExists(atPath: javaPath) {
                return javaPath
            }
        }

        // Check common macOS paths (including Homebrew keg-only location)
        let commonPaths = [
            "/opt/homebrew/opt/openjdk/bin/java",
            "/opt/homebrew/bin/java",
            "/usr/bin/java",
            "/usr/local/bin/java"
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}

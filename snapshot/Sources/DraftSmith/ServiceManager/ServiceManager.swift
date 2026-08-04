import AppKit
import Foundation

@Observable
@MainActor
final class ServiceManager {
    private(set) var serviceStates: [ServiceKind: ServiceState] = [
        .languageTool: .idle,
        .llm: .idle,
        .whisper: .idle
    ]

    let languageToolService: LanguageToolService
    let llmService: LLMService
    let transcriptionService: TranscriptionService
    let fastPathService: NLFastPathService
    let capabilities: SystemCapabilities

    private var healthCheckTask: Task<Void, Never>?
    private var shutdownObserver: Any?

    init(
        languageToolService: LanguageToolService = LanguageToolService(),
        llmService: LLMService = LLMService(),
        transcriptionService: TranscriptionService = TranscriptionService(),
        capabilities: SystemCapabilities = .current
    ) {
        self.languageToolService = languageToolService
        self.llmService = llmService
        self.transcriptionService = transcriptionService
        self.fastPathService = NLFastPathService()
        self.capabilities = capabilities
    }

    func startBackgroundServices() {
        // Start LanguageTool in background on launch
        Task {
            await startService(.languageTool)
        }

        // Pre-load LLM so it's ready when first needed
        Task {
            await startService(.llm)
        }

        // Pre-load Whisper so voice features are ready immediately
        // (skip on low-RAM machines where it would conflict with the LLM)
        if !capabilities.isLowRAM {
            Task {
                await startService(.whisper)
            }
        }

        // Start health check timer
        startHealthChecks()

        // Register for shutdown
        shutdownObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.shutdownAll()
            }
        }
    }

    func ensureReady(_ kind: ServiceKind) async {
        let currentState = serviceStates[kind] ?? .idle

        guard !currentState.isReady else { return }

        // Low-RAM mutual exclusion
        if capabilities.isLowRAM {
            switch kind {
            case .llm:
                if serviceStates[.whisper]?.isReady == true {
                    await stopService(.whisper)
                }
            case .whisper:
                if serviceStates[.llm]?.isReady == true {
                    await stopService(.llm)
                }
            case .languageTool:
                break
            }
        }

        await startService(kind)
    }

    func serviceState(for kind: ServiceKind) -> ServiceState {
        serviceStates[kind] ?? .idle
    }

    // MARK: - Private

    private func startService(_ kind: ServiceKind) async {
        serviceStates[kind] = .loading(progress: 0)

        do {
            switch kind {
            case .languageTool:
                try await languageToolService.start()
                serviceStates[kind] = await languageToolService.state
            case .llm:
                try await llmService.start()
                serviceStates[kind] = await llmService.state
            case .whisper:
                try await transcriptionService.start()
                serviceStates[kind] = await transcriptionService.state
            }
        } catch {
            serviceStates[kind] = .error(error.localizedDescription)
        }
    }

    private func stopService(_ kind: ServiceKind) async {
        serviceStates[kind] = .unloading
        switch kind {
        case .languageTool:
            await languageToolService.stop()
        case .llm:
            await llmService.stop()
        case .whisper:
            await transcriptionService.stop()
        }
        serviceStates[kind] = .idle
    }

    private func startHealthChecks() {
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(AppConstants.healthCheckInterval))
                guard let self = self else { break }
                // Only health-check LanguageTool (the always-running service)
                if self.serviceStates[.languageTool]?.isReady == true {
                    let healthy = await self.languageToolService.healthCheck()
                    if !healthy {
                        self.serviceStates[.languageTool] = await self.languageToolService.state
                        // Auto-restart
                        await self.startService(.languageTool)
                    }
                }
            }
        }
    }

    private func shutdownAll() async {
        healthCheckTask?.cancel()
        healthCheckTask = nil

        await languageToolService.stop()
        await llmService.stop()
        await transcriptionService.stop()

        serviceStates = [
            .languageTool: .idle,
            .llm: .idle,
            .whisper: .idle
        ]
    }
}

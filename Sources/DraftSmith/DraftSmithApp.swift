import SwiftUI
import SwiftData
import AppKit

@main
struct DraftSmithApp: App {
    // SPM executables need explicit GUI activation on macOS
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer

    @State private var serviceManager: ServiceManager
    @State private var documentManager: PDFDocumentManager
    @State private var progressTracker: ReviewProgressTracker
    @State private var modelDownloadManager: ModelDownloadManager

    // These are initialized after modelContainer is available
    @State private var issueManager: IssueManager
    @State private var profileManager: ProjectProfileManager
    @State private var promptManager: PromptManagerService
    @State private var styleMemoryManager: StyleMemoryManager
    @State private var checkEngine: CheckEngine
    @State private var rewriteEngine: RewriteEngine
    @State private var doubleCheckPipeline: DoubleCheckPipeline
    @State private var emailStudioService: EmailStudioService
    @State private var voiceNotePipeline: VoiceNotePipeline

    @State private var showFirstLaunch = false

    init() {
        // Configure SwiftData
        let schema = Schema([
            Issue.self,
            ProjectProfile.self,
            ReviewSession.self,
            ExamplePair.self,
            FeedbackEvent.self,
            StyleCapsule.self,
            PromptTemplate.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        self.modelContainer = container

        // Create all app directories
        AppDirectories.createAllDirectories()

        // Initialize services
        let sm = ServiceManager()
        let dm = PDFDocumentManager()
        let pt = ReviewProgressTracker()
        let mdm = ModelDownloadManager()

        let context = container.mainContext
        let im = IssueManager(modelContext: context)
        let pm = ProjectProfileManager(modelContext: context)
        let pms = PromptManagerService(modelContext: context)
        let smm = StyleMemoryManager(modelContext: context)

        let ltClient = LanguageToolClient()
        let dcp = DoubleCheckPipeline(languageToolClient: ltClient)

        let ce = CheckEngine(serviceManager: sm, issueManager: im, profileManager: pm)
        let re = RewriteEngine(
            serviceManager: sm,
            promptManager: pms,
            styleMemoryManager: smm,
            doubleCheckPipeline: dcp
        )

        let ess = EmailStudioService(
            serviceManager: sm,
            promptManager: pms,
            styleMemoryManager: smm,
            doubleCheckPipeline: dcp
        )

        let recorder = AudioRecorder()
        let vnp = VoiceNotePipeline(
            audioRecorder: recorder,
            serviceManager: sm,
            rewriteEngine: re
        )

        _serviceManager = State(initialValue: sm)
        _documentManager = State(initialValue: dm)
        _progressTracker = State(initialValue: pt)
        _modelDownloadManager = State(initialValue: mdm)
        _issueManager = State(initialValue: im)
        _profileManager = State(initialValue: pm)
        _promptManager = State(initialValue: pms)
        _styleMemoryManager = State(initialValue: smm)
        _checkEngine = State(initialValue: ce)
        _rewriteEngine = State(initialValue: re)
        _doubleCheckPipeline = State(initialValue: dcp)
        _emailStudioService = State(initialValue: ess)
        _voiceNotePipeline = State(initialValue: vnp)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(serviceManager)
                .environment(documentManager)
                .environment(progressTracker)
                .environment(modelDownloadManager)
                .environment(issueManager)
                .environment(profileManager)
                .environment(promptManager)
                .environment(styleMemoryManager)
                .environment(checkEngine)
                .environment(rewriteEngine)
                .environment(emailStudioService)
                .environment(voiceNotePipeline)
                .sheet(isPresented: $showFirstLaunch) {
                    ModelDownloadView {
                        showFirstLaunch = false
                    }
                    .environment(modelDownloadManager)
                }
                .onAppear {
                    // Seed default templates
                    promptManager.seedDefaults()

                    // Ensure default project profile
                    profileManager.ensureDefaultProfile()

                    // Start background services
                    serviceManager.startBackgroundServices()

                    // Check first launch
                    if modelDownloadManager.needsInitialSetup {
                        showFirstLaunch = true
                    }
                }
        }
        .modelContainer(modelContainer)
        .commands {
            DraftSmithCommands()
        }

        Settings {
            SettingsView()
                .environment(profileManager)
                .environment(styleMemoryManager)
                .environment(promptManager)
                .environment(serviceManager)
                .environment(modelDownloadManager)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct DraftSmithCommands: Commands {
    @FocusedValue(\.documentManager) var documentManager

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open PDF...") {
                NotificationCenter.default.post(name: .openPDFRequested, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)

            Menu("Open Recent") {
                let recents = RecentDocumentsManager.shared.recentURLs
                if recents.isEmpty {
                    Text("No Recent Documents")
                } else {
                    ForEach(recents, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            NotificationCenter.default.post(
                                name: .openRecentRequested,
                                object: nil,
                                userInfo: ["url": url]
                            )
                        }
                    }
                    Divider()
                    Button("Clear Recent") {
                        RecentDocumentsManager.shared.clearRecent()
                    }
                }
            }
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                try? documentManager?.save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(documentManager?.document == nil)

            Button("Save As...") {
                NotificationCenter.default.post(name: .saveAsRequested, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(documentManager?.document == nil)
        }

        CommandMenu("Check") {
            Button("Check Selection") {}
                .keyboardShortcut(KeyboardShortcuts.checkSelection)
            Divider()
            Button("Next Issue") {}
                .keyboardShortcut(KeyboardShortcuts.nextIssue)
            Button("Previous Issue") {}
                .keyboardShortcut(KeyboardShortcuts.previousIssue)
            Divider()
            Button("Toggle Issue Bar") {}
                .keyboardShortcut(KeyboardShortcuts.toggleBottomBar)
        }

        CommandMenu("Voice") {
            Button("Record Voice Note") {}
                .keyboardShortcut(KeyboardShortcuts.recordVoiceNote)
        }

        CommandMenu("Rewrite") {
            Button("Regenerate Variants") {}
                .keyboardShortcut(KeyboardShortcuts.regenerateVariants)
            Divider()
            Button("Soften") {}
                .keyboardShortcut(KeyboardShortcuts.soften)
            Button("Make More Direct") {}
                .keyboardShortcut(KeyboardShortcuts.makeMoreDirect)
        }
    }
}

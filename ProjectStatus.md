# DraftSmith — Project Status

**Last updated:** 2026-02-09

---

## Executive Summary

DraftSmith is a macOS-only, offline-after-initial-setup PDF proofreading workspace for professional editors. It reads PDFs via PDFKit, runs grammar/style checking via a local LanguageTool server, transcribes voice notes via WhisperKit, and uses a local LLM (MLX Swift) for diplomatic comment generation, rewrites, and email drafting. It produces Acrobat-compatible PDF annotations (highlights + popup comments). No text ever leaves the machine.

**Current state:** All 8 implementation phases are code-complete. The app builds successfully (`swift build`), and all 208 tests pass (4 skipped due to PDFKit synthetic PDF limitations). Real-world testing of the proofreading workflow has begun, and several rounds of UX refinements have been implemented based on that testing.

---

## Build & Test

```bash
cd /Users/aidan/Dev/DraftSmith
swift build 2>&1    # Build (passes)
swift test 2>&1     # 208 tests pass, 4 skipped
```

**Important:** If `.build` is cleaned, you must:
1. `swift package resolve`
2. Patch `.build/checkouts/mlx-swift-lm/Libraries/MLXLMCommon/Adapters/LoRA/LoRAContainer.swift` line 90: change `eval(parameters)` to `eval(copy parameters)` (upstream `consuming` parameter bug)
3. Then `swift build`

---

## Codebase Metrics

| Metric | Count |
|--------|-------|
| Source files | 108 |
| Test files | 24 |
| Total tests | 208 (4 skipped) |
| Modules | 8 (PDFWorkspace, ServiceManager, CheckEngine, LocalStore, PromptManager, RewriteEngine, VoiceNotes, EmailStudio) |

---

## Implementation Phases — Status

All phases correspond to milestones in the Technical Brief (Sections 1-15).

### Phase 0 — Project Scaffolding ✅ Complete

- `Package.swift` with SPM dependencies (WhisperKit, mlx-swift-lm)
- `DraftSmithApp.swift` entry point with SwiftData ModelContainer
- `ContentView.swift` root layout
- Core utilities: `AppConstants`, `AppDirectories`, `Errors`, `KeyboardShortcuts`
- Test helpers: `PDFFixtures`, `MockServices`

### Phase 1 (M1) — PDF Annotations Round-Trip ✅ Complete

- PDFKit viewer with selection, thumbnails, zoom, search
- Annotation creation with `ds_uuid` metadata
- `DSAnnotation` value type (never stores `PDFAnnotation` references directly)
- `PDFAnnotationService` — `@MainActor`-isolated (PDFAnnotation is not Sendable)
- `PDFDocumentManager` — open, save, save-as, page navigation
- `TextExtractionService` with confidence heuristic
- Comment sidebar and editor views
- **Tests:** `AnnotationServiceTests`, `TextExtractionServiceTests`, `PDFDocumentManagerTests`

### Phase 2 (M2) — Service Manager + Graceful Degradation ✅ Complete

- `ServiceManager` with lazy loading (PDF loads instantly; LT in background; LLM/Whisper on demand)
- `LanguageToolService` — manages JRE child process, HTTP client, health checks
- `LLMService` — MLX Swift LM with model recommendation by RAM
- `TranscriptionService` — WhisperKit wrapper
- `NLFastPathService` — NSSpellChecker fast-path while LT boots
- Low-RAM mutual exclusion (Whisper unloaded before LLM on ≤8GB machines)
- `ModelDownloadManager` — first-launch setup downloading LLM, JRE, LanguageTool
- Status bar and download progress views
- Mock services for testing
- **Tests:** `ServiceManagerTests`, `LanguageToolClientTests`, `SystemCapabilitiesTests`

### Phase 3 (M3) — Issue Queue + Project Profiles + Progress Tracking ✅ Complete

- SwiftData models: `Issue`, `IssueStatus`, `IssueSeverity`, `ProjectProfile`, `ReviewSession`, `TerminologyEntry`
- `IssueManager` — SwiftData-backed CRUD with filtering
- `ProjectProfileManager` — profile CRUD, rule config, custom dictionaries
- `ReviewProgressTracker` — page visit tracking, issue counts
- Issue queue and detail views
- Project profile editor
- **Tests:** `IssueManagerTests`, `ProjectProfileTests`

### Phase 4 (M4) — LanguageTool Selection Check ✅ Complete

- `CheckEngine` — orchestrates LT checks with fast-path fallback and queuing
- `LanguageToolMatchConverter` — converts LT matches to Issues with dictionary filtering
- `WordDiffEngine` — LCS-based word-level diff
- Visual diff, issue card, verify-text, and check-selection button views
- **Tests:** `CheckEngineTests`, `LanguageToolMatchConverterTests`, `WordDiffEngineTests`

### Phase 5 (M5) — LLM Rewrite/Diplomacy + Double-Check Loop ✅ Complete

- **Prompt Manager:** Templates, token budget, assembler, default templates
- **Rewrite Engine:** Comment variant generation, rewrite variants, LLM response parsing
- **Double-Check:** LanguageTool validation of LLM output (auto-correct spelling, flag/regenerate for style)
- **Style Memory:** Example pairs, feedback events, capsule generation with human-in-the-loop approval
- Preference axes (4 dimensions), variant cards, rewrite panel, capsule approval views
- **Tests:** `PromptAssemblerTests`, `TokenCounterTests`, `LLMResponseParserTests`, `DoubleCheckServiceTests`, `FeedbackAnalyzerTests`, `StyleMemoryManagerTests`, `CapsuleGeneratorTests`

### Phase 6 (M6) — Voice Note Loop ✅ Complete

- Audio recording via AVFoundation (16kHz WAV mono)
- WhisperKit transcription pipeline
- Transcript editor with confirm/re-record
- `VoiceNotePipeline` state machine (idle → recording → transcribing → editing → generating → complete)
- Voice note panel and recording views
- **Tests:** `VoiceNotePipelineTests`, `TranscriptStoreTests`

### Phase 7 (M7) — Email Studio ✅ Complete

- Email draft generation with context pull from review session
- Clipboard service for copy/paste
- Email studio views with draft cards and issue context picker
- **Tests:** `EmailStudioServiceTests`, `ClipboardServiceTests`

### Phase 8 — Final Integration + Polish ✅ Complete (with ongoing refinements)

- Main window layout with all panels integrated
- Settings view
- Menu bar commands (File, Check, etc.)
- Keyboard shortcuts wired
- `AppDelegate` for GUI activation on SPM executables

---

## Recent UX Refinements (Post-Phase-8)

After completing all 8 phases and beginning real-world testing with actual PDF proofreading, several rounds of UX improvements were identified and implemented:

### Round 1: Core UX Improvements (Plan: `dazzling-bouncing-newt.md`)

#### 1. Comment/Suggestion Truncation Fix
- **Problem:** `.lineLimit(3)` on comments and suggestions truncated long text in the sidebar
- **Fix:** Removed `.lineLimit(3)` from both `CommentRowView` and `SuggestionRow` in `CommentSidebarView.swift`

#### 2. Show Category Instead of Rule ID
- **Problem:** Raw LanguageTool rule IDs (e.g. `MORFOLOGIK_RULE_EN_GB`) were displayed to users
- **Fix:** Replaced "Rule" section with "Issue Type" showing only the human-readable category (e.g. "Typos") in `IssueDetailView.swift`

#### 3. Three Comment Options Per Issue Suggestion
- **Problem:** Each suggestion had a single "Add as Comment" button that added the raw replacement word
- **Fix:** Added three options per suggestion:
  - **Quick** (bolt icon) — Structured comment: `"{category}: {suggestion}"`
  - **Natural** (sparkles icon) — LLM-generated natural-language margin comment
  - **Edit** (pencil icon) — LLM-generated, then opened in editor for user modification before adding
- **New method:** `generateIssueComment()` added to `RewriteEngineProtocol` and `RewriteEngine`
- **New view component:** `SuggestionOptionRow` in `IssueDetailView.swift`

#### 4. Auto-Resolve + Auto-Advance
- **Problem:** Adding a comment from an issue didn't resolve the issue or advance to the next one
- **Fix:** Added `advanceToNextUnresolved()` helper in `ContentView.swift`; all resolve/dismiss/add-comment callbacks now delete the issue and advance

#### 5. Save & Save As Menu Commands
- **Problem:** No Save/Save As in the File menu
- **Fix:**
  - Added `FocusedValueKey` for `PDFDocumentManager` (published via `.focusedSceneValue`)
  - Added `CommandGroup(replacing: .saveItem)` to `DraftSmithApp.swift` with Cmd+S (Save) and Cmd+Shift+S (Save As)
  - Save As uses `NSSavePanel` triggered via `Notification.Name.saveAsRequested`

#### 6. Autosave for PDF Annotations
- **Problem:** Issues auto-persist via SwiftData, but PDF annotations required explicit save
- **Fix:** Added autosave infrastructure to `PDFDocumentManager.swift`:
  - 60-second debounce timer on `markModified()`
  - Save on `NSApplication.willResignActiveNotification` (app loses focus)
  - Timer cancelled on explicit save/saveAs

### Round 2: Bug Fixes from Testing

#### 7. Dismiss Not Removing Issues
- **Problem:** `dismissIssue()` only changed status to `.dismissed`, keeping it in the list
- **Fix:** Changed all dismiss/resolve callbacks to use `deleteIssue()` instead

#### 8. LLM `<think>` Tags Leaking into Comments
- **Problem:** Qwen3 model outputs chain-of-thought reasoning in `<think>...</think>` tags that appeared in generated comments
- **Fix:** Added `stripThinkingTags(from:)` method to `RewriteEngine` that removes `<think>` blocks from LLM output

#### 9. Natural Comments Showing Placeholder/Quick Version
- **Problem:** Natural comment generation wasn't replacing the placeholder — root cause was `createAnnotation` requiring `currentSelection` which is nil when working from the issue queue
- **Fix:**
  - Added `createAnnotationForIssue(comment:source:pageIndex:selectionText:)` to `PDFDocumentManager` — searches for flagged text on the page using `document.findString()` instead of requiring a selection
  - Natural comment flow: creates placeholder annotation immediately, then updates asynchronously when LLM finishes
  - Improved prompt: no greetings/salutations, uses style capsule, writes as professional margin notes

#### 10. Improved Prompt Quality for Issue Comments
- **Problem:** Natural comments started with "Hi there" and read like messages, not editorial margin notes
- **Fix:** Updated `generateIssueComment` prompt to include:
  - `"Do not start with 'Hi', 'Hello', or any salutation"`
  - `"Write as a brief professional margin note, not a message"`
  - Style capsule integration for consistent tone

### Round 3: SourceKit & Duplicate Issues

#### 11. ContentView Body Too Complex for SourceKit
- **Problem:** SourceKit couldn't type-check `ContentView.body` in real-time, causing IDE errors
- **Fix:** Major refactor — extracted components into:
  - `SheetModifiers: ViewModifier` for all sheet presentations
  - `mainToolbar` (`@ToolbarContentBuilder`) for toolbar items
  - `mainLayout`, `issuePanel`, `issueDetail(for:)`, `centerPanel`, `commentPanel` computed properties

#### 12. Duplicate Issues Accumulating in SwiftData
- **Problem:** Running "Check Document" multiple times accumulated duplicate issues. Analysis of 366 stored issues showed only 179 unique (page, message) pairs — 187 were duplicates from previous runs
- **Root cause:** `checkDocument` called `clearNewIssues(for:)` which only deleted `.new` status issues; previously resolved/dismissed issues persisted, and each new check run added fresh duplicates
- **Fix:**
  - Added `clearAllIssues(for:)` to `IssueManager` — deletes ALL issues for a document regardless of status
  - Changed `checkDocument` to use `clearAllIssues` instead of `clearNewIssues`

#### 13. IssueQueueView Default Filter
- **Problem:** Default "All" filter showed resolved/dismissed issues alongside new ones
- **Fix:** Changed default filter to `.new` so only actionable issues show by default

---

## Files Modified in UX Refinement Sessions

| File | Changes |
|------|---------|
| `CommentSidebarView.swift` | Removed `.lineLimit(3)` from comments and suggestions |
| `IssueDetailView.swift` | Category instead of rule ID; three-button suggestions (Quick/Natural/Edit); `SuggestionOptionRow` |
| `IssueQueueView.swift` | Default filter changed to `.new` |
| `RewriteEngineProtocol.swift` | Added `generateIssueComment` method signature |
| `RewriteEngine.swift` | Implemented `generateIssueComment` with style capsule, `stripThinkingTags()`, improved prompt |
| `ContentView.swift` | Major refactor: extracted sheets/toolbar/panels; auto-advance; natural comment placeholder flow; `focusedSceneValue`; Save As via `NSSavePanel`; debug logging |
| `PDFDocumentManager.swift` | `FocusedValueKey`; `Notification.Name.saveAsRequested`; autosave timer + deactivation observer; `createAnnotationForIssue` (selection-free annotation creation) |
| `DraftSmithApp.swift` | Save/Save As menu commands via `CommandGroup(replacing: .saveItem)` |
| `CheckEngine.swift` | Changed `clearNewIssues` to `clearAllIssues` to prevent duplicates |
| `IssueManager.swift` | Added `clearAllIssues(for:)` method |

---

## Known Issues & Workarounds

### Build Workarounds
- **mlx-swift-lm `consuming` parameter bug:** Must patch `.build/checkouts/mlx-swift-lm/.../LoRAContainer.swift` line 90 after cleaning `.build`
- **`nonisolated(unsafe)` warnings:** Timer and observer properties in `PDFDocumentManager` use `nonisolated(unsafe)` for `deinit` access; compiler warns "no effect" but this is needed for correctness

### Architecture Constraints
- **PDFAnnotation is not Sendable:** All PDFKit access is `@MainActor`-isolated
- **`#Predicate` macro crashes at runtime:** All SwiftData queries use in-memory filtering instead
- **Synthetic PDFs don't support `createHighlightWithComment`:** 4 tests use `XCTSkip`
- **SwiftData ModelContainer lifecycle:** `ModelContainer` must be retained; deallocation causes SIGTRAP on any subsequent fetch/insert

### Bugs Previously Fixed
- SwiftData init-time fetches in `StyleMemoryManager` and `ProjectProfileManager` caused crashes — deferred to `loadInitialState()` methods
- Range crash on empty strings in `FeedbackAnalyzer.computeEditDistance()` and `WordDiffEngine.longestCommonSubsequence()`
- `TranscriptStore` filename collisions within the same second — added `.withFractionalSeconds` and replaced colons

---

## Architecture Overview

### Technology Stack
- **Platform:** macOS 14+ (Sonoma), Swift 6 strict concurrency
- **UI:** SwiftUI + PDFKit (`NSViewRepresentable` bridge)
- **LLM:** MLX Swift LM (`ml-explore/mlx-swift-lm`) — Apple Silicon native
- **Transcription:** WhisperKit — CoreML, Apple Silicon native
- **Grammar:** LanguageTool via local HTTP (`en-GB` always)
- **Persistence:** SwiftData for structured data
- **Distribution:** Direct Download (not Mac App Store) — avoids JRE sandboxing issues

### Key Design Patterns
- **Protocol-based service abstractions** with real + mock implementations for testing
- **`@Observable @MainActor`** for view models/managers
- **Value types for cross-boundary data** (`DSAnnotation`, `AnnotationMetadata`, etc.)
- **Three-layer architecture:** PDF (truth + anchoring) → Rules (reliable detection) → LLM (rewriting + diplomacy)
- **Double-check loop:** All LLM output validated by LanguageTool before display

### First-Launch Setup (`ModelDownloadManager`)
Downloads three components sequentially (skips if already present):
1. **LLM model** (0-60%) — Qwen3 8B/4B/1.7B based on available RAM
2. **Java JRE** (60-72%) — Eclipse Temurin 21 from Adoptium API
3. **LanguageTool** (72-95%) — from languagetool.org
Marker file: `Runtime/.setup_complete`

---

## Project Structure

```
DraftSmith/
├── Package.swift
├── VisionStatement.md          # Product vision
├── TechnicalBrief.md           # Full technical specification (Sections 1-15)
├── Critique1-4.md              # Design review feedback (incorporated into spec)
├── ProjectStatus.md            # This file
├── Sources/DraftSmith/
│   ├── DraftSmithApp.swift     # @main entry, SwiftData container, menu commands
│   ├── ContentView.swift       # Root layout, wiring, sheet modifiers
│   ├── SettingsView.swift      # Preferences window
│   ├── Core/                   # Constants, directories, errors, shortcuts
│   ├── PDFWorkspace/           # PDF viewing, annotations, comments, progress
│   │   ├── Models/             #   DSAnnotation, AnnotationMetadata
│   │   ├── Services/           #   PDFDocumentManager, PDFAnnotationService, etc.
│   │   └── Views/              #   PDFKitView, CommentSidebar, etc.
│   ├── ServiceManager/         # Service lifecycle, health checks, downloads
│   │   ├── Models/             #   ServiceKind, ServiceState, SystemCapabilities
│   │   ├── Services/           #   LT, LLM, Whisper, FastPath, Downloads, Mocks
│   │   └── Views/              #   StatusBar, DownloadProgress
│   ├── CheckEngine/            # Grammar checking pipeline
│   │   ├── Models/             #   DiffSegment
│   │   ├── Services/           #   CheckEngine, IssueManager, MatchConverter, Diff
│   │   └── Views/              #   IssueQueue, IssueDetail, VisualDiff, etc.
│   ├── LocalStore/             # SwiftData models and profile management
│   │   ├── Models/             #   Issue, ProjectProfile, ReviewSession, etc.
│   │   ├── Services/           #   ProjectProfileManager
│   │   └── Views/              #   ProfileEditor
│   ├── PromptManager/          # LLM prompt templates and assembly
│   │   ├── Models/             #   PromptTask, Template, Axes, TokenBudget
│   │   ├── Services/           #   Assembler, TokenCounter, Manager
│   │   └── Views/              #   PromptInspector
│   ├── RewriteEngine/          # LLM generation, style memory, double-check
│   │   ├── Models/             #   CommentVariant, RewriteVariant, etc.
│   │   ├── Services/           #   RewriteEngine, DoubleCheck, StyleMemory, etc.
│   │   └── Views/              #   VariantCards, RewritePanel, CapsuleApproval
│   ├── VoiceNotes/             # Audio recording + transcription pipeline
│   │   ├── Models/             #   AudioRecording, TranscriptionResult
│   │   ├── Services/           #   AudioRecorder, TranscriptStore, Pipeline
│   │   └── Views/              #   Recording, Transcript, Panel
│   └── EmailStudio/            # Email drafting with context pull
│       ├── Models/             #   EmailDraft, Request, Response
│       ├── Services/           #   EmailStudioService, ClipboardService
│       └── Views/              #   Studio, DraftCards, ContextPicker
└── Tests/DraftSmithTests/
    ├── TestHelpers/            # PDFFixtures, MockServices
    ├── PDFWorkspace/           # 3 test files
    ├── ServiceManager/         # 3 test files
    ├── CheckEngine/            # 3 test files
    ├── LocalStore/             # 2 test files
    ├── PromptManager/          # 2 test files
    ├── RewriteEngine/          # 5 test files
    ├── VoiceNotes/             # 2 test files
    └── EmailStudio/            # 2 test files
```

---

## What Remains

### Immediate (Ready for Next Session)

- [ ] **Remove debug logging** — `refreshIssues()` in `ContentView.swift` has `[DEBUG]` print statements that should be removed before release
- [ ] **Verify natural comment replacement end-to-end** — The placeholder-then-update flow was implemented but needs real-world confirmation with the LLM running
- [ ] **Test Save/Save As menus** — Implemented but not yet verified in manual testing

### Short-Term (Polish for Usable Alpha)

- [ ] **Keyboard shortcuts audit** — Verify all shortcuts from `KeyboardShortcuts.swift` are wired and functional (Cmd+Shift+C for check selection, Ctrl+Space for voice, Cmd+R for regenerate, etc.)
- [ ] **Error handling UX** — When LanguageTool server fails to start, or LLM model isn't downloaded, ensure the user sees clear, actionable messages
- [ ] **Empty state polish** — First-time-open experience when no PDF is loaded
- [ ] **"Check Document" progress** — Currently shows a small spinner; could benefit from per-page progress indicator for large documents

### Medium-Term (Feature Completeness)

- [ ] **Double-check loop for natural comments** — The `generateIssueComment` path doesn't currently run LLM output through LanguageTool validation (unlike the variant generation path)
- [ ] **Preference axes integration** — The 4-axis sliders exist in the RewritePanel but aren't yet connected to the issue-comment generation flow
- [ ] **Style memory onboarding** — No guided flow for adding initial example pairs
- [ ] **Review progress persistence** — `ReviewSession` model exists but may not be fully wired to track pages across app relaunches
- [ ] **Export/reporting** — Vision mentions aggregate review reports ("47 issues found, 38 resolved"); not yet implemented

### Long-Term (v2 Features per Vision Statement)

- [ ] Guided review workflow (issue batching, "unvisited pages" nudges, proactive scanning)
- [ ] Full OCR fallback for extraction-challenged PDFs
- [ ] Batch document scanning
- [ ] Richer annotation types for structural editorial feedback
- [ ] Export/reporting for review completion
- [ ] Mac App Store distribution (JRE sandboxing challenges)

---

## Design Documents

| Document | Purpose |
|----------|---------|
| `VisionStatement.md` | High-level product vision and UX principles |
| `TechnicalBrief.md` | Full technical specification (15 sections, 7 milestones) |
| `Critique1.md` | First design review — identified missing async architecture, preference axes collapse, service lifecycle gaps |
| `Critique2.md` | Second review — identified Homebrew/developer dependency problem, PDF compatibility risks, style memory feedback loop |
| `Critique3.md` | Third review — flagged JRE bundling, 8GB RAM pressure, text extraction, style capsule model collapse risk |
| `Critique4.md` | Fourth review — offline installer, token budget, double-check loop design, preference axes in JSON contracts |
| `.claude/plans/quirky-sprouting-hamming.md` | Full implementation plan (all 8 phases with file lists and verification checklists) |
| `.claude/plans/dazzling-bouncing-newt.md` | UX refinement plan (6 steps: truncation, category, comments, auto-advance, save, autosave) |

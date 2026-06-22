# DraftSmith -- Ledger

> Offline macOS PDF proofreading workspace that turns voice notes and terse editorial comments into diplomatic, professional annotations using local AI.

## Status

**Phase:** Post-implementation polish and real-world testing
**Last updated:** 2026-04-04

All 8 implementation phases are code-complete. 211 tests pass (4 skipped). Six rounds of UX refinements have been completed based on real-world proofreading sessions. The app builds via `swift build` and is distributed as a direct download (not Mac App Store).

## Subsystems

| Subsystem | Status | Doc |
|-----------|--------|-----|
| PDF Workspace | Complete | [subsystems/PDF_WORKSPACE.md](subsystems/PDF_WORKSPACE.md) |
| Service Manager | Complete | [subsystems/SERVICE_MANAGER.md](subsystems/SERVICE_MANAGER.md) |
| Check Engine (LanguageTool) | Complete | [subsystems/CHECK_ENGINE.md](subsystems/CHECK_ENGINE.md) |
| Rewrite Engine (LLM) | Complete | [subsystems/REWRITE_ENGINE.md](subsystems/REWRITE_ENGINE.md) |
| Voice Notes (WhisperKit) | Complete | [subsystems/VOICE_NOTES.md](subsystems/VOICE_NOTES.md) |
| Email Studio | Complete | [subsystems/EMAIL_STUDIO.md](subsystems/EMAIL_STUDIO.md) |
| Prompt Manager | Complete | [subsystems/PROMPT_MANAGER.md](subsystems/PROMPT_MANAGER.md) |
| Local Store (SwiftData) | Complete | [subsystems/LOCAL_STORE.md](subsystems/LOCAL_STORE.md) |

## Technology Stack

- **Platform:** macOS 14+ (Sonoma), Swift 6 strict concurrency
- **UI:** SwiftUI + PDFKit (NSViewRepresentable bridge)
- **LLM:** MLX Swift LM (Apple Silicon native)
- **Transcription:** WhisperKit (CoreML, Apple Silicon native)
- **Grammar:** LanguageTool via local HTTP (en-GB always)
- **Persistence:** SwiftData
- **Distribution:** Direct Download (bundled JRE, no external installs)

## Key Decisions

See [decisions/LOG.md](decisions/LOG.md) for the full decision log.

Key architectural choices:
- Three-layer architecture: PDF (truth) -> Rules (detection) -> LLM (rewriting)
- All LLM output validated by LanguageTool before display (double-check loop)
- Comment-only -- never edits PDF body text
- Offline after initial setup -- no text ever leaves the machine
- Four independent preference axes (not a single tone slider)
- Style Capsule with human-in-the-loop approval to prevent drift

## Open Questions

- **LanguageTool HTTP errors** on certain pages (4 and 9 failed in latest run)
- **handleSelectIssue called multiple times per dismiss** -- SwiftUI re-rendering triggers redundant calls; needs debouncing
- **ForEach duplicate ID warning** -- DiffSegment IDs can collide (e.g. `i:M`)
- **Double-check loop missing for natural comments** -- `generateIssueComment` path skips LanguageTool validation
- **Preference axes not connected to issue-comment generation** -- 4-axis sliders exist but aren't wired to all flows
- **Style memory onboarding** -- no guided flow for adding initial example pairs
- **JRE bundling weight** -- ~100MB+; JNI bridge or partial Swift-native reimplementation under consideration

## Build Notes

```bash
cd /Users/aidan/Dev/DraftSmith
swift build    # 116 source files, 8 modules
swift test     # 211 tests, 4 skipped
```

**Post-clean rebuild requires:** `swift package resolve`, then patch mlx-swift-lm LoRAContainer.swift line 90 (`eval(parameters)` -> `eval(copy parameters)`).

## Repository

`github.com:aeobrien/DraftSmith.git`

## Linked Projects

| Project | Relationship | Notes |
|---------|-------------|-------|

## Notes

Existing design documents (pre-Ledger):
- `VisionStatement.md` -- Product vision, UX principles, scope boundaries
- `TechnicalBrief.md` -- Full 15-section technical specification with 7 milestones
- `ProjectStatus.md` -- Detailed implementation status with all UX refinement rounds
- `FutureIdeas.md` -- Deferred features (focus mode layout, screenshot attachments, inline popover enhancements)
- `Critique1-4.md` -- Four rounds of design review feedback (all incorporated into the spec)

The primary user is Emily, a professional copy editor who reviews PDFs for publishers.

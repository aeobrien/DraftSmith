# Roadmap

## Next Up

| Task | Milestone | Phase | Status | Effort |
|------|-----------|-------|--------|--------|
| 1.1.1 Remove debug logging | 1.1 Code Cleanup | 1: Polish for Alpha | Todo | Quick Win |
| 1.1.2 Fix handleSelectIssue redundant calls | 1.1 Code Cleanup | 1: Polish for Alpha | Todo | Deep Focus |
| 1.1.3 Fix ForEach duplicate ID warning | 1.1 Code Cleanup | 1: Polish for Alpha | Todo | Quick Win |
| 1.1.4 Fix LanguageTool HTTP errors on pages 4 and 9 | 1.1 Code Cleanup | 1: Polish for Alpha | Todo | Deep Focus |
| 1.2.1 Keyboard shortcuts audit | 1.2 UX Polish | 1: Polish for Alpha | Todo | Administrative |
| 2.1.1 Wire double-check loop for natural comments | 2.1 Pipeline Completeness | 2: Feature Completeness | Todo | Deep Focus |

---

## Phase 1: Polish for Alpha
**Status:** In Progress
**Definition of Done:** App is stable and pleasant for daily use by Emily -- no debug noise, no visual glitches, clear error messages, all shortcuts working.

### 1.1 -- Code Cleanup
**Status:** Todo
**Priority:** High
**Definition of Done:** No debug print statements, no SwiftUI warnings in console, no unexplained errors on document check.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.1.1 | Remove debug logging (`[PERF]`, `[REWRITE]`, `[LLM]`, `[VOICE]`, `[DICTATE]`, `[SIDEBAR]`, `[COMMENT]`, `[CHECK]`, `[DEBUG]`, `[HIGHLIGHT-DEBUG]`, `[SCROLL-DEBUG]`) | Done | Quick Win | Completed 2026-04-10. ~50 prints removed from 7 files + timing scaffolding. |
| 1.1.2 | Fix `handleSelectIssue` called multiple times per dismiss | Done | Deep Focus | Completed 2026-04-10. Guard on already-selected issue prevents redundant calls. |
| 1.1.3 | Fix ForEach duplicate ID warning (`DiffSegment` ID collision) | Done | Quick Win | Completed 2026-04-10. Removed non-unique computed id, switched to enumerated index. |
| 1.1.4 | Fix LanguageTool HTTP errors on pages 4 and 9 | Done | Deep Focus | Completed 2026-04-10. Text sanitization (control chars) + 15k-char chunking with sentence-boundary splitting. |
| 1.1.5 | Comment buttons visible for all issue types (not just those with suggestions) | Done | Quick Win | Moved Quick/Natural/Edit buttons outside suggestions conditional in 3 views |
| 1.1.6 | Fix auto-rewrite on quick comments — was rewriting without issue context | Done | Quick Win | Removed requestBackgroundSuggestion() from handleAddAsComment() |

### 1.2a -- Text Extraction
**Status:** Done
**Priority:** High
**Definition of Done:** PDF text extraction artifacts are normalized before reaching LanguageTool, significantly reducing false positives.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.2a.1 | PDF text normalizer — hyphen rejoining, soft hyphens, whitespace collapsing | Done | Deep Focus | PDFTextNormalizer.swift, wired into CheckEngine.swift |
| 1.2a.2 | Ligature normalization, page number removal, wrapped line rejoining, blank line collapsing | Done | Deep Focus | 4 additional passes, tested against 6 real PDFs |
| 1.2a.3 | AI pre-processing pass for remaining false positives (OCR errors, headers/footers) | Todo | Deep Focus | Batch process before Emily starts — can use cloud AI since offline prep |
| 1.2a.4 | Header/footer stripping — detect repeating lines across pages, remove before normalisation | Done | Deep Focus | detectRepeatingHeaders() in CheckEngine.swift, >30% threshold |
| 1.2a.5 | Cross-page sentence merging — merge pages ending mid-sentence into chunks | Done | Deep Focus | CheckChunk with PageSegment tracking for offset mapping |
| 1.2a.6 | Offset-based precise highlighting — store LanguageTool character offsets, match correct occurrence | Done | Deep Focus | Issue.textOffset/textLength, closest-match in 3 code paths (outline, underline, selection) |
| 1.2a.7 | Copilot export/import — batch JSON export for enterprise Copilot rewriting, import by ID | Done | Deep Focus | CopilotExportService.swift, toolbar buttons, rewrittenComment on Issue model |

### 1.2 -- UX Polish
**Status:** Todo
**Priority:** High
**Definition of Done:** First-time experience is clear, errors are actionable, keyboard shortcuts all work.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 1.2.1 | Keyboard shortcuts audit -- verify all shortcuts wired and functional | Todo | Administrative | Cmd+Shift+C, Ctrl+Space, Cmd+R, etc. |
| 1.2.2 | Error handling UX -- clear messages when LT server fails or LLM not downloaded | Todo | Deep Focus | |
| 1.2.3 | Empty state polish -- first-time-open experience with no PDF loaded | Todo | Creative | |
| 1.2.4 | "Check Document" progress -- per-page progress indicator for large documents | Todo | Deep Focus | Currently small spinner only |

---

## Phase 2: Feature Completeness
**Status:** Todo
**Definition of Done:** All v1 features from the Vision Statement and Technical Brief are fully wired and functional end-to-end.

### 2.1 -- Pipeline Completeness
**Status:** Todo
**Priority:** High
**Definition of Done:** All LLM output paths run through the double-check loop; preference axes affect all generation flows.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.1.1 | Wire double-check loop for `generateIssueComment` path | Todo | Deep Focus | Currently skips LanguageTool validation |
| 2.1.2 | Connect preference axes to issue-comment generation flow | Todo | Deep Focus | 4-axis sliders exist in RewritePanel but not wired to all paths |

### 2.2 -- Style Memory and Onboarding
**Status:** Todo
**Priority:** Normal
**Definition of Done:** Emily can add example pairs, feedback accumulates, Style Capsule generates and updates with approval.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.2.1 | Guided onboarding flow for adding initial example pairs | Todo | Creative | No UI exists yet |
| 2.2.2 | Review progress persistence across app relaunches | Todo | Deep Focus | ReviewSession model exists, may not be fully wired |

### 2.3 -- Reporting
**Status:** Todo
**Priority:** Normal
**Definition of Done:** User can see and export a summary of their review session.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 2.3.1 | Export/reporting -- aggregate review summary | Todo | Deep Focus | "47 issues found, 38 resolved" as exportable text |

---

## Phase 3: Future Ideas (v2)
**Status:** Todo
**Definition of Done:** Stretch goals from the Vision Statement for post-v1.

### 3.1 -- Guided Review Workflow
**Status:** Todo
**Priority:** Low
**Definition of Done:** App proactively surfaces issues, batches similar problems, nudges through unvisited pages.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.1.1 | Issue batching and "unvisited pages" nudges | Todo | Deep Focus | |
| 3.1.2 | Proactive scanning (full document scan on open) | Todo | Deep Focus | |

### 3.2 -- PDF Extraction Improvements
**Status:** Todo
**Priority:** Low
**Definition of Done:** App handles extraction-challenged PDFs gracefully.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.2.1 | Full OCR fallback for problematic PDFs | Todo | Deep Focus | Currently relies on PDFKit extraction + "Verify Text" field |
| 3.2.2 | Batch document scanning | Todo | Deep Focus | |

### 3.3 -- UI Enhancements
**Status:** Todo
**Priority:** Low
**Definition of Done:** Advanced UI features from FutureIdeas.md.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.3.1 | Focus mode layout (Option C) -- stacked vertical with indicator strip | Todo | Creative | See FutureIdeas.md |
| 3.3.2 | Screenshot attachment for problem log | Todo | Deep Focus | |
| 3.3.3 | Inline popover enhancements (hover preview, keyboard nav, animation) | Todo | Creative | |
| 3.3.4 | Richer annotation types for structural editorial feedback | Todo | Deep Focus | "Move this paragraph" style notes |

### 3.4 -- Distribution
**Status:** Todo
**Priority:** Low
**Definition of Done:** App available via Mac App Store.

| # | Task | Status | Effort | Notes |
|---|------|--------|--------|-------|
| 3.4.1 | Mac App Store distribution (JRE sandboxing challenges) | Todo | Deep Focus | Entitlement review needed |

---

## Completed Phases

### Phase 0: Implementation (M1-M7)
**Status:** Done

All 8 implementation phases from the Technical Brief are code-complete:

| Milestone | Description | Status |
|-----------|-------------|--------|
| M0 | Project scaffolding | Done |
| M1 | PDF annotations round-trip | Done |
| M2 | Service Manager + graceful degradation | Done |
| M3 | Issue queue + project profiles + progress tracking | Done |
| M4 | LanguageTool selection check | Done |
| M5 | LLM rewrite/diplomacy + double-check loop | Done |
| M6 | Voice note loop | Done |
| M7 | Email Studio | Done |
| M8 | Final integration + polish | Done |

### UX Refinements (6 Rounds)
**Status:** Done

All refinements from real-world testing have been implemented:
1. Comment truncation fix, category display, three comment options, auto-advance, Save/Save As, autosave
2. Dismiss bug fix, `<think>` tag stripping, natural comment flow fix, improved prompts
3. ContentView refactor for SourceKit, duplicate issue fix, default filter change
4. Performance optimisation (1200ms -> 4-16ms dismiss), LLM empty response fix, V-key voice fix
5. Red box fix, issue scroll centering rewrite, underline rendering fix
6. Toggleable issue overlay, API key Keychain storage

---

## Reference

### Status Values
| Status | Meaning |
|--------|---------|
| Todo | Not yet started |
| In Progress | Actively being worked on |
| Blocked: [reason] | Cannot proceed -- reason is one of: poorly-defined, too-large, missing-info, missing-resource, decision-required |
| Waiting | User's part done, waiting on external input |
| Done | Complete |
| Dropped | Deliberately abandoned |

### Effort Types
| Type | Description |
|------|-------------|
| Deep Focus | Sustained concentration, problem-solving, design work |
| Creative | Open-ended, generative, exploratory |
| Administrative | Organising, documenting, updating, filing |
| Communication | Discussions, reviews, feedback |
| Physical | Hands-on work, building, soldering |
| Quick Win | Small, low-effort, momentum-building |

### Priority
High / Normal / Low -- milestones only. Tasks inherit from their milestone unless overridden.

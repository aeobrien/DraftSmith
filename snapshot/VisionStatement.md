## Vision statement: **Draftsmith** (working name)

A macOS-only, offline-after-initial-setup proofreading workspace that feels like a fast, purpose-built Acrobat for publishing: it reads PDFs smoothly, anchors comments reliably, and uses local language tools to turn *detection* (grammar/style issues) and *judgement* (editorial notes, diplomatic phrasing, email drafting) into a low-friction "review → decide → annotate" loop.

It does **not** edit PDF body text. It produces **Acrobat-compatible annotations** (highlights + comments) that travel with the PDF.

---

## Core idea

**Split the problem into three layers, each optimised for what it's best at:**

1. **PDF layer (truth + anchoring):** selection, highlights, comment placement, export compatibility
2. **Rules layer (reliable detection):** deterministic grammar/style checking, consistent flags
3. **LLM layer (rewriting + diplomacy + tone):** suggestions, rephrasing, "gentler/directer/shorter", style mimicry

This avoids the "LLM tries to be Grammarly" trap, and keeps the UI snappy and predictable.

A key principle: **the LLM's output is always checked by the rules layer before reaching the user.** If the LLM generates US spellings in its suggestions, LanguageTool auto-corrects them silently. For style or grammar flags that could change meaning, the variant is either regenerated or the issue is flagged for the user — no silent meaning-altering edits. The user only ever sees clean output.

---

## Tool first, workflow later

v1 is a **tool** — a collection of capabilities (PDF viewing, grammar checking, voice notes, email drafting) that the user composes freely. But the architecture is designed so that later versions can evolve toward a **guided workflow**: surfacing issues proactively, tracking review progress, batching similar issues, and nudging the reviewer through unvisited pages.

The vision's "review → decide → annotate" loop describes the target workflow. v1 provides the building blocks; the guided orchestration comes later. Both documents should be read with this trajectory in mind.

---

## Non-negotiables

### Offline + NDA-safe by design

* **Offline after initial setup.** First launch downloads AI models (~4.5GB for LLM, ~75MB for transcription). After that, no network access is required. For users on restricted corporate networks, an offline installer path (pre-downloaded model bundle or USB transfer) must also be supported.
* No text leaves the machine — ever. Model downloads are the only network activity, and they contain no user data.
* All models/rules run locally.
* Any internal servers bind to localhost only (explicitly avoid accidental network exposure).

### Acrobat-compatible output

* Comments are standard PDF annotations (highlights, notes, popups).
* Output must open cleanly in Acrobat with comments intact — highlights must appear as proper text highlights (not generic shapes), with Unicode (curly quotes, em dashes) rendering correctly.
* Must behave correctly when the PDF already contains annotations.

### Invisible infrastructure

* The user is a professional editor, not a developer. They should never see a terminal, manage a server, or install a dependency manually.
* All local services (grammar engine, LLM, transcription) are bundled with or managed by the app. Startup, health-checking, and shutdown are automatic and invisible.
* If a service is unavailable, the app degrades gracefully — the PDF workspace always works; AI features show clear status indicators and resume automatically when ready.

### Minimise friction at every step

Everything should be keyboard-driven and "one action away":

* one shortcut to "check selection"
* one shortcut to "record note"
* one click to accept/swap tone/regenerate

---

## What the app must do

### A) PDF proofreading workspace

**1) Read PDFs beautifully**

* Fast open, smooth scroll, page thumbnails, zoom, search.
* A notes/comments sidebar that mirrors what users expect from Acrobat/Skim.

**2) Create and manage annotations**

* Highlight selected text and attach a comment popup.
* Jump between annotations; filter by type/status (e.g. "Needs action", "Resolved").
* Save incrementally so the PDF remains the "source of truth".
* Every annotation carries a unique UUID in its metadata, used to link to audio files, transcripts, and AI history. This survives file renames and moves.

**3) Selection accuracy and anchoring**

* Text selection must map to stable annotation anchors (not "approximate page coords only").
* **Known limitation (v1):** PDFKit's text extraction is unreliable on some publishing PDFs — ligatures, custom encodings, embedded fonts without proper ToUnicode maps can produce garbled selections. v1 accepts PDFKit's selection quality as-is. The user highlights what they can select; the app annotates exactly that selection.
* **Extraction fallback (v1):** When the app detects low-confidence text extraction (high rate of non-dictionary words), it displays a "Verify Text" field in the issue sidebar, allowing the user to manually correct the extracted text before the AI pipeline runs. Editors are accustomed to this workflow, and it's preferable to running AI checks on garbage. Full OCR fallback is deferred to v2.

**4) Review progress tracking**

* A persistent indicator showing review progress: pages visited, issues found, issues resolved/dismissed.
* Simple aggregate view: "47 issues found, 38 resolved, 9 dismissed" — enough for the user to know where they stand and to communicate completion status to colleagues.

---

### B) Grammar & style checking (Grammarly-ish, but local)

**1) Run grammar/style checks locally**

* A local rules engine flags issues and returns structured matches (offsets/messages/categories).
* This is the "open-source Grammarly" component.

**Preferred component:** **LanguageTool (local server mode)**

* Designed for grammar/style checking and can run locally with an HTTP API.
* **Caveat:** LanguageTool's UK English rules are less comprehensive than its US English ones. Expect some false negatives and false positives on legitimate UK constructions. The project profile system (below) and custom dictionary support should be used aggressively to compensate.

**2) Apply matches to the PDF UI**

* Issues appear as:

  * on-page highlight overlays
  * a sidebar list grouped by severity/category
* Clicking an issue focuses the exact location and shows:

  * explanation ("why this was flagged" — rule name + rationale)
  * suggested fix(es)
  * **visual diff** between the original passage and the suggested rewrite (inline, word-level)
  * actions: **Accept as comment**, **Dismiss**, **Mark resolved**

**3) "Style guide mode"**

* A switchable profile system (per project/publisher) that influences:

  * what rules are enabled/disabled
  * terminology preferences ("email" vs "e-mail", serial comma, UK spellings, etc.)
  * custom dictionary entries and custom rules
  * severity mapping ("warn" vs "informational")
* The app can ship with a few starter profiles and let the user tweak them.

---

### C) Voice note → diplomatic comment (core time-saver)

**1) The workflow**

* Highlight text → hotkey → talk.
* Audio is recorded and stored locally.
* Offline transcription runs immediately.
* The user sees:

  * transcript (editable)
  * 2–4 suggested "final comments" in different tones
  * optional suggested rewrite of the passage (if desired)

**Preferred component:** **whisper.cpp** for offline transcription (bundled via Swift wrapper, not an external install)

**2) Output handling**

* The chosen final comment is written back into the PDF as a standard comment attached to the highlight.
* The raw audio + transcript remain linked via the annotation's UUID (stored in the app's library as supporting material; optionally embedded as an attachment annotation later if needed).

---

### D) Rewrite + diplomacy engine (local LLM)

**What it's responsible for**

* Turning:

  * LanguageTool flags → clean rewrite options ("minimal fix", "smoother", "publisher-safe")
  * voice transcripts → tactful editorial comments
  * short email intents → full emails in the user's tone
* Always returns **strict structured output** (JSON) so the UI is reliable.
* **All LLM output is run through LanguageTool (en-GB) before being shown to the user.** Spelling errors (especially US→UK) are auto-corrected silently. Style or grammar flags that could change meaning are not auto-applied — the variant is regenerated or the issue is shown to the user.

**Local runtime**

* **Bundled within the app** via `llama.cpp` Swift bindings or Apple's MLX framework — no external install required.
* The app ships with or downloads a recommended default model on first launch (targeting ~8B parameters for machines with 16GB+ RAM).
* Minimum hardware requirements and model recommendations must be stated clearly at download/install time.

---

## Tone learning without "training on her writing"

Should include a **style memory system** consisting of:

### 1) Few-shot examples (lo-fi but powerful)

* User provides ~10–50 representative examples *in the style they're allowed to use*:

  * "Before (raw thought)" → "After (final comment)"
  * "Email intent bullets" → "Final email"
* The app uses these as *style anchors* in prompts.

### 2) Preference axes (multi-dimensional, not a single slider)

Four independent dimensions:

* **Direct ↔ Gentle**
* **Brief ↔ Thorough**
* **Formal ↔ Warm**
* **Suggest rewrite ↔ Comment only**

These combine to produce meaningfully different outputs. Collapsing them into a single "tone" slider loses the granularity that makes this system distinctive.

### 3) Feedback loop

Every time the user edits a suggestion, the app stores:

* the prompt + original suggestion + the final version
* a word-level diff and quantitative measures (e.g. length change ratio)
* a tagged summary of what changed ("shorter", "less apologetic", "remove hedging", "more specific")

That becomes a growing local dataset for better future prompting **without model training**.

### 4) Style Capsule

The system periodically generates a compact **Style Capsule** — a short natural-language summary of the user's editing tendencies, derived from their few-shot examples and accumulated feedback events. This capsule is included in every LLM prompt as a concise style directive.

Design constraints:

* Generated by the LLM itself (summarising patterns from examples + feedback)
* Regenerated when the feedback corpus changes meaningfully (not on every event)
* **Human-in-the-loop:** A new capsule is presented as a suggestion with a diff against the current one. The user must click "Apply" before it becomes active. This prevents "style drift" from a bad LLM summary compounding across all future prompts.
* **Reset button:** The user can always reset to the default (empty) capsule if the system gets confused.
* Cached and size-budgeted (must fit within a fixed token budget to avoid eating the context window)
* Visible to the user for inspection and manual editing

### 5) Optional "house style profiles"

* Per client/publisher: different tone + rules + vocabulary.
* This matters a lot in publishing.

---

## UX principles (how it should feel)

* **Keyboard first.** Everything important has a shortcut.
* **One pane for decisions.** The UI never makes the user hunt:

  * issue list
  * current issue detail
  * suggested actions
* **Regenerate is cheap.** One key to get 3 more variants (but still anchored to the same highlight).
* **Never blocks reading.** AI runs in the background with progress indicators and cancellation; the PDF remains responsive. This requires an async architecture with queuing throughout.
* **Trust through transparency.** Show "why this was flagged" (rule name + explanation) and "what changed" (visual word-level diff between original and suggestion).
* **Graceful degradation.** If a service is starting up, slow, or unavailable, the rest of the app works normally. Status is shown clearly; recovery is automatic.

---

## Scope boundaries

**In scope (v1):**

* PDF viewing + comment writing
* grammar/style flags as annotations
* voice notes → transcribed → diplomatic comments
* email drafting module (separate tab/space), using the same style memory — with the ability to pull context from the current review session (e.g. "Insert Issue Context" button to populate key facts from an issue card or selection)
* review progress tracking (pages visited, issues found/resolved/dismissed)
* visual diffs for rewrite suggestions

**In scope (v2 / future):**

* guided review workflow (issue batching, "unvisited pages" nudges, proactive scanning)
* export/reporting ("47 issues found, 38 resolved" as a summary document)
* full OCR fallback for extraction-challenged PDFs
* batch document scanning
* richer annotation types for structural editorial feedback (see note below)

**Out of scope (by design):**

* editing PDF body text
* cloud syncing / multi-user collaboration

**Acknowledged limitation:** Some editorial feedback is inherently structural — "move this paragraph before the introduction," "cut this section entirely," "swap the order of points 2 and 3." These don't map cleanly to highlight-and-comment. For v1, the comment text handles this adequately ("Consider moving this paragraph to precede the introduction"). A future version may need a dedicated annotation type or margin-note convention for structural notes.

---

## Default toolchain assumptions

* **PDFKit** for rendering + selection + annotations on macOS
* **LanguageTool (embedded, local)** for detection — bundled with a managed JRE or equivalent strategy to avoid requiring Java from the user
* **whisper.cpp** for offline transcription — bundled via Swift wrapper (e.g. `swift-whisper` / SPM), not an external install
* **llama.cpp Swift bindings or MLX** for local LLM rewriting/diplomacy — bundled, not requiring Ollama or Homebrew
* A local "style memory" store (SQLite/CoreData) for examples, feedback, style capsules, and prompt templates

---

## Prompt management

The app has at least four distinct LLM tasks, each requiring a well-crafted system prompt:

1. Diplomatic comment generation
2. Rewrite suggestion
3. Email drafting
4. Style Capsule generation

Each prompt incorporates: the style guide constraints, the current Style Capsule, relevant few-shot examples, and the active preference axis values. This constitutes a real prompt templating system.

Prompts should be:

* versioned internally (so updates don't silently change behaviour)
* inspectable by power users (read-only view in preferences, with the option to override in a future version)
* tested against representative inputs as part of development QA

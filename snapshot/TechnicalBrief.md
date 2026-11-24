## Draftsmith — Spec v1.0 (macOS, single-user, fully offline, comment-only)

### Product promise

A fast macOS PDF proofreading workspace that:

* renders "weird" publishing PDFs reliably
* adds **Acrobat-compatible annotations** (highlights + popup comments)
* runs **grammar/style detection locally** (LanguageTool)
* turns voice notes into **diplomatic editorial comments** locally (Whisper → local LLM)
* drafts emails in the user's style for **Outlook copy/paste**
* enforces **UK English only** as a hard rule
* **requires no developer tools, terminal commands, or manual server management from the user**
* is **offline after initial setup** — first launch downloads models; after that, no network access is required

---

# 1) App bundling strategy (no external installs)

The user installs a single `.app` bundle. All dependencies are embedded or managed automatically. The user never sees a terminal.

## 1.1 PDF layer (built-in)

* **PDFKit** (Apple, built into macOS) for:

  * rendering, selection, annotation creation, save back to PDF

Reference UX:

* **Skim** (open-source PDF reader/annotator for macOS) to copy interaction patterns (sidebar notes, nav, shortcuts).

## 1.2 Grammar & style detection (embedded)

* **LanguageTool** running as an embedded HTTP server on localhost.
* **Java dependency:** LanguageTool requires a JRE. The app bundles a headless JRE within its application support directory, managed entirely by the app. The user is never aware of it.
* **Distribution note:** If distributing via Direct Download (not Mac App Store), the bundled JRE must be included in the `hardened-runtime` notarization. If Mac App Store distribution is pursued later, the JRE-as-child-process approach will need entitlement review — App Store sandboxing restricts spawning child processes. Direct Download is the assumed v1 distribution path.
* **Alternative under investigation:** If bundling a JRE proves too heavy (adds ~100MB+), evaluate running LanguageTool's core rules via a JNI bridge or investigate partial Swift-native reimplementation for the most critical rules. This is a known open question.

## 1.3 Voice transcription (embedded)

* **whisper.cpp** compiled into the app via a Swift wrapper package (e.g. `swift-whisper` or `whisper.spm`).
* Model file (~75MB for `base.en`) bundled with the app or downloaded on first launch with a progress indicator.
* **ffmpeg** functionality: use a lightweight Swift audio conversion library (e.g. `AVFoundation`) instead of shelling out to ffmpeg. Avoid the external dependency.

## 1.4 Local LLM (embedded)

* **llama.cpp** via Swift bindings compiled into the app, or **MLX** (Apple's ML framework) for Apple Silicon–native inference.
* **No Ollama dependency.** The app manages model loading and inference directly.
* Default model downloaded on first launch with clear progress indication and size warning.

### Model selection and hardware requirements

* **Recommended default (16GB+):** A quantised ~8B parameter model (e.g. Llama 3.1 8B Q4_K_M, ~4.5GB).
* **Low-RAM mode (8GB machines):** Default to a highly quantised variant (e.g. Q3_K_S) or a smaller model family (e.g. 3B-class model such as Phi-3 Mini or equivalent). Quality will degrade but the machine remains usable.
* **Ideal hardware:** Apple Silicon, 32GB+ RAM for responsive inference alongside the PDF workspace.
* The app detects available RAM at launch and recommends an appropriate model size. The user can override but is warned about quality/performance trade-offs.

### Update channels

* **App binary** and **model/asset files** are updated independently. A 10MB code fix must never force a 4.5GB model re-download.
* Models are versioned separately and only re-downloaded when a new recommended model is available.

### Offline installer path

* For users on restricted corporate networks, provide an alternative: a downloadable model bundle (or USB-transferable folder) that can be placed in the app's `Runtime/` directory manually. The app detects pre-placed models and skips the download step.

---

# 2) Service Manager module

A dedicated internal module that uniformly manages all local services.

**Responsibilities:**

* **Lazy loading (not all-at-once):** The PDF workspace launches immediately (instant "fast" feel). Other services load on demand:
  * **LanguageTool JRE:** Starts in the background on app launch (takes several seconds). While booting, basic spellcheck is provided by Apple's `NLLanguageRecognizer` as a lightweight fast-path placeholder — not a replacement, just something to show while the full engine loads.
  * **Whisper model:** Loaded into RAM on first voice-note action, not at app launch.
  * **LLM model:** Loaded into RAM on first "Check," "Rewrite," or "Draft Email" action, not at app launch.
* **Low-RAM serial execution (8GB machines):** On machines with ≤8GB RAM, the Service Manager enforces mutual exclusion — Whisper is unloaded from RAM before the LLM is loaded, and vice versa. This prevents swap thrashing at the cost of a brief reload delay when switching between voice notes and rewrite features.
* **Health checks:** Periodic heartbeat to each service. If LanguageTool's HTTP server stops responding, attempt restart automatically.
* **Status indicators:** A persistent, unobtrusive status bar showing the state of each service (loading / ready / error). Visible but not alarming.
* **Graceful degradation:** If a service is unavailable:
  * PDF workspace always works (viewing, manual annotation, navigation).
  * Grammar checking shows "Grammar engine starting..." with a spinner; queued checks run automatically when ready.
  * Voice notes record audio but show "Transcription starting..." until Whisper is loaded.
  * LLM features show "Rewrite engine loading..." with queued requests.
* **Shutdown:** Clean termination of all child processes on app quit.

---

# 3) App architecture (SwiftUI + PDFKit)

## 3.1 Modules (shipping in v1)

1. **PDF Workspace**

   * PDF render + thumbnails + search
   * selection + annotation writing
   * comment sidebar + issue queue
   * review progress tracker (pages visited, issues found/resolved/dismissed)

2. **Check Engine**

   * extract "checkable text" from selection/chunks
   * call LanguageTool
   * manage issue lifecycle (New / Resolved / Dismissed)
   * aggregate issue counts for progress tracking

3. **Voice Notes**

   * record audio (push-to-talk)
   * whisper.cpp transcription (embedded)
   * transcript editor
   * LLM: transcript → diplomatic comment variants

4. **Rewrite Engine**

   * LLM: (passage + context + style) → variants (JSON)
   * preference axis controls (4 dimensions) + regenerate
   * style memory + examples + feedback loop
   * **Double-check loop:** all LLM output passed through LanguageTool (en-GB) silently before display

5. **Email Studio**

   * intent input (typed or voice)
   * **context pull:** "Insert Issue Context" button copies the relevant issue card or current PDF selection into the key facts field. (Full drag-and-drop of custom SwiftUI views is complex; v1 uses a button + `NSItemProvider` plain-text export. Drag-and-drop UX is a v2 polish item.)
   * LLM: intent + context → email variants (JSON)
   * copy-to-clipboard (plain text + optional rich text later)

6. **Service Manager**

   * lifecycle management for LanguageTool, LLM, Whisper
   * health checks, auto-restart, status indicators
   * graceful degradation logic

7. **Prompt Manager**

   * template storage and versioning for all LLM tasks
   * assembly of prompts from: template + style guide + style capsule + few-shot examples + preference axis values
   * read-only inspection in preferences for power users

8. **Local Store**

   * project profiles, style guide, examples, feedback events, style capsules, prompt templates, cache

---

# 4) Core workflow specs

## 4.1 Comment-only rule (hard)

* The app never attempts to rewrite PDF body text.
* "Accept" = create/update a PDF annotation (highlight + popup comment text).

## 4.2 Handling "weird PDFs"

**Design decision:** v1 is selection-first.

* The most reliable anchoring is: **user highlights → you annotate exactly that selection** (no guessing).
* Batch document scanning can exist later, but v1 prioritises accuracy over coverage.
* **Known limitation:** PDFKit's text extraction is unreliable on some publishing PDFs — ligatures, custom encodings, embedded fonts without proper ToUnicode maps. v1 accepts this.
* **Extraction fallback ("Verify Text" field):** If the app detects low-confidence extraction (high rate of non-dictionary words via a simple heuristic check), the issue sidebar displays a "Verify Text" input field pre-populated with the extracted text. The user can correct it before the AI pipeline (LanguageTool + LLM) runs. This is low-cost to implement and matches editors' existing workflow. Full OCR fallback is deferred to v2.

## 4.3 Async architecture

* All AI operations (grammar check, transcription, LLM rewrite) run asynchronously on background threads.
* The PDF workspace remains fully responsive during AI processing.
* Each operation supports: progress indication, cancellation, and queuing (if the service isn't ready yet).
* Results arrive and update the UI non-blockingly.

## 4.4 Primary actions (must be single-keystroke)

* Check selection (LanguageTool)
* Create comment (manual)
* Record voice note (push-to-talk)
* Accept suggestion as comment
* Next/previous issue
* Soften / Make more direct
* Regenerate variants

---

# 5) PDF annotations: compatibility requirements

## 5.1 Annotation types used in v1

* Highlight annotation for the selected text
* Popup/note text for the actual comment body

## 5.2 Annotation metadata

* Every annotation created by Draftsmith writes a unique UUID into the annotation's custom metadata dictionary (via `annotation.setValue(_:forAnnotationKey:)` using a namespaced key `ds_uuid`).
* This UUID links the PDF comment to local audio files, transcripts, and AI history.
* Links survive file renames and moves because they reference the annotation's own UUID, not the document's path or hash.

## 5.3 Saving

* Save changes into the PDF so Acrobat sees them as native comments.
* Keep a local session cache for AI artifacts, but the PDF remains the deliverable.

## 5.4 Acceptance tests (mandatory — all must pass before M1 is complete)

1. Create highlight + comment → save → open in Acrobat → comment appears as expected.
2. Highlights appear as proper **text highlights** in Acrobat (selectable, deletable as highlights — not generic yellow shapes). Verify appearance streams are written correctly.
3. Comments containing Unicode characters (curly quotes, em dashes, accented characters) render correctly in Acrobat.
4. Annotations survive on PDFs that already contain existing annotations from other tools.
5. Test against PDF/A and PDF/X variants (common in publishing).
6. Annotations created in Acrobat are visible and navigable in Draftsmith.

---

# 6) Grammar/style detection spec (LanguageTool)

## 6.1 Language and policy

* `language = en-GB` always (no auto-detect)
* **Caveat:** LanguageTool's en-GB rules are less comprehensive than en-US. Plan for:
  * aggressive use of custom dictionaries from day one
  * custom rule definitions for common publishing-specific patterns
  * periodic evaluation against real editorial text to identify false positive/negative patterns
* Provide a "Project Profile" that can:

  * enable/disable subsets of LanguageTool rules
  * apply house preferences
  * add custom dictionary entries

## 6.2 API interaction

* App sends text chunks (usually the highlighted passage).
* Receives matches: message, offset/length, category, suggestions.
* App renders:

  * issue list with rule name + explanation ("why this was flagged")
  * **visual diff** (word-level, inline) between original and suggested replacement
  * "Add as comment" action (writes annotation)

## 6.3 Double-check loop (LLM output validation)

* All text generated by the LLM (diplomatic comments, rewrites, email drafts) is passed through LanguageTool (en-GB) before being shown to the user.
* **Spelling corrections** (especially US→UK: "organize" → "organise", "color" → "colour") are auto-applied silently.
* **Style or grammar flags** that could change meaning are **not** auto-applied. Instead:
  * If the flag is minor, the variant is shown with a small indicator that LanguageTool raised a concern (tooltip with the rule).
  * If the flag is significant (e.g. possible meaning change), the variant is discarded and the LLM is asked to regenerate.
* The user only ever sees clean, en-GB-compliant output — but meaning-altering silent edits are never made.

---

# 7) Style guide mode (two layers)

## 7.1 Deterministic rules layer

Stored per project as:

* terminology preferences
* banned phrases
* formatting conventions (quotes, punctuation conventions, etc.)
* custom dictionary entries
* "severity" preferences (flag as warn vs info)

This layer:

* influences what you show as issues
* is also fed into the LLM as constraints

## 7.2 Generative layer (LLM)

The LLM must:

* respect the style guide constraints
* offer multiple comment phrasings that **vary** (as requested), not one rigid template
* output strict JSON

---

# 8) "Learn her tone" (no fine-tuning required)

## 8.1 Style memory approach (v1)

Use **Example Pairs** + **Feedback Events**:

* Example Pair:

  * input: rough thought / blunt comment / email bullet list
  * output: her final phrasing

* Feedback Event:

  * model suggestion
  * her edited final
  * word-level diff + quantitative metrics (length change ratio, edit distance)
  * tagged summary of edit intent (e.g., "less hedging", "more specific", "shorter by 60%")

## 8.2 Style Capsule

A compact natural-language summary of the user's editing tendencies, included in every LLM prompt.

* **Generation:** The LLM summarises patterns from the accumulated example pairs + feedback events.
* **Trigger:** Regenerated when the feedback corpus grows by a meaningful threshold (e.g. every 10 new feedback events, or when the user manually requests it).
* **Human-in-the-loop approval:** A new capsule is never auto-activated. It is presented as a suggestion: "Draftsmith noticed you've been editing for brevity. Adopt this new Style Capsule?" with a diff against the current capsule. The user must click "Apply" to activate it. This prevents a bad LLM summary ("User hates verbs") from compounding across all future prompts.
* **Reset button:** The Prompt Manager preferences include a "Reset Style Capsule to Default" action, restoring an empty capsule. Essential escape hatch.
* **Caching:** Cached locally. The previous capsule is kept until the user approves a new one.
* **Size budget:** Hard limit of ~500 tokens. If the capsule exceeds this, the LLM is prompted to compress it.
* **Visibility:** The user can view and manually edit the capsule in preferences.

## 8.3 Preference axes

Four independent dimensions, each a slider:

* **Direct ↔ Gentle**
* **Brief ↔ Thorough**
* **Formal ↔ Warm**
* **Suggest rewrite ↔ Comment only**

These are passed as structured parameters to every LLM prompt, not collapsed into a single "tone" value.

---

# 9) Voice notes spec (whisper.cpp)

## 9.1 Recording

* Push-to-talk while a highlight is active.
* Store audio in app library folder, keyed by annotation UUID (not document hash).
* Use AVFoundation for format handling — no ffmpeg dependency.

## 9.2 Transcription

* Run whisper.cpp locally (embedded in app).
* Keep transcript editable before sending to LLM.

## 9.3 Comment generation

Input to LLM:

* highlighted passage (verbatim)
* transcript
* style guide constraints
* style capsule
* preference axis values (4 dimensions)

Output:

* 3–5 variants, intentionally different
* each variant tagged with brief descriptors ("very gentle", "neutral", "direct")
* all variants passed through LanguageTool double-check before display

---

# 10) Email Studio spec (Outlook copy/paste)

## 10.1 Inputs

* recipient context (optional)
* goal (what needs to happen)
* key facts / bullets
* **context pull:** "Insert Issue Context" button to pull from current review session
* preference axis values

## 10.2 Outputs

* 2–3 email drafts (different tones)
* "shorten", "soften", "more direct", "add warmth", "remove warmth"
* Copy button (plain text + optional rich text later)
* all drafts passed through LanguageTool double-check before display

---

# 11) JSON contracts (LLM outputs)

All LLM endpoints must return valid JSON only.

## 11.1 Diplomatic comment generation

```json
{
  "variants": [
    {
      "id": "v1",
      "label": "gentle + thorough",
      "axes": { "directness": 0.2, "brevity": 0.3, "formality": 0.6, "rewrite_vs_comment": 0.0 },
      "text": "..."
    },
    {
      "id": "v2",
      "label": "neutral + concise",
      "axes": { "directness": 0.5, "brevity": 0.8, "formality": 0.5, "rewrite_vs_comment": 0.0 },
      "text": "..."
    },
    {
      "id": "v3",
      "label": "direct + brief",
      "axes": { "directness": 0.9, "brevity": 0.9, "formality": 0.4, "rewrite_vs_comment": 0.0 },
      "text": "..."
    }
  ],
  "notes_for_user": ""
}
```

The `axes` object reflects where each variant falls on the four preference dimensions (0.0–1.0). The `label` is a human-readable summary derived from the axes. This allows the UI to communicate *why* variants differ from each other.

## 11.2 Rewrite suggestions (optional, still comment-only)

```json
{
  "variants": [
    {
      "id": "r1", "label": "minimal fix",
      "axes": { "directness": 0.5, "brevity": 0.7, "formality": 0.5, "rewrite_vs_comment": 1.0 },
      "text": "...", "diff_summary": "..."
    },
    {
      "id": "r2", "label": "smoother",
      "axes": { "directness": 0.3, "brevity": 0.4, "formality": 0.7, "rewrite_vs_comment": 1.0 },
      "text": "...", "diff_summary": "..."
    },
    {
      "id": "r3", "label": "publisher-safe",
      "axes": { "directness": 0.4, "brevity": 0.5, "formality": 0.9, "rewrite_vs_comment": 1.0 },
      "text": "...", "diff_summary": "..."
    }
  ]
}
```

## 11.3 Email draft

```json
{
  "subject_options": ["...","..."],
  "drafts": [
    {
      "id": "e1", "label": "warm + concise",
      "axes": { "directness": 0.6, "brevity": 0.8, "formality": 0.3, "rewrite_vs_comment": 0.0 },
      "body": "..."
    },
    {
      "id": "e2", "label": "neutral + thorough",
      "axes": { "directness": 0.5, "brevity": 0.2, "formality": 0.6, "rewrite_vs_comment": 0.0 },
      "body": "..."
    }
  ]
}
```

## 11.4 Style Capsule

```json
{
  "capsule_text": "...",
  "key_tendencies": ["prefers brevity", "avoids hedging", "formal register"],
  "token_count": 0
}
```

---

# 12) Prompt management

## 12.1 Prompt tasks

The app maintains versioned prompt templates for:

1. **Diplomatic comment generation** — transcript + passage + style → comment variants
2. **Rewrite suggestion** — passage + issue + style → rewrite variants
3. **Email drafting** — intent + context + style → email variants
4. **Style Capsule generation** — examples + feedback → capsule summary

## 12.2 Prompt assembly

Each prompt is assembled from:

* the task-specific template (versioned)
* style guide constraints (from the active project profile)
* current Style Capsule
* relevant few-shot examples (selected by similarity or recency)
* preference axis values (4 dimensions, as structured data)
* the UK English system directive: "You are a British editorial assistant. You strictly use British English spelling conventions."

### Token budget (8K context window, 8B model)

The default 8B model typically has an 8K context window. Prompt assembly must respect this. Rough allocation:

| Component | Budget | Notes |
|---|---|---|
| System directive + template | ~300 tokens | Fixed per task type |
| Style guide constraints | ~200 tokens | Trimmed if large; summary only |
| Style Capsule | ~500 tokens | Hard limit; compressed if exceeded |
| Few-shot examples | ~1,500 tokens | **3–5 examples max** (not 30–50). Selected by recency or relevance. This is the primary trim target. |
| Task input (passage + transcript) | ~1,500 tokens | The actual text being worked on |
| Preference axes + metadata | ~100 tokens | Compact structured data |
| **Reserved for output** | **~3,900 tokens** | Must leave room for 3–5 variant responses |

**Trim priority** (when budget is tight): few-shot examples are reduced first (drop to 2), then style guide is summarised, then capsule is truncated. The task input and output reservation are never trimmed.

**Implication:** The Vision's "10–50 representative examples" refers to the *stored corpus*, not what goes into a single prompt. The Prompt Manager selects the most relevant 3–5 examples per invocation.

## 12.3 Versioning and inspection

* Each template has a version number. Updates to templates are tracked so behaviour changes are intentional.
* Power users can view (read-only) the assembled prompt in preferences.
* Override capability deferred to a future version.

---

# 13) Local directory layout

* `~/Library/Application Support/Draftsmith/`

  * `Projects/`

    * `ProjectProfiles.sqlite` (or Core Data store)
  * `Audio/`

    * `{annotation_uuid}/{timestamp}.wav`
  * `Transcripts/`

    * `{annotation_uuid}/{timestamp}.txt`
  * `StyleMemory/`

    * `ExamplePairs.sqlite`
    * `FeedbackEvents.sqlite`
    * `StyleCapsules/` (cached capsule text files)
  * `Prompts/`

    * versioned prompt templates
  * `Caches/`

    * LanguageTool results keyed by `{doc_id}:{chunk_hash}`
    * LLM suggestions keyed similarly
  * `Runtime/`

    * bundled JRE (for LanguageTool)
    * whisper model file
    * LLM model file
  * `Logs/` (optional)

---

# 14) Milestones (implementation order)

### M1 — PDF annotations round-trip

* PDFKit viewer + selection
* create highlight + comment with `ds_uuid` metadata
* **expanded acceptance tests:** all 6 tests from Section 5.4 must pass
* verify in Acrobat (proper text highlights, Unicode, existing annotations, PDF/A and PDF/X)

### M2 — Service Manager + graceful degradation

* implement Service Manager module with lazy loading strategy
* LanguageTool embedded server (with bundled JRE) — background launch, NLLanguageRecognizer fast-path while booting
* LLM model loading (on-demand, not at startup)
* Whisper model loading (on-demand, not at startup)
* low-RAM serial execution mode (mutual exclusion of Whisper and LLM)
* status indicators and degradation behaviour

### M3 — Issue queue + project profiles + progress tracking

* sidebar queue, statuses, persistence
* project profiles (rule config, custom dictionaries, terminology)
* review progress indicator (pages visited, issues found/resolved/dismissed)

### M4 — LanguageTool selection check

* check selected text → issue cards with rule explanations
* visual diff (word-level) for suggestions
* "Add as comment" writes annotation

### M5 — LLM rewrite/diplomacy (JSON) + double-check loop

* implement prompt manager + template system + token budget enforcement
* implement JSON parsing + UI variants with multi-axis metadata + 4-axis preference controls
* implement LanguageTool double-check of LLM output (spelling auto-correct; style/grammar flag or regenerate)
* style memory: example pairs + feedback events + capsule generation with human-in-the-loop approval

### M6 — Voice note loop

* record → embedded whisper.cpp → transcript → LLM → comment variants → annotate
* audio linked via annotation UUID

### M7 — Email Studio

* reuse style memory and prompt manager
* context pull from review session ("Insert Issue Context" button)
* deliver copy/paste workflow

---

# 15) Final constraints recap

* **UK English only** (`en-GB` hardcoded; LLM output double-checked by LanguageTool)
* **comment-only** (no body text editing)
* **variation** in comment phrasing is required (multiple genuinely different options)
* **offline after initial setup** (model download on first launch; then localhost-only, no network calls; offline installer path for restricted networks)
* **no developer dependencies** (no Homebrew, no terminal, no manual server management)
* **graceful degradation** (PDF workspace always works; AI features degrade clearly)
* **four preference axes** (not a single tone slider)

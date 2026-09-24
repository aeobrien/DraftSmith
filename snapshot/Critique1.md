## Alignment between the two documents

The technical brief is a faithful translation of the vision overall, but there are some quiet drifts worth flagging:

**The vision promises things the spec doesn't fully deliver.** The vision says "selection accuracy and anchoring" is critical and specifically calls out messy text extraction (line breaks, hyphenation) — but the spec just says "v1 is selection-first" and moves on. This is actually the hardest unsolved problem in the whole app, and the spec treats it as though PDFKit will handle it. PDFKit's text selection on "weird publishing PDFs" (your phrase) is notoriously unreliable — ligatures, custom encodings, embedded fonts without proper ToUnicode maps. The spec should either scope this risk explicitly ("v1 accepts PDFKit selection quality as-is, with known limitations on X, Y, Z") or outline a mitigation strategy.

**The vision's UX principles are largely absent from the spec.** "Never blocks reading — AI runs in the background" implies an async architecture with progress indicators, queuing, and cancellation. The spec doesn't mention concurrency at all. Similarly, "trust through transparency — show why this was flagged" needs UI spec work: what does a rule explanation look like? What does a rewrite diff look like? These aren't cosmetic details; they shape the data model.

**The vision mentions "preference sliders" (direct↔gentle, brief↔thorough, formal↔warm, suggest rewrite↔comment only) but the spec collapses these into a single "tone slider."** Four dimensions became one. Was that a deliberate simplification for v1, or an oversight? If deliberate, worth stating. If not, worth recovering — the multi-axis approach is one of the more distinctive UX ideas here.

---

## Gaps and blindspots

**No error handling or degradation strategy.** What happens when LanguageTool's server isn't running? When Ollama is serving but the model isn't loaded? When whisper.cpp fails on a recording? The spec assumes all four local services are always available. For a "just works" tool, you need graceful degradation — clear status indicators, the ability to use the PDF workspace without the AI services, queued retries, etc. This is especially important because your user isn't a developer; they shouldn't need to debug `ollama serve` from a terminal.

**Service lifecycle is underspecified.** "v1 can ship a 'Start LanguageTool Server' button" — but what about Ollama? Whisper.cpp? Are you launching all of these as child processes? Managed via launchd? What's the startup sequence? This is one of those things that seems minor until it's the reason the app feels janky. I'd recommend a dedicated "Service Manager" module that handles health checks, startup, and status for all local services uniformly.

**The "Style Capsule" concept is promising but vague.** You say you'll "generate a compact Style Capsule from examples + feedback and include it in prompts" — but this is doing a lot of heavy lifting. How is it generated? By the LLM itself (summarising its own few-shot examples)? On what trigger — every time a new feedback event is logged? Is it cached? How long can it get before it eats too much context window? This needs more design work because it's the core of the "learns her tone" promise.

**No mention of prompt engineering or management.** You have at least four distinct LLM tasks (diplomatic comment, rewrite suggestion, email draft, style capsule generation), each needing a well-crafted system prompt that incorporates the style guide, style capsule, few-shot examples, and tone parameters. That's a meaningful prompt templating system. Where do prompts live? How are they versioned? Can the user see/tweak them?

**Model selection and resource requirements are unaddressed.** "Pull llama3.1" — which size? 8B? 70B? This matters enormously for a MacBook. What's the minimum RAM? What happens on an M1 with 8GB vs an M3 with 36GB? The quality of your rewrite/diplomacy output is directly tied to model capability, and your user can't be expected to make this choice. The spec should recommend a default model and state minimum hardware requirements.

---

## Potential problems

**The Acrobat compatibility acceptance test is necessary but probably insufficient.** PDF annotation compatibility is a minefield. You need to test not just "comment appears" but: Does the highlight colour survive? Do comments with Unicode (curly quotes, em dashes — publishing text) render correctly? What about when the PDF already has annotations? What about PDF/A or PDF/X variants common in publishing? I'd expand M1's acceptance criteria significantly.

**LanguageTool's en-GB coverage may disappoint.** LanguageTool is good, but its UK English rules are less comprehensive than its American English ones. Your user will encounter false negatives (missed issues) and false positives (spurious flags on legitimate UK constructions). The "Project Profile" concept helps, but you might want to plan for custom rules or dictionary extensions earlier than you think. Have you evaluated LanguageTool specifically against the kind of text your user works with?

**The comment-only constraint is brilliant but creates an awkward UX for rewrites.** If LanguageTool flags "this sentence has a dangling modifier" and the LLM generates a rewrite, the user has to mentally diff the original against the suggestion, then write a comment like "Consider rephrasing to: [suggestion]." That's a lot of cognitive load. The spec mentions "rewrite diff" in the vision's transparency principle but never specs it. A visual diff between original passage and suggested rewrite would significantly reduce friction.

---

## Missed opportunities

**No concept of "review session" or progress tracking.** Proofreaders work through documents systematically. A simple "X of Y pages reviewed" or "N issues remaining" counter would make the tool feel professional. The vision mentions an issue queue with statuses, but there's no aggregate view of review progress.

**No export or reporting.** After proofreading, does the user ever need a summary? "I found 47 issues, resolved 38, dismissed 9" — even a simple text export of this would be valuable for professional proofreaders who need to communicate what they did.

**The Email Studio feels bolted on.** It shares the style memory, which is good, but it has no connection to the PDF being reviewed. In practice, proofreaders often email *about* the document they're reviewing — "I've completed my review of Chapter 3, here are my main concerns..." Could the Email Studio pull context from the current review session? That would make it feel integrated rather than adjacent.

---

## A challenge to rethink

Here's the bigger question I want to pose: **are you building a tool or building a workflow?**

The spec reads like a tool — a collection of capabilities (PDF viewing, grammar checking, voice notes, email drafting). But the vision reads like a workflow — a "review → decide → annotate" loop. Those are different design targets. A tool gives you features and lets you compose them. A workflow guides you through a process and removes decisions.

Right now, the spec leans tool. The user has to know to select text, then decide whether to grammar-check it or voice-note it or manually comment on it. But the vision's promise is about *reducing friction*. What would it look like if the app guided the reviewer through the document more actively — surfacing issues proactively, suggesting "you haven't reviewed pages 12–18 yet," batching similar issues?

I'm not saying you should build that for v1. But I think being explicit about where you sit on the tool↔workflow spectrum would sharpen both documents. The vision implies workflow; the spec builds a tool. That gap will show up in the UX.

-
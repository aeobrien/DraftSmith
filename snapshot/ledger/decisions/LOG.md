# Decision Log

| # | Date | Decision | Alternatives | Rationale | Impacts |
|---|------|----------|-------------|-----------|---------|
| 1 | Pre-ledger | Three-layer architecture: PDF (truth) -> Rules (detection) -> LLM (rewriting) | Monolithic LLM-does-everything | Avoids "LLM tries to be Grammarly" trap; keeps UI snappy and predictable | All subsystems |
| 2 | Pre-ledger | Comment-only -- never edit PDF body text | In-place PDF text editing | Acrobat-compatible annotations are the deliverable; body editing is fragile and out of scope | PDF Workspace, Rewrite Engine |
| 3 | Pre-ledger | Offline after initial setup -- no text leaves machine | Cloud API (OpenAI, etc.) | NDA-safe by design; user works with confidential manuscripts | All subsystems |
| 4 | Pre-ledger | MLX Swift LM for local LLM (not Ollama) | Ollama, llama.cpp | Bundled in app, no external install, Apple Silicon native | Service Manager, Rewrite Engine |
| 5 | Pre-ledger | WhisperKit for transcription (not whisper.cpp) | whisper.cpp via Swift wrapper | CoreML native, Apple Silicon optimised | Voice Notes, Service Manager |
| 6 | Pre-ledger | Four independent preference axes (not single tone slider) | Single "tone" slider | Multi-dimensional control produces meaningfully different outputs | Rewrite Engine, Prompt Manager |
| 7 | Pre-ledger | Style Capsule with human-in-the-loop approval | Auto-updating capsule | Prevents style drift from bad LLM summaries compounding | Rewrite Engine, Prompt Manager |
| 8 | Pre-ledger | Direct Download distribution (not Mac App Store) | Mac App Store | Avoids JRE sandboxing issues; enables bundled child processes | Service Manager |
| 9 | Pre-ledger | SwiftData for persistence (not Core Data) | Core Data, SQLite directly | Modern Swift-native persistence; integrates with SwiftUI | Local Store |
| 10 | Pre-ledger | Bundled headless JRE for LanguageTool | Require user to install Java; JNI bridge | Invisible infrastructure -- user never sees Java | Service Manager, Check Engine |
| 11 | Pre-ledger | Double-check loop: all LLM output through LanguageTool (en-GB) | Trust LLM spelling/grammar | Catches US spellings silently; prevents meaning-altering auto-edits | Rewrite Engine, Check Engine |
| 12 | 2026-02 | Qwen3 as default LLM (8B/4B/1.7B by RAM) | Llama 3.1 (originally planned) | Selected during implementation | Service Manager |
| 13 | 2026-02 | Delete issues on dismiss/resolve (not just status change) | Keep all issues with status flags | Cleaner UX -- resolved items don't clutter the list | Check Engine |
| 14 | 2026-02 | API key in macOS Keychain (not hardcoded) | Environment variable, config file | Blocked by GitHub secret scanning; Keychain is OS-encrypted | Core |
| 15 | 2026-02 | clearAllIssues on re-check (not just clearNewIssues) | Incremental dedup | Prevents duplicate accumulation; simpler mental model | Check Engine |

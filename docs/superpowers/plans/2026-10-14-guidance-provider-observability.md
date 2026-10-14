# Guidance Provider Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add provider-owned, level-aware and secret-safe Last.fm and Library Signals logging while leaving Better Call Bliss and Bliss Mixer Lab selection logs unchanged.

**Architecture:** Providers emit bounded `guidance_log_event_v1` objects in the existing extensible diagnostics payload. Native hosts preserve prepare and score events without rendering them; the shared Perl host validates and dispatches them to the installed Lyrion provider, whose formatter owns the log category and message text.

**Tech Stack:** Rust, Serde/JSONL, Perl, Lyrion logging, existing Bliss Guidance SPI v2.

**Spec:** `docs/superpowers/specs/2026-10-14-guidance-provider-observability-design.md`

## Global Constraints

- Keep `bliss-guidance-jsonl-v2`; this is an additive diagnostics extension, not an SPI version change.
- Reserve native-provider stdout exclusively for JSONL protocol responses.
- Never expose API keys, authenticated URLs, environment secrets, arbitrary executable paths, or unbounded candidate collections.
- Keep Better Call Bliss and Bliss Mixer Lab established log bodies byte-for-byte unchanged; provider lines are additive and use provider-owned categories.
- Provider logging failure must never alter scores, block a mix/preview, or prevent neutral fallback.
- INFO is summarized and bounded; DEBUG may add sanitized compact JSON and bounded result details.

## Review Focus

- A malformed or oversized event must be dropped without failing the provider session; covered by Task 2 dispatcher tests.
- Prepare events must survive both native-host paths even when score diagnostics also contain events; covered by Tasks 5 and 6 merge tests.
- Last.fm API keys and authenticated URLs must remain absent from success and error events; covered by Task 3 redaction tests.
- Disabled or WARN-level providers must not pay for DEBUG JSON/result construction; covered by Tasks 3 and 4 diagnostic-level tests.
- Existing host selection/result logs must remain unchanged after event dispatch; covered by Task 7 complete formatter fixtures.

---

### Task 1: Define the host-neutral event type

**Files:**
- Modify: `D:\LMS\bliss-playlist-guidance-spi\src\lib.rs`
- Modify: `D:\LMS\bliss-playlist-guidance-spi\SPI.md`
- Create: `D:\LMS\bliss-playlist-guidance-spi\schemas\guidance-log-event-v1.schema.json`

**Interfaces:**
- Produces: `GuidanceLogEventV1`, `GuidanceLogLevel`, constants for event/count/detail bounds, and helpers that read/write bounded events in `Diagnostics.details.log_events_v1`.
- Consumes: existing `Diagnostics { details: Option<Value> }`; wire format and SPI version stay unchanged.

- [ ] **Step 1: Write failing Rust tests** for valid round-trip, unknown/invalid level rejection, event-count truncation, string/detail bounds, and preservation of unrelated diagnostics details.
- [ ] **Step 2: Run `cargo test --locked`** and confirm failures are caused by the absent event type/helpers.
- [ ] **Step 3: Implement the minimal typed contract and schema** without adding a field to `GuidanceResponse` or changing `SPI_VERSION`.
- [ ] **Step 4: Run `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`, and `cargo test --locked`**; expect all green.
- [ ] **Step 5: Commit** with `feat: define guidance provider log events`.

### Task 2: Validate and dispatch events in the shared Perl host

**Files:**
- Modify: `Plugins/BlissGuidance/Runtime.pm`
- Modify: `Plugins/BlissGuidance/Discovery.pm`
- Modify: `tests/runtime.t`
- Modify: `tests/discovery.t`
- Modify: `README.md`

**Interfaces:**
- Consumes: `Diagnostics.details.log_events_v1` from Task 1.
- Produces: `Runtime::score_batch` result key `log_events_v1`; `Discovery::dispatch_log_events($provider, $events, $context)` calling optional `guidance_provider_log_events_v1`.

- [ ] **Step 1: Extend fixture responses and write failing tests** proving prepare and score events are merged in order, invalid/oversized events are ignored, providers without the optional hook remain compatible, and hook exceptions remain neutral.
- [ ] **Step 2: Run the focused Perl tests with Git Perl** and confirm the new assertions fail for missing behavior.
- [ ] **Step 3: Implement bounded extraction, validation and generic dispatch**; return no ready-rendered log strings from shared code.
- [ ] **Step 4: Run all shared-host Perl tests** and expect all green.
- [ ] **Step 5: Commit** with `feat: dispatch provider observability events`.

### Task 3: Emit and render Last.fm events

**Files:**
- Modify: `D:\LMS\bliss-guidance-lastfm\src\main.rs`
- Modify: `D:\LMS\bliss-guidance-lastfm\README.md`
- Modify: `D:\LMS\lms-guidance-lastfm\LastFmGuidance\Plugin.pm`
- Modify: `D:\LMS\lms-guidance-lastfm\LastFmGuidance\Provider.pm`
- Modify: `D:\LMS\lms-guidance-lastfm\tests\provider_descriptor.t`
- Modify: `D:\LMS\lms-guidance-lastfm\tests\plugin_contract.t`
- Create: `D:\LMS\lms-guidance-lastfm\tests\provider_logging.t`

**Interfaces:**
- Consumes: Task 1 event type and Task 2 optional provider hook.
- Produces: `plugin.guidancelastfm` at default WARN; INFO request/cache/result/summary messages; DEBUG sanitized compact JSON, bounded named results, identity resolution and scoring summaries.

- [ ] **Step 1: Capture LastMix's current INFO/DEBUG/ERROR message bodies and add failing formatter/native tests** for track and artist lookups, cache hit/miss, partial failure, malformed response, API rejection, MBID/name fallback, and summary counts.
- [ ] **Step 2: Run focused Rust and Perl tests** and confirm failures reflect missing events/logger hook.
- [ ] **Step 3: Implement level-aware event generation** in direct API mode and provider-level event generation for LastMix acquisition; build DEBUG payloads only when requested.
- [ ] **Step 4: Implement the Perl renderer and logger category**; JSON must be compact, valid and allowlisted, and the API key/full authenticated URL must never be present.
- [ ] **Step 5: Run full native and plugin suites plus an explicit secret scan of captured messages**; expect all green and no credential occurrence.
- [ ] **Step 6: Commit each repository** with `feat: add Last.fm guidance diagnostics` and `feat: log Last.fm guidance activity`.

### Task 4: Emit and render Library Signals events

**Files:**
- Modify: `D:\LMS\bliss-guidance-playcounts\src\main.rs`
- Modify: `D:\LMS\bliss-guidance-playcounts\README.md`
- Modify: `D:\LMS\lms-guidance-library-signals\LibrarySignals\Plugin.pm`
- Modify: `D:\LMS\lms-guidance-library-signals\LibrarySignals\Provider.pm`
- Modify: `D:\LMS\lms-guidance-library-signals\tests\provider_descriptor.t`
- Modify: `D:\LMS\lms-guidance-library-signals\tests\plugin_contract.t`
- Create: `D:\LMS\lms-guidance-library-signals\tests\provider_logging.t`

**Interfaces:**
- Consumes: Task 1 event type and Task 2 optional provider hook.
- Produces: `plugin.guidancelibrarysignals` at default WARN; preparation/source/coverage INFO, bounded query/result DEBUG, APC fallback WARN and resource/SPI ERROR messages.

- [ ] **Step 1: Add failing native and Perl formatter tests** for Lyrion/APC provenance, coverage, query batches/cache hits, APC fallback, partial coverage and database/artifact failures.
- [ ] **Step 2: Run focused Rust and Perl tests** and confirm failures are caused by missing events/logger hook.
- [ ] **Step 3: Implement level-aware native events and the provider-owned Perl renderer** without dumping the complete candidate inventory.
- [ ] **Step 4: Run complete native and plugin suites**; expect all green.
- [ ] **Step 5: Commit each repository** with `feat: expose library signal diagnostics` and `feat: log library signal activity`.

### Task 5: Preserve events through `bliss-mixer`

**Files:**
- Modify: `D:\LMS\bliss-mixer\src\guidance.rs`
- Modify: `D:\LMS\bliss-mixer\Cargo.toml`
- Modify: `D:\LMS\bliss-mixer\Cargo.lock`

**Interfaces:**
- Consumes: Task 1 diagnostics-event helpers.
- Produces: `/api/guidance/score` response diagnostics containing bounded prepare events followed by score events.

- [ ] **Step 1: Change the fixture provider and add a failing test** asserting exact ordered preservation of prepare and score events and unrelated details.
- [ ] **Step 2: Run the focused Rust test** and confirm prepare events are currently absent.
- [ ] **Step 3: Retain both diagnostics objects and merge only `log_events_v1` through the shared helper**; do not render or inspect provider-specific details.
- [ ] **Step 4: Run `cargo fmt --check`, Clippy and `cargo test --locked`**; expect all green.
- [ ] **Step 5: Commit** with `feat: preserve guidance provider log events`.

### Task 6: Preserve events through `bliss-playlist-optimizer`

**Files:**
- Modify: `D:\LMS\bliss-playlist-optimizer\src\guidance.rs`
- Modify: `D:\LMS\bliss-playlist-optimizer\Cargo.toml`
- Modify: `D:\LMS\bliss-playlist-optimizer\Cargo.lock`
- Modify: `D:\LMS\bliss-playlist-optimizer\tests\contracts.rs`

**Interfaces:**
- Consumes: Task 1 diagnostics-event helpers.
- Produces: each serialized `guidance_addon_diagnostics` entry may contain bounded `log_events_v1` collected from prepare and score responses.

- [ ] **Step 1: Add a failing fixture/contract test** asserting prepare and score events survive to the final route/bridge artifact in order.
- [ ] **Step 2: Run focused and full Rust tests** and confirm failure is the currently discarded diagnostics.
- [ ] **Step 3: Store events per provider session and serialize them additively on `AddonDiagnostic`**; leave all existing counter/state fields unchanged.
- [ ] **Step 4: Run formatting, Clippy, unit tests and contract tests**; expect all green.
- [ ] **Step 5: Commit** with `feat: preserve guidance provider log events`.

### Task 7: Dispatch native-host events without changing host logs

**Files:**
- Modify: `D:\LMS\lms-better-call-bliss\BetterCallBliss\GuidanceProviderDiscovery.pm`
- Modify vendored `Plugins/BlissGuidance/Discovery.pm` and `Runtime.pm` in Bliss Mixer Lab.
- Modify: `D:\LMS\lms-better-call-bliss\BetterCallBliss\Jobs.pm`
- Modify: `D:\LMS\lms-better-call-bliss\tests\log_diagnostics.t`
- Modify: `D:\LMS\lms-better-call-bliss\tests\guidance_provider_discovery.t`
- Modify: `D:\LMS\lms-blissmixer-lab\BlissMixerLab\GuidanceProviderAdapter.pm`
- Modify: `D:\LMS\lms-blissmixer-lab\BlissMixerLab\Plugin.pm`
- Modify: `D:\LMS\lms-blissmixer-lab\tests\guidance_provider_adapter.t`
- Modify: `D:\LMS\lms-blissmixer-lab\tests\plugin_contract.t`

**Interfaces:**
- Consumes: Task 2 dispatcher, Task 5 mixer response events and Task 6 optimizer `AddonDiagnostic.log_events_v1`.
- Produces: provider-owned log calls after successful/partial native work; unchanged Better Call Bliss preview text and unchanged Lab candidate-selection log bodies.

- [ ] **Step 1: Add failing host tests** for provider lookup/dispatch, absent provider, malformed events, event-hook failure, and the complete existing Better Call Bliss/Lab formatter bodies.
- [ ] **Step 2: Run focused Perl tests** and confirm only the new dispatch assertions fail.
- [ ] **Step 3: Dispatch events after native results arrive** using discovered provider identity; never make dispatch success a condition of the preview/mix.
- [ ] **Step 4: Synchronize shared-host vendored files and run parity tests** so both hosts match the authoritative shared source.
- [ ] **Step 5: Run each plugin's complete test/validation suite**; expect all established log fixtures unchanged.
- [ ] **Step 6: Commit each repository** with `feat: relay guidance provider diagnostics`.

### Task 8: Cross-repository verification and documentation

**Files:**
- Modify only the owning READMEs/SPI documentation where runtime behavior changed.
- Do not copy provider capability details into host READMEs.

**Interfaces:**
- Consumes: all preceding tasks.
- Produces: verified end-to-end event chain and documentation matching shipped ownership boundaries.

- [ ] **Step 1: Run every Rust repository's format, Clippy and full test commands** and every Perl repository's complete tests/validation scripts.
- [ ] **Step 2: Run fixture sessions at WARN, INFO and DEBUG**; compare provider log bodies, verify INFO summaries and DEBUG JSON/results, and scan all output for a sentinel API key.
- [ ] **Step 3: Compare Better Call Bliss and Lab established formatter fixtures byte-for-byte** against the branch bases.
- [ ] **Step 4: Update component READMEs and SPI examples** with the actual event flow and limitations, keeping provider details in provider repositories.
- [ ] **Step 5: Commit documentation changes** and prepare a whole-branch review package for every affected repository.


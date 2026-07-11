# Java-Free Song Loading Implementation Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement each phase plan task-by-task. Steps in executable phase plans use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完整迁移当前 Godot 产品合同到 Godot + Rust native CLI, 达成已批准的 catalog、搜索、选歌、进度和 gameplay loading SLO, 最终删除全部 Java/Maven/JAR surface.

**Architecture:** Godot 拥有 UI、catalog orchestration、cache policy、progress、resource loading 和 gameplay. Rust core 拥有 VOS、OJN/OJM、osu!mania 解析、timing、audio preparation 与 relocatable bundle v2, 首期通过 native CLI 暴露. Java 仅在迁移期间生成冻结 golden oracle, 完成 parity 和 package gates 后删除.

**Tech Stack:** Godot 4.6.3, GDScript, Rust 1.96.1 with edition 2024, Java 17/Maven 3.9.9 only for temporary oracle phases, macOS arm64 release packaging.

## Global Constraints

- Product formats: VOS, O2Jam OJN/OJM, osu!mania `.osu`/`.osz`, and bundle v2.
- Retired formats and surfaces: BMS, SM, SNP, Swing, and LWJGL application.
- `Start -> Song Selection Ready` warm P95 must be no more than 300 ms.
- Search and format filtering P95 must be no more than 100 ms.
- `Chart -> Gameplay Ready` warm P95 must be no more than 2 s and cold P95 no more than 5 s.
- Loading UI must appear within 100 ms and progress must be real, complete, and monotonic.
- Gameplay cache defaults to 10 GB and Settings must allow values from 5 GB upward.
- Java bundle v1 and catalog cache are ignored, not migrated, and not automatically deleted.
- User settings, song roots, key bindings, gameplay settings, and source songs are preserved.
- First hard release gate is a signed macOS Apple Silicon Godot application.
- Production implementation must follow the Superpowers governance in the approved design.
- Every implementation task uses TDD and ends in a focused commit.

---

## Why This Is Split Into Phase Plans

The approved design spans parser migration, deterministic synthesis, Godot UI, process control, transactional cache, packaging, performance verification, and destructive Java deletion. A single plan would couple independent subsystems and become stale before later phases start. Each phase below must produce working, testable software and pass its exit gate before `superpowers:writing-plans` creates the next executable phase plan from the then-current tree.

## Phase Sequence

### Phase 0: Freeze Golden Truth And Repair Gates

Executable plan: `docs/superpowers/plans/2026-07-11-java-free-golden-foundation.md`.

Produces:

- Hermetic VOS, OJN/OJM, osu!mania, and malformed source fixtures.
- Frozen Java catalog, gameplay, audio, and error oracle with provenance.
- A no-skip migration foundation verifier.
- Repaired current verification scripts with stale Partytime and status-text assumptions removed.

Exit gate:

- Golden corpus regenerates byte-for-byte on the pinned Java commit/JDK environment.
- Migration foundation verifier fails on missing or changed sources/expected files.
- No selected Phase 0 test relies on `/Users/...` external fixtures or JUnit assumptions.

### Phase 1: Rust Core, Contracts, CLI, And Bundle v2

Created after Phase 0 passes.

Produces:

- Rust 1.96.1 workspace and pinned Cargo lockfile.
- Shared domain, error, request/result, and progress contracts.
- Native CLI `version`, `catalog`, and `bundle` command boundaries.
- Relocatable bundle v2 manifest, strong key, staging, hashing, and cancellation primitives.

Exit gate:

- Rust contract tests and malformed-input tests pass.
- CLI events are versioned, sequence-ordered, and machine-readable.
- Bundle staging cannot publish incomplete output.

### Phase 2: OJN/OJM And osu!mania Importers

Created after Phase 1 passes.

Produces:

- OJN three-chart model and OJM/OMC/M30 sample import.
- osu!mania `.osu` and `.osz` 7K import and referenced audio resolution.
- Normalized timing, long-note, sample ID, volume, pan, and catalog output.
- Java-vs-Rust differential parity for every non-VOS golden case.

Exit gate:

- Zero unexplained semantic difference for OJN/OJM and osu!mania goldens.
- Parser mutation tests show no crash, hang, path traversal, or unbounded allocation.

### Phase 3: VOS Parser And Deterministic Audio

Created after Phase 2 passes.

Produces:

- VOS container, metadata, channel, note, and embedded MIDI import.
- Playable-source inference, live/background split, running-status handling, and stable sample deduplication.
- Fixed redistributable SoundFont contract and deterministic offline PCM renderer.
- Cross-Chart content-addressed MIDI sample cache.

Mandatory go/no-go gate before production synth work:

- The chosen synth stack renders the fixed fixtures byte-identically across repeated and reversed-order runs on macOS arm64.
- Output is 44.1 kHz, stereo, signed 16-bit PCM with the accepted minimum gate and tail.
- The representative chart meets the cold 5 s budget in a release prototype.
- SoundFont bytes, version, SHA-256, source, license, and redistribution approval are fixed.

If this gate fails, stop this phase and amend the audio ADR. Do not add a Java fallback.

### Phase 4: Godot Catalog v2 And Grouped Selection UI

Created after Phase 3 establishes final catalog contracts.

Produces:

- Catalog Index v2 store and background Catalog Coordinator.
- Song grouping, basename/title search, multi-format filter, and last-known-good behavior.
- Virtualized Song list and independent Difficulty Selection panel.
- Cached UI before scan, real Catalog Refresh progress, and preserved selection/scroll.

Exit gate:

- A 3,919-Chart fixture creates only visible rows plus bounded overscan.
- Search/filter never starts the converter or disk scan.
- Warm Song Selection Ready and query SLOs pass.

### Phase 5: Gameplay Prewarm, Artifact Cache, Progress, And Audio Loading

Created after Phase 4 passes.

Produces:

- Non-blocking converter process transport with PID ownership and cooperative cancellation.
- Strong Artifact Cache v2 validation, atomic publication, LRU, pinning, and Settings controls.
- Load Coordinator with generation isolation and 300 ms Chart Prewarm.
- Priority audio loader and fixed-capacity player pool.
- Static Godot render metadata and skin assets under `res://`.

Exit gate:

- Cache hit, miss, corruption, source mutation, out-of-space, cancel, and late-result tests pass.
- Progress reaches 100 only after Gameplay Ready.
- Warm and cold gameplay SLOs pass for every product format.

### Phase 6: macOS Cutover, Performance Gate, And Java Deletion

Created only after Phases 0–5 pass.

Produces:

- Signed macOS arm64 Godot package containing the native converter.
- Clean-machine Java-free E2E and package audit.
- Rewritten CI, mise tasks, README, and release workflow.
- Removal of runtime Java bridge, then final removal of Java source, Maven, JARs, Swing/LWJGL, and Java-only tools.

Exit gate:

- Approved golden, functional, performance, package, signing, and Java-absence gates all pass.
- No production runtime or build fallback can invoke Java.
- Frozen provenance remains, but executable Java oracle and implementation are gone.

## Execution Rule

Only the current phase plan is executable. After its exit gate and review pass, mark that plan complete, inspect the live tree, and invoke `superpowers:writing-plans` for the next phase. Use `superpowers:subagent-driven-development` for execution unless the user explicitly selects inline execution.

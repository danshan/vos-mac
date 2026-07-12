# Java-Free Phase 1 Rust Core Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立可独立验证的 Rust 1.96.1 core 与 native CLI 合同, 冻结 shared domain、request/result/progress/error、bundle v2、强 identity、cancellation 和 transactional staging, 为 Phase 2/3 importer 提供无 Java runtime 依赖的稳定边界.

**Architecture:** `open2jam-core` 只拥有确定性 domain/contract/hash/bundle primitives, `open2jam-cli` 只拥有参数、版本握手、JSON/JSONL 文件 transport 和 command adapter. 本阶段不实现 VOS、OJN/OJM、osu!mania parser 或音频生成; `catalog`/`bundle` production handler 对尚未实现的格式返回稳定 machine-readable error, 不制造 parser-dependent 假成功. Rust 只把完整 bundle 发布到 job staging namespace, Godot final cache publication 保留到 Phase 5.

**Tech Stack:** Rust 1.96.1, edition 2024, Cargo resolver 3, `serde`, `serde_json`, `sha2`, mise, macOS arm64, existing hermetic Java migration goldens as test-only evidence.

### Task 0: Binding execution context, not an implementation task

Task 0 has no code, review or commit. It exists so SDD can extract the complete global contract separately from the selected implementation Task. Before Task 1, and again only if this plan changes, run:

```bash
mkdir -p /private/tmp/open2jam-java-free-sdd
$HOME/.codex/plugins/cache/superpowers-dev/superpowers/6.1.1/skills/subagent-driven-development/scripts/task-brief docs/superpowers/plans/2026-07-12-java-free-phase1-rust-core.md 0 /private/tmp/open2jam-java-free-sdd/task-0-global.md
```

For implementation Task `N`, run the same script with `N` and `/private/tmp/open2jam-java-free-sdd/task-N-brief.md`. Every implementer and both reviewers read `task-0-global.md` first, then the selected Task brief. They execute only Task `N` and only the matching Task `N` subsection of the controller micro-checklist; other Task micro-checklists are dependency context, not assigned work. This is the required augmentation that preserves Global Constraints, Cross-Task API Freeze and micro-steps without making a fresh subagent read the whole plan.

## Global Constraints

- `mise.toml` 是 Rust toolchain 唯一 source of truth: `rust = "1.96.1"`. 不增加 `rust-toolchain.toml`, 不允许 bare `cargo` / `rustc` gate.
- Workspace 固定 `edition = "2024"`, `rust-version = "1.96.1"`, `resolver = "3"`, 并提交 `native/Cargo.lock`.
- 所有 production Rust crate 使用 `#![forbid(unsafe_code)]`; Phase 1 不增加 native/C dependency、async runtime、CLI framework 或 parser library.
- Runtime dependency 仅允许 `serde = "1.0"`, `serde_json = "1.0"`, `sha2 = "0.10"`; 新 dependency 必须重新进行 dependency review.
- Product `Format` JSON 值固定为 `VOS`, `O2JAM`, `OSU_MANIA`, `BUNDLE`; `SourceKind` 固定为 `VOS`, `OJN`, `OSU`, `OSZ`, `BUNDLE_V2`.
- Schema versions 固定: protocol/request/result/progress `1`, catalog/bundle/gameplay/audio manifest `2`, ID/source-fingerprint/bundle-key algorithm `1`.
- Stable error codes 固定为 design 列表, 加上 Phase 0 golden 已冻结的 `MISSING_ASSET`, 以及协议层 `INVALID_REQUEST`, `UNSUPPORTED_SCHEMA`, `SOURCE_CHANGED`.
- JSON 使用 camelCase、UTF-8、compact encoding、一个尾随 LF; contract structs 使用 `deny_unknown_fields`; schema mismatch、BOM、trailing non-whitespace、duplicate struct field、invalid UTF-8 必须 fail closed.
- 所有 hash/ID 使用 lowercase full SHA-256. 禁止复制 Java canonical absolute path 加 `#chart=n` 后截断 hash 的 identity.
- Source path 保留 exact UTF-8, 不做 Unicode normalization. `SourceRelativePath` 表示 source package 内 traversal-safe UTF-8 POSIX path; `BundleRelativePath` 表示 generated artifact 的安全 ASCII relative POSIX path. 两者都禁止 absolute、drive prefix、backslash、empty component、`.`、`..` 和 NUL; bundle path 额外禁止 case-fold collision.
- Strong identity 不包含 absolute source path. Source bytes、companion/referenced asset bytes、chart selector、schema、converter version、SoundFont hash、static asset version 都必须影响 bundle key.
- CLI progress 是 append-only JSONL, sequence 从 `1` 连续递增. CLI bundle 只拥有到 `VERIFY_BUNDLE`; `PRELOAD_STARTUP_AUDIO`, `CREATE_GAMEPLAY`, gameplay `READY` 由后续 Godot coordinator 拥有.
- Rust 不读取、不迁移、不删除 Java v1 cache. Phase 1 不修改 Java/Godot production runtime path, 不把 production SoundFont 打入当前 Java JAR.
- 当前会话不修改 `.superpowers` 或 `.superpowers/sdd`. Task brief、report 和 diff package 使用 `/private/tmp/open2jam-java-free-sdd/` 的 task-scoped 文件, review 通过后立即清理; durable status 只写 Phase 1 progress 文档.
- 每个 task 严格执行 RED -> GREEN -> focused regression -> fresh specification review -> fresh code-quality review -> focused commit.
- 依赖波次固定为: Task 1 -> Task 2; Wave A 中 Task 3 与 Task 4 互不依赖; Wave B 中 Task 5 与 Task 6 在 Task 4 合入后互不依赖; Task 7 等待 Task 3 与 Task 5; Task 8 等待 Task 4-7; Task 9 最后串行. 最新用户执行决策将 implementation 并发上限调整为 `2`: Task 1 和 Task 2 继续串行; 之后仅在依赖满足时并发 Task 3/4、Task 5/6, 或 Task 7 与仍未完成的 Task 6. 每个 implementation lane 使用 `/private/tmp` 下 `git clone --no-hardlinks` 创建的完全独立 task clone, 不共享 `.git` 或 `native/target`; integration checkout 保持单写, 同一 Task 的 fresh specification review 与 fresh code-quality review 仍严格串行. 下游只能消费两个 review 均 `APPROVED` 且已通过 integration regression 的 commit. Task 9 与所有 Phase 1 exit gates 最后在 integration checkout 串行执行. 每个 task 完成并写入 durable ledger 后立即清理其 task-owned clone 与 `/tmp` artifact.

## File Map

- `mise.toml`, `AGENTS.md`, `native/Cargo.toml`, `native/Cargo.lock`: Rust 1.96.1 workspace、toolchain 和 canonical commands.
- `native/crates/open2jam-core/src/{schema,format,digest,id,path,error,json,protocol}.rs`: frozen cross-process primitives and protocol contracts.
- `native/crates/open2jam-core/src/domain/`: validated Song/Chart/Event/Sample contract and stable ID derivation consumers.
- `native/crates/open2jam-core/src/{job,progress,cancellation}.rs`: state machine, owner-scoped progress, cooperative cancellation.
- `native/crates/open2jam-core/src/{canonical,source}.rs`: domain-separated hashing and same-handle source capture.
- `native/crates/open2jam-core/src/bundle/`: strong key, manifest v2, exact-tree verifier and transactional staging.
- `native/crates/open2jam-cli/src/{args,io,runner}.rs`: exact CLI grammar, bounded request/result transport and service adapter.
- `native/crates/*/tests/`: behavior tests and immutable fixtures; production code never reads Phase 0 Java goldens.
- `docs/superpowers/plans/2026-07-12-java-free-phase1-progress.md`: durable SDD ledger outside `.superpowers`; update after each approved task.
- `rewrite/tools/verify_native_phase1.sh`: production aggregate only. `test_verify_native_phase1*.sh` own static and mutation contracts and never call themselves recursively.
- `.github/workflows/build.yml`, `rewrite/tools/verify_build_workflow.sh`: one unconditional CI owner and anti-bypass verification.

Every task ends with two independently recorded checkpoints. The implementer may not self-approve either checkpoint: a fresh specification reviewer first maps the task's stated contract to the diff/tests, then a fresh code-quality reviewer inspects the approved implementation. Findings are fixed and re-reviewed before the focused commit.

## Cross-Task Public API Freeze

The signature blocks below are API contracts. Blocks marked `text` are not literal Rust source; the task implementation supplies complete bodies and tests, never `todo!()`, `unimplemented!()` or placeholder branches.

Task 2 additionally produces:

```text
Digest::{parse, from_bytes, as_bytes}
SourceId::{from_digest, digest}
SongId::{from_digest, digest}
ChartId::{from_digest, digest}
SampleId::{from_digest, digest}
SourceFingerprint::{from_digest, digest}
BundleKey::{from_digest, digest}
BundleRelativePath::{parse, as_str}
SourceRelativePath::{parse, as_str}
AbsoluteSourcePath::{parse, as_path, into_path_buf}
ErrorCode::as_str
Command::as_str
CommandResultV1::{succeeded, failed, cancelled, protocol_failure}
```

Task 4 additionally produces:

```text
JobStateMachine::{new, state, transition}
ProgressSink::write
ProgressTracker::{new, emit}
JsonlProgressWriter::create
MarkerCancellation::new
```

`ProgressTracker<'a>` borrows `&'a mut dyn ProgressSink`; later interfaces always use `&mut ProgressTracker<'_>`.

Task 5 additionally produces:

```text
CapturedSource::open
CapturedSource::reader -> Result<&mut File, CoreError>
CapturedSource::{rewind, finalize}
capture_source_component
compute_source_fingerprint
compute_bundle_key
```

Task 6 additionally produces:

```text
UsageError::{message, exit_code}
UnsupportedCommandService
run_with_service(args, service, stdout, stderr) -> u8
AtomicResultWriter::{reserve, publish}
```

Task 7 additionally produces:

```text
BundleFile::from_bytes
BundleManifestV2::{new, validate, key_input}
VerifiedBundle::{root, manifest, into_parts}
verify_bundle
```

## Controller Micro-Checklist

The numbered steps below are task milestones. The controller dispatch brief and implementer report must track these smaller actions in order; each checkbox is one edit or one command, not a multi-file hidden step.

Task 1:

- [ ] Add Rust `1.96.1` to `mise.toml`.
- [ ] Create the workspace manifest.
- [ ] Create the core manifest and RED crate root.
- [ ] Create the CLI manifest and RED crate root.
- [ ] Create `version_command.rs`.
- [ ] Install Rust and generate `Cargo.lock`.
- [ ] Run the behavioral RED command.
- [ ] Implement `VersionInfo`.
- [ ] Implement the version command.
- [ ] Add the workspace smoke script.
- [ ] Update `native/README.md`.
- [ ] Update the `AGENTS.md` runtime section.
- [ ] Run the workspace smoke script.
- [ ] Run focused GREEN.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.
- [ ] Run locked metadata verification.

Task 2:

- [ ] Add primitive test cases to `protocol_contract.rs`.
- [ ] Add the five exact malformed fixtures.
- [ ] Add `sha2` and generate `Cargo.lock`.
- [ ] Run the focused RED command.
- [ ] Implement schema and format enums.
- [ ] Implement digest and typed ID newtypes.
- [ ] Implement path and `JobId` validation.
- [ ] Implement identity wrappers and golden vectors.
- [ ] Implement coded errors and strict JSON.
- [ ] Implement request/result envelopes.
- [ ] Run focused GREEN.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 3:

- [ ] Add constructor invariant cases.
- [ ] Add serde-bypass cases.
- [ ] Add the Java evidence reader and assertions.
- [ ] Run the focused RED command.
- [ ] Implement timing, key and lane types.
- [ ] Implement event and sample types.
- [ ] Implement format identities and grouping.
- [ ] Implement Chart validation.
- [ ] Implement private Wire conversions.
- [ ] Run focused GREEN.
- [ ] Run the corpus diff.
- [ ] Run workspace doc tests.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 4:

- [ ] Add the state-edge table.
- [ ] Add the owner/phase table.
- [ ] Add exact JSONL byte cases.
- [ ] Add cancellation cases and run focused RED.
- [ ] Implement the state machine.
- [ ] Implement progress types and tracker.
- [ ] Implement the JSONL writer.
- [ ] Implement marker cancellation.
- [ ] Run the 20-pass focused GREEN loop.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 5:

- [ ] Add fingerprint golden vectors.
- [ ] Add the bundle-key mutation table.
- [ ] Add capture mutation cases and run focused RED.
- [ ] Implement `CanonicalHasher`.
- [ ] Implement same-handle capture.
- [ ] Implement source fingerprinting.
- [ ] Implement the bundle key.
- [ ] Run focused GREEN.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 6:

- [ ] Add the grammar table.
- [ ] Add protocol-failure result cases.
- [ ] Add reservation cases.
- [ ] Add the no-clobber fault table and run focused RED.
- [ ] Implement argument parsing.
- [ ] Implement bounded request reading.
- [ ] Implement result reservation.
- [ ] Implement hard-link publication.
- [ ] Implement the service runner and binary wiring.
- [ ] Run focused GREEN.
- [ ] Run the version regression.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 7:

- [ ] Add the typed manifest fixture.
- [ ] Add the manifest validation table.
- [ ] Add the verifier adversarial table and run focused RED.
- [ ] Implement private manifest/Wire conversion.
- [ ] Implement key reconstruction.
- [ ] Implement the bounded exact-tree verifier.
- [ ] Add relocation proof.
- [ ] Run focused GREEN.
- [ ] Run workspace doc tests.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 8:

- [ ] Add the staging cancellation/fault table.
- [ ] Add destination and cleanup tables and run focused RED.
- [ ] Implement private staging create/write.
- [ ] Implement manifest-last finalize.
- [ ] Implement the completed-state API.
- [ ] Implement stale staging cleanup.
- [ ] Implement fixture services.
- [ ] Run core GREEN.
- [ ] Run CLI transport GREEN.
- [ ] Run fmt.
- [ ] Run clippy.
- [ ] Run the workspace test.

Task 9:

- [ ] Implement the native static checker.
- [ ] Implement native mutation fixtures and prove aggregate RED.
- [ ] Implement the aggregate and prove static GREEN.
- [ ] Implement workflow checker fixtures and prove workflow RED.
- [ ] Add the CI step and prove workflow GREEN.
- [ ] Run all serial Phase 1 gates.

For every arrow-separated action above, the task report records the exact file changed or command run and its observed RED/GREEN result. Specification review, code-quality review and commit remain three separate final checkboxes in each Task section.

---

### Task 1: Pin the Rust workspace and implement the version handshake

**Files:**
- Modify: `mise.toml`
- Modify: `AGENTS.md`
- Create: `native/Cargo.toml`
- Create: `native/Cargo.lock`
- Create: `native/README.md`
- Create: `native/crates/open2jam-core/Cargo.toml`
- Create: `native/crates/open2jam-core/src/lib.rs`
- Create: `native/crates/open2jam-core/src/version.rs`
- Create: `native/crates/open2jam-cli/Cargo.toml`
- Create: `native/crates/open2jam-cli/src/main.rs`
- Create: `native/crates/open2jam-cli/tests/version_command.rs`
- Create: `rewrite/tools/test_native_workspace.sh`

**Interfaces:**
- Consumes: Phase 0 clean HEAD and mise runtime rules.
- Produces: `open2jam_core::version::VersionInfo`, binary `open2jam-converter version`, Rust 1.96.1 workspace and lockfile used by every later task.

- [ ] **Step 1: Create the compilable RED workspace and version E2E**

Add `rust = "1.96.1"` under `[tools]` in `mise.toml`. Create the workspace with this exact dependency boundary:

```toml
[workspace]
members = [
  "crates/open2jam-core",
  "crates/open2jam-cli",
]
resolver = "3"

[workspace.package]
version = "0.1.0"
edition = "2024"
rust-version = "1.96.1"
license = "Artistic-2.0"

[workspace.dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
sha2 = "0.10"
```

`open2jam-core/Cargo.toml`:

```toml
[package]
name = "open2jam-core"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true

[dependencies]
serde.workspace = true
serde_json.workspace = true
```

`open2jam-cli/Cargo.toml`:

```toml
[package]
name = "open2jam-cli"
version.workspace = true
edition.workspace = true
rust-version.workspace = true
license.workspace = true

[[bin]]
name = "open2jam-converter"
path = "src/main.rs"

[dependencies]
open2jam-core = { path = "../open2jam-core" }
serde_json.workspace = true
```

Create the temporary RED core crate root exactly as:

```rust
#![forbid(unsafe_code)]
```

Add this exact RED executable body, then write `version_command.rs` to require the version stdout shown below and empty stderr. Do not create `native/Cargo.lock` by hand:

```rust
#![forbid(unsafe_code)]

fn main() {
    eprintln!("usage: open2jam-converter version|catalog|bundle");
    std::process::exit(2);
}
```

`version_command.rs` is exactly:

```rust
use std::process::Command;

#[test]
fn version_command_emits_the_frozen_handshake() {
    let output = Command::new(env!("CARGO_BIN_EXE_open2jam-converter"))
        .arg("version")
        .output()
        .expect("version command must start");

    assert!(output.status.success());
    assert_eq!(
        output.stdout,
        b"{\"schemaVersion\":1,\"converterVersion\":\"0.1.0\",\"protocolSchemaVersion\":1,\"catalogSchemaVersion\":2,\"bundleSchemaVersion\":2,\"catalogFormats\":[],\"bundleFormats\":[]}\n"
    );
    assert!(output.stderr.is_empty());
}
```

Expected stdout after GREEN:

```json
{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}
```

- [ ] **Step 2: Install Rust and generate the initial lockfile**

Run:

```bash
mise install
mise exec -- rustc --version
mise exec -- cargo generate-lockfile --manifest-path native/Cargo.toml
test -f native/Cargo.lock
```

Expected: exit `0`, `rustc 1.96.1`, and a generated `native/Cargo.lock`.

- [ ] **Step 3: Run the behavioral RED test**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test version_command --locked
```

Expected: FAIL specifically in `version_command_emits_the_frozen_handshake` because `open2jam-converter version` exits `2`; crate roots, dependencies and lockfile must already be valid.

- [ ] **Step 4: Implement the version contract**

Create `open2jam-core/src/lib.rs`:

```rust
#![forbid(unsafe_code)]

pub mod version;
```

Create `version.rs`:

```rust
use serde::{Deserialize, Serialize};

pub const PROTOCOL_SCHEMA_VERSION: u16 = 1;
pub const CATALOG_SCHEMA_VERSION: u16 = 2;
pub const BUNDLE_SCHEMA_VERSION: u16 = 2;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct VersionInfo {
    pub schema_version: u16,
    pub converter_version: String,
    pub protocol_schema_version: u16,
    pub catalog_schema_version: u16,
    pub bundle_schema_version: u16,
    pub catalog_formats: Vec<String>,
    pub bundle_formats: Vec<String>,
}

impl VersionInfo {
    pub fn current() -> Self {
        Self {
            schema_version: 1,
            converter_version: env!("CARGO_PKG_VERSION").to_owned(),
            protocol_schema_version: PROTOCOL_SCHEMA_VERSION,
            catalog_schema_version: CATALOG_SCHEMA_VERSION,
            bundle_schema_version: BUNDLE_SCHEMA_VERSION,
            catalog_formats: Vec::new(),
            bundle_formats: Vec::new(),
        }
    }
}
```

Implement `main.rs` with exact command matching, one-line compact JSON, and exit code `2` for any non-`version` invocation. Do not advertise a format before its importer exists.

```rust
#![forbid(unsafe_code)]

use std::ffi::OsStr;
use std::io::{self, Write};

use open2jam_core::version::VersionInfo;

fn main() {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == OsStr::new("version") {
        let stdout = io::stdout();
        let mut output = stdout.lock();
        if let Err(error) = serde_json::to_writer(&mut output, &VersionInfo::current())
            .and_then(|_| output.write_all(b"\n").map_err(serde_json::Error::io))
        {
            eprintln!("version output failed: {error}");
            std::process::exit(4);
        }
        return;
    }
    eprintln!("usage: open2jam-converter version|catalog|bundle");
    std::process::exit(2);
}
```

- [ ] **Step 5: Add the workspace smoke gate and developer commands**

`rewrite/tools/test_native_workspace.sh` must assert:

```text
rust 1.96.1 is declared exactly once in mise.toml
workspace members are exactly open2jam-core and open2jam-cli
edition is 2024 and resolver is 3
Cargo.lock exists
open2jam-converter version output is exact
bare cargo/rustc invocations are absent from repository native gates
```

Use this complete script body:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'native workspace contract failed: %s\n' "$1" >&2
  exit 1
}

rust_count=$(rg -n '^rust = "1\.96\.1"$' mise.toml | wc -l | tr -d ' ')
[[ "$rust_count" == "1" ]] || fail "rust 1.96.1 must appear exactly once"

members=$(awk '
  /^members = \[/ { in_members = 1; next }
  in_members && /^\]/ { in_members = 0; exit }
  in_members {
    gsub(/[",[:space:]]/, "")
    if (length($0) > 0) print
  }
' native/Cargo.toml)
expected_members=$'crates/open2jam-core\ncrates/open2jam-cli'
[[ "$members" == "$expected_members" ]] || fail "workspace members differ"

[[ $(rg -c '^resolver = "3"$' native/Cargo.toml) == "1" ]] || fail "resolver differs"
[[ $(rg -c '^edition = "2024"$' native/Cargo.toml) == "1" ]] || fail "edition differs"
[[ -f native/Cargo.lock ]] || fail "Cargo.lock is missing"

for crate_root in \
  native/crates/open2jam-core/src/lib.rs \
  native/crates/open2jam-cli/src/main.rs; do
  head -n 1 "$crate_root" | rg -qx '#!\[forbid\(unsafe_code\)\]' \
    || fail "unsafe_code is not forbidden in $crate_root"
done

expected='{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}'
actual=$(mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version)
[[ "$actual" == "$expected" ]] || fail "version output differs"

if rg -n '^[[:space:]]*(cargo|rustc)[[:space:]]' rewrite/tools native/README.md; then
  fail "bare cargo or rustc command found"
fi

printf 'native workspace contract passed\n'
```

Add canonical commands to `native/README.md` and the runtime section of `AGENTS.md`:

```bash
mise current
mise install
mise exec -- rustc --version
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

- [ ] **Step 6: Run each GREEN gate exactly**

```bash
bash rewrite/tools/test_native_workspace.sh
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test version_command --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
mise exec -- cargo metadata --manifest-path native/Cargo.toml --locked --format-version 1 >/dev/null
```

Expected: every command exits `0`, `rustc 1.96.1`, exact version output, and `Cargo.lock` remains unchanged.

- [ ] **Step 7: Pass the fresh specification review**

Reviewer checks the exact toolchain/workspace members, `#![forbid(unsafe_code)]`, empty capability arrays, version stdout/stderr bytes, mise-only commands and committed lockfile. Fix every finding and request re-review until `APPROVED`.

- [ ] **Step 8: Pass the fresh code-quality review**

Reviewer checks error handling, exact command matching, output authority, dependency scope and shell-gate false positives. Fix every finding and request re-review until `APPROVED`.

- [ ] **Step 9: Commit**

```bash
git add mise.toml AGENTS.md native rewrite/tools/test_native_workspace.sh
git commit -m "build: add Rust converter workspace"
```

---

### Task 2: Freeze strict protocol primitives and request/result contracts

**Files:**
- Modify: `native/crates/open2jam-core/src/lib.rs`
- Modify: `native/crates/open2jam-core/src/version.rs`
- Modify: `native/crates/open2jam-core/Cargo.toml`
- Modify: `native/Cargo.lock`
- Create: `native/crates/open2jam-core/src/schema.rs`
- Create: `native/crates/open2jam-core/src/digest.rs`
- Create: `native/crates/open2jam-core/src/canonical.rs`
- Create: `native/crates/open2jam-core/src/id.rs`
- Create: `native/crates/open2jam-core/src/path.rs`
- Create: `native/crates/open2jam-core/src/format.rs`
- Create: `native/crates/open2jam-core/src/error.rs`
- Create: `native/crates/open2jam-core/src/protocol.rs`
- Create: `native/crates/open2jam-core/src/json.rs`
- Create: `native/crates/open2jam-core/tests/protocol_contract.rs`
- Create: `native/crates/open2jam-core/tests/fixtures/valid/catalog-request-v1.json`
- Create: `native/crates/open2jam-core/tests/fixtures/valid/bundle-request-v1.json`
- Create: `native/crates/open2jam-core/tests/fixtures/valid/catalog-result-v1.json`
- Create: `native/crates/open2jam-core/tests/fixtures/malformed/unknown-field.json`
- Create: `native/crates/open2jam-core/tests/fixtures/malformed/duplicate-field.json`
- Create: `native/crates/open2jam-core/tests/fixtures/malformed/wrong-schema.json`
- Create: `native/crates/open2jam-core/tests/fixtures/malformed/trailing-data.json`
- Create: `native/crates/open2jam-core/tests/fixtures/malformed/bom.json`

**Interfaces:**
- Consumes: `VersionInfo` and workspace constants from Task 1.
- Produces: schema constants, typed SHA-256 IDs, safe paths, format/source enums, stable errors, `CatalogRequestV1`, `BundleRequestV1`, `CommandResultV1<T>`, strict encode/decode API.

- [ ] **Step 1: Write failing primitive and fixture tests**

Tests must require:

```rust
assert_eq!(Digest::parse("sha256:0000000000000000000000000000000000000000000000000000000000000000")?.to_string(), expected);
assert!(Digest::parse("sha256:ABC").is_err());
assert!(BundleRelativePath::parse("audio/sample.wav").is_ok());
assert!(BundleRelativePath::parse("../sample.wav").is_err());
assert!(BundleRelativePath::parse("C:\\sample.wav").is_err());
assert_eq!(SourceRelativePath::parse("音楽/譜面.osu")?.as_str(), "音楽/譜面.osu");
assert!(SourceRelativePath::parse("../譜面.osu").is_err());
assert!(JobId::parse(".").is_err());
assert!(JobId::parse("..").is_err());
assert!(JobId::parse("job:1").is_err());
assert_eq!(serde_json::to_string(&Format::O2Jam)?, "\"O2JAM\"");
assert_eq!(ErrorCode::MissingAsset.as_str(), "MISSING_ASSET");
```

Load every valid/malformed fixture. Valid fixtures must round-trip to compact JSON plus one LF; malformed fixtures must return `INVALID_REQUEST` or `UNSUPPORTED_SCHEMA` without panic.

Use these exact valid fixture payloads. `catalog-result-v1.json` is `CommandResultV1<CatalogOutputV1>`.

```json
{"schemaVersion":1,"jobId":"job-001","command":"CATALOG","roots":["/tmp/open2jam-songs"],"previousIndexPath":null,"stagingRoot":"/tmp/open2jam-staging","cancelMarkerPath":"/tmp/open2jam-cancel/job-001"}
```

```json
{"schemaVersion":1,"jobId":"job-002","command":"BUNDLE","chartId":"chart:sha256:0000000000000000000000000000000000000000000000000000000000000000","sourcePath":"/tmp/open2jam-songs/chart.vos","sourceKind":"VOS","selector":{"kind":"VOS_CHART","index":0},"stagingRoot":"/tmp/open2jam-staging","cancelMarkerPath":"/tmp/open2jam-cancel/job-002","soundfont":{"path":"/tmp/open2jam-assets/GeneralUser-GS.sf2","version":"2.0.3","sha256":"sha256:9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe"},"staticAssetsVersion":"open2jam-gameplay-assets-v1"}
```

```json
{"schemaVersion":1,"jobId":"job-001","command":"CATALOG","status":"SUCCEEDED","output":{"catalogPath":"/tmp/open2jam-staging/catalog-v2.json","sourceCount":1,"songCount":1,"chartCount":1,"rejectedSourceCount":0},"error":null}
```

Malformed fixture bytes are exact: unknown-field adds `"unexpected":true`; duplicate-field repeats `"schemaVersion":1`; wrong-schema replaces it with `2`; trailing-data appends `x` after the closing brace and LF; BOM prefixes bytes `EF BB BF` to the otherwise valid catalog request.

Add `sha2.workspace = true` to `open2jam-core/Cargo.toml`, then refresh the lockfile before the RED test so dependency resolution is not the failure reason:

```bash
mise exec -- cargo generate-lockfile --manifest-path native/Cargo.toml
test -f native/Cargo.lock
```

- [ ] **Step 2: Run protocol tests and verify RED**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test protocol_contract --locked
```

Expected: FAIL because the protocol modules and public types do not exist.

- [ ] **Step 3: Implement exact schema, format, digest, ID, and path types**

`sha2.workspace = true` was added and locked in Step 1, where hashing first becomes production code.

`schema.rs`:

```rust
pub const PROTOCOL_SCHEMA_VERSION: u16 = 1;
pub const REQUEST_SCHEMA_VERSION: u16 = 1;
pub const RESULT_SCHEMA_VERSION: u16 = 1;
pub const PROGRESS_SCHEMA_VERSION: u16 = 1;
pub const CATALOG_SCHEMA_VERSION: u16 = 2;
pub const BUNDLE_SCHEMA_VERSION: u16 = 2;
pub const GAMEPLAY_SCHEMA_VERSION: u16 = 2;
pub const AUDIO_MANIFEST_SCHEMA_VERSION: u16 = 2;
pub const ID_ALGORITHM_VERSION: u16 = 1;
pub const SOURCE_FINGERPRINT_VERSION: u16 = 1;
pub const BUNDLE_KEY_ALGORITHM_VERSION: u16 = 1;
pub const STATIC_ASSETS_VERSION: &str = "open2jam-gameplay-assets-v1";
```

`format.rs`:

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Format {
    Vos,
    #[serde(rename = "O2JAM")]
    O2Jam,
    OsuMania,
    Bundle,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum SourceKind { Vos, Ojn, Osu, Osz, BundleV2 }
```

`Digest` must store `[u8; 32]`, serialize as the literal prefix `sha256:` followed by exactly 64 lowercase hex digits, and reject uppercase, wrong prefix, wrong length, or non-hex. `SourceId`, `SongId`, `ChartId`, `SampleId`, `SourceFingerprint`, and `BundleKey` must remain distinct newtypes. IDs use the exact prefixes `source:sha256:`, `song:sha256:`, `chart:sha256:`, `sample:sha256:` followed by 64 lowercase digits; fingerprints and bundle keys use `sha256:` plus 64 lowercase digits.

`JobId` is not content-addressed and is used as one portable filename component. It accepts `1..=128` ASCII characters from `[A-Za-z0-9._-]`, requires the first character to be alphanumeric, rejects `.`/`..`, separators, colon, controls, trailing dot/space, and case-insensitive Windows reserved basenames `CON`, `PRN`, `AUX`, `NUL`, `COM1..COM9`, `LPT1..LPT9`. It serializes transparently. Tests prove every rejected value before Task 8 joins it into a path.

Move the schema constants introduced by Task 1 out of `version.rs`: `version.rs` imports them from `schema.rs`. Change `VersionInfo.catalog_formats` and `VersionInfo.bundle_formats` from `Vec<String>` to `Vec<Format>`; their serialized empty arrays remain byte-identical.

`BundleRelativePath::parse` must accept only `[A-Za-z0-9][A-Za-z0-9._/-]*`, reject components `.`/`..`, `//`, leading/trailing slash, backslash, colon, NUL, and expose a slash-preserving string. `SourceRelativePath::parse` accepts exact non-normalized UTF-8 code points but rejects absolute/drive-prefixed paths, leading/trailing slash, backslash, NUL, empty/`.`/`..` components; it is used only for paths inside a trusted source package. `AbsoluteSourcePath` must require a non-empty absolute UTF-8 path, preserve exact code points, reject NUL and lexical `.`/`..`, and never enter an identity hash.

Implement `CanonicalHasher` in this task so ID and later bundle algorithms share one framing implementation. Integers are big-endian; strings and bytes have a `u64` byte-length prefix. `SourceId` remains a gameplay-correctness identity derived from source kind plus strong `SourceFingerprint`; it is deliberately separate from catalog grouping identity.

The following is the exact public signature contract, not a literal Rust source fragment:

```text
derive_source_id(kind: SourceKind, source: &SourceFingerprint) -> SourceId
derive_sample_id(content_sha256: &Digest) -> SampleId

SongIdentity::vos(package_path: SourceRelativePath, identity_title: String) -> Result<SongIdentity, CoreError>
SongIdentity::ojn_file(file_path: SourceRelativePath) -> SongIdentity
SongIdentity::osu_beatmap_set(package_path: SourceRelativePath) -> SongIdentity
SongIdentity::osz_package(package_path: SourceRelativePath) -> SongIdentity
SongIdentity::bundle_declared(song_id: SongId) -> SongIdentity
SongIdentity::song_id(&self) -> SongId

ChartIdentity::vos(index: u8) -> Result<ChartIdentity, CoreError>
ChartIdentity::ojn(index: u8) -> Result<ChartIdentity, CoreError>
ChartIdentity::osu(relative_path: SourceRelativePath) -> ChartIdentity
ChartIdentity::bundle_declared(chart_id: ChartId) -> ChartIdentity
ChartIdentity::from_selector(selector: ChartSelector) -> Result<ChartIdentity, CoreError>
ChartIdentity::selector(&self) -> ChartSelector
ChartIdentity::chart_id(&self, song_id: &SongId) -> ChartId
```

`SongIdentity` is an opaque validated wrapper over private variants `Vos { packagePath, identityTitle }`, `OjnFile { filePath }`, `OsuBeatmapSet { packagePath }`, `OszPackage { packagePath }`, and `BundleDeclared { songId }`. `identityTitle` is the parser's canonical VOS identity title, not editable display/search text. `ChartIdentity` is an opaque validated wrapper over private variants `Vos { index }`, `Ojn { index }`, `Osu { relativePath }`, and `BundleDeclared { chartId }`. VOS index is only `0`; OJN is `0..=2`.

Both identity wrappers implement `Serialize` normally and `Deserialize` only through private `SongIdentityWire` / `ChartIdentityWire` plus `TryFrom`, reusing the public constructors. Unknown fields, empty VOS identity title, wrong index and traversal path fail with `INVALID_REQUEST`; no public enum variant or field permits bypass.

Freeze the only valid compatibility matrix:

| Product Format | SourceKind | SongIdentity | ChartIdentity / ChartSelector |
|---|---|---|---|
| `VOS` | `VOS` | `Vos` | `Vos` / `VOS_CHART` |
| `O2JAM` | `OJN` | `OjnFile` | `Ojn` / `OJN_CHART` |
| `OSU_MANIA` | `OSU` | `OsuBeatmapSet` | `Osu` / `OSU_BEATMAP` |
| `OSU_MANIA` | `OSZ` | `OszPackage` | `Osu` / `OSU_BEATMAP` |
| `BUNDLE` | `BUNDLE_V2` | `BundleDeclared` | `BundleDeclared` / `BUNDLE_CHART` |

`Song::new` validates the complete row, including every Chart identity. `BundleRequestV1::validate` enforces the `SourceKind -> ChartSelector` columns, and Bundle-declared Chart ID equality. Private Wire conversions reuse the same checks. Table-driven tests accept exactly these five rows and reject every cross-product mismatch, including `VOS + OJN_CHART`, `O2JAM Song + Vos Chart`, and `BUNDLE_V2 + OSU_BEATMAP`.

Domains are exact ASCII `open2jam.source-id.v1\0`, `open2jam.song-id.v1\0`, `open2jam.chart-id.v1\0`, and `open2jam.sample-id.v1\0`. Canonical `u16` tags are frozen: `SourceKind` is `VOS=1`, `OJN=2`, `OSU=3`, `OSZ=4`, `BUNDLE_V2=5`; non-Bundle `SongIdentity` is `VOS=1`, `OJN_FILE=2`, `OSU_BEATMAP_SET=3`, `OSZ_PACKAGE=4`; non-Bundle `ChartIdentity` is `VOS=1`, `OJN=2`, `OSU=3`. Non-Bundle identities frame `ID_ALGORITHM_VERSION`, kind tag and the exact fields above. `BundleDeclared` returns its declared full ID byte-for-byte and is never hashed a second time. `derive_source_id` frames the source-kind tag and full source fingerprint; `derive_sample_id` frames the full content digest.

Tests freeze exact golden vectors and require: VOS package/title mutation sensitivity; one OJN file grouping three indices; one osu directory or OSZ package grouping multiple beatmaps; same title in different packages remaining distinct; display title/search key mutation not changing identity; root relocation preserving root-relative identity; and Bundle-declared Song/Chart IDs remaining byte-identical.

- [ ] **Step 4: Implement stable errors and strict JSON**

`ErrorCode` must serialize exactly:

```rust
pub enum ErrorCode {
    UnsupportedFormat,
    CorruptChart,
    MissingCompanion,
    MissingAsset,
    AudioDecodeFailed,
    SoundfontFailed,
    OutOfSpace,
    CacheCorrupt,
    ConverterCrashed,
    Cancelled,
    InternalError,
    InvalidRequest,
    UnsupportedSchema,
    SourceChanged,
}
```

Use `SCREAMING_SNAKE_CASE`. `ErrorInfo` is `{ code, message, sourcePath?, context }`, where `context` is a `BTreeMap<String,String>`. Its fields are private; strict `ErrorInfoWire -> TryFrom` and read-only getters reject NUL in message/context before a result becomes valid.

Define the internal error boundary without another dependency:

```rust
pub struct CoreError {
    code: ErrorCode,
    message: String,
    source_path: Option<AbsoluteSourcePath>,
    context: BTreeMap<String, String>,
}

impl CoreError {
    pub fn new(code: ErrorCode, message: impl Into<String>) -> Self {
        let message = message.into();
        if message.contains('\0') {
            return Self {
                code: ErrorCode::InternalError,
                message: "error message contained NUL".to_owned(),
                source_path: None,
                context: BTreeMap::new(),
            };
        }
        Self { code, message, source_path: None, context: BTreeMap::new() }
    }

    pub fn code(&self) -> ErrorCode { self.code }
    pub fn message(&self) -> &str { &self.message }
    pub fn source_path(&self) -> Option<&AbsoluteSourcePath> { self.source_path.as_ref() }
    pub fn context(&self) -> &BTreeMap<String, String> { &self.context }
}

pub enum ProtocolError {
    Invalid(CoreError),
    Io {
        code: ErrorCode,
        source: std::io::Error,
    },
    Json {
        code: ErrorCode,
        source: serde_json::Error,
    },
}

impl ProtocolError {
    pub fn code(&self) -> ErrorCode {
        match self {
            Self::Invalid(error) => error.code(),
            Self::Io { code, .. } | Self::Json { code, .. } => *code,
        }
    }
}
```

Implement `Display`, `std::error::Error`, conversion from `CoreError` to `ErrorInfo`, and a `with_context` builder. `with_context` handles NUL in key/value with the same fixed `INTERNAL_ERROR` fallback; it never retains the rejected bytes. Strict request syntax/UTF-8/unknown/duplicate/trailing failures use the `Json` variant with code `INVALID_REQUEST`; schema mismatch uses `Invalid(CoreError)` with code `UNSUPPORTED_SCHEMA`; callers must choose an explicit stable code for every I/O boundary. Tests assert `error.code()` for every malformed fixture, require `bad\u0000message` in a wire `ErrorInfo` to fail strict decoding, and require `CoreError::new(CorruptChart, "bad\0message")` to encode without NUL as `INTERNAL_ERROR`. No error path may discard the stable `ErrorCode`.

Expose:

```rust
pub trait Contract: serde::Serialize + serde::de::DeserializeOwned {
    fn validate(&self) -> Result<(), ProtocolError>;
}
```

```text
decode_contract<T: Contract>(bytes: &[u8]) -> Result<T, ProtocolError>
encode_contract<T: Contract>(value: &T) -> Result<Vec<u8>, ProtocolError>
```

`decode_contract` rejects UTF-8 BOM, invalid UTF-8, unknown/duplicate struct fields, trailing non-whitespace and schema mismatch. `encode_contract` validates first, uses compact `serde_json::to_vec`, and appends exactly one `\n`.

- [ ] **Step 5: Implement request/result envelopes**

Use these exact public shapes:

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CatalogRequestV1 {
    pub schema_version: u16,
    pub job_id: JobId,
    pub command: Command,
    pub roots: Vec<AbsoluteSourcePath>,
    pub previous_index_path: Option<AbsoluteSourcePath>,
    pub staging_root: AbsoluteSourcePath,
    pub cancel_marker_path: AbsoluteSourcePath,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleRequestV1 {
    pub schema_version: u16,
    pub job_id: JobId,
    pub command: Command,
    pub chart_id: ChartId,
    pub source_path: AbsoluteSourcePath,
    pub source_kind: SourceKind,
    pub selector: ChartSelector,
    pub staging_root: AbsoluteSourcePath,
    pub cancel_marker_path: AbsoluteSourcePath,
    pub soundfont: SoundFontRequest,
    pub static_assets_version: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Command { Catalog, Bundle }

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    tag = "kind",
    rename_all = "SCREAMING_SNAKE_CASE",
    rename_all_fields = "camelCase",
    deny_unknown_fields
)]
pub enum ChartSelector {
    VosChart { index: u8 },
    OjnChart { index: u8 },
    OsuBeatmap { relative_path: SourceRelativePath },
    BundleChart { chart_id: ChartId },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SoundFontRequest {
    pub path: AbsoluteSourcePath,
    pub version: String,
    pub sha256: Digest,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum JobStatus { Succeeded, Failed, Cancelled }

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CommandResultV1<T> {
    pub schema_version: u16,
    pub job_id: Option<JobId>,
    pub command: Command,
    pub status: JobStatus,
    pub output: Option<T>,
    pub error: Option<ErrorInfo>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CatalogOutputV1 {
    pub catalog_path: AbsoluteSourcePath,
    pub source_count: u64,
    pub song_count: u64,
    pub chart_count: u64,
    pub rejected_source_count: u64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleOutputV1 {
    pub staging_path: AbsoluteSourcePath,
    pub bundle_key: BundleKey,
    pub manifest_path: AbsoluteSourcePath,
}
```

Validation enforces matching command, schema `1`, pairwise-distinct request/progress/result/cancel paths at the CLI layer, unique sorted roots, `ChartIdentity::from_selector` success, the exact Task 2 `SourceKind -> ChartSelector` compatibility row, `BUNDLE_CHART.chartId == request.chartId`, `SUCCEEDED` output XOR `FAILED/CANCELLED` error, and `CANCELLED` code for cancelled status. `jobId` is present for every successfully decoded request. It may be `null` only when `status=FAILED`, `output=null`, and `error.code` is `INVALID_REQUEST` or `UNSUPPORTED_SCHEMA`; this is the machine-readable protocol-failure envelope used when strict decoding cannot recover a trustworthy job ID.

- [ ] **Step 6: Run malformed matrix and workspace regression**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test protocol_contract --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`, every malformed fixture has its stable code, valid bytes round-trip exactly, Task 1 version output is unchanged, and `Cargo.lock` does not change during `--locked` verification.

- [ ] **Step 7: Pass the fresh specification review**

Reviewer checks every schema constant, enum spelling, fixture byte, strict decode failure code, `JobId` path-component safety, Unicode source path separation, ID domain/input framing and result-envelope invariant. Fix every finding and request re-review until `APPROVED`.

- [ ] **Step 8: Pass the fresh code-quality review**

Reviewer checks manual hex/framing correctness, serde duplicate/unknown handling, invariant-preserving newtypes, error-source retention and absence of absolute paths from IDs. Fix every finding and request re-review until `APPROVED`.

- [ ] **Step 9: Commit the reviewed contract freeze**

```bash
git add native/Cargo.lock native/crates/open2jam-core
git commit -m "feat: freeze native protocol contracts"
```

This commit is the Wave A base. Both reviews must be approved before Task 3 or Task 4 starts.

---

### Task 3: Define the normalized Song, Chart, Event, and Sample domain

**Files:**
- Modify: `native/crates/open2jam-core/src/lib.rs`
- Create: `native/crates/open2jam-core/src/domain/mod.rs`
- Create: `native/crates/open2jam-core/src/domain/song.rs`
- Create: `native/crates/open2jam-core/src/domain/chart.rs`
- Create: `native/crates/open2jam-core/src/domain/event.rs`
- Create: `native/crates/open2jam-core/src/domain/sample.rs`
- Create: `native/crates/open2jam-core/tests/domain_contract.rs`
- Create: `native/crates/open2jam-core/tests/golden_evidence.rs`

**Interfaces:**
- Consumes: Task 2 `Format`, `SourceKind`, typed IDs, safe paths and stable errors.
- Produces: parser-independent normalized domain used by Phase 2/3 importers and Task 7 bundle manifest.

- [ ] **Step 1: Write failing domain invariant tests**

Cover these exact invariants:

```rust
assert_eq!(Lane::new(0, KeyCount::SEVEN)?.index(), 0);
assert!(Lane::new(7, KeyCount::SEVEN).is_err());
assert!(Note::new(
    lane,
    TimeMicros(1_000),
    Some(TimeMicros(999)),
    None,
    100,
    0,
    0,
).is_err());
assert!(Note::new(lane, TimeMicros(1_000), None, None, 101, 0, 0).is_err());
assert!(Note::new(lane, TimeMicros(1_000), None, None, 100, 101, 0).is_err());
assert!(TimingPoint::new(TimeMicros(0), 0, 1, 4, 0).is_err());
assert!(Chart::new(summary, timing, notes, autoplay, bga, samples).is_err());
```

The last assertion must fail on an unsorted event stream, a missing referenced `SampleId`, duplicate sample IDs, non-increasing `sourceOrder` ties, or a chart whose `keys` is not `7`.

- [ ] **Step 2: Write the golden evidence tests and verify RED**

Test-only structs may deserialize:

```text
rewrite/golden/java-migration/manifest.json
rewrite/golden/java-migration/expected/parser-oracle.json
rewrite/golden/java-migration/expected/vos/catalog.json
rewrite/golden/java-migration/expected/ojn/catalog.json
rewrite/golden/java-migration/expected/osu/osu-catalog.json
rewrite/golden/java-migration/expected/osu/osz-catalog.json
```

Require 27 logical cases, VOS/O2Jam/osu distribution `7/10/10`, `18 ACCEPT`, `9 REJECT`, and errors `CORRUPT_CHART`, `MISSING_ASSET`, `MISSING_COMPANION`, `UNSUPPORTED_FORMAT`. Require the representative OJN catalog's three Java chart entries to become one `Song` with three `ChartSummary` values. Assert that no new `SongId` or `ChartId` equals the legacy truncated Java ID.

Run:

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test domain_contract --test golden_evidence --locked
```

Expected: FAIL because the normalized domain modules do not exist.

- [ ] **Step 3: Implement the parser-independent domain types**

Use integer time and rational tempo, never `f32`/`f64` in the normalized contract:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(transparent)]
pub struct TimeMicros(pub u64);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct RationalMicrosPerBeat {
    numerator: u64,
    denominator: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(transparent)]
pub struct KeyCount(u8);

impl KeyCount {
    pub const SEVEN: Self = Self(7);
    pub fn get(self) -> u8 { self.0 }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize)]
#[serde(transparent)]
pub struct Lane(u8);

impl Lane {
    pub fn new(index: u8, keys: KeyCount) -> Result<Self, CoreError> {
        if index < keys.get() {
            Ok(Self(index))
        } else {
            Err(CoreError::new(ErrorCode::CorruptChart, "lane exceeds key count"))
        }
    }
    pub fn index(self) -> u8 { self.0 }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TimingPoint {
    at: TimeMicros,
    micros_per_beat: RationalMicrosPerBeat,
    meter_numerator: u8,
    source_order: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Note {
    lane: Lane,
    start: TimeMicros,
    end: Option<TimeMicros>,
    sample_id: Option<SampleId>,
    volume: u8,
    pan: i16,
    source_order: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AutoplayEvent {
    at: TimeMicros,
    sample_id: SampleId,
    volume: u8,
    pan: i16,
    source_order: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BgaEvent {
    at: TimeMicros,
    asset_id: String,
    source_order: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Sample {
    sample_id: SampleId,
    audio_kind: AudioKind,
    channels: u8,
    sample_rate: u32,
    source_order: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Chart {
    summary: ChartSummary,
    timing: Vec<TimingPoint>,
    notes: Vec<Note>,
    autoplay: Vec<AutoplayEvent>,
    bga: Vec<BgaEvent>,
    samples: Vec<Sample>,
}
```

Freeze these constructors exactly:

```text
RationalMicrosPerBeat::new(numerator: u64, denominator: u32) -> Result<RationalMicrosPerBeat, CoreError>
TimingPoint::new(at: TimeMicros, numerator: u64, denominator: u32, meter_numerator: u8, source_order: u32) -> Result<TimingPoint, CoreError>
Note::new(lane: Lane, start: TimeMicros, end: Option<TimeMicros>, sample_id: Option<SampleId>, volume: u8, pan: i16, source_order: u32) -> Result<Note, CoreError>
Chart::new(summary: ChartSummary, timing: Vec<TimingPoint>, notes: Vec<Note>, autoplay: Vec<AutoplayEvent>, bga: Vec<BgaEvent>, samples: Vec<Sample>) -> Result<Chart, CoreError>
```

Add `AutoplayEvent`, `BgaEvent`, and `Sample` with typed IDs, integer volume `0..=100`, pan `-100..=100`, exact `sourceOrder`, and a closed `AudioKind` enum `WAV|OGG|MP3|MIDI_RENDERED`. Notes carry their own O2Jam volume/pan semantics even when no sample is attached; importers use `100/0` for formats without overrides. `Chart::new` sorts nothing silently; it validates canonical order and returns `CORRUPT_CHART` on invalid input.

Task 2 already gives `SongIdentity` and `ChartIdentity` private variants plus validated serde. In this task, every other invariant-bearing type has private fields and implements `Deserialize` only through a private `*Wire` DTO plus `TryFrom<*Wire>`, delegating to the same public constructor used by importers. This applies to `RationalMicrosPerBeat`, `KeyCount`, `Lane`, `TimingPoint`, `Note`, `AutoplayEvent`, `BgaEvent`, `Sample`, `ChartSummary`, `Song`, and `Chart`; direct derived `Deserialize` on those types is forbidden. Add one JSON bypass test per invariant, including invalid identity/format pairs, denominator `0`, keys other than `7`, lane `7`, end before start, volume/pan overflow, unsorted events and missing sample references.

Use these grouping surfaces:

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields, try_from = "SongWire")]
pub struct Song {
    song_id: SongId,
    identity: SongIdentity,
    source_id: SourceId,
    format: Format,
    title: String,
    source_basename: String,
    artist: Option<String>,
    genre: Option<String>,
    cover_asset: Option<BundleRelativePath>,
    charts: Vec<ChartSummary>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    deny_unknown_fields,
    try_from = "ChartSummaryWire"
)]
pub struct ChartSummary {
    chart_id: ChartId,
    song_id: SongId,
    source_id: SourceId,
    identity: ChartIdentity,
    difficulty_name: String,
    level: Option<u16>,
    keys: KeyCount,
    bpm_milli: Option<u32>,
    duration_ms: u64,
    note_count: u64,
    charter: Option<String>,
}
```

Construction surfaces are exact:

```text
ChartSummary::new(
    song_identity: &SongIdentity,
    source_id: SourceId,
    identity: ChartIdentity,
    difficulty_name: String,
    level: Option<u16>,
    bpm_milli: Option<u32>,
    duration_ms: u64,
    note_count: u64,
    charter: Option<String>,
) -> Result<ChartSummary, CoreError>

Song::new(
    identity: SongIdentity,
    source_id: SourceId,
    format: Format,
    title: String,
    source_basename: String,
    artist: Option<String>,
    genre: Option<String>,
    cover_asset: Option<BundleRelativePath>,
    charts: Vec<ChartSummary>,
) -> Result<Song, CoreError>
```

`ChartSelector` is produced only by the Task 2 `ChartIdentity`. `ChartSummary::new` stores `song_id = song_identity.song_id()`, `chart_id = identity.chart_id(song_id)`, and `keys = KeyCount::SEVEN`; `selector()` delegates to `identity.selector()`, so callers cannot inject a redundant selector. `Song::new` stores `song_id = identity.song_id()`, requires the complete Task 2 Format/SongIdentity/ChartIdentity compatibility row, a non-empty title/basename, one or more unique selector/chart pairs, every Chart's stored Song ID to match, and stable selector order. Bundle identities preserve declared Song/Chart IDs; other formats use the frozen derivation.

Expose read-only getters only:

```text
Song::{song_id, identity, source_id, format, title, source_basename, artist, genre, cover_asset, charts}
ChartSummary::{chart_id, song_id, source_id, identity, selector, difficulty_name, level, keys, bpm_milli, duration_ms, note_count, charter}
```

Add dependency-free `compile_fail` rustdoc examples showing an external caller cannot construct either type with a struct literal or mutate `song_id`, `chart_id`, `keys`, identity or chart ordering.

Add grouping tests for: VOS package/title identity with multiple Chart summaries; OJN one file with indices `0/1/2`; osu directory and OSZ package with multiple beatmaps; same title/different package separation; display title mutation preserving identity; Bundle-declared IDs preserved byte-for-byte; and root relocation preserving root-relative identity.

- [ ] **Step 4: Keep Java evidence test-only**

Production modules must not contain `legacy`, Java class names, old `sourcePath` ID rules, or v1 catalog structs. `golden_evidence.rs` may define private deserialization structs only for assertions. It must never write or regenerate the Phase 0 corpus.

- [ ] **Step 5: Run focused and workspace GREEN**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test domain_contract --test golden_evidence --locked
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --doc --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
git diff --exit-code -- rewrite/golden/java-migration
```

Expected: every command exits `0`, OJN groups `1 Song / 3 Charts`, all 27 oracle cases are accounted for, and the corpus is unchanged.

- [ ] **Step 6: Pass the fresh specification review**

Reviewer maps every normalized field and constructor to the design and Java evidence, including OJN `1 Song / 3 Charts`, selector-derived IDs, note volume/pan and serde-bypass tests. Fix and re-review to `APPROVED`.

- [ ] **Step 7: Pass the fresh code-quality review**

Reviewer checks private invariants, `TryFrom` reuse, canonical ordering, integer-only timing, error codes and production isolation from Java v1 types. Fix and re-review to `APPROVED`.

- [ ] **Step 8: Commit**

```bash
git add native/crates/open2jam-core/src/domain native/crates/open2jam-core/src/lib.rs native/crates/open2jam-core/tests
git commit -m "feat: define normalized rhythm domain"
```

---

### Task 4: Implement progress, job-state, and cooperative cancellation primitives

**Files:**
- Modify: `native/crates/open2jam-core/src/lib.rs`
- Create: `native/crates/open2jam-core/src/job.rs`
- Create: `native/crates/open2jam-core/src/progress.rs`
- Create: `native/crates/open2jam-core/src/cancellation.rs`
- Create: `native/crates/open2jam-core/tests/progress_contract.rs`
- Create: `native/crates/open2jam-core/tests/cancellation_contract.rs`

**Interfaces:**
- Consumes: Task 2 `JobId`, `Command`, `ErrorCode`, strict JSON encoder and safe absolute paths.
- Produces: `JobState`, `ProgressEventV1`, `ProgressTracker`, `JsonlProgressWriter`, `Cancellation` and `MarkerCancellation` used by Tasks 5, 6 and 8.

- [ ] **Step 1: Write failing state-machine and JSONL tests**

Require these transitions and reject every other edge:

```text
CREATED -> RUNNING -> SUCCEEDED
                   -> FAILED
        -> CANCEL_REQUESTED -> CANCELLED
```

Require sequence `1,2,3`, no gaps/repeats, `completedUnits <= totalUnits`, stable `jobId`/command, append-only one-event-per-line JSON, and `create_new` failure when a progress file already exists. The shared enum includes `CHECK_CACHE` for the later Godot coordinator, but a CLI-owned bundle writer must reject `CHECK_CACHE`, `PRELOAD_STARTUP_AUDIO`, `CREATE_GAMEPLAY`, and `READY`; CLI events begin at `HASH_SOURCES` and may end at `VERIFY_BUNDLE`.

- [ ] **Step 2: Write cancellation boundary tests and verify RED**

Test absent marker, regular marker, symlink marker, directory marker, cancellation between source components, cancellation before output rename, and no source/output mutation after a cancelled checkpoint.

Run:

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test progress_contract --test cancellation_contract --locked
```

Expected: FAIL because progress/cancellation modules do not exist.

- [ ] **Step 3: Implement the exact progress contract**

`job.rs` defines the closed state enum `Created`, `Running`, `CancelRequested`, `Succeeded`, `Failed`, `Cancelled` and opaque `JobStateMachine { state: JobState }`. Its exact public API is:

```text
JobStateMachine::new() -> JobStateMachine
JobStateMachine::state(&self) -> JobState
JobStateMachine::transition(&mut self, next: JobState) -> Result<(), CoreError>
```

`transition` implements only the graph in Step 1 and returns `INTERNAL_ERROR` without changing state for every other edge.

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ProgressPhase {
    DiscoverSources,
    FingerprintSources,
    ParseSources,
    WriteCatalog,
    CatalogReady,
    CheckCache,
    HashSources,
    ParseChart,
    CompileTiming,
    PrepareAudio,
    WriteBundle,
    VerifyBundle,
    PreloadStartupAudio,
    CreateGameplay,
    Ready,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    deny_unknown_fields,
    try_from = "ProgressEventWire"
)]
pub struct ProgressEventV1 {
    schema_version: u16,
    job_id: JobId,
    sequence: u64,
    command: Command,
    phase: ProgressPhase,
    completed_units: u64,
    total_units: u64,
    unit: String,
    current_item: Option<String>,
}
```

Freeze owner validation explicitly:

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProgressOwner { CatalogCli, BundleCli, GodotGameplay }

pub trait ProgressSink {
    fn write(&mut self, event: &ProgressEventV1) -> Result<(), CoreError>;
}

pub struct ProgressTracker<'a> {
    job_id: JobId,
    command: Command,
    owner: ProgressOwner,
    next_sequence: u64,
    sink: &'a mut dyn ProgressSink,
}
```

```text
ProgressPhase::is_allowed_for(self, owner: ProgressOwner) -> bool
ProgressTracker::new(job_id: JobId, command: Command, owner: ProgressOwner, sink: &mut dyn ProgressSink) -> Result<ProgressTracker, CoreError>
ProgressTracker::emit(&mut self, phase: ProgressPhase, completed_units: u64, total_units: u64, unit: String, current_item: Option<String>) -> Result<(), CoreError>
JsonlProgressWriter::create(path: &Path) -> Result<JsonlProgressWriter, CoreError>
```

`CatalogCli` accepts only discovery through `CATALOG_READY`; `BundleCli` accepts only `HASH_SOURCES` through `VERIFY_BUNDLE`; `GodotGameplay` accepts `CHECK_CACHE` and the complete gameplay phase sequence. `ProgressTracker::emit` owns sequence and validates allowed phases for its command/owner. `JsonlProgressWriter::create` uses `OpenOptions::create_new(true).write(true)`, writes canonical JSON + LF, and flushes after each complete event. It never repairs or truncates an existing file.

`ProgressEventV1` is created only by the tracker or private `ProgressEventWire -> TryFrom`; expose read-only getters for every field. Wire decoding rejects zero sequence, wrong schema, empty/NUL unit and `completedUnits > totalUnits`; the consuming boundary separately validates the phase against its supplied `ProgressOwner`.

- [ ] **Step 4: Implement marker cancellation**

```rust
pub trait Cancellation: Send + Sync {
    fn checkpoint(&self) -> Result<(), Cancelled>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Cancelled;

pub struct NeverCancelled;
pub struct MarkerCancellation { marker: PathBuf }
```

`MarkerCancellation` uses `symlink_metadata`: `NotFound` means continue; any existing entry type means cancelled without following it. Map cancellation only to `CANCELLED`, never `INTERNAL_ERROR`.

- [ ] **Step 5: Run GREEN and interruption regressions**

```bash
for iteration in $(seq 1 20); do
  mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test progress_contract --test cancellation_contract --locked
done
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`, all 20 iterations produce byte-identical JSONL, and no test-owned temporary file remains.

- [ ] **Step 6: Pass the fresh specification review**

Reviewer checks the exact state graph, owner/phase matrix including shared `CHECK_CACHE`, contiguous sequence, append-only bytes and cancellation mapping. Fix and re-review to `APPROVED`.

- [ ] **Step 7: Pass the fresh code-quality review**

Reviewer checks transition exhaustiveness, symlink-safe marker behavior, no truncation/repair, deterministic JSONL and cleanup of test-owned temporary roots. Fix and re-review to `APPROVED`.

- [ ] **Step 8: Commit**

```bash
git add native/crates/open2jam-core/src/job.rs native/crates/open2jam-core/src/progress.rs native/crates/open2jam-core/src/cancellation.rs native/crates/open2jam-core/src/lib.rs native/crates/open2jam-core/tests
git commit -m "feat: add native progress and cancellation"
```

---

### Task 5: Implement stable source fingerprints and strong bundle keys

**Files:**
- Modify: `native/crates/open2jam-core/src/lib.rs`
- Modify: `native/crates/open2jam-core/src/canonical.rs`
- Create: `native/crates/open2jam-core/src/source.rs`
- Create: `native/crates/open2jam-core/src/bundle/mod.rs`
- Create: `native/crates/open2jam-core/src/bundle/key.rs`
- Create: `native/crates/open2jam-core/tests/source_fingerprint.rs`
- Create: `native/crates/open2jam-core/tests/bundle_key.rs`

**Interfaces:**
- Consumes: Task 2 digest/ID/schema/path types and Task 4 `Cancellation`.
- Produces: stable file capture, `SourceFingerprint`, `BundleKeyInput`, `compute_source_fingerprint`, `compute_bundle_key` used by Tasks 7 and 8.

- [ ] **Step 1: Write failing hash sensitivity tests**

Require byte-identical output across repeated and reversed caller order. Require a changed primary byte, companion byte, referenced audio byte, role, ordinal, chart ID, chart selector, schema, converter version, SoundFont digest, or static asset version to change the final key. Include a selector-only mutation where `chartId` is held constant to prove the selector is independently framed. Require absolute file relocation with identical bytes/roles to keep the fingerprint and bundle key unchanged.

- [ ] **Step 2: Write source mutation and symlink tests, then verify RED**

Cover symlink input, non-regular input, duplicate `(role, ordinal)`, mutation after `open` but before the first `reader()`, in-place truncate after a partial parser read, atomic pathname replace after open, more than `65,536` components, and cancellation between components. The first-reader test must return `SOURCE_CHANGED` without exposing the handle; the partial-read and replace tests must make `finalize` return `SOURCE_CHANGED`.

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test source_fingerprint --test bundle_key --locked
```

Expected: FAIL because canonical hashing and capture APIs do not exist.

- [ ] **Step 3: Implement length-framed domain-separated hashing**

Extend the Task 2 `CanonicalHasher`; it must expose only typed framing:

```text
CanonicalHasher::new(domain: &[u8]) -> CanonicalHasher
CanonicalHasher::write_u16(&mut self, value: u16)
CanonicalHasher::write_u32(&mut self, value: u32)
CanonicalHasher::write_u64(&mut self, value: u64)
CanonicalHasher::write_bytes(&mut self, value: &[u8])
CanonicalHasher::write_str(&mut self, value: &str)
CanonicalHasher::finish(self) -> Digest
```

Integers are big-endian. `write_bytes` and `write_str` prefix a `u64` byte length. Domains are exact ASCII `open2jam.source-fingerprint.v1\0` and `open2jam.bundle-key.v1\0`. Do not hash JSON or concatenate unframed strings.

- [ ] **Step 4: Implement stable same-handle source capture**

```rust
pub struct SourceComponent {
    pub role: SourceRole,
    pub ordinal: u32,
    pub size_bytes: u64,
    pub content_sha256: Digest,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum SourceRole {
    Primary,
    Companion,
    ReferencedAudio,
    ReferencedAsset,
}

pub struct CapturedSource {
    path: PathBuf,
    file: File,
    opened_identity: FileIdentity,
    opened_size_bytes: u64,
    opened_mtime_seconds: i64,
    opened_mtime_nanoseconds: i64,
    role: SourceRole,
    ordinal: u32,
}
```

On the Phase 1 macOS target, private `FileIdentity` is `{ device: u64, inode: u64 }`; size and `(mtime, mtime_nsec)` also come from `std::os::unix::fs::MetadataExt`. These open-time values are never serialized or hashed. Exact public signatures:

```text
CapturedSource::open(path: &Path, role: SourceRole, ordinal: u32) -> Result<CapturedSource, CoreError>
CapturedSource::reader(&mut self) -> Result<&mut File, CoreError>
CapturedSource::rewind(&mut self) -> Result<(), CoreError>
CapturedSource::finalize(self, cancellation: &dyn Cancellation) -> Result<SourceComponent, CoreError>
capture_source_component(path: &Path, role: SourceRole, ordinal: u32, cancellation: &dyn Cancellation) -> Result<SourceComponent, CoreError>
```

Canonical `SourceRole` `u16` tags are `PRIMARY=1`, `COMPANION=2`, `REFERENCED_AUDIO=3`, `REFERENCED_ASSET=4`; Rust enum discriminant layout is never hashed directly. `CapturedSource::open` rejects symlinks/non-regular files, opens read-only once and records identity, size and modification stamp from that handle. Phase 2/3 parsers accept `&mut CapturedSource` and read only through `reader()?`; reopening `path` is forbidden. `reader()` compares current handle metadata to the open-time snapshot and returns `SOURCE_CHANGED` before exposing bytes on drift. `finalize` compares again before seek/hash, rewinds and hashes the same handle in bounded `64 KiB` chunks with cancellation checkpoints, compares again after hashing, then compares current `symlink_metadata(path)` identity to the opened identity. Any identity/size/mtime drift at those points or pathname replacement returns `SOURCE_CHANGED`. Tests mutate between open/first-reader and after a partial parser read, then require the appropriate boundary to fail; they also cover atomic replacement. Malicious restoration of identical size/mtime is outside the trusted local-file boundary. `capture_source_component` delegates to `open` plus `finalize`. The hash input contains role, ordinal, size and content digest, never absolute path.

- [ ] **Step 5: Implement source fingerprint and bundle key**

```rust
pub struct BundleKeyInput {
    pub bundle_schema_version: u16,
    pub converter_version: String,
    pub static_assets_version: String,
    pub soundfont_sha256: Digest,
    pub song_id: SongId,
    pub chart_id: ChartId,
    pub chart_selector: ChartSelector,
    pub source_fingerprint: SourceFingerprint,
}
```

```text
compute_source_fingerprint(components: &[SourceComponent]) -> Result<SourceFingerprint, CoreError>
compute_bundle_key(input: &BundleKeyInput) -> BundleKey
```

Sort a copy by `(role, ordinal)` and reject duplicates; do not mutate caller order. The source fingerprint frames, in order: `SOURCE_FINGERPRINT_VERSION`, component count as `u32`, then for each component its role tag, ordinal, size and full digest. The bundle key frames, in order: `BUNDLE_KEY_ALGORITHM_VERSION`, bundle schema, converter version, static-assets version, full SoundFont digest, full Song ID digest, full Chart ID digest, canonical selector tag/payload, and full source fingerprint. It does not trust `chartId` as an implicit selector binding. Golden-vector tests freeze one exact expected digest for each algorithm in addition to mutation tests.

- [ ] **Step 6: Run determinism and workspace GREEN**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test source_fingerprint --test bundle_key --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`, exact hashes remain stable, relocation is invariant, every semantic input mutation changes the key, and no unbounded read appears.

- [ ] **Step 7: Pass the fresh specification review**

Reviewer checks every strong-key input, selector-only sensitivity, relocation invariance, same-handle parser boundary, mutation/replace detection, bounds and cancellation points. Fix and re-review to `APPROVED`.

- [ ] **Step 8: Pass the fresh code-quality review**

Reviewer inspects handle/path identity checks, seek/hash error mapping, canonical framing, caller-order preservation, no unbounded reads and no reopened parser path. Fix and re-review to `APPROVED`.

- [ ] **Step 9: Commit**

```bash
git add native/crates/open2jam-core/src/canonical.rs native/crates/open2jam-core/src/source.rs native/crates/open2jam-core/src/bundle native/crates/open2jam-core/src/lib.rs native/crates/open2jam-core/tests
git commit -m "feat: add strong bundle identity"
```

---

### Task 6: Implement native CLI argument and file-transport boundaries

**Files:**
- Modify: `native/crates/open2jam-cli/Cargo.toml`
- Modify: `native/crates/open2jam-cli/src/main.rs`
- Create: `native/crates/open2jam-cli/src/lib.rs`
- Create: `native/crates/open2jam-cli/src/args.rs`
- Create: `native/crates/open2jam-cli/src/io.rs`
- Create: `native/crates/open2jam-cli/src/runner.rs`
- Create: `native/crates/open2jam-cli/tests/args_contract.rs`
- Create: `native/crates/open2jam-cli/tests/file_transport.rs`
- Create: `native/crates/open2jam-cli/tests/cli_contract.rs`

**Interfaces:**
- Consumes: Task 2 request/result/error contracts, Task 4 JSONL progress and cancellation, Task 1 version command.
- Produces: manual exact CLI parser, atomic result writer, stable exit codes, injectable command runner, `catalog` and `bundle` file boundaries without parser-dependent fake success.

- [ ] **Step 1: Write failing CLI matrix tests**

Require exactly:

```text
open2jam-converter version
open2jam-converter catalog --request <file> --progress <file> --result <file>
open2jam-converter bundle --request <file> --progress <file> --result <file>
```

Reject missing, duplicate, unknown or reordered flag/value pairs; extra positional args; same request/progress/result path; symlink output; existing progress/result file; non-existing parent; wrong request command; wrong schema; malformed UTF-8/JSON. Split the authority boundary exactly:

- CLI grammar or unusable request/progress/result path fails before result ownership is established: exit `2`, no created output.
- Once all three paths are valid and the absent result path is reserved, malformed UTF-8/JSON/BOM/unknown/duplicate/trailing data writes `CommandResultV1` with `jobId:null`, `status:FAILED`, `error.code:INVALID_REQUEST`, then exits `2`.
- Wrong schema writes the same envelope with `UNSUPPORTED_SCHEMA`; valid JSON whose command disagrees with the CLI writes `INVALID_REQUEST` and preserves its validated `jobId`.
- Protocol-failure cases do not create a progress file. Tests determine the outcome from exit code plus parsed result bytes, never stderr.

- [ ] **Step 2: Write atomic result and crash-safety tests, then verify RED**

Require result bytes to appear only after complete compact JSON + LF is synced and no-clobber linked into place. Inject failures around the link and directory sync boundaries. Existing result files must never be truncated or replaced, including a target created in the reservation/publication race window.

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test args_contract --test file_transport --test cli_contract --locked
```

Expected: FAIL because CLI transport modules do not exist.

- [ ] **Step 3: Implement manual arguments and stable exit codes**

Do not add `clap`. `open2jam-cli/src/lib.rs` starts with `#![forbid(unsafe_code)]` and exports only `args`, `io`, and `runner`; `main.rs` retains the same crate attribute. Expose:

```rust
pub const EXIT_SUCCESS: u8 = 0;
pub const EXIT_JOB_FAILED: u8 = 1;
pub const EXIT_USAGE_OR_PROTOCOL: u8 = 2;
pub const EXIT_CANCELLED: u8 = 3;
pub const EXIT_INTERNAL: u8 = 4;

pub enum ParsedCommand {
    Version,
    Catalog(JobFiles),
    Bundle(JobFiles),
}

pub struct JobFiles {
    pub request: PathBuf,
    pub progress: PathBuf,
    pub result: PathBuf,
}

pub struct UsageError {
    message: String,
}
```

```text
parse_args(args: impl IntoIterator<Item = OsString>) -> Result<ParsedCommand, UsageError>
UsageError::message(&self) -> &str
UsageError::exit_code(&self) -> u8
```

All three job paths must be absolute after lexical normalization, pairwise distinct and non-symlink. Each parent must already exist and be a non-symlink directory. The input request must be a regular non-symlink file. Progress/result must not exist.

- [ ] **Step 4: Implement atomic result transport**

```rust
pub enum ResultTempScope {
    Job(JobId),
    Protocol(Command),
}

pub trait ResultContract: Contract {
    fn job_id(&self) -> Option<&JobId>;
    fn command(&self) -> Command;
}

pub struct AtomicResultWriter {
    requested_path: PathBuf,
    private_path: PathBuf,
    file: File,
}

pub trait ResultPublicationFs {
    fn hard_link(&self, private_path: &Path, requested_path: &Path) -> io::Result<()>;
    fn sync_parent(&self, parent: &Path) -> io::Result<()>;
    fn remove_private(&self, private_path: &Path) -> io::Result<()>;
}

pub struct StdResultPublicationFs;
```

```text
read_request<T: Contract>(path: &Path) -> Result<T, ProtocolError>
AtomicResultWriter::reserve(requested_path: &Path, temp_scope: &ResultTempScope) -> Result<AtomicResultWriter, ProtocolError>
AtomicResultWriter::publish<T: ResultContract>(self, result: &T) -> Result<(), ProtocolError>
AtomicResultWriter::publish_with<T: ResultContract>(self, result: &T, fs: &dyn ResultPublicationFs) -> Result<(), ProtocolError>
write_result_atomic<T: ResultContract>(requested_path: &Path, temp_scope: &ResultTempScope, result: &T) -> Result<(), ProtocolError>
```

`CommandResultV1<TOutput>` implements `ResultContract`. Read requests with a `1 MiB` hard cap. `reserve` creates the same-parent private file with `create_new`: `.<result-name>.<job-id>.tmp` for a Job scope, or `.<result-name>.protocol-<catalog|bundle>.tmp` when no trustworthy job ID exists. The scope and result job ID/command must match.

`publish` delegates the same result to `publish_with` using `StdResultPublicationFs`. `publish_with` uses this exact no-clobber order: encode compact JSON plus LF; write all; `sync_all` the private file; call `fs.hard_link`; call `fs.sync_parent`; call `fs.remove_private`; call `fs.sync_parent` again. `hard_link` is the publication primitive because it cannot replace a racing destination. `AlreadyExists` never truncates, replaces, removes or validate-then-deletes the caller-owned result. Before link success, errors remove only the private file and leave result absent. After link success, errors retain the complete result, return `INTERNAL_ERROR`, and add `resultPublished=true` to context. `file_transport.rs` defines a deterministic scripted `ResultPublicationFs` that delegates real operations except at one selected call and injects link, first/second directory-sync or cleanup failure; every branch asserts result/private-file authority.

Retry keeps the same logical `JobId` but must allocate new request/progress/result paths. Rust never repairs or cleans an existing transport path. Stale transport files are ignored by Godot's generation/path binding and cleaned in Phase 5. A new progress file restarts sequence at `1`; a completed staging orphan can be reused only with these fresh transport paths.

- [ ] **Step 5: Implement command runner without fake importer success**

Expose an injectable service boundary for integration tests:

```rust
pub trait CommandService {
    fn catalog(
        &self,
        request: CatalogRequestV1,
        progress: &mut ProgressTracker<'_>,
        cancellation: &dyn Cancellation,
    ) -> Result<CatalogOutputV1, CoreError>;

    fn bundle(
        &self,
        request: BundleRequestV1,
        progress: &mut ProgressTracker<'_>,
        cancellation: &dyn Cancellation,
    ) -> Result<BundleOutputV1, CoreError>;
}
```

The runner boundary is:

```text
run_with_service(args: impl IntoIterator<Item = OsString>, service: &dyn CommandService, stdout: &mut dyn Write, stderr: &mut dyn Write) -> u8
```

The Phase 1 binary service returns `UNSUPPORTED_FORMAT` with detail `No source importer is enabled in protocol phase 1.` for both job commands. It still validates request/schema/paths and writes a versioned failure result. Tests inject a deterministic service to prove success result/progress transport, but production must not advertise or emit parser success. `VersionInfo` continues to report empty capability arrays. Build table-driven `cli_contract.rs` cases for every boundary above; each case asserts exact exit code, result existence, parsed `error.code`, nullable/present job ID, progress existence and empty stdout.

- [ ] **Step 6: Verify stdout/stderr and result authority**

`version` writes one JSON line to stdout. Job commands write no business JSON to stdout; result/progress files are authoritative. Stderr may contain human detail but tests must decide outcomes only from exit code and result `error.code`.

- [ ] **Step 7: Run focused and workspace GREEN**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test args_contract --test file_transport --test cli_contract --locked
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test version_command --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`, no test leaves a private result temp, and production capabilities remain empty.

- [ ] **Step 8: Pass the fresh specification review**

Reviewer checks exact grammar, path-ownership cutoff, machine-readable protocol failures, nullable job ID invariant, result temp scope, exit codes, stdout authority and empty production capabilities. Fix and re-review to `APPROVED`.

- [ ] **Step 9: Pass the fresh code-quality review**

Reviewer checks TOCTOU behavior, bounded reads, `create_new`, hard-link no-clobber publication, directory sync, post-publication error semantics, result-code mapping and injected service separation. Fix and re-review to `APPROVED`.

- [ ] **Step 10: Commit**

```bash
git add native/crates/open2jam-cli
git commit -m "feat: add native CLI transport"
```

---

### Task 7: Implement the relocatable bundle v2 manifest and verifier

**Files:**
- Modify: `native/crates/open2jam-core/src/bundle/mod.rs`
- Create: `native/crates/open2jam-core/src/bundle/manifest.rs`
- Create: `native/crates/open2jam-core/src/bundle/verify.rs`
- Create: `native/crates/open2jam-core/tests/bundle_manifest.rs`
- Create: `native/crates/open2jam-core/tests/bundle_verifier.rs`
- Create: `native/crates/open2jam-core/tests/fixtures/bundle-valid/bundle.json`
- Create: `native/crates/open2jam-core/tests/fixtures/bundle-valid/gameplay.json`
- Create: `native/crates/open2jam-core/tests/fixtures/bundle-valid/audio-manifest.json`

**Interfaces:**
- Consumes: Task 2 strict JSON/path/digest types, Task 3 IDs, Task 5 `BundleKeyInput` and strong key.
- Produces: `BundleManifestV2`, `BundleFile`, `SoundFontIdentity`, `verify_bundle` and `VerifiedBundle` used by staging and future Godot validation parity.

- [ ] **Step 1: Write failing canonical manifest tests**

Construct the fixture through typed values so every hash is real and reproducible, never a placeholder:

```rust
let gameplay = b"{}\n";
let audio_manifest = b"{}\n";
let song_id = SongId::from_digest(Digest::from_bytes([1; 32]));
let chart_identity = ChartIdentity::vos(0)?;
let chart_selector = chart_identity.selector();
let chart_id = chart_identity.chart_id(&song_id);
let identity = BundleIdentity {
    converter_version: "0.1.0".to_owned(),
    static_assets_version: STATIC_ASSETS_VERSION.to_owned(),
    soundfont: SoundFontIdentity {
        version: "2.0.3".to_owned(),
        sha256: Digest::parse(
            "sha256:9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe",
        )?,
    },
    song_id,
    chart_id,
    chart_selector,
    source_fingerprint: SourceFingerprint::from_digest(Digest::from_bytes([3; 32])),
};
let files = vec![
    BundleFile::from_bytes(BundleRelativePath::parse("audio-manifest.json")?, audio_manifest),
    BundleFile::from_bytes(BundleRelativePath::parse("gameplay.json")?, gameplay),
];
let manifest = BundleManifestV2::new(identity, files)?;
assert_eq!(manifest.bundle_key(), &compute_bundle_key(&manifest.key_input()));
```

The encoded field order is `schemaVersion`, `complete`, `bundleKey`, `converterVersion`, `staticAssetsVersion`, `soundfont`, `songId`, `chartId`, `chartSelector`, `sourceFingerprint`, `files`. Files are sorted and unique, exclude `bundle.json`, and require `gameplay.json` plus `audio-manifest.json`.

- [ ] **Step 2: Write the adversarial verifier matrix and verify RED**

Cover `complete=false`, wrong schema/key, malformed/unknown/duplicate field, missing/extra file, wrong size/hash, duplicate/case-fold-colliding path, absolute/parent/backslash path, symlink file, symlink directory, non-regular entry, unsorted files, manifest larger than `1 MiB`, more than `65,536` files, and relocation to a different parent.

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test bundle_manifest --test bundle_verifier --locked
```

Expected: FAIL because manifest and verifier APIs do not exist.

- [ ] **Step 3: Implement the manifest types and validation**

```rust
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    deny_unknown_fields,
    try_from = "BundleManifestWire"
)]
pub struct BundleManifestV2 {
    schema_version: u16,
    complete: bool,
    bundle_key: BundleKey,
    converter_version: String,
    static_assets_version: String,
    soundfont: SoundFontIdentity,
    song_id: SongId,
    chart_id: ChartId,
    chart_selector: ChartSelector,
    source_fingerprint: SourceFingerprint,
    files: Vec<BundleFile>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BundleFile {
    pub path: BundleRelativePath,
    pub size_bytes: u64,
    pub sha256: Digest,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BundleIdentity {
    pub converter_version: String,
    pub static_assets_version: String,
    pub soundfont: SoundFontIdentity,
    pub song_id: SongId,
    pub chart_id: ChartId,
    pub chart_selector: ChartSelector,
    pub source_fingerprint: SourceFingerprint,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SoundFontIdentity {
    pub version: String,
    pub sha256: Digest,
}
```

`BundleManifestV2::new` computes the key from `BundleIdentity`; callers cannot inject a key. Strict deserialization uses private `BundleManifestWire` plus `TryFrom`, never direct field construction. `validate()` requires schema `2`, complete true, exact static asset version, sorted unique paths, required files, selector/chart-ID consistency via `ChartIdentity::from_selector`, and recomputed bundle key equality. For `BUNDLE_CHART`, the selector's declared Chart ID must equal the manifest Chart ID. The selector is serialized so a verifier can independently reconstruct every `BundleKeyInput` field.

Expose only read-only manifest access:

```text
BundleManifestV2::{schema_version, complete, bundle_key, converter_version, static_assets_version, soundfont, song_id, chart_id, chart_selector, source_fingerprint, files, key_input}
```

A `compile_fail` rustdoc example attempts a struct literal from outside the module and proves direct field injection is unavailable; integration tests construct only through `new` or strict JSON. This uses no extra dependency.

- [ ] **Step 4: Implement bounded exact-tree verification**

```rust
pub struct VerifiedBundle {
    root: PathBuf,
    manifest: BundleManifestV2,
}

pub struct BundleValidationError {
    pub code: ErrorCode,
    pub message: String,
    pub relative_path: Option<BundleRelativePath>,
}
```

```text
verify_bundle(root: &Path, expected_key: Option<&BundleKey>) -> Result<VerifiedBundle, BundleValidationError>
VerifiedBundle::root(&self) -> &Path
VerifiedBundle::manifest(&self) -> &BundleManifestV2
VerifiedBundle::into_parts(self) -> (PathBuf, BundleManifestV2)
```

Use `symlink_metadata`, bounded recursive walk, and streaming `64 KiB` hashing. Reject every symlink and every extra/missing path. Read `bundle.json` once with a `1 MiB` cap. Verify artifacts before returning; returned `VerifiedBundle` is an audit value, not a hostile-process security handle.

- [ ] **Step 5: Prove relocation and no static render metadata**

Copy the valid fixture to two unrelated roots and require identical verification and key. Assert `render-metadata.json`, absolute `sourcePath`, and current Java catalog IDs are absent from bundle fixtures and manifest structs.

- [ ] **Step 6: Run focused and workspace GREEN**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test bundle_manifest --test bundle_verifier --locked
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --doc --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`, repeated/reversed fixture verification is byte-identical, and no fixture changes.

- [ ] **Step 7: Pass the fresh specification review**

Reviewer checks exact field order, selector persistence/key reconstruction, required files, complete marker, relocation and every adversarial tree case. Fix and re-review to `APPROVED`.

- [ ] **Step 8: Pass the fresh code-quality review**

Reviewer checks bounded walk/hash/read limits, symlink rejection, case-fold collision, error path context, manifest-last assumptions and no hostile-process guarantee overclaim. Fix and re-review to `APPROVED`.

- [ ] **Step 9: Commit**

```bash
git add native/crates/open2jam-core/src/bundle native/crates/open2jam-core/tests
git commit -m "feat: verify relocatable bundle v2"
```

---

### Task 8: Add transactional bundle staging and compose the CLI boundary

**Files:**
- Modify: `native/crates/open2jam-core/src/bundle/mod.rs`
- Create: `native/crates/open2jam-core/src/bundle/staging.rs`
- Create: `native/crates/open2jam-core/tests/bundle_staging.rs`
- Modify: `native/crates/open2jam-cli/src/runner.rs`
- Create: `native/crates/open2jam-cli/tests/bundle_transport.rs`
- Create: `native/crates/open2jam-cli/tests/catalog_transport.rs`

**Interfaces:**
- Consumes: Task 4 cancellation/progress, Task 5 strong identity, Task 6 CLI transport, Task 7 manifest/verifier.
- Produces: `BundleStager`, `CompletionDisposition`, verified completed staging publication, end-to-end transport tests, and explicit unsupported production handler until Phase 2/3 importers land.

- [ ] **Step 1: Write failing staging atomicity tests**

Require:

```text
<stagingRoot>/.partial/<jobId>/  private and incomplete
<stagingRoot>/<jobId>/           visible only after complete verification
```

Test cancel before create, between artifact writes, before manifest, before staging rename; injected write error; process interruption immediately before and after the staging rename and immediately before and after result hard-link publication; existing completed destination; existing corrupt destination; and a valid-but-different destination. Before staging rename, failures leave no newly completed root. After staging rename, a crash may leave a valid completed staging orphan without a result; this is an explicitly modeled recoverable state, not a consumable success.

- [ ] **Step 2: Verify RED**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test bundle_staging --locked
```

Expected: FAIL because `BundleStager` does not exist.

- [ ] **Step 3: Implement the typestate stager**

```rust
pub struct BundleStager<State> {
    state: State,
}

pub struct Incomplete {
    private_root: PathBuf,
    completed_root: PathBuf,
    files: Vec<BundleFile>,
}

pub struct Complete {
    verified: VerifiedBundle,
    disposition: CompletionDisposition,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CompletionDisposition {
    Published,
    Reused,
}
```

```text
BundleStager<Incomplete>::create(staging_root: &Path, job_id: &JobId) -> Result<BundleStager<Incomplete>, CoreError>
BundleStager<Incomplete>::private_root(&self) -> &Path
BundleStager<Incomplete>::write_artifact<R: Read>(&mut self, path: BundleRelativePath, reader: &mut R, cancellation: &dyn Cancellation) -> Result<BundleFile, CoreError>
BundleStager<Incomplete>::finalize(self, identity: BundleIdentity, cancellation: &dyn Cancellation) -> Result<BundleStager<Complete>, CoreError>
BundleStager<Complete>::disposition(&self) -> CompletionDisposition
BundleStager<Complete>::verified(&self) -> &VerifiedBundle
BundleStager<Complete>::completed_root(&self) -> &Path
BundleStager<Complete>::manifest(&self) -> &BundleManifestV2
BundleStager<Complete>::bundle_key(&self) -> &BundleKey
BundleStager<Complete>::into_verified(self) -> VerifiedBundle
```

Create parents without following symlinks. Each artifact uses a private create-new temp file, bounded stream/hash, `sync_all`, then rename inside the private root. `finalize` writes `bundle.json` last, verifies the private root, checks cancellation again, syncs, atomically renames to `<stagingRoot>/<jobId>`, then re-verifies the completed root and stores that `VerifiedBundle` in `Complete`. `Published` means this call performed the rename; `Reused` means an existing destination independently verified and matched every expected file. Rust must not move anything to `artifacts/<bundleKey>`.

After a cancellation or error that occurs after private-root creation, return the contained private path in error context and retain that incomplete root for Phase 5 stale-staging cleanup. Tests assert its shape and then remove only their own outer fixture root. A successful finalize leaves no `.partial/<jobId>` entry.

Add the cleanup primitive now, while Godot startup enumeration/age policy remains Phase 5 ownership:

```text
cleanup_stale_job(staging_root: &Path, job_id: &JobId) -> Result<(), CoreError>
```

It is allowed only after the coordinator proves `jobId` is not the current generation. It validates the root and every traversed entry with `symlink_metadata`, never follows links, removes only `.partial/<jobId>` and `<jobId>`, and never touches `artifacts/` or any sibling. Tests cover stale partial, completed orphan, symlink replacement, `.`/`..`/reserved `JobId` rejection inherited from Task 2, and idempotent absence. Phase 5 wires this primitive to startup cleanup and active-generation filtering.

- [ ] **Step 4: Define existing-destination behavior**

If `<stagingRoot>/<jobId>` already exists: valid and byte-identical returns `Complete { disposition: Reused }`; invalid means `CACHE_CORRUPT`; valid but different means `INTERNAL_ERROR` with deterministic-output/collision context. Never overwrite or recursively delete the existing destination. Invalid/different destinations cannot construct `Complete`.

- [ ] **Step 5: Compose CLI transport without parser success**

Use an in-test `FixtureBundleService` to stage fixed `gameplay.json` and `audio-manifest.json`, emit `HASH_SOURCES` through `VERIFY_BUNDLE`, and return `BundleOutputV1`. It must construct the output only from `completed_root()`, `bundle_key()` and `manifest()`; direct access to private stager fields is forbidden. Use an in-test `FixtureCatalogService` to publish an empty catalog fixture and return `CatalogOutputV1`. These prove transport composition only. The production binary service remains the Task 6 structured `UNSUPPORTED_FORMAT` handler and `VersionInfo` capability arrays remain empty.

The two publication boundaries are deliberately separate. A completed staging tree becomes consumable only when a successful result for the same current generation contains its exact `jobId`, staging path, key and manifest path, and the consumer re-verifies it. A crash between staging rename and result publication therefore leaves a valid orphan that is ignored. Retry keeps the same logical Job ID but uses newly allocated request/progress/result paths; it may re-verify byte-identical staging as `Reused` and publish the fresh result. Existing stale transport files are never reused or cleaned by Rust; Phase 5 generation filtering and cleanup own them.

- [ ] **Step 6: Run cancellation, ordering, and no-publication GREEN**

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test bundle_staging --locked
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-cli --test bundle_transport --test catalog_transport --locked
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

Expected: every command exits `0`; no pre-rename failure publishes staging; no result failure creates a false result; the permitted orphan is ignored and reusable with fresh transport paths; no CLI event reaches `CHECK_CACHE` or `READY`; all test-owned roots are removed.

- [ ] **Step 7: Pass the fresh specification review**

Reviewer checks every cancellation/crash boundary, orphan authority, current-generation binding, idempotent destination behavior, exact cleanup scope and the production unsupported handler. Fix and re-review to `APPROVED`.

- [ ] **Step 8: Pass the fresh code-quality review**

Reviewer checks typestate ownership, sync/rename ordering, symlink-safe cleanup, collision handling, private-root error context and separation from final Godot cache publication. Fix and re-review to `APPROVED`.

- [ ] **Step 9: Commit**

```bash
git add native/crates/open2jam-core/src/bundle native/crates/open2jam-core/tests/bundle_staging.rs native/crates/open2jam-cli
git commit -m "feat: publish complete bundle staging"
```

---

### Task 9: Add the fail-closed Phase 1 aggregate and CI gate

**Files:**
- Modify: `mise.toml`
- Modify: `.github/workflows/build.yml`
- Modify: `rewrite/tools/verify_build_workflow.sh`
- Modify: `rewrite/tools/test_verify_java_migration_goldens.sh`
- Modify: `rewrite/tools/test_verify_java_migration_goldens_behavior.sh`
- Create: `rewrite/tools/verify_native_phase1.sh`
- Create: `rewrite/tools/test_verify_native_phase1.sh`
- Create: `rewrite/tools/test_verify_native_phase1_behavior.sh`

**Interfaces:**
- Consumes: all Phase 1 workspace/tests plus the existing Phase 0 aggregate and workflow verifier.
- Produces: `mise run verify-native`, exact CI ownership, anti-bypass behavior gates, and Phase 1 exit evidence.

- [ ] **Step 1: Write a failing exact native aggregate contract**

`test_verify_native_phase1.sh` must require one active top-level invocation of each exact command:

```bash
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --doc --locked
mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version
```

It must also require the two exact workspace members, Rust `1.96.1`, edition `2024`, resolver `3`, committed lockfile, empty production format capabilities, no `unsafe` block, no bare cargo gate, and no Rust source under Java `src/` or Godot runtime folders. It separately requires `#![forbid(unsafe_code)]` before the first effective item in `open2jam-core/src/lib.rs`, `open2jam-cli/src/lib.rs`, and `open2jam-cli/src/main.rs`; behavior tests remove each attribute independently and require failure.

- [ ] **Step 2: Write omission/comment/duplicate/dead-invocation mutations and verify RED**

For each of the five aggregate commands and the CI `mise run verify-native` step, create isolated fixture mutations: remove, comment, duplicate, wrap in `if false`. Every case must fail with an exact diagnostic. Baseline fixture records each stub invocation exactly once.

Freeze the verifier call graph to avoid recursion:

```text
verify_native_phase1.sh
  -> test_native_workspace.sh
  -> test_verify_native_phase1.sh rewrite/tools/verify_native_phase1.sh
  -> test_verify_native_phase1_behavior.sh
       -> test_verify_native_phase1.sh "$fixture_aggregate" "$fixture_native"
       -> verify_build_workflow.sh "$fixture_workflow"
  -> five production Cargo commands

verify_build_workflow.sh [workflow-path]
  -> statically validates the argument, defaulting to .github/workflows/build.yml

test_verify_java_migration_goldens*.sh
  -> existing Phase 0 aggregate mutation checks only
```

`test_verify_native_phase1.sh` accepts one required aggregate path and one optional native-root path defaulting to `native`; it performs static validation, never executes the aggregate and never calls the behavior test. `test_verify_native_phase1_behavior.sh` owns a task-local temporary directory, copies minimal valid aggregate/native fixtures, applies one mutation at a time, invokes only the static checker, asserts non-zero plus one exact diagnostic, and removes its directory with a scoped trap. For the literal command stored in shell variable `command`, diagnostics are emitted by `printf 'native aggregate missing active command: %s\n' "$command"`, `printf 'native aggregate duplicates command: %s\n' "$command"`, or `printf 'native aggregate hides command in dead branch: %s\n' "$command"`. Source mutations independently insert `#[ignore]`, a `cfg_attr` attribute containing `ignore`, `#[cfg(test)]` under `src/`, an early `return` under `tests/`, a runtime environment lookup under `tests/`, `#[cfg(any())]`, conditional `cfg_attr` and `cfg!()` under `tests/`. The checker rejects every `cfg`, `cfg_attr` or `cfg!` token in integration-test sources, while source modules separately reject `#[cfg(test)]`. Exact diagnostics are `native source contains ignored test`, `native source contains in-source test module`, `native test contains early return`, `native test contains environment gate`, and `native test contains conditional compilation`. The CI checker emits exactly `build workflow missing active command: mise run verify-native`, `build workflow duplicates command: mise run verify-native`, or `build workflow hides command in dead branch: mise run verify-native`.

Run the behavior contract first, then prove the production aggregate is RED:

```bash
bash rewrite/tools/test_verify_native_phase1_behavior.sh
bash rewrite/tools/test_verify_native_phase1.sh rewrite/tools/verify_native_phase1.sh
```

Expected: the first command exits `0` with `native aggregate behavior contract passed`; the second exits non-zero with `native aggregate missing: rewrite/tools/verify_native_phase1.sh`. It must not fail for usage or fixture setup.

- [ ] **Step 3: Implement the native aggregate and mise task**

Add:

```toml
[tasks.verify-native]
description = "Verify Rust core and native CLI contracts"
run = "bash rewrite/tools/verify_native_phase1.sh"
```

`verify_native_phase1.sh` checks required commands/files, runs the non-recursive static/behavior contract tests above, then the five exact commands. Before running Cargo it rejects ignored tests, in-source test modules, integration-test conditional compilation, early return and environment gates under `native/`. Capture Cargo test output once through a task-local log while preserving the command exit status; require every emitted test summary to contain `0 failed; 0 ignored`, then delete the log. Snapshot hashes of `Cargo.lock` and `native/**/tests/fixtures/**` before execution and require exact equality afterward.

Use this aggregate body; the static checker treats only trailing shell redirections as part of the same active command:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
cd "$repo_root"

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/open2jam-native-phase1.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT

fail() {
  printf 'native Phase 1 verification failed: %s\n' "$1" >&2
  exit 1
}

snapshot_contract_files() {
  {
    shasum -a 256 native/Cargo.lock
    find native -type f -path '*/tests/fixtures/*' -print \
      | LC_ALL=C sort \
      | while IFS= read -r file; do shasum -a 256 "$file"; done
  } | shasum -a 256 | awk '{print $1}'
}

before=$(snapshot_contract_files)

bash rewrite/tools/test_native_workspace.sh
bash rewrite/tools/test_verify_native_phase1.sh rewrite/tools/verify_native_phase1.sh
bash rewrite/tools/test_verify_native_phase1_behavior.sh

if rg -n '#\[ignore\]|#\[cfg_attr\([^]]*ignore' native; then
  fail "ignored native test found"
fi
if rg -n '#\[cfg\(test\)\]' native/crates/*/src; then
  fail "in-source native test module found"
fi
if rg -n '(^|[;{])[[:space:]]*return([[:space:]]|;)' native/crates/*/tests; then
  fail "native test contains early return"
fi
if rg -n 'std::env::(var|var_os)[[:space:]]*\(|option_env!' native/crates/*/tests; then
  fail "native test contains environment gate"
fi
if rg -n '#\[cfg|#\[cfg_attr|cfg!' native/crates/*/tests; then
  fail "native test contains conditional compilation"
fi

mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings

test_log="$tmp_root/cargo-test.log"
set +e
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked >"$test_log" 2>&1
test_status=$?
set -e
cat "$test_log"
[[ "$test_status" == "0" ]] || fail "cargo test failed"
summary_count=$(rg -c '^test result:' "$test_log" || true)
[[ "$summary_count" -gt 0 ]] || fail "cargo test summary is missing"
if rg '^test result:' "$test_log" | rg -v '0 failed; 0 ignored'; then
  fail "cargo test summary contains failure or ignored test"
fi

doc_log="$tmp_root/cargo-doc-test.log"
set +e
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --doc --locked >"$doc_log" 2>&1
doc_status=$?
set -e
cat "$doc_log"
[[ "$doc_status" == "0" ]] || fail "cargo doc test failed"
doc_summary_count=$(rg -c '^test result:' "$doc_log" || true)
[[ "$doc_summary_count" -gt 0 ]] || fail "cargo doc test summary is missing"
if rg '^test result:' "$doc_log" | rg -v '0 failed; 0 ignored'; then
  fail "cargo doc test summary contains failure or ignored test"
fi

version_log="$tmp_root/version.log"
mise exec -- cargo run --quiet --manifest-path native/Cargo.toml -p open2jam-cli --bin open2jam-converter --locked -- version >"$version_log"
expected='{"schemaVersion":1,"converterVersion":"0.1.0","protocolSchemaVersion":1,"catalogSchemaVersion":2,"bundleSchemaVersion":2,"catalogFormats":[],"bundleFormats":[]}'
[[ $(tr -d '\n' <"$version_log") == "$expected" ]] || fail "version output differs"

after=$(snapshot_contract_files)
[[ "$before" == "$after" ]] || fail "lockfile or native fixture changed"

printf 'native Phase 1 verification passed\n'
```

Verify the implemented aggregate contract before touching CI:

```bash
bash rewrite/tools/test_verify_native_phase1.sh rewrite/tools/verify_native_phase1.sh
bash rewrite/tools/test_verify_native_phase1_behavior.sh
```

Expected: both exit `0`.

- [ ] **Step 4: Make the workflow checker RED without weakening Phase 0**

First extend `verify_build_workflow.sh` and its isolated behavior fixtures to require the new step. The script accepts an optional workflow path and defaults to the real workflow. Before editing `.github/workflows/build.yml`, run:

```bash
bash rewrite/tools/verify_build_workflow.sh .github/workflows/build.yml
```

Expected: non-zero with exactly `build workflow missing active command: mise run verify-native`.

- [ ] **Step 5: Add the CI step and prove workflow GREEN**

Add exactly one unconditional step after `Install project runtime` and before `Verify migration goldens`:

```yaml
      - name: Verify native converter
        run: mise run verify-native
```

Extend `verify_build_workflow.sh` to require exact identity/order/count, reject `if` and `continue-on-error`, and update its pinned whole-file SHA only after every workflow behavior mutation passes. The two existing Java golden test scripts change only where their frozen workflow fixture/checksum must include this one new step; their selected suites, omission/comment/duplicate/dead checks and diagnostics remain byte-for-byte otherwise unchanged. Keep Phase 0 golden, Maven build, and package steps unchanged.

```bash
bash rewrite/tools/verify_build_workflow.sh .github/workflows/build.yml
bash rewrite/tools/test_verify_native_phase1_behavior.sh
```

Expected: both exit `0`.

- [ ] **Step 6: Run complete Phase 1 exit gates serially**

Run, in this order and never concurrently in the shared worktree:

```bash
mise run verify-native
mise run verify-goldens
mise run build
bash rewrite/tools/verify_java_migration_package.sh
```

Expected:

```text
Rust fmt/clippy/workspace tests: PASS, zero ignored
CLI events: versioned, contiguous sequence, machine-readable
Bundle staging: no incomplete completed-root publication
Phase 0 selected tests: 99, zero fail/error/skip
Full Java oracle build: 205, zero fail/error, only 8 pre-existing non-selected skips
Production SoundFont generic and production gates: PASS
Golden corpus/worktree/task-owned /tmp: clean
```

- [ ] **Step 7: Pass the fresh Phase 1 specification review**

The specification reviewer maps every roadmap Phase 1 deliverable and exit gate to current files/tests, including all prior task approvals. Fix and re-review every finding until `APPROVED`.

- [ ] **Step 8: Pass the fresh Phase 1 code-quality review**

The code reviewer inspects protocol strictness, file races within the trusted-single-writer boundary, bounded reads, cancellation, staging atomicity/orphan recovery, CLI result authority, dependency surface, shell call graph and CI anti-bypass. Fix and re-review every finding until `APPROVED`.

- [ ] **Step 9: Commit**

```bash
git add mise.toml .github/workflows/build.yml rewrite/tools/verify_build_workflow.sh rewrite/tools/test_verify_java_migration_goldens.sh rewrite/tools/test_verify_java_migration_goldens_behavior.sh rewrite/tools/verify_native_phase1.sh rewrite/tools/test_verify_native_phase1.sh rewrite/tools/test_verify_native_phase1_behavior.sh
git commit -m "test: gate native Phase 1 contracts"
```

---

## Phase 1 Completion Evidence

Phase 1 is complete only when all nine focused commits are present, every task has approved specification and code-quality reviews, Task 9 serial gates are green, `native/Cargo.lock` is unchanged after `--locked` verification, and the worktree/corpus/task-owned temporary roots are clean. At that point create the Phase 2 OJN/OJM and osu!mania importer plan from the live tree with `superpowers:writing-plans`; do not begin VOS/MIDI work before Phase 2 closes.

# Native converter

`native/` 包含 Rust `1.96.1` workspace. 所有 Rust 命令必须通过 mise 运行, 并使用已提交的 lockfile 执行门禁.

## Canonical commands

```bash
mise current
mise install
mise exec -- rustc --version
mise exec -- cargo fmt --manifest-path native/Cargo.toml --all -- --check
mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings
mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked
```

## 当前迁移状态

Ticket 04 进行中. 严格 request/result 协议与路径、错误、ID 包装已有实现, 可单独验证:

```bash
mise exec -- cargo test --manifest-path native/Cargo.toml -p open2jam-core --test protocol_contract --locked
mise exec -- cargo clippy --manifest-path native/Cargo.toml -p open2jam-core --lib --test protocol_contract --locked -- -D warnings
```

这些窄检查不替代完整 workspace 门禁. 两项旧身份派生测试保留在 `tests/identity_contract.rs`, 当前仍因缺实现而使完整门禁失败. 身份派生还需对齐已批准的 Library Root 决策; 未发布 catalog/bundle 能力, `version` 的能力数组保持为空.

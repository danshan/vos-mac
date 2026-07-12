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

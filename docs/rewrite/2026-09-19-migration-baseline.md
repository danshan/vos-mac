# Ticket 01 验证基线

本记录对应用户批准的本地迁移 ticket 01. 本轮仅恢复验证与原型运行条件, 不将未实现的 Rust 协议或 importer 计为完成.

## 故障与修复

### Nested TMPDIR

原 verifier 先读取默认 JVM temp root, 再给子进程设置嵌套 TMPDIR, 但假定后一次 JVM temp root 不变. 当前 macOS/Zulu 组合会从 TMPDIR 推导 java.io.tmpdir, 导致 verifier 在 Maven 启动前失败.

修复显式将已验证的原 JVM temp root 传入 JVM probe 与 Maven/Surefire 的 java.io.tmpdir, 同时保留嵌套进程 TMPDIR. 仍验证 root 的 canonical 路径、严格后代关系、异常退出状态和安全清理. 不放宽 generator 的文件系统限制.

已有 shell 行为测试现模拟随 TMPDIR 改变的 JVM 默认行为, 修复前无法到达 Maven 子进程, 修复后 INT/TERM/HUP 场景通过. 真实 nested-TMPDIR gate 输出 42 tests, 0 failures/errors/skips.

### macOS SDK

默认 xcrun 选择 macOS 27.0 SDK, 安装的 Apple linker/TAPI 无法识别其 arm64e.x1 stub. 用未构建过的 release profile 复现失败, 排除了 debug 缓存造成的假通过.

本 checkout 的 ignored mise.local.toml 使用已安装的 macOS 26.5 SDK, 使 canonical mise 命令可成功构建 release. 没有更改 Java/Maven/Rust 版本, 没有修改系统 SDK、xcode-select 或 shell startup. 该本机覆盖不提交, 其他机器不得无条件照抄此 SDK 绝对路径.

已通过 Context7 核对 mise 的本地覆盖用法: [mise 官方 FAQ](https://github.com/jdx/mise/blob/main/docs/faq.md). 共享版本和任务仍由 mise.toml 管理.

### Godot

从 [Godot 官方 4.6.3 release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) 下载 macOS universal archive, 核对 GitHub release asset 公布的 SHA-256:

```text
30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8
```

工具位于本地 tracker 下被 Git 忽略的 target/tools 目录, 通过 mise.local.toml 的 env._.path 暴露 godot. 版本输出为 4.6.3.stable.official.7d41c59c4. 没有改变系统安装. Godot 导入和既有 app_state 测试出口为 0, 日志无 ERROR/SCRIPT ERROR.

上述 SDK 与 Godot 配置是本机运行条件, 不是可携带的 release 包或自动安装器. 换机器时应重新验证 SDK 与工具来源; ticket 03 才负责内嵌 helper 和可复制 application.

## 验证证据

| 入口 | 本轮结果 | 归属 |
|---|---|---|
| mise current 与 Java/Maven/Rust version | Java 17.0.19, Maven 3.9.9, Rust 1.96.1 | 固定项目运行时 |
| nested TMPDIR shell behavior | 通过, 保留 INT/TERM/HUP 清理 | 本轮回归修复 |
| nested TMPDIR 真 JVM/Maven | 42 tests, 0 failures/errors/skips | 本轮回归修复 |
| mise run verify-goldens | gate passed; 主 Java 集合 99 tests, 0 failures/errors/skips | oracle/provenance/package/hash 累计验证 |
| mise run native-release | release profile 构建成功 | SDK 覆盖生效 |
| Rust version_command | 1 passed, 0 failed | 已实现 CLI handshake |
| native workspace gate 与其 self-test | 均通过 | 工具调用与 stdout/stderr 合同 |
| cargo fmt check | 通过 | 格式 |
| Rust workspace all-targets test/clippy | 9 个 unresolved imports, 仍失败 | 既有 protocol_contract 引用缺实现, ticket 04 |
| Godot import 与 app_state smoke | 出口 0, 日志无 ERROR/SCRIPT ERROR | 原型 engine 可用性, 不代表全部 gameplay gate |
| 全量 Maven clean verify | BUILD SUCCESS; 205 tests, 0 failures/errors, 8 skipped | 既有整套测试含条件跳过, 不与零跳过 golden gate 的 99 项混淆 |

Rust 缺少 digest/error/format/id/json/path/protocol/schema 等模块. 本轮没有用空实现、忽略测试或删除断言处理这些失败. 原始 corpus 与 native Cargo.lock 未改动.

完整 Godot gameplay/视觉 parity aggregate 尚不属于上述 engine smoke 证据, 不宣称本轮已通过. 后续 ticket 必须按受影响行为和最终累计门禁验证.

Sandbox 下 mise 状态写入会产生 stderr 警告, Godot 编辑器设置写入和 macOS time 资源统计也可能受限. 本轮在正常权限下复验对应命令, 保留严格 gate, 不过滤这些错误制造成功.

## 原型入口

在验证过 SDK 和 Godot 的项目环境运行:

```bash
mise current
mise run native-release
mise exec -- godot --version
mise exec -- godot --headless --editor --path rewrite/godot --import --quit
/usr/bin/time -l native/target/release/open2jam-converter version
```

release task 使用 native workspace 与 committed lockfile. 当前 version 输出的 catalogFormats/bundleFormats 仍为空, 测量只证明可执行文件与资源统计入口可用, 不代表任何合成或加载 SLO. ticket 02 将替换测量对象为真实离线合成, 记录独立 sample、wall time、RSS 和 PCM bytes; ticket 03 验证实际 app 打包链路.

本轮完整日志位于本机临时目录, 不作为跨机器 gate 输入:

- `/tmp/vos-migration-nested-tmpdir.log`
- `/tmp/vos-migration-goldens.log`
- `/tmp/vos-migration-full-build.log`
- `/tmp/vos-migration-native-release.log`
- `/tmp/vos-migration-native-version.log`
- `/tmp/vos-migration-clippy.log`
- `/tmp/vos-migration-godot-import.log`
- `/tmp/vos-migration-godot-smoke.log`
- `/tmp/vos-migration-release-probe.time`

# 01: 恢复可信的迁移验证基线

**What to build:** 维护者能够在项目固定工具链下获得可信的迁移验证结果, 明确区分环境故障、既有失败与尚未实现的功能.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] 通过项目 runtime 配置验证 Java/Maven/Rust 环境, 查明 SDK linker 与 JVM temp-root 失败原因; 修复不依赖手工修改宿主环境.
- [x] 冻结 oracle 的来源、expected 和 hash 可核对, 缺失或篡改会使验证失败, 不重写 expected 制造通过.
- [x] 记录每个现有 gate 的结果和失败归属; 未实现模块导致的协议 RED 测试明确保留为后续工作, 不跳过或删除断言.
- [x] 为两个前置原型提供可复现的 release 构建与测量入口; 若环境仍阻碍原型, 本 ticket 不标完成.

验收记录: nested TMPDIR 42 tests 零失败/跳过, golden gate 99 tests 零失败/跳过, Maven 全量 205 tests 零失败且有 8 个既有 skip. Rust release、version test、workspace gate 和 Godot import/smoke 可用; Rust all-targets test/clippy 仍因协议模块未实现失败, 归属 ticket 04. 固定 Godot 下载及 SDK 覆盖仅在项目本地生效. 完整 Godot aggregate 未执行, smoke 不代表 gameplay 累计验收通过.

Code review: 以用户确认的 d4cedf802e22a4eefd08426ddba17f3cd17c2856 为基点, Standards 轴硬违规 0、smell 0; Spec 轴发现 0. 两轴为独立静态审查, 不冒充独立重跑测试. ticket 01 完成后解除 02/03 的 ticket 依赖.

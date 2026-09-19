# 01: 恢复可信的迁移验证基线

**What to build:** 维护者能够在项目固定工具链下获得可信的迁移验证结果, 明确区分环境故障、既有失败与尚未实现的功能.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] 通过项目 runtime 配置验证 Java/Maven/Rust 环境, 查明 SDK linker 与 JVM temp-root 失败原因; 修复不依赖手工修改宿主环境.
- [ ] 冻结 oracle 的来源、expected 和 hash 可核对, 缺失或篡改会使验证失败, 不重写 expected 制造通过.
- [ ] 记录每个现有 gate 的结果和失败归属; 未实现模块导致的协议 RED 测试明确保留为后续工作, 不跳过或删除断言.
- [ ] 为两个前置原型提供可复现的 release 构建与测量入口; 若环境仍阻碍原型, 本 ticket 不标完成.


# 27: 移除剩余 Java 并完成最终迁移验收

**What to build:** 维护者可以在完全没有 Java 的环境构建、测试与打包, 玩家所有保留能力由 Godot + Rust 提供.

**Blocked by:** 26: 交付完整的无 Java 运行包.

**Status:** ready-for-agent

- [ ] 替换剩余 Java-only 验证和 fixture 消费工具, 使用冻结数据与 provenance 验证, 不再执行 Java oracle.
- [ ] 移除 Java 源码、Maven/JAR、旧 Swing/LWJGL 应用和已退役格式的可执行实现, 不误删原始歌曲、用户设置或冻结 oracle 数据.
- [ ] 项目 build/test/package、CI 与开发任务不再依赖 JRE/JDK/Maven/JAR, 不存在可选 Java fallback.
- [ ] 在无 Java 环境完成完整 golden、功能、性能、音频、打包与 Java-absence 累计门禁, 检查动态调用与依赖而非仅文本搜索.
- [ ] 更新开发与运行说明, 区分保留的历史 provenance 文本与可执行依赖, 交付可审阅的最终 Java-free 证据.
- [ ] 删除前保留版本控制可恢复点并核对门禁; 任何保留产品能力未完成时不进行最终删除.


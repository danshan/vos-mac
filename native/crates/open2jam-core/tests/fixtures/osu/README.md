# osu timing oracle

这组自制谱面通过生产 Java ChartParser 和 RenderTimingCompiler 生成冻结结果. OsuTimingOracle.java 只序列化实际结果, 不重新实现 timing 算法. Rust 测试读取 JSON, 不执行 Java. ticket 27 删除迁移期 generator, 保留 fixtures.

- timing.osu 覆盖源 timing 乱序、负时间 tempo/scroll、同刻重复 BPM 与多个 scroll、3/4/5 拍号、跨拍号长音、自定义 sample 和 binary32 volume.
- late-tempo.osu 覆盖首个 tempo 晚于 0、向前外推、非整数 beat length、跨 tempo 长音和毫秒间隔事件.
- JSON samples 元组为 `[timeUs, measure, lane, flag, sampleIndex, volume]`, lane -1 表示 autoplay, 其余为 0..6. timing 元组为 `[timeUs, bpm]`. 使用与 exporter 相同的时间/BPM 去重规则, 在去重后转换为整数微秒. volume 将 Java float 精确提升为 double 后记录.
- 这是长音修复前的 compiler oracle, 不替代 EventList 修复、sample/audio 准备、bundle v2 与 Godot 验收. 原有 seven-key gameplay golden 仍保持不变, 另有测试直接对照其 notes.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/timing.osu native/crates/open2jam-core/tests/fixtures/osu/timing-java.json
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/late-tempo.osu native/crates/open2jam-core/tests/fixtures/osu/late-tempo-java.json
```

| 文件 | SHA-256 |
|---|---|
| timing.osu | 0cb526d044dca58ed58d697848b2933242d9761f0bf0a5cea472a04233d20f5d |
| timing-java.json | 6cee31e2f8bf902d727dcee1f4d36b1fb8cddd20506e0ce227e58b3dcb9fde91 |
| late-tempo.osu | e68f78a0abb675b7efaface0112cafb05307a542c019c55d9d55b6f901a64ac0 |
| late-tempo-java.json | b67d91be6bf3cfae50e01a842876a2e694eaa4527c1c9ba4e36dd136f525b614 |
| OsuManiaParser.java | 7ae00715cddc8b79f639cb1dc94cecca4225047f3c3dedd42d9f478aa7dbd943 |
| RenderTimingCompiler.java | 95da9d1bc2e03a58e60e58c612efce59b0621944dbc634a86e4fb8454b6775c0 |

边界差异: Rust 明确拒绝 i32 时间差溢出、无限 velocity、超过 1,000,000 measures 或精确微秒范围的 timeline, 以及 Java 拍号缩放产生的各输出轨道时间倒退. 不以 wraparound、重排 notes 或覆盖 golden 隐藏这些问题. 原始事件上限为 notes + timing <= 1,000,000; 展开 hold 尾部与 meter 事件后最多 2,000,001 个内部事件, 未按时间跨度无界分配. TimingMap 查询使用二分, stable sort 前后及逐输入事件/measure 检查取消.

编译器保持 binary64 累积时间, 仅输出时取整数微秒, 不用逐事件舍入后的时间继续累积. BPM/scroll 暂以 binary64 保留 Java compiler 值, 尚未做 bundle Ratio 转换或最终完整 Chart 编译. 该转换必须保留相应精度并在后续 adapter 增量验证, 不能以本组 oracle 宣称已完成 wire 精度验收.

# OJN 长音修复 oracle

`hold-repair.json` 由迁移期 Java `EventList.fixEventList(OPEN2JAM, true)` 生成. 固定随机种子 20260919, 共 64 组, 每组 24 个事件, 包含三个 playable lanes 与 autoplay. Rust 测试只读取此 JSON, 不执行 Java.

- input 元组: source sample index (zero-based), lane (-1 为 autoplay), flag (0 tap / 2 hold / 3 release).
- expected 元组: 原始事件在组内的位置 index, sample index, 修正后的 lane, 修正后的 flag.
- 源 `parsers/src/org/open2jam/parsers/EventList.java` SHA-256: `852482159c20bd44d3c84e940fef3bed609d441439036dd24eba65836a58dfad`.
- JSON SHA-256: `bfeb009c9d674bb348f717f64bc50d3eb357ab19509c2db2edac565980dff469`.

生成命令依赖已由项目构建生成的迁移期 JAR. 最终 ticket 27 删除 Java generator, 保留冻结 JSON.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjnHoldOracle.java native/crates/open2jam-core/tests/fixtures/ojn/hold-repair.json
```

这组 oracle 验证事件修复, 不替代最终 bundle / gameplay 验收. 特别保留 backward repair 移动已遍历 RELEASE 到 autoplay 的行为; Java 不会再次清理此事件的 flag. 没有 tail 的最终 HOLD 也不在该修复步骤中丢弃.

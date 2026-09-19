# Godot + Rust 迁移 tickets

用户已批准 27 个纵向切片及阻塞关系, 并明确选择本地文件跟踪. 本目录为该迁移的本地 tracker, 每项工作在 issues 下有独立文件. 不创建远程 issues.

## 执行规则

- Triage vocabulary: ready-for-agent. 此标签不表示依赖已经完成; 只有所有 Blocked by 项及外部前置满足的 ticket 才能开始依赖这些条件的实施.
- 当前状态: 01/02/03/04 已完成并通过两轴审查, 下一顺序为 05; 依赖 04 的其他 tickets 也已解除该项阻塞. 02 只证明受控合成原型可继续集成, 不解除最终性能门禁. 不因已有草稿或部分代码将 ticket 标为完成.
- 01 完成后 02 与 03 可独立推进. 原型只有通过 go/no-go 才解除 04 的阻塞, 失败报告不等于通过.
- Q6/Q7 已明确批准: 拒绝重复或重叠 root; 离线保留旧记录并标不可用, 仅完整成功扫描确认删除. 16/17 的外部决策前置已满足, ticket 依赖仍须完成.
- 每项验收以可观察的 CLI/bundle/Godot 行为为主, 保留必要的精度 golden 与包验收. 完成时在该 ticket 记录验证证据、剩余限制并更新复选框.
- 这套已批准的纵向顺序将 Godot v2 consumer 提前到 04, 各格式接入时直接验证 gameplay, 不再以旧 roadmap 的横向阶段顺序阻止这些切片. 原 roadmap 的产品范围、正确性与累计退出门禁继续适用.
- 最终目标是全部保留能力由 Godot + Rust 接替, 运行、构建、测试与打包不依赖 Java. 已退役格式与旧应用移除, 不逐项重写. 本机自用只影响分发要求.
- 26 只代表 runtime cutover; 27 通过后才满足完整 Java-Free. 不提前删除迁移期 oracle 或生产尚需的 Java 逻辑.

## Tickets

| Ticket | Blocked by | 外部前置 |
|---|---|---|
| [01: 恢复可信的迁移验证基线](issues/01-restore-migration-baseline.md) | None | - |
| [02: 验证 VOS 离线合成可行性](issues/02-prove-vos-offline-synthesis.md) | 01 | - |
| [03: 验证最小 macOS application](issues/03-prove-macos-app.md) | 01 | - |
| [04: 打通 bundle v2 到 Gameplay Ready](issues/04-play-bundle-v2.md) | 02, 03 | - |
| [05: 取消加载并隔离过期结果](issues/05-cancel-stale-loads.md) | 04 | - |
| [06: 复用有效缓存并安全重建损坏产物](issues/06-validate-artifact-cache.md) | 05 | - |
| [07: 发现并游玩外部 bundle v2](issues/07-discover-external-bundles.md) | 04 | - |
| [08: 游玩基础 OJN/OJM 歌曲](issues/08-play-ojn-ojm.md) | 04 | - |
| [09: 游玩 OMC 音频变体](issues/09-play-omc.md) | 08 | - |
| [10: 游玩 M30 音频变体](issues/10-play-m30.md) | 08 | - |
| [11: 游玩本地 osu!mania 7K 谱面](issues/11-play-osu-seven-key.md) | 04 | - |
| [12: 安全导入并游玩 OSZ 歌曲包](issues/12-play-osz.md) | 11 | - |
| [13: 游玩基础 VOS 歌曲](issues/13-play-basic-vos.md) | 04 | - |
| [14: 保持复杂 VOS 的 MIDI 与 gameplay 语义](issues/14-play-complex-vos.md) | 13 | - |
| [15: 跨 Chart 复用 VOS 合成缓存](issues/15-share-vos-sample-cache.md) | 06, 14 | - |
| [16: 管理稳定的 Library Root 与重新定位](issues/16-relocate-library-roots.md) | 07 | 已确认 |
| [17: 后台刷新曲库并处理部分来源不可用](issues/17-refresh-partially-available-library.md) | 16 | 已确认 |
| [18: 交付大型曲库的分组、搜索和筛选](issues/18-search-large-catalog.md) | 17 | - |
| [19: 预热 Chart 并展示完整真实进度](issues/19-prewarm-with-real-progress.md) | 06, 18 | - |
| [20: 有界加载音频并回收播放器](issues/20-bound-audio-resources.md) | 04 | - |
| [21: 通过 Settings 控制缓存容量](issues/21-configure-cache-budget.md) | 06, 19 | - |
| [22: 单实例运行与崩溃后恢复](issues/22-recover-single-instance.md) | 03, 05, 06 | - |
| [23: 保留现有用户设置与原始数据](issues/23-preserve-user-data.md) | 16 | - |
| [24: 冻结跨格式性能与安全验收工作集](issues/24-freeze-acceptance-workloads.md) | 02, 09, 10, 12, 14 | - |
| [25: 通过完整加载性能和故障验收](issues/25-pass-loading-acceptance.md) | 15, 19, 20, 21, 22, 24 | - |
| [26: 交付完整的无 Java 运行包](issues/26-ship-java-free-runtime.md) | 23, 25 | - |
| [27: 移除剩余 Java 并完成最终迁移验收](issues/27-remove-remaining-java.md) | 26 | - |

# 08: 游玩基础 OJN/OJM 歌曲

**What to build:** 玩家扫描基础 OJN/OJM 歌曲, 在同一 Song 下选择不同难度并完整游玩.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** ready-for-agent

- [ ] 原始 OJN 经 Rust catalog、bundle 与 Godot 显示和加载, 不调用 Java exporter.
- [ ] 同一 OJN 的多个 chartIndex 归于同一 Song, 各 Chart 的音符和音频关联正确.
- [ ] 基础 OJM 样本可解码并播放, timing、长音、事件顺序和源 volume/pan 精度与冻结 oracle 对照.
- [ ] 截断数据、无效长度和缺失音频有可诊断结果, 不崩溃、挂起或无界分配.
- [ ] 仅声明本 ticket 覆盖的基础 OJM 路径, 不把 OMC/M30 变体算作已完成.


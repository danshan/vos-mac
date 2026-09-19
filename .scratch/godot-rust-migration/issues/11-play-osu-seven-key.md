# 11: 游玩本地 osu!mania 7K 谱面

**What to build:** 玩家选择本地 7K osu!mania 谱面, 解析关联音频后以正确时序游玩.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** ready-for-agent

- [ ] 原始 osu 谱面从 Rust catalog 到 bundle v2 和 Godot gameplay 全链路可用.
- [ ] 关联音频、timing、scroll、长音和 sample 行为与冻结 oracle 对照.
- [ ] 非支持模式或键数明确拒绝, 不静默按 7K 解释.
- [ ] 缺失音频、畸形内容与无效引用给出可诊断错误, 不影响其他歌曲.


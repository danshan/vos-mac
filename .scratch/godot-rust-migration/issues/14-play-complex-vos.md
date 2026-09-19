# 14: 保持复杂 VOS 的 MIDI 与 gameplay 语义

**What to build:** 玩家游玩包含复杂 MIDI 和背景音频的 VOS 时, 保持可演奏音轨、声音和音符时序正确.

**Blocked by:** 13: 游玩基础 VOS 歌曲.

**Status:** ready-for-agent

- [ ] 覆盖 playable-source inference、live/background 分流、running status、tempo 和稳定事件顺序.
- [ ] bank/program、velocity、pan、duration、minimum gate、tail 与 sample 去重语义有代表性及边界 fixtures.
- [ ] 从原始输入到 gameplay 验证复杂场景, 不只单测 MIDI 解码器.
- [ ] 固定音源下重复/逆序音频渲染确定; 系统 DLS 音色差异按既有 accepted deviation 处理, 不豁免其他语义.
- [ ] 所有 VOS golden 差异可解释, 不由新实现自动覆盖 expected.


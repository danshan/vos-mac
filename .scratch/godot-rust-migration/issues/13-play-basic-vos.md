# 13: 游玩基础 VOS 歌曲

**What to build:** 玩家能够从最小受支持的原始 VOS 文件进入实际 gameplay, 音频由固定音源现场准备.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** ready-for-agent

- [ ] 使用生产 VOS 解析路径完成 metadata、音符和嵌入 MIDI 读取, 经 CLI/bundle/Godot 全链路可游玩.
- [ ] 使用已通过原型的 synth/config 与固定 SoundFont, 不以预生成 WAV 或 Java fallback 替代.
- [ ] 最小 fixtures 的音符、timing、sample 关联与音频行为通过冻结 oracle 和 canonical 音频合同验证.
- [ ] 畸形容器和缺失/截断 MIDI 可诊断失败, 不把基础路径完成视为所有复杂 VOS 已支持.


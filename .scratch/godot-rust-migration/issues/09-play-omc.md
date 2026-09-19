# 09: 游玩 OMC 音频变体

**What to build:** 玩家能够游玩使用 OMC 音频的 O2Jam 歌曲, 获得正确的样本和播放顺序.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** ready-for-agent

- [ ] 真实 OJN/OMC 输入从扫描、难度选择到 gameplay 全链路通过, 使用生产解码路径.
- [ ] 解码与样本映射对照固定 fixtures/oracle, 不用预解码文件绕过 OMC.
- [ ] 畸形或截断 OMC 可诊断失败, 不破坏已可用的其他歌曲.
- [ ] 既有基础 OJM 行为保持通过, 记录任何经明确接受的语义差异.


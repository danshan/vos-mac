# 24: 冻结跨格式性能与安全验收工作集

**What to build:** 维护者获得固定、可复现的代表性与压力工作集, 玩家规模支持边界有实际测量依据.

**Blocked by:** 02: 验证 VOS 离线合成可行性; 09: 游玩 OMC 音频变体; 10: 游玩 M30 音频变体; 12: 安全导入并游玩 OSZ 歌曲包; 14: 保持复杂 VOS 的 MIDI 与 gameplay 语义.

**Status:** ready-for-agent

- [ ] 覆盖 VOS、基础 OJM、OMC、M30、osu/OSZ 和 bundle 路径所需代表性及压力输入, 固定 provenance 与 hash.
- [ ] 依据原型和生产 importer 测量冻结 notes、独立 sample、合成时长、资源 bytes 等规模维度, 不只按文件大小或音符数选样.
- [ ] 记录硬件、release 构建、缓存状态、重复次数、P95 计算方式和各阶段测量口径.
- [ ] 分别定义 Performance Acceptance Corpus 与安全资源上限, 不为了通过 5 s 只保留简单曲目.
- [ ] 自动验收不隐含依赖用户本机外部曲库, 新工作集不覆盖既有 oracle expected.
- [ ] 数据仍不足时保留阻塞并补证据, 不填入未经测量的安全阈值.


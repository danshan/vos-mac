# 21: 通过 Settings 控制缓存容量

**What to build:** 玩家通过 Settings 控制派生缓存空间, 正在加载或游玩的内容不会被后台淘汰.

**Blocked by:** 06: 复用有效缓存并安全重建损坏产物; 19: 预热 Chart 并展示完整真实进度.

**Status:** ready-for-agent

- [ ] 默认 Gameplay Cache Budget 为 10 GB, Settings 至少支持从 5 GB 起调整并持久化.
- [ ] 超预算后台按 LRU 淘汰未 pin 的完整 Chart artifact, Catalog index 不计入此预算.
- [ ] 选择、预热与 gameplay 使用期保持 pin, 切换和退出正确释放, 不因竞态删掉当前资源.
- [ ] 所有候选均被 pin 或空间不足时行为可诊断, 不通过误删原始歌曲满足预算.
- [ ] 记录全局 MIDI 派生缓存的空间归属与清理规则, 不以遗漏该缓存造成无限磁盘增长.


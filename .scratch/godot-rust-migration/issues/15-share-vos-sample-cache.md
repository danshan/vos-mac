# 15: 跨 Chart 复用 VOS 合成缓存

**What to build:** 玩家加载使用相同合成输入的不同 VOS Chart 时复用合成结果, 同时保留独立可搬移 bundle.

**Blocked by:** 06: 复用有效缓存并安全重建损坏产物; 14: 保持复杂 VOS 的 MIDI 与 gameplay 语义.

**Status:** ready-for-agent

- [ ] 相同完整合成输入命中全局 MIDI 派生缓存, 音源 bytes/hash、配置或生成版本变化正确失效.
- [ ] 用跨 Chart 实际加载证明复用及结果一致, 不依赖调用次数 mock 作为唯一证据.
- [ ] 取消、损坏和不完整写入不会污染全局缓存或新 bundle.
- [ ] 完成的 bundle 不依赖外部 CAS; 删除全局派生缓存并搬移 bundle 后仍可游玩.


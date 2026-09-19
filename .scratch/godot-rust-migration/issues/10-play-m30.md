# 10: 游玩 M30 音频变体

**What to build:** 玩家能够游玩使用 M30 音频的 O2Jam 歌曲, 保持样本引用与解码语义正确.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** ready-for-agent

- [ ] 真实 OJN/M30 输入从扫描、难度选择到 gameplay 通过, 不调用 Java 或预解码替代路径.
- [ ] 样本 ID、解码输出和引用关系由冻结 fixtures/oracle 验证.
- [ ] 损坏的头部、长度和样本引用受到边界检查, 不 crash、hang 或无界分配.
- [ ] 基础 OJM 路径无回归, 未解释的 parity 差异不得通过重写 expected 消除.


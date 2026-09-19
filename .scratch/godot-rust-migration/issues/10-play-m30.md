# 10: 游玩 M30 音频变体

**What to build:** 玩家能够游玩使用 M30 音频的 O2Jam 歌曲, 保持样本引用与解码语义正确.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** ready-for-agent

- [ ] 真实 OJN/M30 输入从扫描、难度选择到 gameplay 通过, 不调用 Java 或预解码替代路径.
- [ ] 样本 ID、解码输出和引用关系由冻结 fixtures/oracle 验证.
- [ ] 损坏的头部、长度和样本引用受到边界检查, 不 crash、hang 或无界分配.
- [ ] 基础 OJM 路径无回归, 未解释的 parity 差异不得通过重写 expected 消除.


## 前置代码核对

- Java M30 bank header 为 28 bytes, sample header 为 52 bytes. encryption_flag=0 不变换, 16 使用 nami, 32 使用 0412, 每个完整 4-byte block 做 XOR, 末尾 1..3 bytes 不变. 每个 sample 独立开始, 与 OMC 的跨 sample 状态不同.
- Java sample ref 为 signed short, codec_code=0 映射到 1000+ref, codec_code=5 直接 ref. 旧逻辑对未知 codec/flag 仅警告并继续, Rust 实现必须明确规定边界与诊断, 不盲目沿用未知格式猜测.
- 现有 frozen m30-nami/m30-0412 fixture 的音频 payload 仅 8 bytes, 只能证明 parser metadata, 不足以作为真实 Vorbis 解码到 gameplay 的证据. 后续须增加自制可解码 Vorbis 的编码 M30 输入及生产 Java oracle, 不改写原有冻结期望.

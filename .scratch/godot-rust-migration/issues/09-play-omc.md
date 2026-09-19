# 09: 游玩 OMC 音频变体

**What to build:** 玩家能够游玩使用 OMC 音频的 O2Jam 歌曲, 获得正确的样本和播放顺序.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** ready-for-agent

- [ ] 真实 OJN/OMC 输入从扫描、难度选择到 gameplay 全链路通过, 使用生产解码路径.
- [ ] 解码与样本映射对照固定 fixtures/oracle, 不用预解码文件绕过 OMC.
- [ ] 畸形或截断 OMC 可诊断失败, 不破坏已可用的其他歌曲.
- [ ] 既有基础 OJM 行为保持通过, 记录任何经明确接受的语义差异.


## 前置代码核对

- Java OJMParser.parseOMC 对 OMC 的 WAV payload 先按 17 段 permutation 重排, 再应用累计 XOR; Ogg payload 不走这两步.
- XOR 状态每个 bank 初始化 key=0xff/counter=0, 跨非空 WAV sample 延续, 不允许每个 sample 重置. 每 8 bytes 的下一 key 来自变换前 byte, 空槽只推进 sample index.
- 重排 key 为 (length % 17) * 17, 每段长度 floor(length/17), 尾部 remainder 保持原位置. 后续固定 oracle 必须覆盖跨 sample 状态和不同 remainder, 不能只验证一个短 sample.
- 已有原始 fixture 位于 rewrite/golden/java-migration/sources/ojn/omc.ojn 与 omc.ojm. 仍须核对样本覆盖度并用生产 decoder 贯通, 本记录不代表实现或验收完成.

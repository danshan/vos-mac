# 09: 游玩 OMC 音频变体

**What to build:** 玩家能够游玩使用 OMC 音频的 O2Jam 歌曲, 获得正确的样本和播放顺序.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** in-progress

- [ ] 真实 OJN/OMC 输入从扫描、难度选择到 gameplay 全链路通过, 使用生产解码路径.
- [ ] 解码与样本映射对照固定 fixtures/oracle, 不用预解码文件绕过 OMC.
- [ ] 畸形或截断 OMC 可诊断失败, 不破坏已可用的其他歌曲.
- [ ] 既有基础 OJM 行为保持通过, 记录任何经明确接受的语义差异.


## 前置代码核对

- Java OJMParser.parseOMC 对 OMC 的 WAV payload 先按 17 段 permutation 重排, 再应用累计 XOR; Ogg payload 不走这两步.
- XOR 状态每个 bank 初始化 key=0xff/counter=0, 跨非空 WAV sample 延续, 不允许每个 sample 重置. 每 8 bytes 的下一 key 来自变换前 byte, 空槽只推进 sample index.
- 重排 key 为 (length % 17) * 17, 每段长度 floor(length/17), 尾部 remainder 保持原位置. 后续固定 oracle 必须覆盖跨 sample 状态和不同 remainder, 不能只验证一个短 sample.
- 已有原始 fixture 位于 rewrite/golden/java-migration/sources/ojn/omc.ojn 与 omc.ojm. 仍须核对样本覆盖度并用生产 decoder 贯通, 本记录不代表实现或验收完成.

## 当前增量: 核心 OMC 变换

- core decode_omc_in_place 先校验完整 bank, 再逐样本重排和累计 XOR, 保持 Ogg bank 不变. 成功后签名变为 OJM, 复用现有 PCM/Vorbis 准备. 取消后的 buffer 必须丢弃; 在变换前捕获原始 source fingerprint.
- 变换只额外保留当前 sample 的编码副本, 沿用 512 MiB bank 上限; 读取副本、重排复制和 XOR 每 64 KiB 检查取消. 不声称最终 RSS 或性能门禁完成.
- 冻结 Java oracle 覆盖所有 remainder、跨 sample 状态、空槽、原始 OMC fixture, 比较 decoded payload 与最终 PCM16. 另验证畸形完整 bank 在改写前拒绝、Ogg bytes 不变和中途取消.
- red /tmp/vos-omc-red.log, 核心证据 /tmp/vos-omc-core.log, workspace /tmp/vos-omc-workspace.log.
- 尚未接入 CLI 与 Godot, 当前 production adapter 仍明确拒绝 OMC. 不关闭 ticket, 下一步将核心变换接入捕获 bytes 后、样本准备前, 并保留原始编码源 digest.

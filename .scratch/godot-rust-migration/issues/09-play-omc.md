# 09: 游玩 OMC 音频变体

**What to build:** 玩家能够游玩使用 OMC 音频的 O2Jam 歌曲, 获得正确的样本和播放顺序.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** done

- [x] 真实 OJN/OMC 输入从扫描、难度选择到 gameplay 全链路通过, 使用生产解码路径.
- [x] 解码与样本映射对照固定 fixtures/oracle, 不用预解码文件绕过 OMC.
- [x] 畸形或截断 OMC 可诊断失败, 不破坏已可用的其他歌曲.
- [x] 既有基础 OJM 行为保持通过, 记录任何经明确接受的语义差异.


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
- 核心增量 `bb1f8b0` 固定基点独立审查: Standards 0 项, Spec 0 项. workspace / clippy / fmt 验证证据完整, 生产集成仍待续.

## 当前增量: 生产 OMC 转换与 Godot 链路

- CLI 在捕获和哈希 companion 后检测 OMC signature, 对私有 buffer 执行核心变换, 复用 plain OJM parser 与 PCM/Vorbis 准备. 原始磁盘 bytes 不变, fingerprint 保留编码源 digest, 相同 decoded PCM 的 OMC/OJM 源仍有不同 bundleKey.
- CLI 回归对实际冻结 OMC fixture 比较 Java PCM16, 验证原始文件未变及编码/明文身份不同. 截断 OMC 返回 CORRUPT_CHART, 不发布残缺 bundle, 已准备的有效 bundle 仍完整, 随后的健康源仍可正常转换. M30 继续明确拒绝.
- verify_native_ojn_gameplay.sh 增加 omc fixture 参数, 直接读取原始 omc.ojn/omc.ojm, 在 OJN 中补三个轨道的可判定事件; OMC bank bytes 保持冻结原样, 未预解码. 复用真实设置扫描、独立难度选择、native converter、判定/音频与 Result 全链路. 同时保留默认 plain OJM gate.
- red /tmp/vos-omc-cli-red.log; 验证记录 /tmp/vos-omc-cli.log, /tmp/vos-omc-gameplay.log, /tmp/vos-omc-plain-regression.log, /tmp/vos-omc-integration-workspace.log. 此增量没有 Godot runtime 改动或新增依赖.

## 最终 ticket 验收

- 状态 done. 生产集成提交 f579f5d, 独立固定基点审查 Standards 0 项 / Spec 0 项.
- 原始输入全链路证据: /tmp/vos-omc-gameplay.log 标明 omc variant, 从目录设置到三个难度各自的 gameplay/audio/Result; 原始 OMC bank 没有经过预解码替代.
- 解码/映射证据: 冻结生产 Java oracle 与 core omc_decode 三个测试, CLI 对原始 OMC fixture 比较 prepared PCM16, encoded source fingerprint 独立于 decoded PCM.
- 异常隔离证据: CLI 多个截断点返回 CORRUPT_CHART, 不发布失败任务的完成目录, 既有 healthy bundle 验证完整, 健康输入可恢复转换.
- 回归证据: /tmp/vos-omc-plain-regression.log 与 /tmp/vos-omc-integration-workspace.log, 对应进程退出 0; clippy/fmt 退出 0. 未引入未解释的 parity 差异.
- 后续 M30、全格式资源/性能门禁仍由 10/24/25 处理, 此 ticket 完成不代表整体迁移完成.

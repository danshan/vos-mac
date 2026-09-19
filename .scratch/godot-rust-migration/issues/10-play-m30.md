# 10: 游玩 M30 音频变体

**What to build:** 玩家能够游玩使用 M30 音频的 O2Jam 歌曲, 保持样本引用与解码语义正确.

**Blocked by:** 08: 游玩基础 OJN/OJM 歌曲.

**Status:** in-progress

- [ ] 真实 OJN/M30 输入从扫描、难度选择到 gameplay 通过, 不调用 Java 或预解码替代路径.
- [ ] 样本 ID、解码输出和引用关系由冻结 fixtures/oracle 验证.
- [ ] 损坏的头部、长度和样本引用受到边界检查, 不 crash、hang 或无界分配.
- [ ] 基础 OJM 路径无回归, 未解释的 parity 差异不得通过重写 expected 消除.


## 前置代码核对

- Java M30 bank header 为 28 bytes, sample header 为 52 bytes. encryption_flag=0 不变换, 16 使用 nami, 32 使用 0412, 每个完整 4-byte block 做 XOR, 末尾 1..3 bytes 不变. 每个 sample 独立开始, 与 OMC 的跨 sample 状态不同.
- Java sample ref 为 signed short, codec_code=0 映射到 1000+ref, codec_code=5 直接 ref. 旧逻辑对未知 codec/flag 仅警告并继续, Rust 实现必须明确规定边界与诊断, 不盲目沿用未知格式猜测.
- 现有 frozen m30-nami/m30-0412 fixture 的音频 payload 仅 8 bytes, 只能证明 parser metadata, 不足以作为真实 Vorbis 解码到 gameplay 的证据. 后续须增加自制可解码 Vorbis 的编码 M30 输入及生产 Java oracle, 不改写原有冻结期望.

## 当前实现与验收证据

- core parse_m30_in_place 对完整 bank 校验后才原位 XOR, 返回借用 Ogg samples. 支持 flag 0/16/32 与 codec 0/5, ref 使用 signed short, ID 为 ref 或 1000+ref. 四字节完整组变换, remainder 保持不变. 取消后 buffer 丢弃.
- 边界: 沿用 512 MiB bank、65536 samples、64 MiB encoded Ogg 上限; offset 必须为 28, payload size/count 必须完整匹配, 拒绝截断、重复或负引用、尾部未声明数据. version、music flag 与 pcm_samples 不影响解码, 不按这些声明分配资源.
- Java 对未知 flag/codec 仅警告后继续, Rust 明确 UnsupportedFormat; 对重复引用不采用 Java 覆盖策略, 返回 CorruptChart. 这些是安全拒绝边界, 不冒充未知格式兼容性. 原冻结 goldens 未修改.
- CLI 在原始 digest/fingerprint 捕获后移动私有音频 buffer, 使用 M30 生产解析和既有 Vorbis/WAV 准备, 不复制整个 bank, 原始文件 bytes 保持不变. key sound index 7 与 BGM index 1003 均绑定到正确 SampleId, 相同音频内容去重.
- 新可播放编码 fixture 与 Java oracle 见 core fixtures/ojn/README.md. 三种 flag 的 raw Ogg hash、引用 metadata、PCM 均对照生产 Java; Godot gate 以 m30-plain/m30-nami/m30-0412 参数逐一通过设置扫描、难度选择、判定/audio/Result.
- red /tmp/vos-m30-red.log, /tmp/vos-m30-cli-red.log. 原始 stub fixture 最初测试误认为 ref=0, 核对 factory 后改为实际 ref=1, 不是生产 parity 变更.
- 证据 /tmp/vos-m30-core.log, /tmp/vos-m30-cli.log, /tmp/vos-m30-workspace.log, /tmp/vos-m30-plain-gameplay.log, /tmp/vos-m30-nami-gameplay.log, /tmp/vos-m30-0412-gameplay.log, /tmp/vos-m30-plain-regression.log, /tmp/vos-m30-omc-regression.log.

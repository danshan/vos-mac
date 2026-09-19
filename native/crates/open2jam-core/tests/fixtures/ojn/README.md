# OJN 长音修复 oracle

`hold-repair.json` 由迁移期 Java `EventList.fixEventList(OPEN2JAM, true)` 生成. 固定随机种子 20260919, 共 64 组, 每组 24 个事件, 包含三个 playable lanes 与 autoplay. Rust 测试只读取此 JSON, 不执行 Java.

- input 元组: source sample index (zero-based), lane (-1 为 autoplay), flag (0 tap / 2 hold / 3 release).
- expected 元组: 原始事件在组内的位置 index, sample index, 修正后的 lane, 修正后的 flag.
- 源 `parsers/src/org/open2jam/parsers/EventList.java` SHA-256: `852482159c20bd44d3c84e940fef3bed609d441439036dd24eba65836a58dfad`.
- JSON SHA-256: `bfeb009c9d674bb348f717f64bc50d3eb357ab19509c2db2edac565980dff469`.

生成命令依赖已由项目构建生成的迁移期 JAR. 最终 ticket 27 删除 Java generator, 保留冻结 JSON.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjnHoldOracle.java native/crates/open2jam-core/tests/fixtures/ojn/hold-repair.json
```

这组 oracle 验证事件修复, 不替代最终 bundle / gameplay 验收. 特别保留 backward repair 移动已遍历 RELEASE 到 autoplay 的行为; Java 不会再次清理此事件的 flag. 没有 tail 的最终 HOLD 也不在该修复步骤中丢弃.

## 音频 fixture

`tone.ogg` 与 `tone-multipage.ogg` 使用本项目生成的正弦波, 无外部音乐内容. 源 PCM 为 8000 Hz mono / 800 frames, 第 i 个 signed 16-bit 样本为 round(12000 * sin(2 * pi * 440 * i / 8000)). 使用 FFmpeg 9.0.1 内置实验性 Vorbis encoder 转为 44100 Hz stereo; 多页版本重复源 40 次. 编码器会引入重采样长度差异, 短文件的最终 granule 为 4416, 不能按输入时长假定 4410 frames.

```bash
ffmpeg -v error -y -i /tmp/ojn-tone.wav -ac 2 -ar 44100 -c:a vorbis -strict -2 tone.ogg
ffmpeg -v error -y -stream_loop 39 -i /tmp/ojn-tone.wav -ac 2 -ar 44100 -c:a vorbis -strict -2 tone-multipage.ogg
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java native/crates/open2jam-core/tests/fixtures/ojn/tone.ogg native/crates/open2jam-core/tests/fixtures/ojn/tone-java.pcm
```

`tone-java.pcm` 为迁移期 Java `OggPcmDecoder` / stb_vorbis 输出, stereo / 44100 Hz / PCM16 little-endian, 共 17664 bytes. 测试要求 Rust 与 Java 的长度相同, 每个 16-bit 样本差异不超过 1 LSB, 允许两个浮点解码器的末位量化差异. 本界限仅由当前 fixture 验证, 真实曲目集合仍在 ticket 24/25 验收.

| 文件 | SHA-256 |
|---|---|
| tone.ogg | 0dd2ab1efc0313bbba9db4b45cbf6e130c26449e57425da39c5fa6515ecc0b56 |
| tone-multipage.ogg | 8b49402dac335276af85ffcea70306398924c24b1126e5c8c75bded0bc0dd7ad |
| tone-java.pcm | 132a25d298c440ef5bd27451f96d46d46e7ec40cfeccc7a53a41bc4e099b050d |

FFmpeg 与 Java 仅用于一次性生成冻结 fixture, Rust 测试不调用它们. ticket 27 删除 Java generator, 保留 fixtures.

## 整数 PCM 量化 oracle

`integer-pcm-java.json` 由同一个 JavaSound decoder 生成. PCM8 覆盖所有 256 个 unsigned 值; PCM24/32 各覆盖 256 个边界及固定种子随机 signed 值. WAV format tag 为 1, mono / 8000 Hz, 预期为 PCM16 little-endian. 测试要求逐样本完全一致, 不使用 Ogg 的 1 LSB 容差.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java --integer-fixtures native/crates/open2jam-core/tests/fixtures/ojn/integer-pcm-java.json
```

JSON SHA-256: `20aa21cf3d51c39e4b71b7db41ff95065f0883f1c4534651ebe006b9d8ddd619`. 量化规则同时核对了项目 mise Zulu 17.66.19.0 的 `lib/src.zip` 内 `AudioFloatConverter`: PCM8/24 按正负端点分别归一化, PCM32 使用 binary32 比例, 输出再按 PCM16 正负端点量化. PCM16 自身使用原样路径.

`extended-pcm-java.json` 补充 format tag 3 的 float32/64 和 tag 6/7 的 A-law / μ-law. float 样本覆盖 0、正负端点、小值和 ±2, 每种 11 个; A-law / μ-law 各穷举 256 个编码字节. input 为原始字节数组, expected 为 PCM16 signed 数值. 所有样本要求与 Java 完全一致. 有限 float 超出 [-1, 1] 时保留 Java 的 int -> short 窄化行为, 不隐式改为 clipping; 非有限 float 在 Rust 中明确拒绝.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java --extended-fixtures native/crates/open2jam-core/tests/fixtures/ojn/extended-pcm-java.json
```

JSON SHA-256: `45de1ecb5d20faf05f2e4f47d2298a2237a60af5815b25d4974c34909979135b`.

## Metadata 编码样本

`ojn_parser.rs` 的 display metadata 测试使用固定 source bytes 与独立 Unicode 期望值. 四个 legacy 样本分别通过 Python 标准库的 euc_kr、gbk、big5、shift_jis 编码得到, 运行测试不再编码期望值. 原文分别为 `아름다운 세상`, `美丽的音乐世界`, `美麗的音樂世界`, `美しい音楽の世界`. UTF-8 样本为 `音楽の世界`. 测试还验证首个 NUL 后的垃圾字节不会影响显示, 不同字段可使用不同编码, 原始 source bytes 保留.

这组期望值不是 Java 显示 oracle. 对相同文本补零至 64 bytes 后调用旧 `ByteHelper.toString`, Java detector 分别误判四个 legacy 样本为 GB2312、EUC-KR、US-ASCII 和 GB18030. Native 保持有效 UTF-8 原文, 否则逐字段使用 chardetng 检测并通过 encoding_rs 严格解码, 不复刻已观察到的乱码. 此策略不保证任意短字段都可正确推断编码; companion 匹配必须在 file adapter 结合实际目录处理, 不把显示文本的猜测当作路径授权.

## OMC 解码 oracle

OmcOracle.java 直接调用生产 Java OJMParser.parseFile 和 JavaSoundPcmDecoder, 冻结原始解密 payload 与 PCM16 输出. Rust 测试只读取冻结文件, 不执行 Java. 多样本 bank 由固定公式 `(sample_index * 31 + byte_index * 7 + 3) % 256` 构造编码 bytes, 长度为 0, 1..34, 0, 257, 覆盖全部 17 个重排余数、跨 sample XOR 状态和空槽. 该文件是自制测试数据, 沿用项目许可证.

- omc-multisample.ojm: SHA-256 `3b694bbd32feec3ea72da78273743699fb9ab5c2ea5e7c6aa535883f03ac1d9f`.
- omc-multisample-java.json: SHA-256 `e415ec138a46c70f03a75dd409980138677f2a912ebcd90e9ae0a60ad4d7dce6`.
- omc-frozen-java.json: SHA-256 `7f877b01c70aadacd5888ab1d4868d487adceeb21dd432c99807a203d4d1d2ba`.
- Java decoder source SHA-256: `b4a61fb35727b60d152ca318826e9c4fa1b525c765245e372cf472165d518488`.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OmcOracle.java native/crates/open2jam-core/tests/fixtures/ojn/omc-multisample.ojm native/crates/open2jam-core/tests/fixtures/ojn/omc-multisample-java.json
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OmcOracle.java rewrite/golden/java-migration/sources/ojn/omc.ojm native/crates/open2jam-core/tests/fixtures/ojn/omc-frozen-java.json
```

既有 omc.ojm 的源 hash 由 migration manifest 管理. 重排 permutation 从现有 Java format table 迁移; 对照输出来自 Java 生产解码, 不是 Rust 自己生成的期望值. 原始 Ogg bytes 不经过 OMC WAV 变换; 本轮短 Ogg sentinel 只验证不变性, 不作为音频可解码证明.

## M30 可播放输入与 oracle

create_m30_audio_fixtures.py 使用既有自制 tone.ogg 构造 plain / nami / 0412 三个编码 bank, 先写 codec 0/ref 3 (index 1003), 再写 codec 5/ref 7 (index 7), 不以文件顺序猜测 sample ID. M30Oracle.java 直接调用生产 OJMParser 与 OggPcmDecoder. 三种输入的解密 SHA-256/metadata oracle 一致, 两个 sample 的 Java PCM 均与已冻结 tone-java.pcm 完全一致. Rust 对 Ogg bytes 要求精确一致, prepared PCM 使用此前已声明的 1 LSB Vorbis decoder 容差. 无外部歌曲素材, 沿用项目许可证.

- m30-plain.ojm: SHA-256 `5b390755b58c3917296da973acbf060d4f883f2ef308c17f331b92e87c9bb972`.
- m30-nami.ojm: SHA-256 `7fb08be6266f6ac3bf7378ed7a44fc7404e78f4c8a5d0945c758163646a51077`.
- m30-0412.ojm: SHA-256 `6b27749061f8bb366a7d6c306c1a14ffbb8e1bacc45896f89f7988615f232dd2`.
- m30-java.json: SHA-256 `1e70bce280c4a9c360126f6015e78fe4a2017ffb3944cde62ffbbfab9b743058`.

```bash
mise exec -- python3 rewrite/tools/create_m30_audio_fixtures.py
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/M30Oracle.java native/crates/open2jam-core/tests/fixtures/ojn/m30-nami.ojm /tmp/m30-java
```

其余两个 flag 使用同一 generator 命令更换输入路径; 比较 JSON 与两个 PCM 输出, 不覆盖既有 expected. 原 migration sources 中的 M30 stub fixture 仍只代表 metadata 可解析, reference 为 1, 8-byte payload 明确返回 AudioDecodeFailed.

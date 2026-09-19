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

# osu timing oracle

这组自制谱面通过生产 Java ChartParser 和 RenderTimingCompiler 生成冻结结果. OsuTimingOracle.java 只序列化实际结果, 不重新实现 timing 算法. Rust 测试读取 JSON, 不执行 Java. ticket 27 删除迁移期 generator, 保留 fixtures.

- timing.osu 覆盖源 timing 乱序、负时间 tempo/scroll、同刻重复 BPM 与多个 scroll、3/4/5 拍号、跨拍号长音、自定义 sample 和 binary32 volume.
- late-tempo.osu 覆盖首个 tempo 晚于 0、向前外推、非整数 beat length、跨 tempo 长音和毫秒间隔事件.
- JSON samples 元组为 `[timeUs, measure, lane, flag, sampleIndex, volume]`, lane -1 表示 autoplay, 其余为 0..6. timing 元组为 `[timeUs, bpm]`. 使用与 exporter 相同的时间/BPM 去重规则, 在去重后转换为整数微秒. volume 将 Java float 精确提升为 double 后记录.
- 这是长音修复前的 compiler oracle, 不替代 EventList 修复、sample/audio 准备、bundle v2 与 Godot 验收. 原有 seven-key gameplay golden 仍保持不变, 另有测试直接对照其 notes.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/timing.osu native/crates/open2jam-core/tests/fixtures/osu/timing-java.json
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/late-tempo.osu native/crates/open2jam-core/tests/fixtures/osu/late-tempo-java.json
```

| 文件 | SHA-256 |
|---|---|
| timing.osu | 0cb526d044dca58ed58d697848b2933242d9761f0bf0a5cea472a04233d20f5d |
| timing-java.json | 6cee31e2f8bf902d727dcee1f4d36b1fb8cddd20506e0ce227e58b3dcb9fde91 |
| late-tempo.osu | e68f78a0abb675b7efaface0112cafb05307a542c019c55d9d55b6f901a64ac0 |
| late-tempo-java.json | b67d91be6bf3cfae50e01a842876a2e694eaa4527c1c9ba4e36dd136f525b614 |
| OsuManiaParser.java | 7ae00715cddc8b79f639cb1dc94cecca4225047f3c3dedd42d9f478aa7dbd943 |
| RenderTimingCompiler.java | 95da9d1bc2e03a58e60e58c612efce59b0621944dbc634a86e4fb8454b6775c0 |

边界差异: Rust 明确拒绝 i32 时间差溢出、无限 velocity、超过 1,000,000 measures 或精确微秒范围的 timeline, 以及 Java 拍号缩放产生的各输出轨道时间倒退. 不以 wraparound、重排 notes 或覆盖 golden 隐藏这些问题. 原始事件上限为 notes + timing <= 1,000,000; 展开 hold 尾部与 meter 事件后最多 2,000,001 个内部事件, 未按时间跨度无界分配. TimingMap 查询使用二分, stable sort 前后及逐输入事件/measure 检查取消.

编译器保持 binary64 累积时间, 仅输出时取整数微秒, 不用逐事件舍入后的时间继续累积. 原始 timeline 的 BPM/scroll 以 binary64 保留 Java compiler 值. 下节另行验证完整 Chart 的 Ratio 转换; 仅凭修复前的原始 timeline oracle 不能宣称已完成 wire 精度验收.

## 完整 Chart 与精度补充

后续 CompiledOsuChart 增量已实现 Ratio wire 转换与 sample ID 绑定. 上述原始 timing oracle 仍代表修复前边界. 新增 hold-repair-gameplay-java.json 直接调用生产 VosGameplayExporter, 因而包含 EventList 修复后的重叠长音、转 autoplay、释放顺序和 volume. 仅将 sourcePath 归一化为 fixture.osu, 不改变其他 expected 字段. sample ID 0 的静音 autoplay 在 v2 中不生成虚构 audio asset; 对照时明确排除此类音频空事件.

precision.osu 的同刻多 tempo/scroll 冻结非整数及接近整数的 Java binary64 值. Rust wire Ratio 与 oracle 的相对误差上限为 4 * f64::EPSILON, 详见 docs/rewrite/2026-09-19-gameplay-v2-values.md. Note 时间仍使用独立整数微秒合同, volume 精确保留 binary32, 不使用上述容差.

```bash
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/hold-repair.osu native/crates/open2jam-core/tests/fixtures/osu/hold-repair-gameplay-java.json gameplay
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OsuTimingOracle.java native/crates/open2jam-core/tests/fixtures/osu/precision.osu native/crates/open2jam-core/tests/fixtures/osu/precision-java.json
```

| 文件 | SHA-256 |
|---|---|
| hold-repair.osu | abcf70fad9d71a9df25b793e00dc564ba7cbba806e821bf1cdb32f6442bf45d0 |
| hold-repair-gameplay-java.json | cbf99ed96917774c6bc81fcf56194fbfdacb3dd1c7dfcc5a14a1a9d6b0dceb5e |
| precision.osu | 9b67a77795933e8d18786107ac69379f7683e7e8995810847fec511f62c13947 |
| precision-java.json | 477c88ae79830fa1588ebdbae31944bb0169302269246ca362551655b0e68469 |

## 文件音频 oracle

四个 MP3 由既有自制 tone-java.pcm 编码, 输入为 stereo / 44100 Hz / PCM16 little-endian. FFmpeg 9.0.1 的 libmp3lame 仅用于生成 fixture, Rust 测试不调用 FFmpeg 或 Java. oracle 由生产 JavaSoundPcmDecoder 输出, 通过已有 OjmAudioOracle.java 冻结, 不使用 Rust 输出更新 expected. 自制信号沿用项目许可证.

```bash
ffmpeg -v error -y -f s16le -ar 44100 -ac 2 -i native/crates/open2jam-core/tests/fixtures/ojn/tone-java.pcm -c:a libmp3lame -b:a 128k -write_xing 0 -id3v2_version 0 tone.mp3
ffmpeg -v error -y -f s16le -ar 44100 -ac 2 -i native/crates/open2jam-core/tests/fixtures/ojn/tone-java.pcm -c:a libmp3lame -b:a 128k -write_xing 1 -id3v2_version 0 tone-xing.mp3
ffmpeg -v error -y -f s16le -ar 44100 -ac 2 -i native/crates/open2jam-core/tests/fixtures/ojn/tone-java.pcm -ar 22050 -ac 1 -c:a libmp3lame -q:a 4 -write_xing 1 -id3v2_version 4 -metadata title=Fixture mono-22050.mp3
ffmpeg -v error -y -f s16le -ar 44100 -ac 2 -i native/crates/open2jam-core/tests/fixtures/ojn/tone-java.pcm -ar 11025 -ac 1 -c:a libmp3lame -q:a 4 -write_xing 1 -id3v2_version 3 -metadata title=Fixture mono-11025.mp3
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java tone.mp3 tone-mp3-java.pcm
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java tone-xing.mp3 tone-xing-java.pcm
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java mono-22050.mp3 mono-22050-java.pcm
mise exec -- java -cp target/open2jam-0.1.2.jar rewrite/tools/OjmAudioOracle.java mono-11025.mp3 mono-11025-java.pcm
```

| 文件 | PCM 属性 / bytes | SHA-256 |
|---|---|---|
| tone.mp3 | MPEG-1, stereo CBR | 67c0443aec43e4fe5f4b3df2ac4dd65b5a77b10339d4c43c6a6ed17200028992 |
| tone-mp3-java.pcm | 44100 Hz stereo, 23040 | a7d895ef9535a76ad82f47899c60b21529394d06aad1a39cefd604a86c6b11c7 |
| tone-xing.mp3 | MPEG-1, stereo CBR, Info | 91adc4301e3eb9fd030117987720b1e4b67b0934b13624a586844aec31050e2f |
| tone-xing-java.pcm | 44100 Hz stereo, 27648 | 4f77ff4465157df808916e01fdcfa30d3711dbbf4024c6b210921ecb40d2c560 |
| mono-22050.mp3 | MPEG-2, mono VBR, ID3v2.4 | 759d475adef5a8211255400540f035ceb237cd913c16455a433ebd94c30afbba |
| mono-22050-java.pcm | 22050 Hz mono, 8064 | b2e35e8578cce53a036bb931f4b56036b800194c55295010b62f5668d67d5b34 |
| mono-11025.mp3 | MPEG-2.5, mono VBR, ID3v2.3 | 3854b339298c4327dc0b25f0dccf06ebbd7358d6bff71a2346328180f518b7af |
| mono-11025-java.pcm | 11025 Hz mono, 5760 | d04d022bb2c26c6d211ac26f3c8647e973b73471b9ec6f5fd2fc2d4372c2836f |

MP3 PCM 对照要求 sample rate、channels、样本数与对齐完全相同, 数值差异峰值 <= 32 PCM16 LSB、RMS <= 16 LSB. 首两组 stereo 的峰值差异为 17 LSB, RMS 分别约 10.339 和 9.438 LSB. 门限约束不同浮点 decoder 的量化差异, 不容许按音频相关性平移或裁剪后再比较. 32 LSB 约为 signed PCM16 满幅的 0.1%, 这不是 WAV 或 Ogg 的新容差.

生产路径保留 JavaSound 的未裁剪 MP3 时间轴, 包括 Xing/Info/VBRI metadata frame. Symphonia 常规 demuxer 会移除这些帧, 所以 native 使用有限 MPEG frame framing 并关闭 gapless, 实际 frame 解码仍由 Symphonia 完成. 四组中 Info/Xing 已有直接 oracle; VBRI 使用同样完整 frame 路径, 尚无独立 VBRI fixture. ID3v2 footer 和 ID3v1 附加测试验证 metadata 不产生 PCM. 严格拒绝截断帧, 不复刻宽松 EOF/resync. free-bitrate、非 ID3 尾部和 WAV extensible 等当前未支持输入不会静默得到部分音频.

依赖核对: [Symphonia 0.6.1 官方文档](https://docs.rs/symphonia/0.6.1/symphonia/) 确认 mp3 feature; 本地同版本 AudioDecoderOptions 默认开启 gapless, MP3 显式关闭. MPEG header/framing 与 metadata 规则同时核对该版本 bundle-mp3/header.rs、demuxer.rs 和 metadata/id3v2 源码. Context7 library 解析成功, docs 请求 fetch failed 后使用这些来源.

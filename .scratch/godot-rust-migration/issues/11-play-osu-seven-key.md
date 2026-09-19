# 11: 游玩本地 osu!mania 7K 谱面

**What to build:** 玩家选择本地 7K osu!mania 谱面, 解析关联音频后以正确时序游玩.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** in-progress

- [ ] 原始 osu 谱面从 Rust catalog 到 bundle v2 和 Godot gameplay 全链路可用.
- [ ] 关联音频、timing、scroll、长音和 sample 行为与冻结 oracle 对照.
- [ ] 非支持模式或键数明确拒绝, 不静默按 7K 解释.
- [ ] 缺失音频、畸形内容与无效引用给出可诊断错误, 不影响其他歌曲.


## 当前增量: 有界 osu!mania 7K 原始解析

- core OsuSource 从 UTF-8 文本解析 metadata、audio reference、tap/hold、自定义 sample、BPM 与 inherited scroll 点. 仅接受 Mode=3/CircleSize=7, 不将 6.5 等非 7K 值四舍五入为 7K.
- 保留 Java 当前行为: 源时间按 floor(ms + 0.5) 取整, X 映射后 clamp 到七轨, volume clamp 后以 binary32 除以 100, 自定义 sample 首次出现从 index 2 分配并按文件名复用. index 0 表示无自定义音频, index 1 留给背景轨. 不将这个原始模型误当作最终微秒 timeline.
- 支持 UTF-8 BOM、CRLF、TitleUnicode/ArtistUnicode 与 difficulty Version. 字段覆盖顺序沿用 Java 文件顺序. 缺少有效基础 tempo 时保留 120 BPM / 4 拍默认; 资源文件是否存在留给 adapter 检查.
- 当前安全边界: source 64 MiB、单行 64 KiB、notes + timing 最多 1,000,000、custom samples 最多 65534. 按行及输入 chunk 检查取消. 拒绝无格式头、非法 UTF-8/NUL、非有限数值、time 超 i32 毫秒范围、无效 hold、危险路径和生成无限 BPM/scroll 的数值.
- Java 对畸形行、无效 hold/timing 常跳过或用默认值, Rust 对已识别语义字段明确报 CorruptChart 并附 line, 不静默丢音符. 未实现的 slider/spinner 类型返回 UnsupportedFormat. 这些是输入拒绝差异, 原 goldens 未改动.
- 格式核对来源: https://osu.ppy.sh/wiki/en/Client/File_formats/osu_(file_format), 同时以仓库 OsuManiaParser 为当前播放语义依据. 官方格式包含更多默认 hitsound/事件能力, 本次不额外宣称超出 Java 已支持的行为.
- 测试: frozen seven-key 的七轨与长音、sample 复用/音量、scroll、非 mania/非 7K、畸形输入、4096-note 工作集与取消. red /tmp/vos-osu-parser-red.log, /tmp/vos-osu-number-red.log; 当前记录 /tmp/vos-osu-parser.log, /tmp/vos-osu-parser-workspace.log.
- 尚待: Java timing/scroll/measure 编译 oracle、完整 sample/audio 准备、osu beatmap-set 身份与 catalog、native bundle adapter 和 Godot 实际加载. ticket 保持 in-progress.
- 原始解析增量 daff5bc 固定基点独立审查: Standards 0 项 / Spec 0 项. workspace、clippy、fmt 退出 0. 下一步需复刻 Java TimingMap 的 measure 转换与 RenderTimingCompiler 的非 OJN 拍号缩放, 不能直接用源毫秒加固定偏移代替 timing oracle.

## 当前增量: osu timing 编译

- OsuSource.timeline 保留 Java 两阶段编译: 按基础 tempo 积分并归一化 measure, 再按 RenderTimingCompiler 的非 OJN 拍号缩放得到事件时间. 保留 1500 ms lead-in、每小节拍号重置、meter=4 不额外发 reset、同刻 stable order 和 scroll 只改变 visual timing 的行为.
- 两组新增生产 Java compiler oracle 覆盖负时间、正时间首个 tempo、变速、非整数 beat length、重复 BPM、同刻 scroll、3/4/5 拍号与长音. 原 seven-key gameplay golden 不变, 另有直接对照. fixtures/osu/README.md 记录来源、hash、生成方法与拒绝边界.
- 保持 binary64 累积, 最终时间转换为整数微秒. 数值溢出、过多 measures、各输出轨道倒退明确拒绝. 二分 timing 查询避免每个 note 线性遍历全部 tempo; cancellation 覆盖输入构建和稀疏小节填充.
- red 记录: /tmp/vos-osu-timing-red.log 与 /tmp/vos-osu-timing-bounds-red.log. 当前测试记录: /tmp/vos-osu-timing-green.log. 本增量不完成 ticket: long-note repair、BPM/scroll Ratio wire 转换、sample/audio、catalog/adapter 与 Godot 加载仍待实现.
- timing 增量 7fbc199 固定基点独立审查: Standards 0 项 / Spec 0 项. workspace、clippy、fmt 退出 0; 记录 /tmp/vos-osu-timing-workspace.log、/tmp/vos-osu-timing-clippy.log. Java oracle provenance 仍匹配冻结源, 记录 /tmp/vos-osu-timing-provenance.log. 无产品 Java-free 完成声明.

## 当前增量: 完整 osu Chart 构造

- OsuSource.compile + CompiledOsuChart.with_samples 连接 timing、长音修复、稳定 ChartIdentity、音符/尾部顺序和 sample ID 解析, 输出通过验证的 GameplayChartV2. OJN 与 osu 使用共享 legacy_notes 实现, 保留有界搜索与取消.
- 新增生产 VosGameplayExporter 长音 oracle 对照重叠 holds、转 autoplay 的 notes、同刻顺序与释放时间. sampleless Note 保留; Java 中 index 0 的静音 autoplay 不生成 v2 音频引用. 非零 sample 缺失明确返回 MissingAsset, 未配对 hold 返回 CorruptChart.
- 0..100 音量按 Java binary32 精确转换为 Ratio. 非整数 BPM/scroll 使用既有 wire bounds 内的连分数, 回转 binary64 相对误差 <= 4 * f64::EPSILON, 否则拒绝; 独立 precision oracle 与超范围测试覆盖该行为. 不更改已冻结整数微秒.
- duration 覆盖全部事件与 timing, 不直接复制旧 nominal duration. chart_path 相对 beatmap set, 下一步 adapter 负责 catalog source 与 audio 文件绑定.
- red: /tmp/vos-osu-gameplay-red.log. 当前精度与修复记录: /tmp/vos-osu-gameplay-precision.log, OJN 原有 64 组修复 oracle 继续用于共享算法回归. 尚待 sample/audio 实际解码、catalog/adapter 和 Godot 全链路验收, ticket 保持 in-progress.
- core Chart 增量 f12140e 固定基点独立审查: Standards 0 项 / Spec 0 项. workspace 记录 /tmp/vos-osu-gameplay-workspace.log, Clippy /tmp/vos-osu-gameplay-clippy.log, 最终 core /tmp/vos-osu-gameplay-final-core.log, fmt 退出 0. OJN 真实 CLI -> Godot 三难度回归记录 /tmp/vos-osu-shared-holds-ojn-gameplay.log, 退出 0. 这条回归证明共享修复未破坏既有 OJN 链路, 不代表 osu 已在 Godot 可玩.

## 当前增量: 独立 WAV / Ogg / MP3 文件音频

- 将既有 PCM/Vorbis 准备实现移至 audio 模块, OJM 保留类型 re-export, 实际解码复用同一路径. 新增有界 RIFF chunk 解析, WAV 输出与现有 Java osu audio golden 精确一致; unknown metadata chunk 按 padding 跳过, 重复 fmt/data、截断和错误尺寸明确拒绝.
- 仅为既有 Symphonia 0.6.1 启用 mp3 feature, native lock 新增同版本 symphonia-bundle-mp3. Context7 library 解析成功但 docs 请求 fetch failed; 交叉核对本地 0.6.1 源与官方 docs.rs, 未凭旧版 API 实现.
- 发现普通 Symphonia demuxer 会去掉 Xing/Info frame, JavaSound 则将其作为一帧音频保留. Native 对 MP3 使用有界 MPEG-1/2/2.5 Layer III frame 读取并关闭 gapless, 交给同一个 Symphonia decoder, 不自行实现音频 codec. metadata frame 同样解码, 不猜测补静音. 保持 ID3v2.2..2.4/ID3v1 tag 不产生音频; 截断末帧不能当作正常 EOF.
- 四组 Java PCM oracle 冻结 mono/stereo、CBR/VBR、MPEG-1/2/2.5、ID3/Xing 的长度与时序. MP3 decoder 数值容差明确为峰值 <= 32 PCM16 LSB, RMS <= 16 LSB, 不放宽长度或允许时间偏移. 两组 stereo oracle 的实测峰值为 17 LSB; 该容差只用于 MP3. WAV 精确与 Ogg 1 LSB 约束不变.
- 输入文件暂限 64 MiB、单个准备后 PCM 256 MiB, 每 chunk/frame 检查取消. 此处不宣称 ticket 20 最终资源策略完成. free-bitrate MP3、任意非 ID3 尾部以及 WAV extensible/未支持编码明确失败, 更广实际歌曲工作集仍需 ticket 24/25 验证.
- red: /tmp/vos-audio-files-red.log、/tmp/vos-wave-file-red.log, MP3 时序差异记录 /tmp/vos-mp3-parity-probe.log, 文件音频矩阵 /tmp/vos-audio-files-matrix.log. 当前完成 adapter 的音频前置能力; 文件身份/资源捕获、catalog、bundle producer 与 Godot osu 入口仍待接线, ticket 保持 in-progress.

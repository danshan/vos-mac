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

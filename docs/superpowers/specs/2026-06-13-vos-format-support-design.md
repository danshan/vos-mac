# VOS Format Support Design

## 目标

在当前 open2jam 项目基础上增加 VOS 文件支持, 游戏方式保持和现有项目一致. VOS 只作为新的谱面输入格式接入现有 `Chart` 和 `EventList` 管线, 不引入独立玩法, 独立判定, 或独立 runtime path.

## 关键约束

- 每个 `.vos` 文件作为一个 chart.
- VOS header 中存在有效 `Level` 时, 作为数值难度展示和排序.
- VOS `Level` 缺失或解析异常时, UI 显示 `Unknown`.
- 不把 VOS 强行映射成 Easy, Normal, Hard 等 O2Jam 难度档位.
- 第一版不复刻 VOS 原版演奏逻辑, 只把 VOS note 映射到现有 open2jam 轨道, 长音, 判定和显示.
- 第一版不引入真实 MIDI 播放或 MIDI-to-sample 转换.

## 参考依据

VosDroid 的 `VosParser` 说明 VOS INF segment 读取顺序包括 `Title`, `Artist`, `Comment`, `Author`, `MusicType`, `MusicTypeEx`, `VosTimeLength`, 以及 1 byte `Level`. 其实现只解析 `Level`, 未看到稳定的 Easy, Normal, Hard 语义映射. 因此本项目保留 VOS 原始数值 level, 并把缺失 level 作为 UI 显示问题处理.

## 架构方案

采用原生 parser 接入方案:

- 新增 `VOSChart`, 继承现有 `Chart`.
- 新增 `VOSParser`, 负责 `.vos` 文件识别, header 解析, note 解析, 和 `EventList` 生成.
- `Chart.TYPE` 增加 `VOS`.
- `ChartParser.parseFile(File)` 注册 `VOSParser`.
- UI 仅增加 level display helper, 不改变 `Chart.getLevel()` 的 `int` 契约.

该方案保持 format parsing 与 gameplay 分离. VOS parser 的输出是现有 `EventList`, 后续渲染, timing, judgment, autoplay 逻辑继续复用当前实现.

## 文件发现与分组

当前 `ChartParser` 是统一格式分发入口. VOS 支持应遵循现有模式:

- 如果输入是单个 `.vos` 文件, 返回只包含一个 `VOSChart` 的 `ChartList`.
- 如果输入是目录, 扫描目录内 `.vos` 文件, 每个 `.vos` 文件产生一个 `VOSChart`.
- 第一版不做同曲名多难度合并, 因为尚未确认 VOS 资源包存在稳定命名约定.

## Metadata 映射

`VOSChart` 字段映射:

- `title`: VOS `Title`, 缺失时使用文件名去扩展名.
- `artist`: VOS `Artist`, 缺失时为空字符串.
- `genre`: VOS `MusicType` 映射值, 未知值显示 `Other`.
- `noter`: VOS `Author`.
- `duration`: VOS `VosTimeLength / 1000`.
- `level`: VOS `Level`, 缺失时内部使用 `0`.
- `levelKnown`: VOS `Level` 是否成功读取.
- `cover`: 第一版不从 VOS 读取 cover, 默认走现有 no-image 逻辑.

`levelKnown` 是 VOS 专有 metadata, 不改变 `Chart` 抽象. UI 需要识别 `VOSChart` 或使用一个 helper 方法显示 `Unknown`.

## Event 映射

VosDroid 的 note 结构显示每个 note 为 13 bytes:

- `sequencer`: 4 bytes.
- `duration`: 4 bytes.
- `channel`: 1 byte.
- `pitch`: 1 byte.
- `volume`: 1 byte.
- `keyboard`: 1 byte.
- `type`: 1 byte.

映射规则:

- `keyboard` 中的 key index 映射到 `Event.Channel.NOTE_1` 到 `NOTE_7`.
- VOS 标记为 user-playable 的 note 映射为 playable note.
- 非 user-playable note 第一版映射到 `AUTO_PLAY` 或忽略 key sound, 取决于现有 sample 支持是否能安全表达该事件. 不引入 MIDI 播放.
- 普通 note 使用 `Event.Flag.NONE`.
- Long note start 使用 `Event.Flag.HOLD`.
- Long note end 使用 `Event.Flag.RELEASE`.

时间映射:

- `measure = sequencer / 0x300`.
- `position = (sequencer % 0x300) / 0x300.0`.
- Long note release 使用 `sequencer + duration` 计算 release 位置.

这个规则与 VosDroid 中 `sequencer * resolution / 0x300` 的转换关系一致, 并能直接进入现有 `Event` 的 measure/position 排序和 timing 管线.

## UI 调整

需要调整的位置:

- `src/org/open2jam/gui/ChartTableModel.java`.
- `src/org/open2jam/gui/ChartListTableModel.java`.

当前这两处直接显示 `c.getLevel()`. 新设计应增加一个小型 display helper:

- 非 VOS chart: 返回 `String.valueOf(c.getLevel())`.
- VOS chart 且 `levelKnown == true`: 返回 `String.valueOf(c.getLevel())`.
- VOS chart 且 `levelKnown == false`: 返回 `Unknown`.

表格排序仍使用 `Chart.compareTo()` 的 `getLevel()` 数值, 不在第一版引入 UI 层自定义排序.

## 默认缩略图

第一版使用现有 `Chart.getNoImage()` 作为 VOS 默认缩略图. 如果后续要增加 VOS 专用默认图, 应作为独立资源变更处理, 不阻塞 parser 接入.

## 错误处理

- Header magic 不匹配时, `VOSParser.canRead()` 返回 false 或 `parseFile()` 返回 null.
- Segment 地址越界, note 长度异常, 或 INF segment 不完整时, 当前文件跳过并记录 warning.
- `Level` 单独解析失败不应导致整首歌不可用, 只把 `levelKnown` 置为 false.
- Metadata 字符串按 VOS 常见编码读取, 若不能可靠识别, 第一版可优先使用 GB2312 并 fallback 到平台默认或 UTF-8.

## 验证计划

自动验证:

- 新增 parser fixture 测试, 覆盖 metadata, known level, missing level, note count, long note flags, event ordering.
- 如果缺少 VOS fixture, 可从公开样例构造最小 `.vos` fixture, 只包含 header, INF, channel, note 和必要 segment.

构建验证:

```bash
mvn -s .mvn/settings.xml test
mvn -s .mvn/settings.xml -DskipTests package
```

人工验证:

- 把 `.vos` 文件加入歌曲目录后, 歌曲列表能扫描到该 chart.
- 有 `Level` 的 VOS 显示数值难度.
- 缺失 `Level` 的 VOS 显示 `Unknown`.
- VOS 无 cover 时显示默认缩略图.
- 进入游戏后轨道, note, long note, 判定方式保持当前 open2jam 行为.

## 非目标

- 不实现 VOS 原版 MIDI 演奏复刻.
- 不实现同曲多 VOS 文件自动聚合为多难度.
- 不新增 Easy, Normal, Hard 语义映射.
- 不重写当前歌曲选择 UI.
- 不调整现有 OJN, BMS, SM, SNP 行为.

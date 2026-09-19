# Game Loading

该上下文定义从主菜单进入选歌页, 以及从难度选择进入 gameplay 的用户可见加载边界与性能预算.

## Language

**Song**:
玩家在选歌列表中看到的逻辑歌曲, 仅以名称显示. Song 由稳定的 `songId` 标识; 名称相同但来源歌曲包或规范化源目录不同的 Song 不得合并.
_Avoid_: Catalog entry, chart row

**Chart**:
属于某个 Song 的可游玩谱面, 在玩家选择 Song 后作为难度选项显示. O2Jam 同一 `.ojn` 文件中的多个 `chartIndex` 是同一 Song 的不同 Chart.
_Avoid_: Song, difficulty row

**Difficulty Selection**:
玩家选择 Song 后, 在独立面板中选择其 Chart 的步骤. 歌曲列表保持固定行高且只显示歌曲名称; 选择 Chart 或执行明确的 Play 操作后才进入加载.
_Avoid_: Expanded song row, flattened chart list

**Song ID**:
区分曲库来源与歌曲包的稳定歌曲身份, 不因曲库当前位置或显示名称变化而改变. 显式重新定位曲库保留其下歌曲身份, 新增曲库来源不按内容相同自动合并歌曲.
_Avoid_: Title key, display name

**Library Root**:
用户独立管理的一处曲库来源, 其身份与当前所在目录分离. 新增目录表示新来源, 不隐式替代已有曲库.
_Avoid_: Absolute path identity, content-deduplicated library

**Library Relocation**:
用户明确为已有 Library Root 指定新目录的操作, 保留该曲库身份及其中仍可对应的歌曲身份和选择状态. 根据内容相同自动推断搬移不属于该操作.
_Avoid_: Remove and re-add, automatic move detection

**Song Search**:
在内存中的 Song 索引上对子串进行大小写无关匹配, 匹配来源文件的 basename 或歌曲 `title`. 不匹配完整目录路径、artist、难度或其他元数据, 也不得触发目录扫描或 Java 进程.
_Avoid_: Metadata search, catalog scan

**Format Filter**:
选歌页上对 `O2Jam`, `VOS`, `osu!mania`, `Bundle` 的多选筛选. 默认全部选中且至少保留一个类型; 筛选结果与 Song Search 结果取交集.
_Avoid_: Single format mode, directory filter

**Godot Product Contract**:
Java-free 产品必须完整支持的输入与运行能力, 包括 VOS、O2Jam OJN/OJM、osu!mania `.osu`/`.osz`、exported bundle discovery, 以及 catalog、gameplay、audio、缓存、进度、取消和 Godot 打包. 旧 Swing/LWJGL 应用及 BMS、SM、SNP 不属于该合同并正式退役.
_Avoid_: Entire legacy Java surface, parser dispatch list

**Java-Free**:
产品运行、开发构建、测试 gate 和发布包均不需要 JRE、JDK、Maven、JAR 或 Java fallback. Java 只可在迁移期间作为冻结 golden corpus 的来源, parity gate 完成后必须删除.
_Avoid_: Java-free runtime only, optional Java exporter

**Migration Release Platform**:
首个 Java-free 完整迁移版本面向本机自用, 交付 ad-hoc 签名的 macOS Apple Silicon Godot application. 公开下载分发、Developer ID、公证及其他桌面安装包不属于本次交付范围.
_Avoid_: Simultaneous desktop release matrix, macOS-only core

**Native Converter**:
共享的 Rust core 及其 native CLI adapter, 负责原始谱面解析、timing 编译、音频准备和 relocatable bundle 生成. Godot 通过结构化进度与可取消进程调用使用它; 只有 benchmark 证明该边界阻碍性能预算时才增加薄 GDExtension adapter.
_Avoid_: GDScript binary parser, Java exporter replacement shim

**VOS Audio Parity**:
固定、可再分发 SoundFont 下的确定性行为等价, 严格保持 MIDI tempo、event order、bank/program、note、velocity、pan、duration、minimum gate、tail 和 PCM 格式. 不要求与依赖 macOS 系统 DLS 的旧 Java 输出 bit-exact, 并接受一次可审计的 canonical timbre 变化.
_Avoid_: System DLS parity, platform-dependent PCM

**Song Selection Ready**:
选歌页已经显示可选择的歌曲列表, 并且搜索与类型筛选可以立即响应. 热启动 P95 不超过 300 ms.
_Avoid_: Song page opened, catalog loaded

**Gameplay Ready**:
所选谱面已经完成 gameplay 必需资源的准备, 玩家可以开始游玩. 加载预算在固定的 Performance Acceptance Corpus 上验收, 不代表所有规模曲目都具有相同加载时限.
_Avoid_: Gameplay page opened, loading finished

**Cold Gameplay Load**:
所选 Chart 的派生产物与全局 MIDI 派生缓存均为空时, 从选择该 Chart 到 Gameplay Ready 的完整等待, 包含约 300 ms 的预热触发等待. 该术语不等同于操作系统文件缓存也为空.
_Avoid_: Post-prewarm Play latency, empty chart cache only

**Performance Acceptance Corpus**:
用于验收加载预算的固定代表性与压力曲目集合, 其具体规模由原型测量后冻结. 集合规模之外、仍在安全资源上限内的曲目继续支持并展示真实进度, 但不承诺相同加载预算.
_Avoid_: All possible charts, safety input limit

**Loading Progress**:
从操作开始到对应 Ready 状态为止, 持续向玩家展示的真实加载进度. 总进度必须从 0 到 100 单调递增, 同时显示当前阶段及实际完成数量; 100 只表示对应 Ready 状态已经达成.
_Avoid_: Spinner, fake progress

**Catalog Refresh**:
选歌页可操作后继续执行的歌曲目录扫描. 有缓存时不得阻塞选歌, 应显示基于真实已完成数量的进度并增量更新列表; 无缓存时才使用阻塞式加载.
_Avoid_: Startup scan, catalog reload

**Gameplay Artifact Cache**:
按 `chartId`、源文件指纹和 exporter schema version 标识的持久化 gameplay 导出产物. 命中时复用 gameplay JSON、audio manifest 及已准备资源; 缓存无效或损坏时安全重建.
_Avoid_: Temporary export, unchecked cache

**Gameplay Cache Budget**:
Gameplay Artifact Cache 的可配置容量上限, 默认 10 GB 且 Settings 允许从至少 5 GB 起调整. 超限时后台按 LRU 淘汰未被选择、预热或 gameplay 使用的完整 Chart artifact; Catalog index 不计入该预算.
_Avoid_: Unbounded cache, source song quota

**Legacy Derived Data**:
旧 Java exporter 生成的 catalog、bundle 和 audio cache. Java-free 版本使用全新 v2 namespace, 不读取或迁移这些数据且默认不自动删除; 用户设置、歌曲目录、键位、gameplay 配置和原始歌曲文件不属于此术语并继续保留.
_Avoid_: User settings, source songs

**Chart Prewarm**:
难度选中并稳定停留约 300 ms 后, 对当前 Chart 执行的后台缓存校验、导出和资源准备. 同一时间只预热一个 Chart; Play 必须复用正在执行或已完成的预热任务.
_Avoid_: Prewarm all difficulties, duplicate gameplay load

**Load Generation**:
一次 Catalog Refresh、Chart Prewarm 或 gameplay 加载任务的身份. 返回、切换选择或取消会使旧 generation 失效; 过期结果不得更新当前 UI、发布不完整缓存或启动 gameplay.
_Avoid_: Detached load, stale callback

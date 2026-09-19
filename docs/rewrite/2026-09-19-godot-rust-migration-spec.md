# Godot + Rust Java-free 迁移规格

状态: 测试边界与 27 个实施切片已确认, 用户已选择本地文件 tracker 并授权实施. 本文综合已有产品合同、accepted ADR、代码审查与用户 Q1-Q7 答案. 未回答的问题不视为接受推荐值.

## Problem Statement

当前 Godot 产品仍依赖 Java 完成曲库扫描、所选 Chart 导出和部分音频准备. 玩家无法使用一个完整、自包含的 Java-free application, 开发和验证链路也依赖 JDK、Maven 与 JAR. 仅替换界面无法完成技术栈迁移.

Rust 已有 workspace、CLI version 入口和协议测试草稿, 但生产 catalog、bundle、parser 与音频合成链路尚未完成. 现有 Godot 的同步扫描、任务取消、缓存验证和音频资源生命周期也需要配套迁移. 因而当前状态是迁移早期, 不能把现有 Godot gameplay 或协议测试的存在视作完整迁移已可交付.

迁移同时存在三类核心风险: 源格式语义在新领域模型中丢失, VOS 离线合成无法满足加载预算, 以及 native helper 在实际 macOS application 中无法正确定位、执行或恢复. 这些风险需要在大规模 parser 开发和删除 Java 之前得到证据支持.

## Solution

交付面向本机自用、采用 ad-hoc 签名的 macOS arm64 Godot application. Godot 负责玩家交互、加载协调和 gameplay, Rust Native Converter 负责原始格式解析、timing 编译、音频准备与 bundle v2 生成. 最终运行、构建、测试与打包均不需要 Java.

本机自用仅限定分发范围, 不缩小技术迁移范围. 保留产品合同内的全部 Java 逻辑必须由 Godot + Rust 接替; 已明确退役的格式和旧应用直接移除, 不要求逐项重写. 最终不保留 Java helper、可选 Java fallback 或 Java-only 测试工具. Java 只在迁移期间作为冻结 oracle 的参照, 不属于最终交付.

保留 VOS、O2Jam OJN/OJM、osu!mania 7K 的 `.osu`/`.osz` 和 bundle v2 支持. 玩家可以管理多个 Library Root, 通过独立 Difficulty Selection 选择 Chart, 使用快速搜索和筛选, 查看真实进度, 取消加载, 并复用经过验证的缓存.

在完整 parser 开发之前执行 VOS 离线合成与最小 macOS app 两个可行性原型. 原型用于尽早发现性能和打包障碍, 不替代完整产品范围或最终验收. 迁移期间以冻结 Java goldens 为语义参照, 完成累计门禁后再删除 Java.

## User Stories

1. 作为本机玩家, 我希望直接运行 macOS arm64 application, 以便不安装 Java 也能游玩.
2. 作为玩家, 我希望导入 VOS 歌曲, 以便继续使用现有 VOS 曲库.
3. 作为玩家, 我希望导入 OJN 及其关联 OJM 音频, 以便保留 O2Jam 歌曲与多个难度.
4. 作为玩家, 我希望导入 osu!mania 7K 的 `.osu` 和 `.osz`, 以便使用受支持的本地谱面.
5. 作为玩家, 我希望发现并打开 bundle v2, 以便使用已准备好的可搬移歌曲产物.
6. 作为玩家, 我希望添加多个 Library Root, 以便独立管理不同来源的曲库.
7. 作为玩家, 我希望来源不同但名称相同的 Song 保持独立, 以便不会错误合并歌曲.
8. 作为玩家, 我希望显式重新定位搬移后的 Library Root, 以便保留仍可对应的歌曲身份与选择状态.
9. 作为玩家, 我希望新增目录被视为新来源, 以便系统不会仅凭内容相同擅自替换已有曲库.
10. 作为玩家, 我希望选歌列表以 Song 分组并保持固定行高, 以便快速浏览大型曲库.
11. 作为玩家, 我希望在独立 Difficulty Selection 中选择 Chart, 以便同一歌曲的多个难度不会挤占歌曲列表.
12. 作为玩家, 我希望按 basename 或 title 进行大小写无关的子串搜索, 以便搜索行为可预测.
13. 作为玩家, 我希望多选格式筛选并与搜索结果取交集, 以便快速定位所需歌曲.
14. 作为玩家, 我希望热启动时先获得可操作的缓存列表, 以便无需等待全曲库扫描.
15. 作为玩家, 我希望 Catalog Refresh 在后台增量更新列表并尽量保留选择和滚动位置, 以便刷新不打断操作.
16. 作为玩家, 我希望一个损坏文件不会使整个曲库无法使用, 以便继续选择其他可用歌曲.
17. 作为玩家, 我希望搜索和筛选直接使用内存索引, 以便每次输入不会触发磁盘扫描或 converter.
18. 作为玩家, 我希望稳定选择 Chart 后开始预热, 以便减少随后 Play 的等待.
19. 作为玩家, 我希望 Play 复用当前预热任务或结果, 以便不会重复导出与加载.
20. 作为玩家, 我希望加载界面及时出现并展示真实阶段和完成数量, 以便理解等待原因.
21. 作为玩家, 我希望进度达到 100 时确实可以开始游玩, 以便不会遇到虚假的完成状态.
22. 作为玩家, 我希望切换 Chart、返回或取消后旧任务失效, 以便旧结果不会启动错误的 gameplay.
23. 作为玩家, 我希望完整有效的缓存能够复用, 以便再次游玩更快.
24. 作为玩家, 我希望源文件变化或缓存损坏时安全重建产物, 以便不会播放过期或不完整内容.
25. 作为玩家, 我希望调整 Gameplay Cache Budget, 以便控制派生数据的磁盘占用.
26. 作为玩家, 我希望正在选择、预热或游玩的产物不会被 LRU 淘汰, 以便加载与 gameplay 稳定.
27. 作为玩家, 我希望大型但仍在安全上限内的 Chart 能继续加载并显示真实进度, 以便性能验收规模不会成为隐式格式限制.
28. 作为玩家, 我希望音符、长音、音量、声像和视觉时序保持正确, 以便迁移不会改变谱面含义.
29. 作为玩家, 我希望 VOS 音频在固定 SoundFont 下具有稳定行为, 以便重复加载不会因系统音源变化而改变结果.
30. 作为玩家, 我希望再次打开 application 时唤起同一用户配置的原实例, 以便不会出现多个实例争抢缓存.
31. 作为玩家, 我希望应用异常退出后的未完成任务不会污染后续加载, 以便重启后能够恢复正常使用.
32. 作为现有用户, 我希望保留歌曲目录、键位和 gameplay 设置, 以便迁移不要求重新配置.
33. 作为现有用户, 我希望原始歌曲与旧派生缓存不会被自动删除, 以便迁移保持数据可恢复.
34. 作为维护者, 我希望使用冻结 oracle 解释每项语义差异, 以便新实现不会以更新 expected 掩盖回归.
35. 作为维护者, 我希望先验证 VOS 合成与 app 打包, 以便在投入完整实现前发现关键障碍.
36. 作为维护者, 我希望完成迁移后构建、测试和打包均无需 Java, 以便技术栈真正收敛到 Godot + Rust.
37. 作为维护者, 我希望所有完成声明都有功能、性能或包验收证据, 以便协议草稿和原型不会被误算为交付完成.

## Implementation Decisions

### 架构与职责

- 沿用 accepted ADR 的 CLI-first 架构. Rust core 负责 parser、timing、audio preparation 与 relocatable bundle; native CLI 作为 adapter. Godot 负责 UI、Catalog Refresh 协调、缓存策略、进度展示、资源加载和 gameplay.
- 不把二进制 parser 或 MIDI 合成移入 GDScript. 只有测量证明 CLI 与文件交换开销阻碍已接受预算时, 才考虑薄 GDExtension adapter.
- CLI 提供 version、catalog 和 bundle 边界, 使用版本化的结构化 request/result/progress, 有序事件和可取消任务. 当前 version 入口不代表 catalog/bundle 已实现.
- 使用既有固定工具链和 lockfile 约束, 通过项目 runtime 配置运行 Rust 与迁移期间的 Java 工具. 不通过更换宿主 shell 环境绕过项目版本约束.

### 身份、目录与选择

- Library Root 身份与其当前目录分离. 显式 Library Relocation 保留 root 身份及其中仍可对应的 Song/Chart 身份和选择状态; 新增目录不按内容推断搬移.
- Song ID 必须隔离不同曲库来源与歌曲包, 不以 title 或当前绝对路径作为身份. 原始歌曲 hash 输入已按 `2026-09-19-native-identity-contract.md` 修订为 root token、格式和相对路径; namespace 持久化与外部 bundle catalog 组合由 ticket 16 完成.
- 保持 Song 分组与独立 Difficulty Selection. O2Jam 同一来源文件中的多个 chartIndex 属于同一 Song 的不同 Chart.
- Song Search 仅匹配 basename/title, 不匹配完整路径、artist 或难度. Format Filter 默认全部选中且至少保留一种格式.
- Catalog 缓存可用时先显示可操作列表, 后台扫描和增量更新; 没有可用缓存时显示阻塞式真实加载进度. 搜索与筛选不启动 converter 或扫描.
- 首发拒绝相同物理目录或相互包含的 root, 每个 root 内递归扫描. root 暂不可读时保留旧记录并标不可用; 只有完整成功扫描才确认歌曲删除.

### 领域语义与 bundle v2

- 完整覆盖 VOS、OJN/OJM、osu!mania 7K 以及 bundle v2 discovery, 不以实现其中一种格式代表迁移完成.
- 保留源格式可表达的 volume/pan 精度, 特别是 OJN 的离散比例; 不默默舍入到整数百分比. 最终数值类型在协议冻结时确定.
- 领域模型必须承载 judgment/visual timing、scroll、measure 和长音头尾事件顺序, 以实际 gameplay consumer 所需语义为边界.
- Godot 需要真实的 v2 adapter, 明确时间单位、格式枚举、稳定 sample 标识到运行时标识的映射与相对资源解析. 不能只以 Rust 自身序列化往返证明兼容.
- bundle v2 自包含且可搬移, 使用内部相对资源路径, 不要求 bundle 外部 CAS 才能使用. 全局 MIDI 派生缓存属于生成优化, 不成为 bundle 的外部运行依赖.
- Rust 验证其生成的 staging 产物; Godot 按 accepted 合同再次验证 manifest/schema、大小、hash 和必要资源, 并在当前 generation 仍有效时完成发布. 不在尚无性能证据时删除第二次验证.

### VOS 音频

- 使用已接受的 GeneralUser GS 2.0.3 及既有来源、hash、许可和 owner acceptance. 不重复发起音源授权选择.
- 保留 MIDI tempo、event order、bank/program、note、velocity、pan、duration、minimum gate 与 tail 语义. 输出为 44.1 kHz、stereo、signed 16-bit PCM.
- VOS Audio Parity 要求固定 SoundFont 下的确定性行为等价, 不要求与依赖系统 DLS 的旧 Java 输出 bit-exact; 既有 canonical timbre 变化是明确接受的差异.
- synth engine 尚未选定. 以重复与逆序执行确定性、音频行为和 release 原型性能为选择证据. 失败时修订音频决策, 不恢复 Java fallback.

### 任务、缓存与资源生命周期

- 每个用户配置单实例, 再次启动唤起原实例. 单实例不免除 helper 残留、应用崩溃和 staging 恢复责任.
- Load Generation 隔离当前任务与过期任务. 切换、返回或取消后, 旧结果不能更新当前 UI、发布不完整缓存或启动 gameplay.
- converter 调用必须非阻塞且具有进程所有权和取消能力. session、job、orphan helper 的具体回收协议需要在执行计划中补全, 不能以一个 UI cancelled 标记替代进程与资源回收.
- Chart 选择稳定约 300 ms 后执行单 Chart Prewarm; 同时只有一个预热目标, Play 复用相同任务.
- Gameplay Artifact Cache 依据 Chart 身份、源内容指纹和版本信息验证, 损坏或过期时重建. 完整产物经验证后原子发布, 不暴露部分输出.
- Gameplay Cache Budget 默认 10 GB, Settings 至少允许从 5 GB 起调整. 后台按 LRU 淘汰未被选择、预热或 gameplay 使用的完整产物, Catalog index 不计入该预算.
- 音频加载采用有界资源管理与可复用 player pool, 避免逐事件无限创建播放器. 具体容量依据实际工作负载测量, 不预先编造上限.

### 性能与 Ready 定义

| 边界 | 已接受目标 |
|---|---|
| 热启动到 Song Selection Ready | P95 <= 300 ms |
| 搜索和格式筛选 | P95 <= 100 ms |
| 加载反馈出现 | <= 100 ms |
| warm Chart 到 Gameplay Ready | P95 <= 2 s |
| cold Chart 到 Gameplay Ready | P95 <= 5 s, 面向冻结验收工作集 |

- Gameplay Ready 表示 gameplay 必需资源已准备且可开始游玩. 进入页面或 converter 退出不等于 Ready.
- Cold Gameplay Load 从选择 Chart 起计时, 包含约 300 ms 预热等待; 所选 Chart 派生产物及全局 MIDI 派生缓存均为空. 不隐含操作系统 page cache 也为空.
- 代表性与压力 Performance Acceptance Corpus 在原型测量后冻结. 不通过只选择已达标的简单曲目降低门禁.
- 超过验收规模但仍在安全资源上限内的 Chart 继续支持, 展示真实进度并允许更久加载. 安全上限与性能工作集是不同概念, 数值尚待测量.
- 总进度从 0 到 100 单调递增, 同时展示当前阶段和实际完成数量; 100 只表示对应 Ready 已达成.

### 迁移顺序与交付

1. 保持冻结 Java oracle 与 provenance 可验证, 先区分已有验证环境问题和新实现问题.
2. 在完整 parser 开发前执行 VOS 离线合成原型和最小 macOS app 原型. 前者验证行为、确定性与成本; 后者验证内嵌 helper、资源定位、arm64 和 ad-hoc 签名.
3. 修订并冻结 Rust 领域、身份、CLI 与 bundle v2 合同, 补全 core 与协议实现.
4. 完成 OJN/OJM 和 osu!mania importers, 对冻结语义做差分验证.
5. 完成 VOS parser、确定性合成与跨 Chart MIDI sample cache.
6. 完成 Godot Catalog v2、Song 分组、搜索筛选与后台刷新.
7. 完成 prewarm、任务取消、事务缓存、真实进度和有界音频资源加载.
8. 完成 macOS app、累计性能与无 Java 验收, 最后删除 Java bridge、Java 源码、Maven/JAR 和 Java-only 验证工具.

- 原型是已确认的生产阶段顺序例外, 不等同于 production importer 或最终打包完成. 各生产阶段仍有独立退出门禁.
- 首发仅本机自用, application 与内嵌 native helper 使用 ad-hoc 签名. 保留无 Java 隔离环境与包内依赖完整性验收.
- 新版使用 v2 派生数据 namespace, 不读取、不迁移且默认不删除 v1 cache. 原始歌曲、歌曲目录、键位与 gameplay 设置保留; application 数据目录变化不能导致设置意外丢失.
- 删除 Java 的前提是所有产品格式、功能、性能、音频、包和 Java-absence 门禁通过. 只移除运行时 Java 不满足 Java-Free 定义.

## Testing Decisions

测试边界状态: 用户已确认采用 Godot -> Native Converter CLI -> bundle v2 -> Gameplay Ready 的主验收边界, 复用冻结 Java goldens, 保留必要的 parser/timing 精度测试及 macOS 包验收. 以下为验收设计, 不表示测试已全部执行.

1. 以 Godot 调用 Native Converter CLI、消费 bundle v2 并达到对应 Ready 状态的可观察行为链作为主验收边界. 尽量复用现有 Godot 测试、CLI contract tests 和 golden 差分机制, 不为每个内部类引入新的 mock 接口.
2. 好的测试断言用户可见结果、协议行为和数据完整性, 而不是内部方法调用次数、私有结构或构造函数赋值. 用输入源、CLI 事件、产物和 UI/Ready 状态判断正确性.
3. parser/timing 的精度与错误处理保留必要的低层 golden 测试. 对 OJN/OJM、osu!mania 和 VOS 检查音符、timing、长音、事件顺序、sample 关联、音量和声像. 这些测试补足端到端难以精确定位的语义差异, 不重复整个实现算法.
4. 复用现有 hermetic fixture factories、冻结 Java catalog/gameplay/audio/error oracle 及 provenance 校验. 新实现不得自动更新 expected 来消除失败; accepted deviation 必须解释来源与影响.
5. VOS 音频检查固定音源和配置下的重复执行、逆序执行确定性, PCM 格式、gate/tail 与 MIDI 行为. 与旧系统 DLS 的波形不同不自动判为回归, 也不因此放弃音符和时序语义验证.
6. 身份测试覆盖多 root 同名歌曲隔离、显式 relocation 保留对应身份、新增副本形成新来源. 重叠目录和离线 root 的期望必须在相关产品规则确定后补齐.
7. Godot 真实 consumer 测试覆盖 v2 单位转换、格式映射、sample 引用和资源路径, 验证原始输入通过 converter 产物可以进入 gameplay, 而不只检验 JSON 可以解析.
8. 任务和缓存测试覆盖命中、缺失、源变化、hash 损坏、缺资源、磁盘不足、取消、快速切换、迟到结果、崩溃后恢复. 断言不发布不完整产物、不启动旧 Chart、不误删正在使用的数据.
9. 恶意或畸形输入覆盖截断、越界长度、无效引用、路径穿越与资源放大. 验收目标是可诊断失败且无 crash、hang 或无界分配; 具体安全阈值在测量后冻结.
10. Catalog/UI 复用现有 3,919-Chart 场景检查有界可见行加 overscan、分组、选择保留和纯内存查询, 并分别测量 warm list 与 query SLO.
11. Gameplay 性能使用冻结的跨格式代表性与压力工作集, 记录硬件、release 构建、缓存状态、样本量与 P95 计算口径. 将源读取、合成、两侧验证和资源准备计入整体等待, 不只报告 synth 内核耗时.
12. 真实 VOS demo 可补充原型测量, 但本机外部文件不能成为 hermetic 自动化 gate 的隐含依赖. 现有 4,096-note fixture 仅有 14 个 sample, 不能单独代表高合成成本场景.
13. macOS 包验收是主行为链之外必要的交付边界: 在无 Java 的隔离环境验证 ad-hoc 签名、目标架构、内嵌 helper 执行、资源查找、各格式加载与重复启动唤起. 本机自用不增加公开下载公证要求.
14. 最终 build/test/package gate 不调用 Java, 不依赖 JAR 或可执行 Java oracle. 保留冻结数据与 provenance 即可; 迁移期用 Java 生成 oracle 不等于终态可以继续依赖 Java.

## Out of Scope

- BMS、SM、SNP, 旧 Swing/LWJGL application 和已退役的 Partytime 匹配行为.
- 非 7K 的 osu!mania 支持扩展.
- 首发公开下载分发、Developer ID、公证、stapling, 以及其他桌面平台安装包.
- 同一用户配置下同时运行多个应用实例.
- 根据内容相同自动推断曲库搬移或合并不同来源.
- 自动读取、迁移或删除旧 v1 派生缓存, 以及自动删除原始歌曲.
- 与系统 DLS 输出 bit-exact 的 VOS 波形一致性.
- 对所有可能规模的 Chart 承诺 cold 5 s, 或为达标引入 Java fallback.
- 在没有测量依据时直接采用 GDExtension 或删除既有完整验证步骤.

## Further Notes

- 已确认 Q1-Q5: 前置两个原型; 显式 Library Relocation; 固定性能验收规模且更大曲目允许更久加载; 每配置单实例; 本机自用 ad-hoc 签名.
- Q6 已批准: 拒绝相同物理目录或相互包含的 Library Root, 每个 root 内递归扫描.
- Q7 已批准: root 暂不可读时保留旧记录并标记不可用, 只有完整成功扫描才确认歌曲删除.
- 仍需工程细化: identity namespace/hash 与 bundle declared ID 的组合, session/job/orphan ownership, 协议数值精度与完整时序字段. 这些问题必须在相关实现合同冻结前解决, 不应让 agent 自行假定已批准.
- 仍需原型证据: synth 选择、固定合成配置、跨格式验收工作集、安全资源上限、内存与磁盘成本. 当前规格不填入未经测量的数值, 也不声称 cold 5 s 已证明可达.
- 已有环境问题包括 macOS SDK linker 兼容问题、尚未发现可用 Godot installation, 以及 golden verifier 的 JVM temp-root 检查失败. 这些是前序审查记录, 本次仅整理规格, 未重新验证环境或执行实现测试.
- 代码审查基线为 `d4cedf802e22a4eefd08426ddba17f3cd17c2856`. 当前 Rust 协议测试引用的若干模块尚未实现; 应将其视为未完成工作, 不将 RED 测试视作功能完成.
- 用户已选择本地文件 tracker, 27 个 tickets 已发布并使用 `ready-for-agent` triage 标签. 不创建远程 issues; 未决项不能因标签而被推定为已解决.
- 用户已批准纵向切片顺序并明确调用 implement. Godot v2 consumer 提前随最小完整链路落地, 各格式接入时验证真实 gameplay; 这一执行顺序替代旧横向阶段约束, 保留完整产品范围与累计门禁. Q6/Q7 的产品决策前置现已满足.

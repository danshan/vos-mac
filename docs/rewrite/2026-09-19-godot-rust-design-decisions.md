# Godot + Rust 迁移决策记录

状态: 用户已批准 27 个纵向 tickets 并通过 implement 授权实施. Q6/Q7 仍未决, 只阻塞依赖其语义的 tickets; 下方访谈树保留为此前决策过程记录.

目标: 通过 grill-with-docs 明确迁移中的产品语义、架构取舍和验收条件, 将决定落实到术语表、必要 ADR 和可执行迁移计划, 再推进 Godot + Rust 的完整 Java-free 交付. 本文件不替代原 roadmap, 不缩小迁移完成定义.

当前代码基线: `d4cedf802e22a4eefd08426ddba17f3cd17c2856`. 2026-09-19 启动访谈时, 工作区已有可行性报告和未跟踪的 `mise.lock`. 最新提交仍为协议测试, 不代表协议实现完成.

## 已有决定

以下依据当前 CONTEXT、accepted ADR 和 roadmap, 作为访谈基线继续使用. 不因开始新一轮讨论而重新请求批准.

| 决定 | 依据 |
|---|---|
| Godot 保留 UI/gameplay, Rust core 负责导入、timing、音频准备, 首期采用 native CLI | ADR 0002 |
| 产品支持 VOS、OJN/OJM、osu!mania 7K 和 bundle v2 | Godot Product Contract |
| BMS/SM/SNP 与旧 Swing/LWJGL 退役 | Godot Product Contract |
| 完成包含运行、开发构建、测试与发布均不依赖 Java | Java-Free |
| 首发目标 macOS arm64; 其他桌面安装包不阻塞 | Migration Release Platform |
| 固定 GeneralUser GS 2.0.3, 保留既有 owner acceptance | SoundFont contract 与 ADR 0003 |
| 不迁移、不自动删除 v1 派生缓存, 保留原始歌曲和用户设置 | Legacy Derived Data |
| 保留 300 ms 选歌、100 ms 查询、warm 2 s/cold 5 s 的已批准目标 | roadmap Global Constraints |

## 决策树

每轮只询问前置条件已确定的决策. 代码事实由审查查明, 不让用户代查. 推荐选项不自动视为用户决定.

| ID | 决策 | 前置条件 | 状态 | 决定后的文档落点 |
|---|---|---|---|---|
| D1 | 曲库搬移与新增来源的身份语义 | 既有 Song/Chart 定义, 当前 identity 合同核对 | Q2 已接受显式重新定位 | Library Root/Relocation 术语, ADR 0004 |
| D2 | cold 5 s 的工作负载范围及超出范围时的产品行为 | 既有 SLO, 当前 benchmark 合同核对 | Q3 已接受固定验收规模与更大曲目更久加载 | Cold Load 术语, performance spec |
| D3 | 首发是否支持同时运行多个应用实例 | 当前进程与缓存 ownership 合同核对 | Q4 已接受每配置单实例 | ADR 0005, 生命周期 spec |
| D4 | 首发发布渠道与签名、公证验收 | macOS arm64 既定, 当前 release 合同核对 | Q5 已接受本机自用与 ad-hoc 签名 | release spec 与 ADR 0002 |
| D5 | 是否调整串行 roadmap, 前置 VOS 与最小 app 风险原型 | 可行性报告, 原计划的阶段限制 | Q1 已接受前置两个原型 | roadmap 的显式修订 |
| D6 | identity 算法、重叠 root、relocation 与 bundle declared ID 的组合 | D1 | 已具备讨论前提, 下一轮展开 | identity ADR, vectors, request/catalog contract |
| D7 | synth 原型预算、固定配置、通过/停止条件 | D2, D5 | 已具备讨论前提 | audio ADR 补充与原型计划 |
| D8 | session/job/cancel/orphan 与缓存发布协议 | D3 | 已具备讨论前提 | process/cache spec 与故障矩阵 |
| D9 | 分发包、数据目录保留、干净机器验收 | D4 | 已具备讨论前提 | release plan 与设置迁移测试 |
| D10 | 完整 v2 语义与 Godot adapter 合同 | D6, 既有 gameplay 事实 | 等待前置决定 | Phase 1 Task 3, v2 consumer 验证计划 |
| D11 | 修订后的里程碑、累计门禁与 Java 删除顺序 | D7-D10 | 等待前置决定 | roadmap 与当前 phase plan |
| D12 | 用户确认共同理解, 转入实施 | 所有开放分支已解决, 文档一致 | 未满足 | 访谈结论与实施入口 |
| D13 | 部分曲库离线时的列表与删除语义 | D1, 已有 last-known-good 规则 | 待用户决定, Q7 | Library Availability 术语与 Catalog Refresh 合同 |

## 必须解决的工程约束

以下是可行性审查发现的正确性要求, 不应作为是否接受数据丢失的产品选择题:

- OJN volume/pan 必须保留源格式精度, 不得默默舍入到整数百分比.
- 领域模型必须表达 judgment/visual timing、scroll speed、measure 与长音头尾顺序.
- v2 wire 必须有实际 Godot consumer 验证, 不以 Rust 自身序列化测试替代.
- 现有 Java goldens 不由新实现自动重写; 任何 accepted deviation 单独记录.
- 性能未知必须用原型与 benchmark 确认, 不以语言切换推定达标.
- baseline gate 失败与新代码失败分开记录, 不删除断言制造绿色状态.

具体类型、数值精度、算法和 adapter 形态, 在相关产品语义确定后落入计划. 已接受的内容才写入 accepted ADR; 未决项保留在此记录, 不混入 CONTEXT 术语表.

## 当前轮次

第一轮 Q1-Q5 已全部回答并落实到文档. 用户在 Q5 选择本机自用, 未采用普通下载分发的推荐选项.

| 问题 | 对应决策 | 推荐/决定 |
|---|---|---|
| Q1 | D5 | 已接受: 前置 VOS 合成与最小 app 原型, 保持最终产品范围和门禁 |
| Q2 | D1 | 已接受: 显式重新定位曲库以保留身份; 新增目录不自动推断搬移 |
| Q3 | D2 | 已接受: 从 Chart 选择开始测 true cold, 在冻结工作集执行 5 s 门禁; 超出验收规模但未超安全上限的曲目允许更久加载 |
| Q4 | D3 | 已接受: 每个用户配置单实例, 再次启动唤起原实例 |
| Q5 | D4 | 已接受: 本机自用, ad-hoc 签名; 不要求 Developer ID、公证或公开下载验收 |

第一轮提问前的只读事实核对:

- Phase 1 identity 构造函数仅包含相对 package/file path 等信息, 尚无 root namespace; relocation invariant 已明确. 依据: `docs/superpowers/plans/2026-07-12-java-free-phase1-rust-core.md:729` 和 `:763`.
- Gameplay Ready 终点已明确, 但 cold 起点、全局 sample cache 状态、单 Chart 规模上限尚未明确. 依据: `docs/superpowers/specs/2026-07-11-java-free-song-loading-design.md:273` 和 `:282`.
- staging orphan 的文件恢复合同已有设计, 不等于 Godot 崩溃后的存活 helper 已有完整 ownership 方案. 单实例/多实例未定. 依据: `docs/superpowers/plans/2026-07-12-java-free-phase1-rust-core.md:2021` 和 `:2031`.
- 签名 app 和 clean-machine gate 已明确; 分发渠道、Developer ID、公证与 stapling 尚未成为 accepted 合同. 依据: `docs/adr/0002-use-rust-native-converter-cli.md:17` 和迁移 spec 的 Java deletion gate.

## 本轮已落实的文档

- Q1: roadmap 新增 Early Feasibility Prototypes, 同步修订 Phase 1 末尾的 VOS/MIDI 顺序约束. 未把未决的性能工作集或分发要求写成既定门禁.
- Q2: CONTEXT 新增 Library Root 与 Library Relocation, 修正 Song ID 对 Java exporter 的实现依赖描述; ADR 0004 记录显式重新定位与自动内容推断之间的取舍.
- Q3: CONTEXT 定义 Cold Gameplay Load 与 Performance Acceptance Corpus; spec 与 roadmap 记录已接受计时、缓存和规模边界, 具体工作集与资源上限仍待测量冻结.
- Q4: ADR 0005、spec 与 roadmap 记录每配置单实例.
- Q5: CONTEXT、ADR 0002、spec 与 roadmap 明确本机自用和 ad-hoc 签名; 未将公开分发建议写入最终门禁.

## 第二轮

| 问题 | 对应决策 | 推荐, 尚未接受 |
|---|---|---|
| Q6 | D6 | 首发拒绝相同或互相包含的 Library Root, 保留各 root 内递归扫描 |
| Q7 | D13 | 暂不可读 root 保留旧歌曲并标不可用; 完整成功扫描才确认文件删除 |

进一步事实核对已完成:

- 真实 demo `Age of empire.vos` 在仓库明确引用的本机目录中存在. 其 sample 数、累计合成时长和 PCM bytes 尚未冻结, 后续由原型提取, 不要求用户手工统计.
- Hermetic VOS minimal 为 1 note/1 sample, representative 为 2 notes/2 samples, stress 为 4,096 notes/14 samples. 音符数量不能直接代表独立 sample 合成成本. 历史 31.09 s 表格未绑定具体 fixture, 不将其当成某首真实 demo 的测量.
- Rust staging 验证与 Godot 消费端再次完整验证是现有 accepted 合同. 保留该合同直到 benchmark 提供调整依据, 不在未测量前重问已接受 ownership.
- Relocatable bundle 保持内部相对资源路径, 不依赖 bundle 外部 CAS. copy/hardlink 等存储优化留给有证据的实现取舍.
- 首发分发渠道已定为本机自用, 无需继续询问 Apple Developer 账号或公证证书. 原有无 Java 的隔离环境 gate 仍保留.

事实核对与用户答案将在本文件继续更新. 完整验收仍以原 Java-free 产品合同及经用户确认的明确修订为准.

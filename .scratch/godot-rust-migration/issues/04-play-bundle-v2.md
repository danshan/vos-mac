# 04: 打通 bundle v2 到 Gameplay Ready

**What to build:** 受控 Chart 通过 native CLI 生成 bundle v2, 由 Godot 验证、加载并实际游玩, 建立后续格式接入的完整路径.

**Blocked by:** 02: 验证 VOS 离线合成可行性; 03: 验证最小 macOS application.

**Status:** in-progress

- [ ] 落实必要的 core、版本化 CLI request/result/progress 与错误合同, 现有相关协议测试从缺实现状态转为可验证行为.
- [ ] 受控谱面经真实 Rust 生成与 Godot consumer 到达 Gameplay Ready, 而非只做 JSON round-trip 或在 Godot 内伪造成功.
- [ ] 冻结并验证 us 等时间单位转换、格式映射、sample 引用、相对资源路径、volume/pan 精度及长音头尾顺序.
- [ ] 模型表达 judgment/visual timing、scroll 与 measure, 测试使用能暴露丢失语义的输入.
- [ ] Rust 验证产物, Godot 再次完整验证 manifest/schema、文件大小与 hash; 无效产物不能进入 gameplay.
- [ ] 只增加可并存的迁移路径, 保留迁移期 oracle; 这一步不删除 Java 或宣布所有格式完成.


## 实施进度: 严格协议基础

2026-09-19: 已补齐 digest、强类型 ID 包装、JobId、路径、错误、schema 和 request/result JSON 合同. 现有 14 项非身份派生测试通过; 另补源文件名中合法冒号和空曲库请求 2 项回归. CLI 的 8 项合成测试与版本握手测试继续通过. 限定 core library/protocol test 的 clippy 无 warning.

旧 `protocol_contract.rs` 中 2 项身份派生测试完整移到 `identity_contract.rs`, 不加 ignore、不改 golden、不从 workspace 排除. 完整 workspace test 仍因未实现的 SongIdentity、ChartIdentity 与派生函数失败. 旧身份合同与新 Library Root 决策的一致性尚需修订, 不能把当前 ID 包装或 catalog roots DTO 当成已冻结的最终曲库身份协议.

此阶段尚未完成 CLI bundle 服务、progress、bundle v2 验证或 Godot 接入, 上方验收复选框保持未完成. 日志: `/tmp/vos-ticket04-protocol-red.log`, `/tmp/vos-ticket04-path-red.log`, `/tmp/vos-ticket04-empty-red.log`, `/tmp/vos-ticket04-cli.log`, `/tmp/vos-ticket04-workspace.log`.

阶段提交: `d35b042`. 独立两轴静态审查均无新增发现: Standards 0, Spec 0. 审查未替代或豁免仍失败的 workspace 总门禁.

## 实施进度: 进度文件与真实 CLI 错误传输

2026-09-19: 新增 ProgressEventV1、owner/phase 校验、连续序号 tracker 和 create-new JSONL writer. 逐条 flush, 已有文件或 symlink 不覆盖. tracker 写入失败后拒绝继续写该流, 不尝试拼接或修复可能截断的记录.

真实 `catalog`/`bundle` CLI 入口现支持固定的 request/progress/result 参数顺序, 1 MiB 请求上限、结构化协议失败、取消路径与传输路径隔离, 以及 no-clobber 原子结果发布. 发布使用同目录私有文件、sync、hard-link、目录 sync、清理和再次目录 sync. 对发布前/后失败分别保持路径 ownership, 不覆盖竞态创建的结果.

本阶段仍没有启用 importer: 有效请求返回 `UNSUPPORTED_FORMAT`, version 能力数组为空, 不伪造成功或 Gameplay Ready. 进度模块尚待实际 bundle 服务驱动; 本阶段未声称完成旧横向 Task 4/6 的全部 job-state、cancellation 和 service composition 要求.

验证: 7 项进度合同、16 项原协议合同、8 项真实 CLI、4 项文件发布、1 项版本握手和 8 项合成回归. 原身份测试仍保留并阻止 workspace 累计门禁通过. 日志: `/tmp/vos-ticket04-progress-green.log`, `/tmp/vos-ticket04-transport-cli-green.log`, `/tmp/vos-ticket04-transport-workspace.log`. 失败后仍需新 transport 路径重试.

阶段实现提交: `a41a8b3`. Spec 审查发现 1 项 P2: 进度 schema 不兼容经 serde 丢失 `UNSUPPORTED_SCHEMA` 稳定码. 已由 `62abbaa` 修复, 精确错误码回归先 RED 后 GREEN. 最终两轴复审均无未解决发现: Standards 0, Spec 0. 44 项限定回归与 release build 通过; fmt 和相关 clippy 通过. 未豁免旧 identity 缺实现导致的 workspace 总门禁失败.

## 实施进度: 原始歌曲身份与累计门禁

原始 Song identity 改为 root namespace、格式和相对路径, 移除标题与绝对路径输入. Song/Chart algorithm v2 与独立 Python preimage/hash vectors 已实现; source/sample domain v1 有明确 framing. 合同修订见 `docs/rewrite/2026-09-19-native-identity-contract.md`. 旧 native 草稿的标题敏感断言和无 root 构造被新已批准语义取代, 冻结 Java goldens 未改变.

完整 native workspace 现有 49 项测试通过, workspace all-target clippy 通过. 日志: `/tmp/vos-ticket04-identity-workspace.log`. 先前 identity 缺实现导致的累计门禁失败已解除, 不代表 ticket 04 的 bundle/gameplay 验收完成. bundle declared wire ID 保留, catalog 来源组合与 root 持久化仍归 ticket 16.

身份阶段提交 `8463df2`, Spec 发现 root-level osu set 表达缺口, 已由 `a3f0750` 修复并通过新回归与复审. 最终 Standards 0、Spec 0 未解决发现. 当前完整 workspace 49 项通过, 没有因身份草稿跳过测试. 下一步接入实际 bundle v2 生成、严格验证和 Godot runtime 消费.

## 实施进度: Bundle 文件完整性

补齐严格 BundleManifestV2、完整内容 key v1 和 bounded verifier. 校验文件集合、size/hash、schema/key/identity、目录组件大小写冲突、symlink 与非普通文件; 支持整个目录搬移. 独立 Python framing vectors 覆盖四种 selector. Manifest 限制 1 MiB、65,536 文件和每路径 64 组件, 防止路径前缀索引放大. 详细边界见 `docs/rewrite/2026-09-19-bundle-integrity-contract.md`.

该层仅完成文件完整性审计, 不证明 gameplay/audio schema 或 Gameplay Ready. 仍无 production importer 能力声明, 不关闭上方完整链路验收项. 验证日志: `/tmp/vos-ticket04-bundle-workspace.log`, `/tmp/vos-ticket04-bundle-doc.log`.

阶段提交 `1f26909`, 验证质量修正 `dd6f575`. 累计 native workspace 57 项与 1 项 compile-fail doctest 的日志均无失败, fmt/clippy 无新增问题. Standards 发现的无效 compile-fail 示例已修复: 临时公开字段的 mutation probe 使测试失败, 恢复私有后通过. 文件数量测试同时独立验证 65,537 个唯一有序路径, 不依赖重复项或文件字节上限提前拒绝.

最终两轴复审: Standards 0、Spec 0 未解决发现. 仅关闭此文件完整性阶段的审查, ticket 04 与整体 Java-free 迁移继续进行.

## 实施进度: Gameplay 精度与 Note

新增 TimeMicros、约分 Ratio、7-lane Note 与独立 HoldTail. 保留亚毫秒时间、OJN 15/16 音量与 -7/8 声像、头尾 measure/eventOrder; serde 不能绕过 lane、比例和长音先后校验. 数值合同见 `docs/rewrite/2026-09-19-gameplay-v2-values.md`. 完整 Chart、timing、audio 引用与 Godot adapter 尚未实现, 不关闭 ticket.

阶段实现 `253d195`. 累计 61 项 native 回归的日志无失败: `/tmp/vos-ticket04-gameplay-values.log`; workspace clippy 与 fmt 无新增问题. 独立两轴审查 Standards 0、Spec 0. 旧横向计划 Task 3 增加显式替代说明, 防止后续 importer 沿用有损的整数百分比模型.

## 实施进度: Chart 核心事件与引用

新增 GameplayChartV2、TimingPoint、ScrollPoint、AutoplayEvent. judgment/visual timing 分离, scroll ratio 与 measure 索引独立保留. 同一构造/serde 边界拒绝缺失引用、乱序/重复事件、头尾 order 冲突和 duration 越界. sampleless Note 在所有源格式保留音量与声像. Schema、未知/重复字段以及停止速度的回归也已加入.

尚未完成 audio/bundle 跨文件校验、BGA 资源模型、实际 producer 与 Godot consumer, ticket 保持 in-progress. 数值合同补充该阶段的精确边界, 不以序列化 round-trip 代表 Gameplay Ready.

阶段提交 `743510c`. 累计 67 项 native 回归日志无失败: `/tmp/vos-ticket04-gameplay-chart.log`; workspace clippy 无 warning. 独立两轴审查 Standards 0、Spec 0. 下一阶段需要把 audio manifest、Chart 与 bundle identity/hash 做跨文件连接, 再交给真实 Godot consumer.

## 实施进度: Audio manifest 与跨文件校验

新增 AudioManifestV2 与 load_bundle_documents. 在完整目录 size/hash 验证之上校验 Chart/audio/bundle 的 songId、chartId、format、sample 集合及实际资源路径; prepared SampleId 与资源内容 digest 对照. JSON 读取有 64 MiB 上限, 同一批读取字节再次校验 hash 后才反序列化. 测试会同时更新文件清单 hash, 确认文件完整性成功仍不能掩盖跨文件语义冲突.

本层不解码 WAV, 不等于 Gameplay Ready; production importer、真实受控 producer 和 Godot consumer 仍待完成. 原始压缩音频输入继续由后续 audio preparation 转成 WAV, 不缩减产品范围.

阶段提交 `59307a3`. 累计 71 项 native 回归日志无失败: `/tmp/vos-ticket04-bundle-documents.log`; workspace clippy 无 warning. 独立审查 Standards 0、Spec 0. 下一步生成真实可解码的受控 WAV/bundle, 接入 native CLI 和 Godot runtime; 不把本阶段的文档一致性验证当作音频或游玩证据.

## 实施进度: 真实受控 bundle 与 Godot WAV 解码

新增开发 controlled-bundle-probe, 使用共享 core 生成严格 Chart/audio/bundle 和真实 44.1 kHz stereo PCM16 WAV. fixture 含 tap/hold、同刻长音释放后新音头、亚毫秒时间、离散比例及不同 timing 轨道. 重复输出路径拒绝覆盖, 搬移后 bundle 仍有效.

独立 Python wave 解码与 Godot 4.6.3 AudioStreamWAV 加载已提供真实音频资源证据, 详见 `docs/rewrite/2026-09-19-controlled-bundle-probe.md`. 尚未接通正式 CLI bundle 服务与完整 Godot v2 adapter, 不将音频解码 smoke 当成 Gameplay Ready.

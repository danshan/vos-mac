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

验证: 6 项进度合同、16 项原协议合同、8 项真实 CLI、4 项文件发布、1 项版本握手和 8 项合成回归. 原身份测试仍保留并阻止 workspace 累计门禁通过. 日志: `/tmp/vos-ticket04-progress-green.log`, `/tmp/vos-ticket04-transport-cli-green.log`, `/tmp/vos-ticket04-transport-workspace.log`. 失败后仍需新 transport 路径重试.

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

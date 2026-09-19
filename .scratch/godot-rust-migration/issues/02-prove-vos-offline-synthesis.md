# 02: 验证 VOS 离线合成可行性

**What to build:** 从受控 MIDI 输入离线合成可播放 PCM, 在完整 parser 开发前证明候选 synth 的行为、确定性和成本.

**Blocked by:** 01: 恢复可信的迁移验证基线.

**Status:** ready-for-agent

- [ ] 使用已接受的 GeneralUser GS 2.0.3 及其固定 hash, 保留既有许可与 owner acceptance; 不使用系统 DLS 或 Java fallback.
- [ ] 固定配置下输出 44.1 kHz stereo signed 16-bit PCM; 验证 tempo、事件顺序、bank/program、velocity、pan、duration、minimum gate 和 tail.
- [ ] 重复及逆序执行产生确定性结果; 记录 release 构建、硬件、独立 sample 数、总合成时长、wall time、峰值内存和 PCM bytes.
- [ ] 同时覆盖代表性输入与高合成成本输入, 不将大量重复音符误当成大量独立 sample; 本机外部 demo 不成为自动 gate 的隐含依赖.
- [ ] 明确 synth/config 选择和 go/no-go 证据. 仅完成测量报告不等于通过; 失败阻塞后续生产实现并要求修订音频决策.
- [ ] 原型只证明受控输入的可行性, 不声称完整 VOS parser 或端到端 cold 5 s 已经达标.


# 02: 验证 VOS 离线合成可行性

**What to build:** 从受控 MIDI 输入离线合成可播放 PCM, 在完整 parser 开发前证明候选 synth 的行为、确定性和成本.

**Blocked by:** 01: 恢复可信的迁移验证基线.

**Status:** done

- [x] 使用已接受的 GeneralUser GS 2.0.3 及其固定 hash, 保留既有许可与 owner acceptance; 不使用系统 DLS 或 Java fallback.
- [x] 固定配置下输出 44.1 kHz stereo signed 16-bit PCM; 验证 tempo、事件顺序、bank/program、velocity、pan、duration、minimum gate 和 tail.
- [x] 重复及逆序执行产生确定性结果; 记录 release 构建、硬件、独立 sample 数、总合成时长、wall time、峰值内存和 PCM bytes.
- [x] 同时覆盖代表性输入与高合成成本输入, 不将大量重复音符误当成大量独立 sample; 本机外部 demo 不成为自动 gate 的隐含依赖.
- [x] 明确 synth/config 选择和 go/no-go 证据. 仅完成测量报告不等于通过; 失败阻塞后续生产实现并要求修订音频决策.
- [x] 原型只证明受控输入的可行性, 不声称完整 VOS parser 或端到端 cold 5 s 已经达标.

结果: RustySynth 1.3.6 作为后续集成候选, 8 项真实 probe CLI tests 与既有 version test 通过, clippy/fmt 通过. 64/1,024 合成工作集及 192-sample 真实 VOS 的重复/逆序 PCM 均一致且无削波. 真实 VOS 进程时间观察到 1.33–2.17 s; 压力组观察到 2.04–7.38 s, 保留波动与曾超预算的证据. Go 仅针对受控原型继续集成, 不解除 ticket 24/25 的完整工作集和端到端性能门禁.

Code review: Standards 0 项; Spec 首轮发现 P2 累计时间截断, 补 RED/GREEN 回归并保留分数余量后复审无剩余发现. 生产 parser、SMF 解码和复杂 MIDI 行为仍按后续 tickets 验收.

# 04: 打通 bundle v2 到 Gameplay Ready

**What to build:** 受控 Chart 通过 native CLI 生成 bundle v2, 由 Godot 验证、加载并实际游玩, 建立后续格式接入的完整路径.

**Blocked by:** 02: 验证 VOS 离线合成可行性; 03: 验证最小 macOS application.

**Status:** ready-for-agent

- [ ] 落实必要的 core、版本化 CLI request/result/progress 与错误合同, 现有相关协议测试从缺实现状态转为可验证行为.
- [ ] 受控谱面经真实 Rust 生成与 Godot consumer 到达 Gameplay Ready, 而非只做 JSON round-trip 或在 Godot 内伪造成功.
- [ ] 冻结并验证 us 等时间单位转换、格式映射、sample 引用、相对资源路径、volume/pan 精度及长音头尾顺序.
- [ ] 模型表达 judgment/visual timing、scroll 与 measure, 测试使用能暴露丢失语义的输入.
- [ ] Rust 验证产物, Godot 再次完整验证 manifest/schema、文件大小与 hash; 无效产物不能进入 gameplay.
- [ ] 只增加可并存的迁移路径, 保留迁移期 oracle; 这一步不删除 Java 或宣布所有格式完成.


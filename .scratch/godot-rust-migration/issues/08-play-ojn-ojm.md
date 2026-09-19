# 08: 游玩基础 OJN/OJM 歌曲

**What to build:** 玩家扫描基础 OJN/OJM 歌曲, 在同一 Song 下选择不同难度并完整游玩.

**Blocked by:** 04: 打通 bundle v2 到 Gameplay Ready.

**Status:** in-progress

- [ ] 原始 OJN 经 Rust catalog、bundle 与 Godot 显示和加载, 不调用 Java exporter.
- [ ] 同一 OJN 的多个 chartIndex 归于同一 Song, 各 Chart 的音符和音频关联正确.
- [ ] 基础 OJM 样本可解码并播放, timing、长音、事件顺序和源 volume/pan 精度与冻结 oracle 对照.
- [ ] 截断数据、无效长度和缺失音频有可诊断结果, 不崩溃、挂起或无界分配.
- [ ] 仅声明本 ticket 覆盖的基础 OJM 路径, 不把 OMC/M30 变体算作已完成.

## 当前增量: 有界二进制解析

- `open2jam_core::ojn::OjnSource` 读取三个难度的 metadata 和实际事件. 保留分数拍位置、稳定同拍顺序、hold/release、源 sample index 及精确 volume/pan. 文本保留原始编码字节, 尚未接入字符集解码.
- `open2jam_core::ojm::parse_plain_ojm` 提取借用的 PCM/Ogg payload, 保留空槽及两组样本编号. 不复制整个音频 payload, 不将提取等同于音频解码. OMC/M30 明确返回 UnsupportedFormat.
- 当前实现安全上限为 OJN 64 MiB / 1,000,000 个非空事件, OJM 512 MiB / WAV 索引 0..999 / Ogg 索引 1000..65535. 这些是当前解析器的拒绝边界, 不是最终性能验收规模; ticket 24 仍需用真实工作集复核. 文件 adapter 还须在读取前实施相同输入上限.
- 冻结 representative OJN 只有 header 声明的 note count, 没有实际事件. 新增 public parser seam 测试用显式事件覆盖分数位置、长音、同拍事件及 volume/pan, 原 goldens 未改动. 这些测试不等同于 timing 编译后的 Java parity.
- 验证命令: `mise exec -- cargo test --manifest-path native/Cargo.toml --workspace --all-targets --locked`, `mise exec -- cargo clippy --manifest-path native/Cargo.toml --workspace --all-targets --locked -- -D warnings`.
- 待续: 字符集策略、timing 编译、音频准备、持久化 LibraryRootId 传递以及 raw OJN 的 CLI/catalog/bundle/Godot 闭环. 本 ticket 的最终验收项暂不勾选.

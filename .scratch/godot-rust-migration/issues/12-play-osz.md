# 12: 安全导入并游玩 OSZ 歌曲包

**What to build:** 玩家直接导入 OSZ 中受支持的 7K 谱面, 无需手工解压并修复资源路径.

**Blocked by:** 11: 游玩本地 osu!mania 7K 谱面.

**Status:** ready-for-agent

- [ ] 从 OSZ discovery 到 Song/Chart 选择、资源解析和 gameplay 完整可用.
- [ ] 同包多个谱面和相对音频引用保持正确, 不依赖解压临时目录的绝对位置.
- [ ] 拒绝路径穿越和越界资源访问, 解包具有明确资源约束; 最终阈值与验收工作集冻结结果一致.
- [ ] 畸形 archive、缺失音频和取消不留下可误用的完整产物.


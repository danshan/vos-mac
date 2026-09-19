# 16: 管理稳定的 Library Root 与重新定位

**What to build:** 玩家独立管理多个曲库来源, 显式搬移后保留对应歌曲身份和选择, 新增副本仍作为新来源.

**Blocked by:** 07: 发现并游玩外部 bundle v2.

**Status:** ready-for-agent

外部前置: Q6 重复/重叠 Library Root 的产品规则尚未确认; ticket 07 完成不自动解除此条件.

- [ ] 开始依赖产品规则的实现前取得 Q6 的明确决定: 相同物理目录及相互包含的 root 如何处理; 不把推荐的拒绝策略当作已批准.
- [ ] 冻结 root namespace 的持久化、Song/Chart identity 输入及 bundle declared ID 的组合, 身份不依赖当前绝对路径或 title.
- [ ] 不同来源的同名歌曲不合并, 新增内容副本不自动替代已有来源.
- [ ] 显式 Library Relocation 在仍可对应的源条目上保留身份与选择, 重启后仍成立.
- [ ] 通过多 root、搬移、新增副本及已决定的重叠策略验证完整 UI/索引行为.


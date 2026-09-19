# 16: 管理稳定的 Library Root 与重新定位

**What to build:** 玩家独立管理多个曲库来源, 显式搬移后保留对应歌曲身份和选择, 新增副本仍作为新来源.

**Blocked by:** 07: 发现并游玩外部 bundle v2.

**Status:** ready-for-agent

Q6 已确认: 首发拒绝相同物理目录和互相包含的 root, 每个 root 内递归扫描.

- [x] Q6 产品决定已取得: 拒绝重复或重叠 root.
- [ ] 冻结 root namespace 的持久化、Song/Chart identity 输入及 bundle declared ID 的组合, 身份不依赖当前绝对路径或 title.
- [ ] 不同来源的同名歌曲不合并, 新增内容副本不自动替代已有来源.
- [ ] 显式 Library Relocation 在仍可对应的源条目上保留身份与选择, 重启后仍成立.
- [ ] 通过多 root、搬移、新增副本及已决定的重叠策略验证完整 UI/索引行为.


## 前置进展

- ticket 08 接入 raw source 前, 已补齐 CATALOG rootIds 的严格传递和 Godot 结果核对. 显式提供 token 时, 外部 bundle 的 source selection key 由 rootId + relativePath 形成, declared ID 不变. 合同详见 docs/rewrite/2026-09-19-native-identity-contract.md.
- 当前仅完成 transport / source selection key 的前置工作, 不勾选 token 持久化、重新定位 UI、跨重启选择恢复等验收.

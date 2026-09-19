---
status: accepted
---

# Preserve library identity through explicit relocation

2026-09-19 用户确认: 移动整个曲库时, 通过显式 Library Relocation 为原 Library Root 指定新目录并保留身份; 直接新增目录视为新来源, 不按相同内容猜测搬移或自动合并. 该选择兼顾多来源隔离与搬移后的歌曲身份、选择状态保留, 避免内容副本与真实搬移无法区分时错误关联曲库.

## Considered Options

- 显式重新定位: 用户需要一次明确操作, 但来源归属可解释, 不依赖全量内容扫描.
- 自动按内容推断: 减少部分手动操作, 但相同副本、旧磁盘暂不可用和内容修改会产生歧义.

## Consequences

Library Root 身份不能直接等同于当前绝对路径. 具体持久化方式、identity hash 输入、重叠 root 和缺失歌曲的处理在后续合同中定义, 本决定不提前冻结这些实现细节.

# 18: 交付大型曲库的分组、搜索和筛选

**What to build:** 玩家在大型曲库中快速浏览 Song、独立选择 Chart 并搜索或组合格式筛选.

**Blocked by:** 17: 后台刷新曲库并处理部分来源不可用.

**Status:** ready-for-agent

- [ ] Song 列表固定行高且按歌曲分组, 难度在独立 Difficulty Selection 显示.
- [ ] 大小写无关子串搜索仅匹配 basename/title, 不匹配完整路径、artist 或难度.
- [ ] 格式多选默认全选且至少保留一种, 与搜索取交集; 输入和筛选不启动 converter 或磁盘扫描.
- [ ] 3,919-Chart 场景只创建可见行和有界 overscan, 选择行为不依赖完整 UI 节点列表.
- [ ] 在记录的硬件、release 环境和统计口径下验证 warm Song Selection Ready P95 <= 300 ms, 查询/筛选 P95 <= 100 ms.


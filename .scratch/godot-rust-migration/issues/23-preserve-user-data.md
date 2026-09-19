# 23: 保留现有用户设置与原始数据

**What to build:** 现有用户切换到新版后继续使用原来的曲库配置、键位和 gameplay 设置, 原始数据保持可恢复.

**Blocked by:** 16: 管理稳定的 Library Root 与重新定位.

**Status:** ready-for-agent

- [ ] 保留曲库目录、键位和 gameplay 配置, 应用名称或数据目录变化不会造成静默设置丢失.
- [ ] 旧曲库配置映射到稳定 Library Root 身份, 不将该适配误作旧派生缓存迁移.
- [ ] 新版本使用独立 v2 cache namespace, 不读取、迁移或自动删除 v1 catalog/bundle/audio cache.
- [ ] 通过升级前后及再次启动验证设置保留, 原始歌曲 bytes 与旧派生数据保持不变.
- [ ] 设置缺失或异常时给出可恢复处理, 不自动覆盖无法理解的原始配置.


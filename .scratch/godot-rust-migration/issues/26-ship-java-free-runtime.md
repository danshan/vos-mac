# 26: 交付完整的无 Java 运行包

**What to build:** 本机玩家得到包含全部运行依赖的 arm64 app, 全部受支持格式无需 Java 即可使用.

**Blocked by:** 23: 保留现有用户设置与原始数据; 25: 通过完整加载性能和故障验收.

**Status:** ready-for-agent

- [ ] 包内包含 native converter、固定 SoundFont 与所需资源, ad-hoc 签名及目标架构验收通过.
- [ ] 在无 Java 的隔离环境验证全部产品格式、选歌、加载、取消、单实例和设置保留.
- [ ] 移除生产 Java bridge 和 runtime fallback, 不依赖开发目录、JAR 或宿主 Java.
- [ ] 故障和性能累计门禁通过, 包内资源定位在搬移 application 后保持有效.
- [ ] 明确此时剩余 Java 仅可能属于迁移期构建/验证资产, 不提前宣布完整 Java-Free.


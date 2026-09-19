# 03: 验证最小 macOS application

**What to build:** 本机玩家能够打开包含 native helper 的最小 Godot app, 在没有 Java 的环境看到 helper 执行结果.

**Blocked by:** 01: 恢复可信的迁移验证基线.

**Status:** ready-for-agent

- [ ] application 与 helper 均为目标 macOS arm64, 使用 ad-hoc 签名并通过包完整性检查.
- [ ] helper 与测试资源从包内定位, application 搬离构建目录后仍能运行.
- [ ] 在没有 Java 的隔离环境从应用启动 helper 并在 Godot 显示结构化结果; 不依赖开发目录或宿主安装的辅助程序.
- [ ] helper 缺失、资源缺失或执行失败可诊断, 不退回 Java.
- [ ] 保留可复现打包步骤和证据; 不增加 Developer ID、公证或公开下载验收要求.


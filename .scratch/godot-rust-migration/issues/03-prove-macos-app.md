# 03: 验证最小 macOS application

**What to build:** 本机玩家能够打开包含 native helper 的最小 Godot app, 在没有 Java 的环境看到 helper 执行结果.

**Blocked by:** 01: 恢复可信的迁移验证基线.

**Status:** done

- [x] application 与 helper 均为目标 macOS arm64, 使用 ad-hoc 签名并通过包完整性检查.
- [x] helper 与测试资源从包内定位, application 搬离构建目录后仍能运行.
- [x] 在没有 Java 的隔离环境从应用启动 helper 并在 Godot 显示结构化结果; 不依赖开发目录或宿主安装的辅助程序.
- [x] helper 缺失、资源缺失或执行失败可诊断, 不退回 Java.
- [x] 保留可复现打包步骤和证据; 不增加 Developer ID、公证或公开下载验收要求.


## 完成证据

实现提交: `ef08230`. 原型与复现步骤见 [macOS application 原型报告](../../../docs/rewrite/2026-09-19-macos-app-prototype.md).

包验收覆盖 arm64、ad-hoc 完整性、搬移、禁止 Java 执行, 以及资源缺失、helper 缺失和 helper 执行失败. CLI 回归包含 8 项合成测试与 1 项版本握手测试. 两轴静态审查: Standards 0, Spec 0. 自动测试为 headless 场景, 未做人工窗口视觉验收.

Go 仅解除最小打包可行性阻塞. 正式资源、完整 gameplay 包与最终 Java-Free 仍需 ticket 26/27 验收.

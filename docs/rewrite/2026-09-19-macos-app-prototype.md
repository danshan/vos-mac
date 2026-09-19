# 最小 macOS application 原型

日期: 2026-09-19. 对应本地 ticket 03. 结论: Go, 可以继续 ticket 04 的生产链路集成. 这不是完整游戏包或最终 Java-Free 验收.

## 交付边界

`rewrite/prototypes/macos-cli` 是独立 Godot 原型. 启动后从自身 executable 的相对位置定位 `Contents/Helpers/open2jam-converter`, 调用 `version`, 解析结构化握手, 将结果显示在 Label. 测试资源从 `Contents/Resources` 读取. 正式生产加载仍需异步协议、取消与故障隔离, 不复用这里的同步 version 调用作为加载架构.

`rewrite/tools/build_macos_cli_probe.sh` 导出应用、裁剪 arm64、嵌入 helper 和资源, 先签 helper 再签 app, 最后校验完整性. 已存在的 app 不覆盖, 重建前需移走旧产物.

官方 4.6.3 模板只含 universal 二进制. 直接选择 arm64 导出失败, 因此 preset 使用 universal, 导出后通过系统 lipo 裁剪, 签名前完成修改. arm64 纹理导入设置也已开启.

## 输入与复现

使用 ticket 01 的 mise 环境和本机 SDKROOT 配置. Godot 4.6.3 stable, Rust 1.96.1. 本次主机为 Apple M5 / macOS 27.0. 工具位于被忽略的 `.scratch/godot-rust-migration/target/tools`.

官方发布源: https://github.com/godotengine/godot/releases/tag/4.6.3-stable . 从官方 export templates 压缩包提取 `templates/macos.zip`, 放置为工具目录中的 `macos.zip`.

- `Godot_v4.6.3-stable_export_templates.tpz` SHA-256: `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`.
- 提取的 `macos.zip` SHA-256: `700a5759952b2260b7d894dc9bc4908d99ce9abe2964a76c6d2bddd4af4738b2`.

```bash
mise exec -- bash rewrite/tools/build_macos_cli_probe.sh
mise exec -- bash rewrite/tools/test_macos_cli_probe.sh
```

产物为 `.scratch/godot-rust-migration/target/macos-probe/VosNativeProbe.app`, 约 85 MiB. 可直接打开查看握手结果. 构建依赖开发工具, 运行包只携带 Godot、Rust helper 和测试资源, 不携带 JVM/JAR.

## 验证证据

初始 CLI 测试在应用不存在时失败. 完成实现后, 自动包验收退出 0:

- app 和 helper 的 `lipo -archs` 均为 arm64.
- 原始包及搬移副本均通过 `codesign --verify --deep --strict`.
- app 搬至临时目录的 `Moved App.app`, 工作目录也离开项目, 仍读到资源并获得版本握手.
- 使用 macOS sandbox-exec 拒绝默认 process-exec, 仅允许 app、内嵌 helper、系统 `/bin/sh` 和其 `/bin/bash` 实现. Java 和其他外部程序不能执行. 这不是卸载宿主 Java, 而是运行时执行隔离.
- 在搬移副本中分别移走资源、移除 helper 执行权限、删除 helper, 均以非零退出和对应结构化错误结束, 没有 Java fallback.

Godot 的 `OS.execute` 经过系统 shell. 初始严格双程序白名单使 helper 返回 127; 加入 `/bin/sh` 后系统报告它需执行 `/bin/bash`, 明确加入该系统实现后通过. 没有放宽为允许任意程序.

日志: `/tmp/vos-macos-probe-build.log`, `/tmp/vos-macos-probe-test.log`, 以及产物目录下的 import/export 日志. 自动测试以 headless 模式验证同一场景逻辑, 未做图形窗口的人工视觉验收.

## 限制

这里只验证 version 握手和小资源, 尚未验证正式 SoundFont、音频解码动态库或完整 gameplay 包. 未承诺其他 macOS 版本, Developer ID、公证或公开下载 Gatekeeper 通过. 这些不影响用户已选择的本机自用范围; 正式包完整性与最终无 Java 门禁仍由 ticket 26/27 承担.

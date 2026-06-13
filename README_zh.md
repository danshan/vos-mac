# vos-mac

<img src="src/resources/open2jam_icon.png" alt="vos-mac icon" width="48" height="48">

[![Build](https://github.com/danshan/vos-mac/actions/workflows/build.yml/badge.svg)](https://github.com/danshan/vos-mac/actions/workflows/build.yml)

[English](README.md) | [简体中文](README_zh.md)

vos-mac 是 [open2jam](https://github.com/open2jamorg/open2jam) 的 macOS 定向 fork. open2jam 是一个开源的 [O2Jam](http://o2jam.wikia.com/wiki/O2Jam) 模拟器.

这个 fork 保留了原始 open2jam 的玩法和文件格式基础, 同时更新运行时, 让应用可以在当前 JDK 和 Apple Silicon macOS 上构建和运行.

## 致谢与上游

本项目派生自原始 open2jam 项目:

* 上游仓库: <https://github.com/open2jamorg/open2jam>
* 原始项目: open2jam, 一个开源 O2Jam 模拟器.
* 许可证: Artistic License 2.0, 保留在 [LICENSE](LICENSE).

感谢 open2jam 的作者和贡献者. 本 fork 继续使用并扩展了原项目的解析器, 玩法, skin, 延迟校准, 本地联机和 UI 基础.

## 本 fork 的主要变化

vos-mac 的主要变化集中在运行时和平台支持:

* 用 Maven/JDK 17 构建替换了旧的 Ant/NetBeans 构建.
* 将渲染从 LWJGL 2 Display API 迁移到 LWJGL 3 OpenGL.
* 用 AWT 承载 LWJGL 3 canvas, 让游戏 OpenGL 窗口可以和现有 Swing UI 在 macOS 上共存.
* 修复 Retina/HiDPI 渲染, 让 gameplay scene 填满窗口, 而不是只显示在左下角.
* 用 LWJGL 3 OpenAL 和 STB Vorbis 解码替换 FMOD Ex native audio.
* 将 JNA 从旧的 x86 时代内置 jar 更新为 Maven 管理的 JNA 5.x.
* 添加带正确 `Main-Class` manifest 的 executable shaded jar 构建.
* 添加当前 key mapping 流程可用的键盘处理, 包括 Space 和 semicolon.
* 添加 VOS chart 解析和播放支持, 包括 VOS keysound 的确定性 MIDI sample 渲染.
* 为不包含封面图的 VOS chart 添加默认选曲封面和加载视觉.
* 加固 gameplay window 启动和失败清理逻辑, 渲染初始化失败时会回到选曲 UI, 不再留下空白窗口.
* 添加 GitHub Actions CI, 在线执行 Maven 构建, 测试, 打包和 jar artifact 上传.
* Apple Silicon 上不再需要 Rosetta 或 x86_64 JDK.

## 平台支持

当前已验证目标:

* Apple Silicon 上的 macOS arm64.
* JDK 17.
* 使用 LWJGL 3 macOS arm64 native 的 Maven 构建.

预期但当前未验证:

* macOS x86_64 可能可以工作, 但需要把 `pom.xml` 中的 LWJGL native classifier 从 `natives-macos-arm64` 改为对应的 x86_64 macOS classifier.
* Linux 和 Windows 当前没有在这个 fork 中验证. 原始 open2jam 面向多个桌面平台, 但这个 fork 当前的构建配置和 native dependency selection 以 macOS arm64 为主.

已知限制:

* 新 OpenAL backend 还没有实现 MP3 sample 解码.
* BGA video 仍依赖现有 VLC/VLCJ 路径, 尚未在所有平台上重新验证.
* 旧的 LWJGL 2, JInput, FMOD Ex 和旧 native bundle 已从这个 fork 中移除.

## 当前功能

* 支持 OJN/OJM 文件, VOS 文件和 BMS 文件.
    * 部分支持 BMS 的 BGA. 包括图片背景和通过 VLC 播放的 movie 文件.
    * VOS 支持包括 chart 解析, 基于 MIDI 生成的 keysound, 默认封面/加载视觉, 以及播放 timing 修复.
* 支持当前 JDK, native dependency 由 Maven 管理的 LWJGL 3 提供.
    * 已在 macOS arm64 和 JDK 17 上验证.
* GitHub Actions 在线构建:
    * 在 push 和 pull request 指向 `master` 时执行 Maven 测试和 package 验证.
    * 成功 workflow run 会上传 packaged jar artifact.
* 音乐目录选择:
    * 可以把歌曲放在多个目录中. open2jam 会分别记录这些目录.
* 可调 KEY/BGM volume.
* Auto-play mode.
* Display 和 audio latency compensation. [Howto](https://github.com/open2jamorg/open2jam/blob/master/docs/autosync.md)
    * 相关讨论:
        * [Audio Latency and Autosyncing](https://github.com/open2jamorg/open2jam/pull/20)
        * [Display lag and audio latency - Some information and problems](https://github.com/open2jamorg/open2jam/issues/8)
* 可选且可配置的替代判定方式: "Timed Judgment", 使用毫秒而不是 beat 判断 note.
* Local matching - 和朋友一起游玩. 由 [partytime](https://github.com/dtinth/partytime) 提供支持. [Demo Video](http://www.youtube.com/watch?v=UaZu2jVOdS8)
* Speed type: Hi-Speed, xR-Speed, W-Speed, Regul-Speed

## 从源码运行

需要 JDK 17 或更新版本, 以及 Maven.

构建项目:

```bash
mvn -s .mvn/settings.xml verify
```

在 macOS 上运行 packaged jar:

```bash
java -jar target/open2jam-0.1.0-SNAPSHOT.jar
```

不要在这个 fork 中使用 `-XstartOnFirstThread`. gameplay window 通过 AWT/Swing 承载, 而不是 GLFW.

从源码运行:

```bash
mvn -s .mvn/settings.xml exec:exec
```

## 许可证

这里的所有代码都按照 Artistic License 2.0 分发.
详情请查看 [LICENSE](LICENSE) 中的完整许可证文本.

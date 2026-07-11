# Godot Java Parity Manual Acceptance

本文档是 `rewrite/godot` 的人工验收清单. 自动测试只能证明 deterministic fixture 和状态机没有回归, 不能证明真实显示器上的全屏布局, 输入手感, audio timing, 以及 Java skin 页面元素已经完全复刻.

## Preconditions

- 当前分支已通过自动 gate.
- 本机可以启动 Godot 项目.
- Settings 中准备至少一个包含 VOS, OJN/OJM, 或 osu!mania 7K chart 的歌曲目录.
- VOS 验收使用同一个 chart 对比 Java runtime 和 Godot runtime; OJN/OJM 与 osu!mania 7K 使用 recorded screenshot packages 对比同一 Java render path.

```bash
mise exec -- bash rewrite/tools/verify_vos_godot_java_parity.sh
OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL=1 mise exec -- bash rewrite/tools/verify_vos_godot_java_parity.sh
godot --path rewrite/godot
rewrite/tools/capture_gameplay_parity_pair.sh /path/to/chart.vos
rewrite/tools/capture_recorded_gameplay_parity_summaries.sh
rewrite/tools/capture_java_gameplay_screenshot.sh /path/to/chart.vos
rewrite/tools/capture_godot_gameplay_screenshot.sh
```

`capture_gameplay_parity_pair.sh` 会使用同一个 selected chart 导出 Godot bundle, 捕获 Java/Godot 两侧 `800x600` gameplay reference screenshot, 并生成 `side-by-side.png`, `diff.png`, `summary.json`. 这是 Gameplay Java parity 人工视觉验收的首选入口.

`capture_recorded_gameplay_parity_summaries.sh` 会刷新当前验收报告使用的四组 recorded screenshot packages: same-chart VOS, real demo VOS, real OJN note-time, real OSU long-note. 如果本机缺少某个 demo chart, 默认会跳过该项; 设置 `OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL=1` 可以把缺失 chart 变成失败.

`verify_vos_godot_java_parity.sh` 默认允许本地没有 recorded screenshot packages 时跳过 summary 校验; 设置 `OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL=1` 会要求四组 recorded summary 和 diff components 都存在并通过阈值, 这是证明 VOS, OJN/OJM, osu!mania 7K 当前 recorded parity 的强验收模式.

`capture_java_gameplay_screenshot.sh` 会通过 Java `Render` + `LWJGLGameWindow` 的真实 framebuffer 生成 reference screenshot, 默认保存到 `target/java-captures/java-gameplay-reference.png`. 运行前需要已有 packaged jar; 如果没有, 先执行 `mise run package`.

`capture_godot_gameplay_screenshot.sh` 会把 Godot fixture gameplay 截图保存到 `target/godot-captures/godot-gameplay-fixture.png`. 它需要普通 Godot renderer, 不要用 `--headless` 运行; headless 环境只能覆盖 texture smoke, 不能替代真实 framebuffer 截图.

人工验收结论记录在 `docs/rewrite/godot-java-parity-manual-acceptance-report.md`. 在 Java reference screenshot 和差异结论补齐之前, 不要把 gameplay parity 标记为完成.

## Fullscreen layout

- Fullscreen 模式下, Main menu, Settings, Song select, Gameplay, Result 都填满当前窗口.
- Windowed 模式和 Fullscreen 模式切换后, UI 元素不会保持旧的 `800x600` 固定布局.
- Settings 长表单可以上下滚动, Back 按钮始终可见.
- Gameplay 区域按照 Java `800x600` skin 基准等比缩放, 不拉伸 lane 或 HUD 数字.
- Song select 进入 Gameplay 和 Result Retry 时先显示 Java loading image, 至少保留 300ms, 然后进入 Gameplay.

## Settings and key bindings

- Song directories 可以配置真实 VOS, OJN/OJM, 或 osu!mania 7K 目录并持久化.
- 7K lane keys 按从左到右的顺序生效.
- Fullscreen 和 VSync 配置会按 Java launch display options 应用到 Godot window.
- Speed 和 volume misc keys 生效, 长按不会重复触发一次性动作.
- Audio latency 和 display latency 分别影响 keysound/autosound 与 visual/judgment 时间.
- Autosync display/audio 使用 Java `Latency.autosync` 的 64-sample 平滑规则, 且只在普通 tap 判定完成后更新 latency.
- Online local matching 和 Partytime server 已移除. Settings 不应出现 host:port 输入或 create server 按钮, Gameplay 不应创建 TCP client/server 或等待联机就绪.
- Autoplay, AutoSound, Haste, visibility modifier, speed type, judgment type 都能从 Settings 带入 Gameplay. Visibility modifier 需要按 Java runtime 验收: layer side effects 生效, 但 mask overlay 会因为 `CompositeEntity.isDead()` 在首帧被移除而不绘制.

## Song select

- Start 进入 Song select.
- Song select 能展示 Settings 中目录导出的 VOS, OJN/OJM, 和 osu!mania 7K charts.
- Title, artist, level, BPM, note count, duration, source file 与 Java exporter 输出一致.
- 返回 Main menu 后再次进入 Song select, 之前的筛选和选中项不会无故丢失.

## Gameplay Java parity

- Note lane, judgment line, measure mark, tap note, long note, pressed key overlay 的位置和层级与 Java skin 一致.
- Gameplay window title 按 Java `Render.startRendering()` 设置为 `artist - title`, 退出 Gameplay 后恢复默认项目标题.
- Score, combo, max combo, jam counter, jam bar, life bar, time bar, pill, per-judgment counters 按 Java `Render` 规则变化.
- Judgment effect, click effect, long flare, combo title, combo wobble 的出现时机和动画帧推进与 Java 逻辑一致.
- Time judgment 和 beat judgment 的 boundary 行为与 Java `TimeJudgment` / `BeatJudgment` 一致.
- HiSpeed, RegulSpeed, xRSpeed, WSpeed note distance 与 Java position strategy 一致.
- Hidden, Sudden, Dark visibility metadata 与 layer side effects 一致. Java `CompositeEntity` lifecycle 会让实际 mask overlay 不显示, Godot runtime 也应保持这个兼容行为.
- Tap note hit, long note head hit, long note tail release, miss, bad, pill conversion, jam combo, max combo 都与 Java scoring 规则一致.
- Accepted keysound, rejected VOS live-trigger keysound, autosound, autoplay, missed sample stop 都与 Java audio behavior 一致.
- Haste mode 改变 game speed, audio pitch, judgment factor, render speed 的方式与 Java runtime 一致.
- BGA event 按 Java `TimeEntity` 判定时间消费: `AUTOSOUND` 开启时与非声音实体一样扣除 audio latency, 但每帧最多消费一个 event.

## Result, retry, and back flow

- Chart 结束后进入 Result, 不需要重启 app.
- Result 显示 score, accuracy, max combo, perfect, cool, good, bad, miss.
- Retry 使用同一个 selected chart 重新进入 Gameplay, score 和 runtime state 从零开始.
- Back 返回 Song select, 保留当前 chart list 和选择位置.
- Main menu 返回主菜单后, 再次 Start 仍可进入同一 VOS catalog.

## Evidence

记录人工验收结果时, 至少填写以下信息:

```text
Date:
Branch:
Commit:
Godot version:
Java version:
Chart paths:
Display mode:
Java reference result:
Godot result:
Java screenshot:
Godot screenshot:
Observed differences:
Decision:
```

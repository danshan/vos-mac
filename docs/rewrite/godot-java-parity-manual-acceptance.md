# Godot Java Parity Manual Acceptance

本文档是 `rewrite/godot` 的人工验收清单. 自动测试只能证明 deterministic fixture 和状态机没有回归, 不能证明真实显示器上的全屏布局, 输入手感, audio timing, 以及 Java skin 页面元素已经完全复刻.

## Preconditions

- 当前分支已通过自动 gate.
- 本机可以启动 Godot 项目.
- Settings 中准备至少一个包含 VOS chart 的歌曲目录.
- 验收使用同一个 VOS chart 对比 Java runtime 和 Godot runtime.

```bash
mise exec -- bash rewrite/tools/verify_vos_godot_java_parity.sh
godot --path rewrite/godot
```

## Fullscreen layout

- Fullscreen 模式下, Main menu, Settings, Song select, Gameplay, Result 都填满当前窗口.
- Windowed 模式和 Fullscreen 模式切换后, UI 元素不会保持旧的 `800x600` 固定布局.
- Settings 长表单可以上下滚动, Back 按钮始终可见.
- Gameplay 区域按照 Java `800x600` skin 基准等比缩放, 不拉伸 lane 或 HUD 数字.

## Settings and key bindings

- Song directories 可以配置真实 VOS 目录并持久化.
- 7K lane keys 按从左到右的顺序生效.
- Speed 和 volume misc keys 生效, 长按不会重复触发一次性动作.
- Audio latency 和 display latency 分别影响 keysound/autosound 与 visual/judgment 时间.
- Autoplay, AutoSound, Haste, visibility modifier, speed type, judgment type 都能从 Settings 带入 Gameplay.

## Song select

- Start 进入 Song select.
- Song select 能展示 Settings 中目录导出的 VOS charts.
- Title, artist, level, BPM, note count, duration, source file 与 Java exporter 输出一致.
- 返回 Main menu 后再次进入 Song select, 之前的筛选和选中项不会无故丢失.

## Gameplay Java parity

- Note lane, judgment line, measure mark, tap note, long note, pressed key overlay 的位置和层级与 Java skin 一致.
- Score, combo, max combo, jam counter, jam bar, life bar, pill, per-judgment counters 按 Java `Render` 规则变化.
- Judgment effect, click effect, long flare, combo title, combo wobble 的出现时机和动画帧推进与 Java 逻辑一致.
- Time judgment 和 beat judgment 的 boundary 行为与 Java `TimeJudgment` / `BeatJudgment` 一致.
- HiSpeed, RegulSpeed, xRSpeed, WSpeed note distance 与 Java position strategy 一致.
- Tap note hit, long note head hit, long note tail release, miss, bad, pill conversion, jam combo, max combo 都与 Java scoring 规则一致.
- Accepted keysound, rejected VOS live-trigger keysound, autosound, autoplay, missed sample stop 都与 Java audio behavior 一致.
- Haste mode 改变 game speed, audio pitch, judgment factor, render speed 的方式与 Java runtime 一致.
- BGA event 按 Java game time 消费, 每帧最多消费一个 event.

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
VOS chart path:
Display mode:
Java reference result:
Godot result:
Observed differences:
Decision:
```

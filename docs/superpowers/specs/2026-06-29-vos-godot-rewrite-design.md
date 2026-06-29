# VOS Godot Rewrite Initial Version Design

## 目标

用 Godot 4 重构 open2jam 的完整游戏体验, 并以 VOS 作为第一版可玩格式. 第一版目标不是同时重写所有谱面格式, 而是先证明新的全屏游戏 runtime 可以完成完整闭环:

`Boot -> MainMenu -> Settings -> SongSelect -> Loading -> Gameplay -> Result`

完成后, 用户可以启动 Godot 版应用, 在 settings 中配置 VOS 歌曲目录和键位, 从 start 进入选歌, 选择 VOS chart, 完成一局, 看到结算分数, 并选择 retry 或返回选歌.

## 范围

第一版只承诺 VOS 完整闭环. `osu!mania 7K` 和 `OJN/OJM` 是后续兼容目标, 但本设计会保留 normalized contract 的扩展空间, 避免 VOS 方案变成一次性专用实现.

本阶段包括:

- 新增 Godot runtime 工程.
- 新增 Java VOS exporter CLI.
- 定义 `catalog.json`, `gameplay.json`, `audio-manifest.json` contract.
- 实现 Godot app state machine.
- 实现 VOS song select, gameplay, result, retry, back flow.
- 增加 Java 和 Godot 侧自动测试.

本阶段不包括:

- 直接在 Godot 中解析 `.vos` 二进制格式.
- 重写 OJN/OJM, BMS, osu!mania parser.
- 移除当前 Java/Swing 发布入口.
- 完整复刻旧版所有 skin, local matching, BGA, autosync UI.
- 将 Java compatibility layer 替换为 Rust core.

## 当前项目基线

当前 `master` 是 Java/Swing + LWJGL 3 应用:

- `src/org/open2jam/Main.java` 启动 Swing UI.
- `src/org/open2jam/gui/Interface.java` 提供 `Music Selection`, `Configuration`, `Advanced Options` tab.
- `src/org/open2jam/gui/parts/MusicSelection.java` 负责目录扫描, chart 选择, game options 保存, 以及创建 `Render`.
- `src/org/open2jam/render/Render.java` 集中处理 timing, input, judgment, score, combo, life, sound, BGA.
- `src/org/open2jam/render/lwjgl/LWJGLGameWindow.java` 创建单独的 AWT-hosted LWJGL gameplay window.
- `src/org/open2jam/Config.java` 使用 `config.vl` 和 `game-options.xml` 保存目录, key mapping, display, volume, latency.

这个结构可以继续作为行为参考, 但不适合作为新的全屏游戏体验入口. 新版应把 UI flow 和 gameplay runtime 放进同一个 Godot app shell.

## 技术选型

推荐方案是 Godot 4 runtime 加 Java VOS exporter bridge.

Godot 负责:

- 全屏和 windowed 窗口模式.
- 菜单, settings, 选歌, loading, gameplay, result.
- 输入绑定捕获和运行时 input dispatch.
- 2D note rendering, UI animation, result presentation.
- 读取 `user://settings.cfg`.
- 读取 Java exporter 生成的 normalized JSON 和导出音频资产.

Java exporter 负责:

- 扫描 VOS 歌曲目录.
- 使用现有 `VOSParser`, `VOSChart`, `EventList`, `SampleData` 解析 VOS.
- 使用现有 VOS MIDI sample 逻辑和 `VosAudioValidator` 作为行为参考.
- 输出稳定 JSON contract 和 Godot 可读取的 audio assets.

选择这个方案的原因:

- VOS 已有 Java parser 和 reference audio validation.
- Godot 首版直接解析 VOS 会把 MVP 拖进私有格式和 MIDI 细节.
- Java exporter 可以保留当前行为, 同时让 Godot runtime 专注体验闭环.
- 后续 `osu!mania 7K` 和 `OJN/OJM` 可以复用同一个 normalized contract.

## 架构

### 目录布局

新增目录:

```text
rewrite/
  godot/
    project.godot
    scenes/
    scripts/
    resources/
  contracts/
    catalog.schema.json
    gameplay.schema.json
    audio-manifest.schema.json
```

Java exporter 代码建议放在当前 Java source tree 内, 复用 Maven 构建和 parser classpath:

```text
src/org/open2jam/export/
  CatalogExporter.java
  GameplayExporter.java
  AudioManifestExporter.java
  ExportCli.java
```

`ExportCli` 可以由 `Main.runCli(...)` 分发, 也可以独立为一个 package-private command helper. 第一版优先减少入口复杂度, 让现有 packaged jar 能直接执行 exporter.

### 运行时边界

Godot 不读取 `.vos`:

1. Settings 中配置歌曲目录.
2. Godot 调用 Java exporter 或读取缓存的 `catalog.json`.
3. SongSelect 显示 catalog.
4. 用户选择 chart 后, Godot 调用 Java exporter 生成 selected chart 的 `gameplay.json` 和 `audio-manifest.json`.
5. Loading 加载 JSON 和音频资产.
6. Gameplay 使用 normalized data 播放.
7. Result 基于 Godot runtime 的 score snapshot 展示结算.

Java exporter 不管理 UI:

- 不显示 Swing dialog.
- 不访问 Godot scene.
- 只接收 CLI 参数, 输出文件, 返回退出码.
- 所有错误输出为结构化 message, 便于 Godot 展示.

## App State Machine

### Boot

职责:

- 加载 `user://settings.cfg`.
- 应用 fullscreen/windowed 配置.
- 检查 Java exporter 可执行路径.
- 初始化默认 key binding.
- 进入 `MainMenu`.

失败处理:

- exporter 不可用时仍进入菜单, 但 start 显示不可用状态.
- settings 文件损坏时使用默认配置并覆盖前先保留错误提示.

### MainMenu

控件:

- `Start`
- `Settings`
- `Quit`

行为:

- `Start` 进入 `SongSelect`.
- `Settings` 进入 `Settings`.
- `Quit` 退出应用.

### Settings

第一版 settings 包含:

- VOS song directories.
- Key bindings for 7K lanes.
- Fullscreen/windowed toggle.
- Master volume.
- BGM volume.
- Keysound volume.
- Display latency.
- Audio latency.

持久化:

- Godot 使用 `ConfigFile` 写入 `user://settings.cfg`.
- Java exporter 不直接读取 Godot settings, Godot 调用 exporter 时把 song directories 和 output paths 作为参数传入.

### SongSelect

职责:

- 加载或刷新 `catalog.json`.
- 显示 VOS chart metadata.
- 支持 search/filter.
- 支持选择 chart.
- 支持返回 `MainMenu`.

第一版 song row 字段:

- Title.
- Artist.
- Level.
- BPM.
- Note count.
- Duration.
- Source file.

刷新策略:

- Settings 改变 song directories 后 catalog 标记为 stale.
- 用户进入 SongSelect 时如果 catalog stale, 触发 exporter.
- exporter 失败时显示错误并保留上一次成功 catalog.

### Loading

职责:

- 对 selected chart 触发 Java exporter.
- 加载 `gameplay.json`.
- 加载 `audio-manifest.json`.
- 预加载 background audio 和第一屏必要 keysounds.
- 进入 `Gameplay`.

失败处理:

- JSON schema 不匹配: 返回 SongSelect 并显示错误.
- 音频资产缺失: 返回 SongSelect 并显示错误.
- 非关键 sample 加载失败: 第一版可以失败退出该 chart, 不静默降级.

### Gameplay

职责:

- 根据 `gameplay.json` 驱动 note rendering.
- 根据 settings 中 key binding 处理 input.
- 执行 judgment.
- 维护 score, combo, max combo, life, judgment counts.
- 根据 `audio-manifest.json` 播放 background 和 live keysounds.
- chart 结束后进入 `Result`.

第一版玩法策略:

- 仅支持 7K VOS lane layout.
- judgment window 可以先复用当前 Java behavior 的数值定义, 但在 Godot 中实现独立 runtime state.
- score 规则先与当前 `Render` 对齐到足够可验证的程度, 不要求逐像素或逐分完全一致.
- ESC 返回 SongSelect 需要确认, 避免误退出一局.

### Result

展示:

- Title.
- Score.
- Accuracy.
- Max combo.
- Judgment counts.
- Miss count.

操作:

- `Retry`: 使用同一 selected chart 重新进入 `Loading`.
- `Back`: 返回 `SongSelect`, 保留当前筛选和选中位置.
- `Main Menu`: 返回 `MainMenu`.

## Contract

所有 contract 必须带 `schemaVersion`. 第一版 schema version 为 `1`.

### Catalog

`catalog.json` 描述所有可选 chart.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-06-29T00:00:00Z",
  "entries": [
    {
      "id": "vos:sha256:example",
      "format": "VOS",
      "sourcePath": "/absolute/path/song.vos",
      "title": "Example",
      "artist": "Artist",
      "noter": "Author",
      "genre": "Other",
      "keys": 7,
      "level": 12,
      "levelKnown": true,
      "bpm": 120.0,
      "durationMs": 90000,
      "noteCount": 885,
      "coverAsset": "",
      "exportStatus": "ready"
    }
  ]
}
```

### Gameplay

`gameplay.json` 描述可被 Godot 直接播放和判定的 normalized chart.

```json
{
  "schemaVersion": 1,
  "chartId": "vos:sha256:example",
  "format": "VOS",
  "keys": 7,
  "bpm": 120.0,
  "durationMs": 90000,
  "timingPoints": [
    {"timeMs": 0.0, "bpm": 120.0, "meter": 4}
  ],
  "notes": [
    {
      "id": 1,
      "lane": 0,
      "startMs": 1000.0,
      "endMs": null,
      "sampleId": 42,
      "volume": 1.0,
      "pan": 0.0,
      "kind": "tap"
    }
  ],
  "autoPlayEvents": [
    {"timeMs": 0.0, "sampleId": 1, "volume": 1.0, "pan": 0.0}
  ]
}
```

### Audio Manifest

`audio-manifest.json` 描述 Godot 需要加载的音频资产.

```json
{
  "schemaVersion": 1,
  "chartId": "vos:sha256:example",
  "assets": [
    {
      "sampleId": 1,
      "path": "user://cache/vos/example/sample-1.wav",
      "type": "wav",
      "role": "background",
      "preload": true
    },
    {
      "sampleId": 42,
      "path": "user://cache/vos/example/sample-42.wav",
      "type": "wav",
      "role": "keysound",
      "preload": false
    }
  ]
}
```

VOS embedded MIDI sample 必须由 Java exporter 转成 Godot 可播放资产. 第一版优先 WAV, 避免 Godot runtime 依赖 MIDI synthesizer.

## Java Exporter

### CLI

建议命令:

```bash
java -jar target/open2jam-0.1.2.jar --export-catalog --format vos --output /tmp/catalog.json /path/to/vos-dir
java -jar target/open2jam-0.1.2.jar --export-gameplay --chart-id vos:sha256:example --catalog /tmp/catalog.json --output /tmp/gameplay.json
java -jar target/open2jam-0.1.2.jar --export-audio --chart-id vos:sha256:example --catalog /tmp/catalog.json --output /tmp/audio-manifest.json --asset-dir /tmp/assets
```

也可以提供组合命令:

```bash
java -jar target/open2jam-0.1.2.jar --export-selected --format vos --source /path/to/song.vos --out-dir /tmp/open2jam-selected
```

### Export Rules

Catalog export:

- 使用 `ChartParser.parseFile(...)` 扫描 `.vos`.
- 每个 `VOSChart` 生成一个 catalog entry.
- `id` 使用 source path canonical form 和文件内容 hash 生成.
- `levelKnown` 保留 VOS 专有语义.

Gameplay export:

- 使用 `VOSChart.getEvents()`.
- playable channels 映射为 lane `0..6`.
- `AUTO_PLAY` 映射为 `autoPlayEvents`.
- `Event.Flag.HOLD` 和 `Event.Flag.RELEASE` 合并为 hold note.
- `Event.Flag.NONE` 输出 tap note.
- `startMs` 和 `endMs` 由 timing compiler 输出, 不让 Godot 重算 measure/position.

Audio export:

- 使用 `VOSChart.getSamples()`.
- embedded MIDI sample 转成 WAV.
- background sample 和 live keysound sample 都输出 manifest entry.
- 对缺失 sample 报错, 不生成不完整 manifest.

## Godot Runtime

### Scenes

建议 scene:

```text
scenes/
  main.tscn
  main_menu.tscn
  settings.tscn
  song_select.tscn
  loading.tscn
  gameplay.tscn
  result.tscn
```

`main.tscn` 承载 app controller, 其他 scene 由 state machine 切换.

### Scripts

建议 script:

```text
scripts/
  app_state.gd
  settings_store.gd
  exporter_client.gd
  catalog_store.gd
  gameplay_loader.gd
  audio_manifest_loader.gd
  gameplay_controller.gd
  score_state.gd
  result_model.gd
```

每个 script 的职责要小:

- `exporter_client.gd`: 只负责调用 Java exporter 和解析退出状态.
- `catalog_store.gd`: 只负责 catalog 数据和筛选.
- `gameplay_controller.gd`: 只负责运行一局.
- `score_state.gd`: 只负责 judgment 后的分数状态.

### Fullscreen

Godot 使用 runtime API 切换窗口模式. Settings 中的选择立即生效, 并写入 `user://settings.cfg`.

项目默认可以启动为 windowed, 首次运行进入 settings 后允许切换 fullscreen. 打包版本可以在 project settings 中设置默认 fullscreen, 但 runtime 必须支持用户切换.

## Error Handling

Exporter error:

- Godot 展示 stderr 中的结构化 message.
- Catalog export 失败时保留旧 catalog.
- Selected export 失败时返回 SongSelect.

Contract error:

- `schemaVersion` 不支持时拒绝加载.
- 必填字段缺失时拒绝加载.
- note lane 超出 keys 范围时拒绝加载.
- audio manifest 中 path 不存在时拒绝进入 Gameplay.

Runtime error:

- 音频播放设备初始化失败时显示错误并返回 MainMenu.
- Gameplay 中用户主动退出时返回 SongSelect, 不生成 Result.
- Chart 自然结束时才进入 Result.

## Testing

### Java Tests

新增测试:

- VOS catalog export includes metadata, levelKnown, noteCount, sourcePath.
- VOS gameplay export emits lanes, tap notes, hold notes, autoPlayEvents.
- VOS audio export emits WAV assets and manifest entries.
- Invalid VOS file returns non-zero exit status and useful error message.
- Existing `VosAudioValidator` tests continue passing.

### Godot Tests

新增 headless tests:

- `settings_store_test.gd`: settings persist and reload.
- `app_state_test.gd`: valid transitions only.
- `catalog_store_test.gd`: loads fixture catalog and filters by title.
- `gameplay_loader_test.gd`: loads fixture gameplay and rejects bad schema.
- `audio_manifest_loader_test.gd`: loads fixture manifest and rejects missing assets.
- `result_flow_test.gd`: retry returns to loading, back returns to song select.

### Manual Acceptance

Manual checklist:

- App starts.
- Fullscreen and windowed both work.
- Settings can add a VOS directory.
- Start opens SongSelect.
- SongSelect can refresh and show at least one VOS chart.
- Selected VOS chart enters Gameplay.
- Gameplay plays background audio and live keysounds.
- Chart completion enters Result.
- Retry starts the same chart again.
- Back returns to SongSelect with selection preserved.

## Cutover Criteria

Godot VOS initial version can be considered usable when:

- VOS reference fixture passes Java export tests.
- Godot fixture flow passes headless tests.
- A real VOS chart completes full manual flow.
- Packaged app can launch without requiring source checkout paths.
- Current Java/Swing version remains available as fallback until multi-format support is ready.

## Future Compatibility

`osu!mania 7K` and `OJN/OJM` should reuse the same contract:

- `format` differentiates parser source.
- `notes`, `autoPlayEvents`, and `assets` keep the same shape.
- Format-specific differences stay inside exporter.

Expected later work:

- osu!mania exporter maps `.osu/.osz`, inherited scroll speed, background audio, hit samples.
- OJN/OJM exporter maps OJN difficulties, OJM decoded samples, keysound schedules.
- Once all target formats are stable behind the contract, evaluate replacing Java exporter with Rust core or native Godot extension.

## Implementation Defaults

第一版采用以下默认决策, 避免实现计划阶段继续发散:

- Local Godot runs invoke the exporter through Maven or the built jar depending on availability, but `exporter_client.gd` exposes a single configured command path.
- Exported catalog, gameplay JSON, and audio assets are cached under `user://exports/vos/`.
- The first packaged Godot app may require a system JRE. Bundling a Java runtime is a packaging follow-up, not a VOS gameplay blocker.
- Automated tests use repository fixtures. Manual acceptance can use any real VOS chart selected by the maintainer.

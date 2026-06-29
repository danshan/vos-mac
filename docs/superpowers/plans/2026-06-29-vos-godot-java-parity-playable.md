# VOS Godot Java Parity Playable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for every loop. Use superpowers:subagent-driven-development only when the user explicitly keeps loop engineering with subagents enabled.

**Goal:** 让 `rewrite/godot` 从当前 preview shell 演进为可玩的 VOS runtime, 并且 gameplay 逻辑, 判定, 分数, combo, life, note distance, 以及游戏页面元素的渲染规则都以 Java runtime 为 source of truth.

**Superseded assumption:** 旧设计中的 “score 规则先与当前 Render 对齐到足够可验证的程度, 不要求逐像素或逐分完全一致” 不再成立. 从本计划开始, gameplay parity 的默认标准是完全复刻 Java 逻辑. 如果某处暂时无法逐像素复刻, 必须用 explicit TODO 和测试边界标出, 不能把近似行为包装成完成状态.

**Architecture:** Java 保留为 VOS compatibility/export layer 和 parity oracle. Godot runtime 负责 fullscreen UI, menu flow, input, audio playback, gameplay rendering, and result flow. 任何复杂解析, timing, skin/entity 规则优先从 Java 导出确定性 JSON 或测试 oracle, 避免在 GDScript 中凭印象重写隐藏规则.

**Verification gate:** 每个 loop 必须先写失败测试, 再实现最小改动, 最后运行 narrow test 和 `rewrite/tools/verify_vos_godot_initial.sh`. 涉及 Java parity 的 loop 还必须增加 Java-side oracle 或 fixture test.

---

## Java Source Of Truth

- `src/org/open2jam/render/Render.java`: gameplay state machine, keyboard handling, score, combo, life, jam bar, pill, judgment effects.
- `src/org/open2jam/game/judgment/TimeJudgment.java`: VOS/default time-window judgment.
- `src/org/open2jam/game/judgment/BeatJudgment.java`: beat-based judgment.
- `src/org/open2jam/game/position/HiSpeed.java`: beat-distance note positioning.
- `src/org/open2jam/game/position/RegulSpeed.java`: regular-speed note positioning.
- `src/org/open2jam/render/entities/*.java`: visual entity behavior, including note, long note, judgment, combo counter, number counter, bar, and animation timing.
- `src/org/open2jam/render/Skin.java` and `src/org/open2jam/render/SkinParser.java`: entity definitions and layout from skin files.

---

## Loop 1: Java-Parity Judgment Strategy

**Hypothesis:** Godot must not keep placeholder judgment behavior. Exact Java judgment windows are small and stable enough to port first, and later score/gameplay loops can depend on them.

**Scope:** Godot logic only. No UI changes.

**Files:**
- Create: `rewrite/godot/scripts/judgment_strategy.gd`
- Create: `rewrite/godot/scripts/tests/judgment_strategy_test.gd`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh`

- [ ] **Step 1: Write failing Godot test**

Test exact Java constants and boundary behavior:

```text
TimeJudgment BAD = 173
TimeJudgment GOOD = 125
TimeJudgment COOL = 41
BeatJudgment BAD = 0.8
BeatJudgment GOOD = 0.5
BeatJudgment COOL = 0.2
```

Expected behavior:
- `accept_time(173)` is true.
- `accept_time(174)` is false.
- `missed_time(-174)` is true.
- `judge_time(41)` is `COOL`.
- `judge_time(42)` is `GOOD`.
- `judge_time(126)` is `BAD`.
- `judge_time(174)` is `MISS`.

- [ ] **Step 2: Run failing test**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/judgment_strategy_test.gd
```

Expected: FAIL because `judgment_strategy.gd` does not exist.

- [ ] **Step 3: Implement strategy**

Implement a script with the smallest public surface required by the tests:

```text
accept_time(hit_time)
missed_time(hit_time)
judge_time(hit_time)
accept_beat(hit_delta)
missed_beat(hit_delta)
judge_beat(hit_delta)
```

- [ ] **Step 4: Add regression gate**

Append the new Godot test to `rewrite/tools/verify_vos_godot_initial.sh`.

- [ ] **Step 5: Verify and commit**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/judgment_strategy_test.gd
JAVA_HOME=/Users/honghao.shan/.asdf/installs/java/zulu-17.58.21 PATH=/Users/honghao.shan/.asdf/installs/java/zulu-17.58.21/bin:$PATH bash rewrite/tools/verify_vos_godot_initial.sh
git add rewrite/godot/scripts/judgment_strategy.gd rewrite/godot/scripts/tests/judgment_strategy_test.gd rewrite/tools/verify_vos_godot_initial.sh docs/superpowers/plans/2026-06-29-vos-godot-java-parity-playable.md
git commit -m "feat: add Java parity judgment strategy"
```

---

## Loop 2: Java-Parity Score, Combo, And Life Model

**Hypothesis:** Current Godot `score_state.gd` is placeholder behavior. It must mirror `Render.handleJudgment`, `Render.setNoteJudgment`, and `ComboCounterEntity` thresholds before gameplay can be called playable.

**Scope:** Replace placeholder scoring with Java-compatible state transitions.

**Files:**
- Modify: `rewrite/godot/scripts/score_state.gd`
- Modify: `rewrite/godot/scripts/tests/result_flow_test.gd`
- Create: `rewrite/godot/scripts/tests/score_state_java_parity_test.gd`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh`

**Java rules to mirror:**
- `COOL`: `jambar += 2`, `consecutive_cools += 1`, `life += rank >= 2 ? 48 : 96`, `score += 200 + jamcombo * 10`.
- `GOOD`: `jambar += 1`, `consecutive_cools = 0`, `score += 100`.
- `BAD`: without pill, `jambar = 0`, `jamcombo = 0`, `life -= 240`, `score += 4`, `consecutive_cools = 0`.
- `MISS`: `jambar = 0`, `jamcombo = 0`, `consecutive_cools = 0`, `life -= 1440`, `score -= min(score, 10)`.
- Combo increases only for `COOL` and `GOOD`.
- Max combo increments one by one while `maxcombo < combo`.
- Jam combo increments when `jambar >= jambar_limit`, then `jambar = 0`.
- Fifteen consecutive `COOL` results grant one pill up to five pills.
- A pill converts one `BAD` into `GOOD`-like handling and consumes the pill.

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/score_state_java_parity_test.gd
```

---

## Loop 3: Note Distance And Timeline Model

**Hypothesis:** Playability requires note positions to match Java timing math before visuals are refined.

**Scope:** Add deterministic Godot math matching Java `HiSpeed`, `RegulSpeed`, and `NoteDistanceCalculator`.

**Files:**
- Create: `rewrite/godot/scripts/timing_model.gd`
- Create: `rewrite/godot/scripts/note_distance_calculator.gd`
- Create: `rewrite/godot/scripts/tests/note_distance_java_parity_test.gd`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh`

**Java rules to mirror:**
- `HiSpeed`: `speed * (timing.getBeat(target) - timing.getBeat(now)) * measureSize / 4`.
- `RegulSpeed`: `delta = target - now`, `beats = delta * 150 / 60000`, `speed * beats * measureSize / 4`.

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/note_distance_java_parity_test.gd
```

---

## Loop 4: Java Render Metadata Export

**Hypothesis:** Rendering parity should be driven by Java skin/entity metadata, not manually recreated labels and rectangles.

**Scope:** Extend Java export with deterministic render metadata for VOS gameplay screen.

**Files:**
- Create: `src/org/open2jam/export/VosRenderMetadataExporter.java`
- Create: `src/test/java/org/open2jam/export/VosRenderMetadataExporterTest.java`
- Modify: `src/org/open2jam/export/VosExportCli.java`
- Modify: `src/test/java/org/open2jam/MainVosExportCliTest.java`

**Export must include:**
- Entity ids from skin map.
- Entity type.
- Position, size, layer, alignment, animation frames if available.
- Gameplay counters required by Java `Render`: score, jam, life, combo, max combo, per-judgment counters.
- Key lane geometry for VOS 7K.

**Verification:**

```bash
mvn -s .mvn/settings.xml -Dtest=VosRenderMetadataExporterTest,MainVosExportCliTest test
```

---

## Loop 5: Godot Gameplay Render Entity Layer

**Hypothesis:** Once render metadata exists, Godot should instantiate a Java-shaped entity tree and update it with Java-compatible state instead of drawing ad hoc UI.

**Scope:** Add Godot render model and view nodes for gameplay.

**Files:**
- Create: `rewrite/godot/scripts/render_entity_model.gd`
- Create: `rewrite/godot/scripts/gameplay_view.gd`
- Create: `rewrite/godot/scripts/tests/render_entity_model_test.gd`
- Modify: `rewrite/godot/scripts/gameplay_controller.gd`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh`

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/render_entity_model_test.gd
```

---

## Loop 6: Real Menu, Settings, And Song Select Flow

**Hypothesis:** The current `main_ui.gd` shell is only a preview. Fullscreen responsive UI must become a real flow with states and scene-owned views.

**Scope:** Split main menu, settings, song select, gameplay, result into explicit views while preserving the current responsive fullscreen behavior.

**Files:**
- Modify: `rewrite/godot/scripts/main_ui.gd`
- Create: `rewrite/godot/scripts/main_menu_view.gd`
- Create: `rewrite/godot/scripts/settings_view.gd`
- Create: `rewrite/godot/scripts/song_select_view.gd`
- Create: `rewrite/godot/scripts/result_view.gd`
- Modify: `rewrite/godot/scripts/settings_store.gd`
- Create: `rewrite/godot/scripts/tests/menu_flow_test.gd`
- Create: `rewrite/godot/scripts/tests/fullscreen_layout_test.gd`

**Verification:**

```bash
godot --headless --path rewrite/godot --resolution 2560x1440 --script res://scripts/tests/fullscreen_layout_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/menu_flow_test.gd
```

---

## Loop 7: Input, Key Binding, And Gameplay Control

**Hypothesis:** VOS 7K play requires configurable key bindings that map to Java keyboard channels and use the same accepted/rejected keysound behavior.

**Scope:** Wire settings key bindings into gameplay input.

**Files:**
- Modify: `rewrite/godot/scripts/settings_store.gd`
- Modify: `rewrite/godot/scripts/gameplay_controller.gd`
- Create: `rewrite/godot/scripts/input_map_store.gd`
- Create: `rewrite/godot/scripts/tests/input_map_store_test.gd`
- Create: `rewrite/godot/scripts/tests/gameplay_input_java_parity_test.gd`

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/input_map_store_test.gd
godot --headless --path rewrite/godot --script res://scripts/tests/gameplay_input_java_parity_test.gd
```

---

## Loop 8: Audio Playback And Keysounds

**Hypothesis:** A chart is not playable until autoplay sounds, accepted note keysounds, rejected VOS live-trigger keysounds, and long-note releases follow Java behavior.

**Scope:** Integrate Godot audio playback with exported audio manifest.

**Files:**
- Modify: `rewrite/godot/scripts/audio_manifest_loader.gd`
- Create: `rewrite/godot/scripts/audio_player_pool.gd`
- Modify: `rewrite/godot/scripts/gameplay_controller.gd`
- Create: `rewrite/godot/scripts/tests/audio_player_pool_test.gd`

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/audio_player_pool_test.gd
```

---

## Loop 9: Result, Retry, And Back-To-Song-Select

**Hypothesis:** The flow is complete only when a player can finish a song, see Java-compatible result state, retry, or return to song select without restarting the app.

**Scope:** Complete the end-to-end app state transitions.

**Files:**
- Modify: `rewrite/godot/scripts/result_model.gd`
- Modify: `rewrite/godot/scripts/result_view.gd`
- Modify: `rewrite/godot/scripts/app_state.gd`
- Modify: `rewrite/godot/scripts/tests/result_flow_test.gd`

**Verification:**

```bash
godot --headless --path rewrite/godot --script res://scripts/tests/result_flow_test.gd
```

---

## Loop 10: Manual Java-Parity Acceptance Gate

**Hypothesis:** Automated unit tests are necessary but not sufficient for visual/gameplay parity. A release candidate must include a deterministic fixture and a manual visual checklist.

**Scope:** Add a repeatable local acceptance workflow.

**Files:**
- Create: `rewrite/tools/verify_vos_godot_java_parity.sh`
- Create: `docs/rewrite/godot-java-parity-manual-acceptance.md`
- Modify: `rewrite/tools/verify_vos_godot_initial.sh`

**Verification:**

```bash
JAVA_HOME=/Users/honghao.shan/.asdf/installs/java/zulu-17.58.21 PATH=/Users/honghao.shan/.asdf/installs/java/zulu-17.58.21/bin:$PATH bash rewrite/tools/verify_vos_godot_java_parity.sh
godot --path rewrite/godot --fullscreen
```

Manual acceptance must check:
- Fullscreen menu scales to the real display.
- Settings can choose song directory and key bindings.
- Song select lists exported VOS songs.
- Gameplay note lane, counters, judgment effect, combo, life, score, and result match the Java oracle for the same fixture.
- Retry restarts the same song.
- Back returns to song select.

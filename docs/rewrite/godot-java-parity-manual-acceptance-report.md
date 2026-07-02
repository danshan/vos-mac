# Godot Java Parity Manual Acceptance Report

## Status

- Decision: Accepted with bounded residual visual difference.
- Automated gate: Passed in the latest local run, with log evidence at `target/verify-vos-godot-java-parity-require-all-refresh-evidence.log`.
- Status text oracle: Passed with both the Label fallback path and the production `statusFont` Java atlas glyph path covered.
- Godot screenshot: `target/godot-captures/godot-gameplay-fixture.png`.
- Java reference screenshot: Capture smoke verified at `target/java-captures/java-gameplay-reference.png`; the Java capture-only window path now exits cleanly after writing the screenshot instead of disposing the macOS OpenGL canvas through the normal window-close path.
- Same-chart comparison package: Generated at `target/gameplay-parity-capture/side-by-side.png`, `target/gameplay-parity-capture/diff.png`, `target/gameplay-parity-capture/diff-components.json`, and `target/gameplay-parity-capture/summary.json`.
- Latest same-chart summary: 800x600 Java vs 800x600 Godot, `differingPixels=227`, `meanAbsDelta=0.0021458333333333334`, `maxChannelDelta=24`.
- Latest same-chart largest diff component: bottom HUD timer/timebar edge at `x=385,y=569,width=23,height=1,pixels=23`.
- Same-chart threshold verifier: `rewrite/tools/verify_gameplay_parity_summary.sh` accepts the current package and fails the pair capture if residuals exceed the configured thresholds.
- Residual shape guard: The same verifier now rejects block-shaped structural components by requiring the largest component short side to stay within the edge-residual threshold. Current same-chart VOS, real demo VOS, real OJN, and real OSU packages all report `largestComponentShortSide=1`.
- Recorded summary gate: `rewrite/tools/verify_vos_godot_java_parity.sh` now verifies the current same-chart VOS, real demo VOS, real OJN note-time, and real OSU long-note summaries when those artifacts are present.
- Recorded summary refresh: `OPEN2JAM_RECORDED_PARITY_REQUIRE_ALL=1 rewrite/tools/capture_recorded_gameplay_parity_summaries.sh` rebuilt all four current packages without skips, with log evidence at `target/capture-recorded-gameplay-parity-require-all.log`.
- Manual residual crop review: `target/parity-crops/java-timebar.png`, `target/parity-crops/godot-timebar.png`, and `target/parity-crops/diff-timebar.png` show no visible bottom HUD timer/timebar structural mismatch at crop scale.
- Real demo VOS smoke package: Generated at `target/gameplay-parity-capture-real-demo/side-by-side.png`, `target/gameplay-parity-capture-real-demo/diff.png`, `target/gameplay-parity-capture-real-demo/diff-components.json`, and `target/gameplay-parity-capture-real-demo/summary.json`.
- Real demo VOS smoke summary: 800x600 Java vs 800x600 Godot, `differingPixels=227`, `meanAbsDelta=0.0021458333333333334`, `maxChannelDelta=24`.
- Real OJN hard chart note-time package: Generated at `target/gameplay-parity-capture-real-ojn-notes/side-by-side.png`, `target/gameplay-parity-capture-real-ojn-notes/diff.png`, `target/gameplay-parity-capture-real-ojn-notes/diff-components.json`, and `target/gameplay-parity-capture-real-ojn-notes/summary.json`.
- Real OJN hard chart note-time summary at `gameTime=5000ms`: 800x600 Java vs 800x600 Godot, `differingPixels=227`, `meanAbsDelta=0.0021458333333333334`, `maxChannelDelta=24`.
- Real OSU long-note package: Generated at `target/gameplay-parity-capture-real-osu-notes/side-by-side.png`, `target/gameplay-parity-capture-real-osu-notes/diff.png`, `target/gameplay-parity-capture-real-osu-notes/diff-components.json`, and `target/gameplay-parity-capture-real-osu-notes/summary.json`.
- Real OSU long-note summary at `gameTime=3800ms`: 800x600 Java vs 800x600 Godot, raw `differingPixels=1033`, raw `meanAbsDelta=0.003907638888888889`, `maxChannelDelta=24`; with explicit renderer rounding tolerance `pixelTolerance=4`, the structural metrics are `significantDifferingPixels=200`, `significantMeanAbsDelta=0.0021868055555555556`, `componentCount=21`, and `largestComponentPixels=21`, so the standard structural thresholds accept it.
- Partytime real localhost loopback: Passed outside the default sandbox with log evidence at `target/godot-logs/partytime-loopback-manual-escalated.log`; the default sandbox still reports `Cannot start server:22`, which is an environment listen-permission failure rather than a protocol failure.

## Scope

This report tracks manual evidence for the `rewrite/godot` Java parity check across VOS, OJN/OJM, and osu!mania 7K recorded screenshot packages. It complements `rewrite/tools/verify_vos_godot_java_parity.sh`; it does not replace visual comparison against the Java runtime.

## Evidence

```text
Date: 2026-07-02
Branch: refact
Commit: e49daca (dirty worktree)
Godot version: 4.6.3.stable.official.7d41c59c4
Java version: OpenJDK 17.0.19 Zulu17.66+19-CA
VOS chart path: /Users/honghao.shan/Music/demo/Age of empire.vos
OJN/OJM chart path: /Users/honghao.shan/Music/demo/o2ma101.ojn
osu!mania 7K chart path: /Users/honghao.shan/Music/demo/1187083 Jay Chou - Nocturne.osz
Display mode: Windowed capture, 800x600 logical Java reference state
Java reference result:
Godot result:
Godot screenshot: target/godot-captures/godot-gameplay-fixture.png
Java screenshot: target/java-captures/java-gameplay-reference.png
Side by side: target/gameplay-parity-capture/side-by-side.png
Diff: target/gameplay-parity-capture/diff.png
Diff components: target/gameplay-parity-capture/diff-components.json
Summary: target/gameplay-parity-capture/summary.json
Real demo side by side: target/gameplay-parity-capture-real-demo/side-by-side.png
Real demo diff: target/gameplay-parity-capture-real-demo/diff.png
Real demo diff components: target/gameplay-parity-capture-real-demo/diff-components.json
Real demo summary: target/gameplay-parity-capture-real-demo/summary.json
Real OJN note-time side by side: target/gameplay-parity-capture-real-ojn-notes/side-by-side.png
Real OJN note-time diff: target/gameplay-parity-capture-real-ojn-notes/diff.png
Real OJN note-time diff components: target/gameplay-parity-capture-real-ojn-notes/diff-components.json
Real OJN note-time summary: target/gameplay-parity-capture-real-ojn-notes/summary.json
Real OSU long-note side by side: target/gameplay-parity-capture-real-osu-notes/side-by-side.png
Real OSU long-note diff: target/gameplay-parity-capture-real-osu-notes/diff.png
Real OSU long-note diff components: target/gameplay-parity-capture-real-osu-notes/diff-components.json
Real OSU long-note summary: target/gameplay-parity-capture-real-osu-notes/summary.json
Partytime real localhost loopback log: target/godot-logs/partytime-loopback-manual-escalated.log
Recorded summary refresh log: target/capture-recorded-gameplay-parity-require-all.log
Observed differences: Java HiDPI framebuffer downscale is mirrored by the Godot Java-reference capture path, and the pair capture now uses `JAVA_DELAY_MS=0` with fixed frame capture to avoid wall-clock animation phase drift. The Java capture-only path now completes without the previous macOS `Trace/BPT trap: 5` caused by disposing `AWTGLCanvas` after the PNG had already been written. The same-chart comparison runs the screenshot compare CLI with `-Djava.awt.headless=true` so pure image comparison does not trigger macOS AWT application registration. Godot image loading now clears fully transparent RGB bytes like Java `TextureLoader.convertImageData`, Java premultiplied blend mode is applied globally to textured sprites to match Java `GL_ONE / GL_ONE_MINUS_SRC_ALPHA`, and the Java-reference Godot `SubViewport` disables Control pixel snapping so fractional Java/OpenGL positions such as the measure marker are preserved. The comparison CLI now records both raw pixel deltas and explicit `pixelTolerance` significant deltas, so renderer rounding noise can be separated from structural mismatches without hiding the raw evidence. The current same-chart pair has the lowest mean absolute delta so far; `MEASURE_MARK`, `JUDGMENT_LINE`, life bar, bottom HUD timebar, static keyboard, timer digits, and status text are now low or zero residual regions. The status text node tree matches the Java `TrueTypeFont` draw loop through atlas glyph containers, including bounds, glyph order, texture regions, filtering, and premultiplied blend mode.
Known remaining differences: The largest remaining VOS/OJN measurable difference is a one-pixel bottom HUD timer/timebar edge near the minute/second display, recorded in `diff-components.json` as `x=385,y=569,width=23,height=1,pixels=23`. The latest same-chart and OJN note-time runs report `differingPixels=227`, `meanAbsDelta=0.0021458333333333334`, and `maxChannelDelta=24`. The real OSU long-note run reports larger low-amplitude long-note edge residuals in raw mode, but with `pixelTolerance=4` the remaining structural component is bounded to `largestComponentPixels=21`; normal-scale side-by-side review shows no missing note, wrong lane, status text, measure, or HUD structural mismatch. Manual crop review found no visible gameplay layout, note, lane, BGA, status text, measure mark, judgment line, timer, or timebar mismatch at normal or crop scale.
Decision: Accepted with bounded residual visual difference.
```

## Current Same-Chart Pair Capture

```bash
rewrite/tools/capture_gameplay_parity_pair.sh /path/to/chart.vos
```

The pair capture command exports the selected chart for Godot, captures Java and Godot gameplay screenshots at the same fixed `gameTime`, then writes side-by-side, diff, diff-components, and summary artifacts under `target/gameplay-parity-capture`. If Java returns an undersized blank framebuffer PNG during AppKit/OpenGL startup, the script retries later capture frames while keeping the fixed `gameTime`.

## Current Java Capture

```bash
rewrite/tools/capture_java_gameplay_screenshot.sh /path/to/chart.vos
```

The Java capture command uses the real Java `Render` and `LWJGLGameWindow` framebuffer with capture-only no-op audio. It is the reference side for the manual visual comparison and must be run against the same chart used for Godot runtime acceptance.

## Current Godot Capture

```bash
rewrite/tools/capture_godot_gameplay_screenshot.sh
```

The current Godot capture command produced an 800x600 PNG using the normal Godot renderer. Use that image as the Godot side of the visual comparison package.

## Residual Review

- The previous largest `MEASURE_MARK` strip residual was traced to Godot `Control` pixel snapping inside the Java-reference `SubViewport`. Disabling `gui_snap_controls_to_pixels` for the project and for the Java-reference capture viewport reduced the same-chart comparison from `differingPixels=997`, `meanAbsDelta=0.03891111111111111`, `maxChannelDelta=66` to `differingPixels=227`, `meanAbsDelta=0.0021458333333333334`, `maxChannelDelta=24`.
- A 1600x1200 Godot physical framebuffer debug capture confirmed that the current 2x2 downsample path is already the best tested match for Java's HiDPI capture downscale. Alternative offset averages, single-pixel picks, and an extra `[1,6,1]` blur all increased the diff.
- A temporary global `TEXTURE_FILTER_NEAREST` experiment increased the diff to `differingPixels=318507`, so Java parity still requires linear filtering for the skin textures.
- A temporary `AtlasTexture.filter_clip=true` experiment increased the diff to `differingPixels=1340`, so the default unclipped atlas filtering remains closer to Java's raw OpenGL texture coordinate behavior.
- `rewrite/tools/capture_gameplay_parity_pair.sh` now runs `rewrite/tools/verify_gameplay_parity_summary.sh` after generating `summary.json` and `diff-components.json`, so regressions above `differingPixels=300`, `meanAbsDelta=0.003`, `maxChannelDelta=24`, `componentCount=30`, `largestComponentPixels=25`, or `largestComponentShortSide=3` fail the capture instead of only appearing in the report. For non-VOS renderer rounding cases, the pair capture can explicitly set `OPEN2JAM_PARITY_COMPARE_PIXEL_TOLERANCE`, which keeps raw diff fields in `summary.json` while verifying `significantDifferingPixels` and `significantMeanAbsDelta`.
- The remaining largest component is a low-amplitude one-pixel edge in the bottom HUD timebar/timer area. Visual inspection of `side-by-side.png` and the timebar crops shows no obvious gameplay layout, note, lane, BGA, status text, measure mark, judgment line, timer, or timebar mismatch at normal or crop scale.

## Accepted Checks

- BGA, lane frame, note, measure mark, judgment line, score, combo, life bar, jam bar, time bar, status text, and result flow have current automated oracle coverage or same-chart screenshot evidence.
- The remaining bottom HUD one-pixel edge residual is accepted as bounded renderer sampling residual for the current VOS Java-reference artifacts.
- Reopen this decision if a future same-chart package exceeds the verifier thresholds or shows a visible structural mismatch in `side-by-side.png`.

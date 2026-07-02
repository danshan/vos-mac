package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;
import org.open2jam.Config;
import org.open2jam.GameOptions;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.sound.Sound;
import org.open2jam.sound.SoundSystem;
import org.open2jam.sound.SoundSystemException;

import sun.misc.Unsafe;

class RenderMiscVolumeOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/misc-volume-oracle.json");

    @Test
    void miscVolumeOracleFixtureMatchesJavaRenderCheckMiscKeyboard() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateMiscVolumeOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot misc volume oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(scenario("master_volume_held_key", 1.0f, 1.0f, 1.0f,
                Step.press("main_volume_down"),
                Step.press("main_volume_down"),
                Step.release("main_volume_down"),
                Step.press("main_volume_down")));
        scenarios.add(scenario("volume_channel_clamps", 1.0f, 0.02f, 0.98f,
                Step.press("main_volume_up"),
                Step.press("key_volume_down"),
                Step.release("key_volume_down"),
                Step.press("bgm_volume_up"),
                Step.release("bgm_volume_up"),
                Step.press("bgm_volume_down")));
        scenarios.add(scenario("initial_volume_clamps", 1.2f, -0.1f, 0.5f,
                Step.press("main_volume_down"),
                Step.press("key_volume_up"),
                Step.press("bgm_volume_down")));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.check_misc_keyboard volume hotkeys"),
                field("volumeStep", 0.05f),
                rawField("scenarios", array(scenarios)));
    }

    private static String scenario(String name, float masterVolume, float keyVolume, float bgmVolume, Step... steps)
            throws Exception {
        RenderHarness harness = new RenderHarness(masterVolume, keyVolume, bgmVolume);
        List<String> snapshots = new ArrayList<String>();
        snapshots.add(harness.snapshot("initial", Step.none(), false));
        for (Step step : steps) {
            snapshots.add(harness.apply(step));
        }
        return object(
                field("name", name),
                field("initialMasterVolume", masterVolume),
                field("initialKeyVolume", keyVolume),
                field("initialBgmVolume", bgmVolume),
                rawField("steps", array(snapshots)));
    }

    private static final class RenderHarness {
        private final Render render;
        private final GameOptions options;
        private final FakeGameWindow window;
        private final RecordingSoundSystem soundSystem;
        private final EnumMap<Config.MiscEvent, Integer> keyboardMisc;

        RenderHarness(float masterVolume, float keyVolume, float bgmVolume) throws Exception {
            render = newRenderWithoutConstructor();
            options = new GameOptions();
            options.setMasterVolume(masterVolume);
            options.setKeyVolume(keyVolume);
            options.setBGMVolume(bgmVolume);
            window = new FakeGameWindow();
            soundSystem = new RecordingSoundSystem();
            keyboardMisc = keyboardMisc();

            setField(render, "opt", options);
            setField(render, "window", window);
            setField(render, "soundSystem", soundSystem);
            setField(render, "keyboard_misc", keyboardMisc);
            setField(render, "misc_keys", new LinkedList<Integer>());
        }

        String apply(Step step) {
            int beforeCalls = soundSystem.totalVolumeSetCalls();
            Integer keyCode = keyboardMisc.get(miscEvent(step.action));
            if (keyCode == null) {
                throw new IllegalArgumentException("Unknown action: " + step.action);
            }
            if ("press".equals(step.event)) {
                window.press(keyCode.intValue());
            } else if ("release".equals(step.event)) {
                window.release(keyCode.intValue());
            }
            render.check_misc_keyboard();
            return snapshot(step.label, step, soundSystem.totalVolumeSetCalls() > beforeCalls);
        }

        String snapshot(String label, Step step, boolean applied) {
            return object(
                    field("label", label),
                    field("event", step.event),
                    field("action", step.action),
                    field("applied", applied),
                    field("masterVolume", options.getMasterVolume()),
                    field("keyVolume", options.getKeyVolume()),
                    field("bgmVolume", options.getBGMVolume()),
                    field("masterSetCalls", soundSystem.masterSetCalls),
                    field("keySetCalls", soundSystem.keySetCalls),
                    field("bgmSetCalls", soundSystem.bgmSetCalls));
        }
    }

    private static EnumMap<Config.MiscEvent, Integer> keyboardMisc() {
        EnumMap<Config.MiscEvent, Integer> map = new EnumMap<Config.MiscEvent, Integer>(Config.MiscEvent.class);
        map.put(Config.MiscEvent.MAIN_VOL_UP, 101);
        map.put(Config.MiscEvent.MAIN_VOL_DOWN, 102);
        map.put(Config.MiscEvent.KEY_VOL_UP, 103);
        map.put(Config.MiscEvent.KEY_VOL_DOWN, 104);
        map.put(Config.MiscEvent.BGM_VOL_UP, 105);
        map.put(Config.MiscEvent.BGM_VOL_DOWN, 106);
        return map;
    }

    private static Config.MiscEvent miscEvent(String action) {
        if ("main_volume_up".equals(action)) {
            return Config.MiscEvent.MAIN_VOL_UP;
        }
        if ("main_volume_down".equals(action)) {
            return Config.MiscEvent.MAIN_VOL_DOWN;
        }
        if ("key_volume_up".equals(action)) {
            return Config.MiscEvent.KEY_VOL_UP;
        }
        if ("key_volume_down".equals(action)) {
            return Config.MiscEvent.KEY_VOL_DOWN;
        }
        if ("bgm_volume_up".equals(action)) {
            return Config.MiscEvent.BGM_VOL_UP;
        }
        if ("bgm_volume_down".equals(action)) {
            return Config.MiscEvent.BGM_VOL_DOWN;
        }
        throw new IllegalArgumentException("Unknown action: " + action);
    }

    private static Render newRenderWithoutConstructor() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        return (Render) unsafe.allocateInstance(Render.class);
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static String object(String... fields) {
        StringBuilder out = new StringBuilder();
        out.append('{');
        for (int i = 0; i < fields.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(fields[i]);
        }
        out.append('}');
        return out.toString();
    }

    private static String array(List<String> values) {
        return array(values.toArray(new String[0]));
    }

    private static String array(String... values) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(values[i]);
        }
        out.append(']');
        return out.toString();
    }

    private static String field(String name, String value) {
        return quote(name) + ":" + quote(value);
    }

    private static String field(String name, int value) {
        return quote(name) + ":" + value;
    }

    private static String field(String name, boolean value) {
        return quote(name) + ":" + Boolean.toString(value);
    }

    private static String field(String name, float value) {
        return quote(name) + ":" + Float.toString(value);
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static final class Step {
        final String event;
        final String action;
        final String label;

        private Step(String event, String action) {
            this.event = event;
            this.action = action;
            this.label = event + "_" + action;
        }

        static Step none() {
            return new Step("none", "none");
        }

        static Step press(String action) {
            return new Step("press", action);
        }

        static Step release(String action) {
            return new Step("release", action);
        }
    }

    private static final class FakeGameWindow implements GameWindow {
        private final Set<Integer> pressedKeys = new HashSet<Integer>();

        void press(int keyCode) {
            pressedKeys.add(Integer.valueOf(keyCode));
        }

        void release(int keyCode) {
            pressedKeys.remove(Integer.valueOf(keyCode));
        }

        public void setTitle(String title) {
        }

        public void setDisplay(DisplayMode dm, boolean vsync, boolean fs) {
        }

        public int getResolutionHeight() {
            return 600;
        }

        public int getResolutionWidth() {
            return 800;
        }

        public void startRendering() {
        }

        public void initScales(double width, double height) {
        }

        public void setGameWindowCallback(GameWindowCallback callback) {
        }

        public boolean isKeyDown(int keyCode) {
            return pressedKeys.contains(Integer.valueOf(keyCode));
        }

        public void destroy() {
        }

        public void update() {
        }

        public void pollInput() {
        }
    }

    private static final class RecordingSoundSystem implements SoundSystem {
        int masterSetCalls;
        int keySetCalls;
        int bgmSetCalls;

        public Sound load(SampleData sample) throws SoundSystemException {
            return null;
        }

        public void release() {
        }

        public void update() {
        }

        public void setBGMVolume(float factor) {
            bgmSetCalls++;
        }

        public void setKeyVolume(float factor) {
            keySetCalls++;
        }

        public void setMasterVolume(float factor) {
            masterSetCalls++;
        }

        public void setSpeed(float factor) {
        }

        int totalVolumeSetCalls() {
            return masterSetCalls + keySetCalls + bgmSetCalls;
        }
    }
}

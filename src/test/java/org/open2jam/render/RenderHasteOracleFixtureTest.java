package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.render.entities.BarEntity;
import org.open2jam.render.lwjgl.Texture;
import org.open2jam.sound.Sound;
import org.open2jam.sound.SoundSystem;
import org.open2jam.sound.SoundSystemException;

import sun.misc.Unsafe;

class RenderHasteOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/haste-mode-oracle.json");
    private static final double BPM = 120.0;
    private static final double MEASURE_SIZE = 385.0;
    private static final double JUDGMENT_LINE = 480.0;
    private static final double NOTE_HEIGHT = 7.0;
    private static final double NOTE_TIME_MS = 9200.0;
    private static final int FULL_LIFE = 24000;

    @Test
    void hasteOracleFixtureMatchesJavaRenderUpdateGameSpeed() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateHasteOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot haste mode oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        RenderHarness harness = new RenderHarness(true, FULL_LIFE);
        List<String> steps = new ArrayList<String>();
        steps.add(harness.snapshot("initial", 0.0, 0, 0.0));
        harness.update("measure_threshold_increase", 6000.0, 7, 6000.0);
        steps.add(harness.snapshot("after_measure_threshold_increase", 6000.0, 7, 6000.0));
        harness.update("pitch_visible_next_frame", 6001.0, 7, 1.0);
        steps.add(harness.snapshot("after_pitch_visible_next_frame", 6001.0, 7, 1.0));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.updateGameSpeed haste mode"),
                field("bpm", BPM),
                field("measureSize", MEASURE_SIZE),
                field("judgmentLine", JUDGMENT_LINE),
                field("noteHeight", NOTE_HEIGHT),
                field("noteTimeMs", NOTE_TIME_MS),
                field("hasteMode", true),
                field("hasteModeNormalizeSpeed", true),
                rawField("steps", array(steps)));
    }

    private static final class RenderHarness {
        private final Render render;
        private final RecordingSoundSystem soundSystem;
        private final BarEntity life;

        RenderHarness(boolean normalizeSpeed, int lifeValue) throws Exception {
            render = newRenderWithoutConstructor();
            soundSystem = new RecordingSoundSystem();
            life = new BarEntity(spriteList(12.0, 12.0), 0.0, 0.0);
            life.setLimit(FULL_LIFE);
            life.setNumber(lifeValue);

            setField(render, "soundSystem", soundSystem);
            setField(render, "lifebar_entity", life);
            setField(render, "haste", true);
            setField(render, "normalizeSpeed", normalizeSpeed);
            setField(render, "gameSpeed", 1.0);
            setField(render, "speedFactor", 1.0);
            setField(render, "effectiveSpeed", 1.0);
            setField(render, "effectiveJudgmentFactor", 1.0);
            setField(render, "pitchShift", 0);
        }

        void update(String name, double gameTimeMs, int gameMeasure, double deltaMs) throws Exception {
            setField(render, "gameTime", gameTimeMs);
            setField(render, "gameMeasure", gameMeasure);
            render.updateGameSpeed(deltaMs);
        }

        String snapshot(String name, double nowMs, int gameMeasure, double deltaMs) throws Exception {
            double gameSpeed = (Double) getField(render, "gameSpeed");
            double speedFactor = (Double) getField(render, "speedFactor");
            double effectiveSpeed = (Double) getField(render, "effectiveSpeed");
            double effectiveJudgmentFactor = (Double) getField(render, "effectiveJudgmentFactor");
            int pitchShift = (Integer) getField(render, "pitchShift");
            return object(
                    field("name", name),
                    field("nowMs", nowMs),
                    field("gameMeasure", gameMeasure),
                    field("deltaMs", deltaMs),
                    field("gameSpeed", gameSpeed),
                    field("pitchShift", pitchShift),
                    field("audioPitchScale", effectiveSpeed),
                    field("effectiveJudgmentFactor", effectiveJudgmentFactor),
                    field("distanceSpeedFactor", speedFactor),
                    field("noteY", noteY(nowMs, speedFactor)),
                    field("soundSpeedUpdateCount", soundSystem.speedUpdates.size()),
                    field("lastSoundSpeed", soundSystem.lastSpeed()));
        }
    }

    private static double noteY(double nowMs, double speedFactor) {
        double beatDistance = (NOTE_TIME_MS - nowMs) * BPM / 60000.0;
        double distance = speedFactor * beatDistance * MEASURE_SIZE / 4.0;
        return JUDGMENT_LINE - distance - NOTE_HEIGHT;
    }

    private static Render newRenderWithoutConstructor() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        return (Render) unsafe.allocateInstance(Render.class);
    }

    private static SpriteList spriteList(double width, double height) {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite(width, height));
        return list;
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static Object getField(Object target, String fieldName) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        return field.get(target);
    }

    private static final class RecordingSoundSystem implements SoundSystem {
        private final List<Float> speedUpdates = new ArrayList<Float>();

        @Override
        public Sound load(SampleData sample) throws SoundSystemException {
            return null;
        }

        @Override
        public void release() {
        }

        @Override
        public void update() {
        }

        @Override
        public void setBGMVolume(float factor) {
        }

        @Override
        public void setKeyVolume(float factor) {
        }

        @Override
        public void setMasterVolume(float factor) {
        }

        @Override
        public void setSpeed(float factor) {
            speedUpdates.add(Float.valueOf(factor));
        }

        double lastSpeed() {
            if (speedUpdates.isEmpty()) {
                return 1.0;
            }
            return speedUpdates.get(speedUpdates.size() - 1).doubleValue();
        }
    }

    private static final class FakeSprite implements Sprite {
        private final double width;
        private final double height;

        FakeSprite(double width, double height) {
            this.width = width;
            this.height = height;
        }

        @Override
        public double getWidth() {
            return width;
        }

        @Override
        public double getHeight() {
            return height;
        }

        @Override
        public void setBlendAlpha(boolean enabled) {
        }

        @Override
        public void setScale(float x, float y) {
        }

        @Override
        public void setSlice(float x, float y) {
        }

        @Override
        public float getScaleX() {
            return 1.0f;
        }

        @Override
        public float getScaleY() {
            return 1.0f;
        }

        @Override
        public void setAlpha(float alpha) {
        }

        @Override
        public Texture getTexture() {
            return null;
        }

        @Override
        public void draw(double x, double y) {
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height,
                ByteBuffer buffer) {
        }
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

    private static String field(String name, boolean value) {
        return quote(name) + ":" + value;
    }

    private static String field(String name, int value) {
        return quote(name) + ":" + value;
    }

    private static String field(String name, double value) {
        return quote(name) + ":" + Double.toString(value);
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

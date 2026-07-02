package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.render.entities.Entity;
import org.open2jam.render.entities.NumberEntity;
import org.open2jam.render.lwjgl.Texture;

import sun.misc.Unsafe;

class RenderFpsTimerOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/fps-timer-oracle.json");

    @Test
    void fpsTimerOracleFixtureMatchesJavaRenderUpdateFpsCounter() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateFpsTimerOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot FPS timer oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        return object(
                field("schemaVersion", 1),
                field("source", "Render.update_fps_counter"),
                rawField("scenarios", array(
                        oneMinuteRolloverScenario(),
                        largeDeltaSingleTickScenario())));
    }

    private static String oneMinuteRolloverScenario() throws Exception {
        RenderHarness harness = new RenderHarness();
        String initial = harness.initialSnapshotJson();
        List<String> frames = new ArrayList<String>();
        for (int i = 0; i < 60; i++) {
            frames.add(harness.frame(1000.0));
        }
        return scenario("one_minute_rollover", initial, frames);
    }

    private static String largeDeltaSingleTickScenario() throws Exception {
        RenderHarness harness = new RenderHarness();
        String initial = harness.initialSnapshotJson();
        List<String> frames = new ArrayList<String>();
        frames.add(harness.frame(999.0));
        frames.add(harness.frame(1.0));
        frames.add(harness.frame(2500.0));
        frames.add(harness.frame(500.0));
        frames.add(harness.frame(0.0));
        return scenario("large_delta_single_tick", initial, frames);
    }

    private static String scenario(String name, String initial, List<String> frames) {
        return object(
                field("name", name),
                rawField("initial", initial),
                rawField("frames", array(frames)));
    }

    private static final class RenderHarness {
        private final Render render;
        private final NumberEntity fpsEntity;
        private final NumberEntity minuteEntity;
        private final NumberEntity secondEntity;
        private final Method updateFpsCounter;

        RenderHarness() throws Exception {
            render = newRenderWithoutConstructor();
            fpsEntity = numberEntity();
            minuteEntity = numberEntity();
            secondEntity = numberEntity();
            secondEntity.showDigits(2);
            render.fps_entity = fpsEntity;
            render.minute_entity = minuteEntity;
            render.second_entity = secondEntity;
            updateFpsCounter = Render.class.getDeclaredMethod("update_fps_counter");
            updateFpsCounter.setAccessible(true);
        }

        String initialSnapshotJson() {
            return snapshotJson(0.0);
        }

        String frame(double deltaMs) throws Exception {
            render.lastFpsTime += deltaMs;
            render.fps++;
            updateFpsCounter.invoke(render);
            return snapshotJson(deltaMs);
        }

        private String snapshotJson(double deltaMs) {
            return object(
                    field("deltaMs", deltaMs),
                    field("lastFpsTimeMs", render.lastFpsTime),
                    field("pendingFrameCount", render.fps),
                    field("displayFps", fpsEntity.getNumber()),
                    field("minute", minuteEntity.getNumber()),
                    field("second", secondEntity.getNumber()));
        }
    }

    private static Render newRenderWithoutConstructor() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        return (Render) unsafe.allocateInstance(Render.class);
    }

    private static NumberEntity numberEntity() {
        return new NumberEntity(digitEntities(), 0.0, 0.0);
    }

    private static List<Entity> digitEntities() {
        List<Entity> digits = new ArrayList<Entity>();
        for (int i = 0; i < 10; i++) {
            digits.add(entity());
        }
        return digits;
    }

    private static Entity entity() {
        return new Entity(spriteList(8.0, 8.0), 0.0, 0.0);
    }

    private static SpriteList spriteList(double width, double height) {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite(width, height));
        return list;
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

    private static String field(String name, double value) {
        return quote(name) + ":" + Double.toString(value);
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }

    private static final class FakeSprite implements Sprite {
        private final double width;
        private final double height;

        private FakeSprite(double width, double height) {
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
}

package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.render.entities.BgaEntity;
import org.open2jam.render.entities.TimeEntity;
import org.open2jam.render.lwjgl.Texture;

class RenderBgaEventOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/bga-event-oracle.json");
    private static final double AUDIO_LATENCY_MS = 100.0;
    private static final double EVENT_TIME_MS = 1000.0;

    @Test
    void bgaEventOracleFixtureMatchesJavaRenderTimeEntityLoop() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateBgaEventOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot BGA event oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(autosoundLatencyScenario());
        scenarios.add(noAutosoundScenario());
        scenarios.add(queuedSameFrameScenario());

        return object(
                field("schemaVersion", 1),
                field("source", "Render TimeEntity loop for BgaEntity"),
                field("audioLatencyMs", AUDIO_LATENCY_MS),
                field("eventTimeMs", EVENT_TIME_MS),
                rawField("scenarios", array(scenarios)));
    }

    private static String autosoundLatencyScenario() {
        RenderLoopHarness harness = new RenderLoopHarness();
        harness.queueBga("first", EVENT_TIME_MS);

        return scenario("autosound_latency", true, frames(
                harness.frame(1000.0, true, AUDIO_LATENCY_MS),
                harness.frame(1099.0, true, AUDIO_LATENCY_MS),
                harness.frame(1100.0, true, AUDIO_LATENCY_MS)));
    }

    private static String noAutosoundScenario() {
        RenderLoopHarness harness = new RenderLoopHarness();
        harness.queueBga("first", EVENT_TIME_MS);

        return scenario("no_autosound_latency", false, frames(
                harness.frame(999.0, false, AUDIO_LATENCY_MS),
                harness.frame(1000.0, false, AUDIO_LATENCY_MS)));
    }

    private static String queuedSameFrameScenario() {
        RenderLoopHarness harness = new RenderLoopHarness();
        harness.queueBga("first", EVENT_TIME_MS);
        harness.queueBga("second", EVENT_TIME_MS);

        return scenario("queued_same_frame", true, frames(
                harness.frame(1100.0, true, AUDIO_LATENCY_MS),
                harness.frame(1100.0, true, AUDIO_LATENCY_MS),
                harness.frame(1101.0, true, AUDIO_LATENCY_MS)));
    }

    private static String scenario(String name, boolean autosound, String frames) {
        return object(
                field("name", name),
                field("autosound", autosound),
                rawField("frames", frames));
    }

    private static String frames(String... frames) {
        List<String> values = new ArrayList<String>();
        for (String frame : frames) {
            values.add(frame);
        }
        return array(values);
    }

    private static final class RenderLoopHarness {
        private final RecordingSprite base = new RecordingSprite("base", 320.0, 240.0);
        private final BgaEntity bga = new BgaEntity(base, 0.0, 0.0);

        void queueBga(String spriteName, double eventTimeMs) {
            RecordingSprite sprite = new RecordingSprite(spriteName, 320.0, 240.0);
            bga.setSprite(sprite);
            bga.setTime(eventTimeMs);
        }

        String frame(double gameTimeMs, boolean autosound, double audioLatencyMs) {
            TimeEntity timeEntity = bga;
            double now = gameTimeMs;
            if (autosound) {
                now -= audioLatencyMs;
            }
            double timeToJudge = now;
            double nextTimeBefore = timeEntity.getTime();
            boolean judged = nextTimeBefore - timeToJudge <= 0.0;
            if (judged) {
                timeEntity.judgment();
            }
            bga.draw();
            return object(
                    field("gameTimeMs", gameTimeMs),
                    field("timeToJudgeMs", timeToJudge),
                    field("nextTimeBeforeMs", nextTimeBefore),
                    field("judged", judged),
                    field("currentSprite", currentSpriteName()),
                    field("nextTimeAfterMs", timeEntity.getTime()));
        }

        private String currentSpriteName() {
            RecordingSprite latest = RecordingSprite.latestDrawn;
            return latest == null ? "" : latest.name;
        }
    }

    private static final class RecordingSprite implements Sprite {
        private static RecordingSprite latestDrawn;

        private final String name;
        private final double width;
        private final double height;
        private float scaleX = 1.0f;
        private float scaleY = 1.0f;

        private RecordingSprite(String name, double width, double height) {
            this.name = name;
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
            scaleX = x;
            scaleY = y;
        }

        @Override
        public void setSlice(float x, float y) {
        }

        @Override
        public float getScaleX() {
            return scaleX;
        }

        @Override
        public float getScaleY() {
            return scaleY;
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
            latestDrawn = this;
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
            latestDrawn = this;
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height,
                ByteBuffer buffer) {
            draw(x, y, scaleX, scaleY);
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

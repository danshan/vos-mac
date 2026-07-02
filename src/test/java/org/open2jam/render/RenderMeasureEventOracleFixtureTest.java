package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;
import org.open2jam.render.entities.MeasureEntity;
import org.open2jam.render.entities.SoundEntity;
import org.open2jam.render.entities.TimeEntity;
import org.open2jam.render.lwjgl.Texture;

class RenderMeasureEventOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/measure-event-oracle.json");
    private static final double AUDIO_LATENCY_MS = 100.0;
    private static final double EVENT_TIME_MS = 1000.0;

    @Test
    void measureEventOracleFixtureMatchesJavaRenderTimeEntityLoop() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateMeasureEventOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot measure event oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(scenario("autosound_latency", true));
        scenarios.add(scenario("no_autosound_latency", false));

        return object(
                field("schemaVersion", 1),
                field("source", "Render TimeEntity loop for MeasureEntity"),
                field("audioLatencyMs", AUDIO_LATENCY_MS),
                field("eventTimeMs", EVENT_TIME_MS),
                rawField("scenarios", array(scenarios)));
    }

    private static String scenario(String name, boolean autosound) {
        RenderLoopHarness harness = new RenderLoopHarness();
        return object(
                field("name", name),
                field("autosound", autosound),
                rawField("frames", array(
                        harness.frame(999.0, autosound, AUDIO_LATENCY_MS),
                        harness.frame(1000.0, autosound, AUDIO_LATENCY_MS))));
    }

    private static final class RenderLoopHarness {
        private final AtomicInteger currentMeasure = new AtomicInteger(0);
        private final MeasureEntity measure = new MeasureEntity(spriteList(), 0.0, 0.0);

        private RenderLoopHarness() {
            measure.setTime(EVENT_TIME_MS);
            measure.setOnJudge(currentMeasure::incrementAndGet);
        }

        private String frame(double gameTimeMs, boolean autosound, double audioLatencyMs) {
            TimeEntity timeEntity = measure;
            double now = gameTimeMs;
            if (autosound) {
                now -= audioLatencyMs;
            }

            double timeToJudge = now;
            if (measure instanceof SoundEntity && autosound) {
                timeToJudge += audioLatencyMs;
            }

            double nextTimeBefore = timeEntity.getTime();
            boolean judged = !measure.isDead() && nextTimeBefore - timeToJudge <= 0.0;
            if (judged) {
                timeEntity.judgment();
            }

            return object(
                    field("gameTimeMs", gameTimeMs),
                    field("timeToJudgeMs", timeToJudge),
                    field("nextTimeBeforeMs", nextTimeBefore),
                    field("judged", judged),
                    field("currentMeasure", currentMeasure.get()),
                    field("dead", measure.isDead()));
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

    private static String field(String name, int value) {
        return quote(name) + ":" + value;
    }

    private static String field(String name, double value) {
        return quote(name) + ":" + Double.toString(value);
    }

    private static String field(String name, boolean value) {
        return quote(name) + ":" + value;
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String text) {
        String escaped = text.replace("\\", "\\\\").replace("\"", "\\\"");
        return "\"" + escaped + "\"";
    }

    private static SpriteList spriteList() {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite());
        return list;
    }

    private static final class FakeSprite implements Sprite {
        @Override
        public double getWidth() {
            return 0.0;
        }

        @Override
        public double getHeight() {
            return 0.0;
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

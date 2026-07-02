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
import org.open2jam.game.judgment.JudgmentResult;
import org.open2jam.game.judgment.TimeJudgment;
import org.open2jam.parsers.BMSChart;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.VOSChart;
import org.open2jam.render.lwjgl.Texture;
import org.open2jam.render.entities.NoteEntity;

class RenderRejectedKeysoundOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/rejected-keysound-oracle.json");
    private static final double NOTE_TIME_MS = 1000.0;
    private static final int SAMPLE_ID = 7;

    @Test
    void rejectedKeysoundOracleFixtureMatchesJavaRenderBranchBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateRejectedKeysoundOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot rejected keysound oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> cases = new ArrayList<String>();
        cases.add(caseJson("vos_accepted_bad_boundary", new VOSChart(), "VOS", 173.0));
        cases.add(caseJson("vos_rejected_first_live_trigger", new VOSChart(), "VOS", 174.0));
        cases.add(caseJson("vos_rejected_live_trigger_boundary", new VOSChart(), "VOS", 280.0));
        cases.add(caseJson("vos_rejected_outside_live_trigger", new VOSChart(), "VOS", 281.0));
        cases.add(caseJson("non_vos_rejected_legacy_replay", new BMSChart(), "OSU", 500.0));

        return object(
                field("schemaVersion", 1),
                field("source", "TimeJudgment.accept with Render.shouldTriggerRejectedKeysound"),
                field("judgmentType", "time"),
                field("noteTimeMs", NOTE_TIME_MS),
                field("sampleId", SAMPLE_ID),
                rawField("cases", array(cases)));
    }

    private static String caseJson(String name, Chart chart, String format, double hitTimeMs) {
        TimeJudgment judgment = new TimeJudgment();
        NoteEntity note = new NoteEntity(spriteList(8.0, 8.0), Event.Channel.NOTE_1, 0.0, 0.0);
        note.setTime(NOTE_TIME_MS);
        note.setHitTime(hitTimeMs);

        boolean accepted = judgment.accept(note);
        String result = accepted ? resultName(judgment.judge(note)) : "";
        boolean rejectedKeysound = !accepted && Render.shouldTriggerRejectedKeysound(chart, note.getHitTime());

        return object(
                field("name", name),
                field("format", format),
                field("hitTimeMs", hitTimeMs),
                field("pressMs", NOTE_TIME_MS - hitTimeMs),
                field("accepted", accepted),
                field("result", result),
                field("rejectedKeysound", rejectedKeysound));
    }

    private static String resultName(JudgmentResult result) {
        return result.name().toLowerCase();
    }

    private static SpriteList spriteList(double width, double height) {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite(width, height));
        return list;
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

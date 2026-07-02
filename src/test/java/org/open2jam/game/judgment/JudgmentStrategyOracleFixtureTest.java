package org.open2jam.game.judgment;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.game.TimingData;
import org.open2jam.parsers.Event;
import org.open2jam.render.Sprite;
import org.open2jam.render.SpriteList;
import org.open2jam.render.entities.NoteEntity;
import org.open2jam.render.lwjgl.Texture;

class JudgmentStrategyOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/judgment-strategy-oracle.json");
    private static final double BPM = 120.0;
    private static final double BEAT_JUDGMENT_FACTOR = 0.664;
    private static final double NOTE_TIME_MS = 2000.0;

    @Test
    void judgmentStrategyOracleFixtureMatchesJavaJudgmentBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateJudgmentStrategyOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot judgment strategy oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        TimingData timing = timingData();
        TimeJudgment timeJudgment = new TimeJudgment();
        timeJudgment.setTiming(timing);
        BeatJudgment beatJudgment = new BeatJudgment();
        beatJudgment.setTiming(timing);

        return object(
                field("schemaVersion", 1),
                field("source", "TimeJudgment and BeatJudgment"),
                field("bpm", BPM),
                field("noteTimeMs", NOTE_TIME_MS),
                field("beatJudgmentFactor", BEAT_JUDGMENT_FACTOR),
                rawField("timeCases", array(timeCases(timeJudgment))),
                rawField("beatCases", array(beatCases(beatJudgment, timing))));
    }

    private static List<String> timeCases(TimeJudgment judgment) {
        double[] hitTimes = {-174.0, -173.0, -126.0, -125.0, -42.0, -41.0, 0.0, 41.0, 42.0, 125.0,
                126.0, 173.0, 174.0};
        List<String> cases = new ArrayList<String>();
        for (double hitTime : hitTimes) {
            NoteEntity note = note(hitTime);
            cases.add(object(
                    field("hitTimeMs", hitTime),
                    field("accepted", judgment.accept(note)),
                    field("missed", judgment.missed(note)),
                    field("result", resultName(judgment.judge(note)))));
        }
        return cases;
    }

    private static List<String> beatCases(BeatJudgment judgment, TimingData timing) {
        double[] hitDeltas = {-0.81, -0.8, -0.51, -0.5, -0.21, -0.2, 0.0, 0.2, 0.21, 0.5, 0.51, 0.8,
                0.81};
        List<String> cases = new ArrayList<String>();
        for (double requestedHitDelta : hitDeltas) {
            double hitTimeMs = requestedHitDelta * BEAT_JUDGMENT_FACTOR * 60000.0 / BPM;
            NoteEntity note = note(hitTimeMs);
            double calculatedHitDelta = (timing.getBeat(note.getTimeToJudge())
                    - timing.getBeat(note.getTimeToJudge() - note.getHitTime())) / BEAT_JUDGMENT_FACTOR;
            cases.add(object(
                    field("requestedHitDelta", requestedHitDelta),
                    field("hitTimeMs", hitTimeMs),
                    field("hitDelta", calculatedHitDelta),
                    field("accepted", judgment.accept(note)),
                    field("missed", judgment.missed(note)),
                    field("result", resultName(judgment.judge(note)))));
        }
        return cases;
    }

    private static TimingData timingData() {
        TimingData timing = new TimingData();
        timing.add(0.0, BPM);
        timing.finish();
        return timing;
    }

    private static NoteEntity note(double hitTimeMs) {
        SpriteList frames = new SpriteList(0.0);
        frames.add(new StaticSprite());
        NoteEntity note = new NoteEntity(frames, Event.Channel.NOTE_1, 0.0, 0.0);
        note.setTime(NOTE_TIME_MS);
        note.setHitTime(hitTimeMs);
        return note;
    }

    private static String resultName(JudgmentResult result) {
        String raw = result.toString();
        if (raw.startsWith("JUDGMENT_")) {
            return raw.substring("JUDGMENT_".length());
        }
        return raw;
    }

    private static final class StaticSprite implements Sprite {
        @Override
        public double getWidth() {
            return 8.0;
        }

        @Override
        public double getHeight() {
            return 8.0;
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

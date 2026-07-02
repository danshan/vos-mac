package org.open2jam.game.position;

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
import org.open2jam.game.TimingData;
import org.open2jam.game.speed.SpeedMultiplier;
import org.open2jam.parsers.Event;
import org.open2jam.render.Sprite;
import org.open2jam.render.SpriteList;
import org.open2jam.render.entities.NoteEntity;
import org.open2jam.render.lwjgl.Texture;

class NoteDistanceCalculatorOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/note-distance-oracle.json");
    private static final double MEASURE_SIZE = 385.0;
    private static final double[] XR_FACTORS = {0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75};

    @Test
    void noteDistanceOracleFixtureMatchesJavaSpeedModes() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateNoteDistanceOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot note distance oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        List<String> timingChanges = new ArrayList<String>();
        timingChanges.add(object(field("timeMs", 0.0), field("bpm", 120.0)));
        timingChanges.add(object(field("timeMs", 1000.0), field("bpm", 240.0)));

        TimingData timing = timing();
        List<String> beatCases = new ArrayList<String>();
        beatCases.add(beatCase(timing, -500.0));
        beatCases.add(beatCase(timing, 0.0));
        beatCases.add(beatCase(timing, 500.0));
        beatCases.add(beatCase(timing, 1000.0));
        beatCases.add(beatCase(timing, 1500.0));

        List<String> distanceCases = new ArrayList<String>();
        distanceCases.add(hiSpeedCase(timing, "hi_speed_basic", 0.0, 1000.0, 2.0, 1.0));
        distanceCases.add(hiSpeedCase(timing, "hi_speed_across_bpm_change", 500.0, 1500.0, 1.5, 1.0));
        distanceCases.add(regulSpeedCase("regul_speed_fixed_bpm", 0.0, 1000.0, 2.0, 1.0));
        distanceCases.add(hiSpeedCase(timing, "adjust_distance_speed_factor", 0.0, 1000.0, 2.0, 1.25));
        distanceCases.add(wSpeedCase(timing, "w_speed_initial", 2.0));
        distanceCases.add(wSpeedCase(timing, "w_speed_one_second_update", 2.0, 1000.0));
        distanceCases.add(wSpeedCase(timing, "w_speed_exact_cycle_boundary", 2.0, 6000.0));
        distanceCases.add(wSpeedCase(timing, "w_speed_boundary_then_reverse_clamp", 2.0, 6000.0, 1000.0));
        distanceCases.add(wSpeedTargetCase(timing));
        distanceCases.add(xrSpeedCase(timing, "xr_speed_lane_one", Event.Channel.NOTE_1, 0));
        distanceCases.add(xrSpeedCase(timing, "xr_speed_lane_seven", Event.Channel.NOTE_7, 6));
        distanceCases.add(xrSpeedCase(timing, "xr_speed_unknown_lane", null, -1));

        return object(
                field("schemaVersion", 1),
                field("source", "NoteDistanceCalculator Java speed modes"),
                field("measureSize", MEASURE_SIZE),
                rawField("timingChanges", array(timingChanges)),
                rawField("beatCases", array(beatCases)),
                rawField("distanceCases", array(distanceCases)));
    }

    private static TimingData timing() {
        TimingData timing = new TimingData();
        timing.add(0.0, 120.0);
        timing.add(1000.0, 240.0);
        timing.finish();
        return timing;
    }

    private static String beatCase(TimingData timing, double timeMs) {
        return object(
                field("timeMs", timeMs),
                field("expectedBeat", timing.getBeat(timeMs)));
    }

    private static String hiSpeedCase(TimingData timing, String name, double nowMs, double targetMs,
            double speed, double speedFactor) {
        HiSpeed distance = new HiSpeed(timing, MEASURE_SIZE);
        return distanceCase(name, "HiSpeed", nowMs, targetMs, speed, -1, speedFactor,
                distance.calculate(nowMs, targetMs, speed, null) * speedFactor);
    }

    private static String regulSpeedCase(String name, double nowMs, double targetMs, double speed,
            double speedFactor) {
        RegulSpeed distance = new RegulSpeed(MEASURE_SIZE);
        return distanceCase(name, "RegulSpeed", nowMs, targetMs, speed, -1, speedFactor,
                distance.calculate(nowMs, targetMs, speed, null) * speedFactor);
    }

    private static String wSpeedCase(TimingData timing, String name, double targetSpeed, double... deltasMs) {
        SpeedMultiplier speed = new SpeedMultiplier(targetSpeed);
        WSpeed distance = new WSpeed(new HiSpeed(timing, MEASURE_SIZE), speed);
        List<String> updates = applyUpdates(distance, targetSpeed, deltasMs);
        return wSpeedDistanceCase(name, targetSpeed, updates, distance.calculate(0.0, 1000.0, 99.0, null));
    }

    private static String wSpeedTargetCase(TimingData timing) {
        SpeedMultiplier speed = new SpeedMultiplier(1.0);
        speed.increase();
        speed.increase();
        WSpeed distance = new WSpeed(new HiSpeed(timing, MEASURE_SIZE), speed);
        List<String> updates = applyUpdates(distance, speed.getSpeed(), 3500.0);
        return wSpeedDistanceCase("w_speed_cycle_uses_target_speed", speed.getSpeed(), updates,
                distance.calculate(0.0, 1000.0, 99.0, null));
    }

    private static List<String> applyUpdates(WSpeed distance, double targetSpeed, double... deltasMs) {
        List<String> updates = new ArrayList<String>();
        double nowMs = 0.0;
        for (double deltaMs : deltasMs) {
            distance.update(nowMs, deltaMs);
            nowMs += deltaMs;
            updates.add(object(
                    field("deltaMs", deltaMs),
                    field("targetSpeed", targetSpeed)));
        }
        return updates;
    }

    private static String wSpeedDistanceCase(String name, double targetSpeed, List<String> updates,
            double expectedDistance) {
        return object(
                field("name", name),
                field("mode", "WSpeed"),
                field("nowMs", 0.0),
                field("targetMs", 1000.0),
                field("speed", 99.0),
                field("lane", -1),
                field("speedFactor", 1.0),
                field("targetSpeed", targetSpeed),
                rawField("updates", array(updates)),
                field("expectedDistance", expectedDistance));
    }

    private static String xrSpeedCase(TimingData timing, String name, Event.Channel channel, int lane)
            throws Exception {
        XRSpeed distance = new XRSpeed(new HiSpeed(timing, MEASURE_SIZE));
        Field values = XRSpeed.class.getDeclaredField("values");
        values.setAccessible(true);
        values.set(distance, XR_FACTORS);
        NoteEntity note = channel == null ? null : new NoteEntity(spriteList(), channel, 0.0, 0.0);
        return object(
                field("name", name),
                field("mode", "xRSpeed"),
                field("nowMs", 0.0),
                field("targetMs", 1000.0),
                field("speed", 2.0),
                field("lane", lane),
                field("speedFactor", 1.0),
                rawField("xrFactors", doubleArray(XR_FACTORS)),
                field("expectedDistance", distance.calculate(0.0, 1000.0, 2.0, note)));
    }

    private static String distanceCase(String name, String mode, double nowMs, double targetMs, double speed,
            int lane, double speedFactor, double expectedDistance) {
        return object(
                field("name", name),
                field("mode", mode),
                field("nowMs", nowMs),
                field("targetMs", targetMs),
                field("speed", speed),
                field("lane", lane),
                field("speedFactor", speedFactor),
                rawField("updates", "[]"),
                field("expectedDistance", expectedDistance));
    }

    private static SpriteList spriteList() {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite());
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

    private static String doubleArray(double[] values) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(Double.toString(values[i]));
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
}

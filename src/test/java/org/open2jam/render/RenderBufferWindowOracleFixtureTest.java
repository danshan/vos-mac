package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.game.TimingData;
import org.open2jam.game.position.HiSpeed;
import org.open2jam.game.position.NoteDistanceCalculator;

class RenderBufferWindowOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/buffer-window-oracle.json");
    private static final double VIEWPORT = 480.0;
    private static final double MEASURE_SIZE = 385.0;
    private static final double SPEED = 1.0;
    private static final double BPM = 120.0;
    private static final double[] EVENT_TIMES = {1000.0, 3000.0, 6000.0};
    private static final double[] UPDATE_TIMES = {0.0, 500.0};

    @Test
    void bufferWindowOracleFixtureMatchesJavaRenderUpdateLoop() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateBufferWindowOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot buffer window oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        TimingData timing = new TimingData();
        timing.add(0.0, BPM);
        timing.finish();
        NoteDistanceCalculator distance = new HiSpeed(timing, MEASURE_SIZE);

        List<String> updates = new ArrayList<String>();
        int nextEventIndex = 0;
        double bufferTimerMs = 0.0;
        for (double nowDisplayMs : UPDATE_TIMES) {
            double beforeTimerMs = bufferTimerMs;
            int beforeIndex = nextEventIndex;
            List<Integer> consumedIndices = new ArrayList<Integer>();

            while (nextEventIndex < EVENT_TIMES.length
                    && VIEWPORT - distance.calculate(nowDisplayMs, bufferTimerMs, SPEED, null) > -10.0) {
                consumedIndices.add(nextEventIndex);
                bufferTimerMs = EVENT_TIMES[nextEventIndex];
                nextEventIndex++;
            }

            updates.add(object(
                    field("nowDisplayMs", nowDisplayMs),
                    field("timerBeforeMs", beforeTimerMs),
                    field("timerAfterMs", bufferTimerMs),
                    rawField("consumedIndices", intArray(consumedIndices)),
                    rawField("bufferedIndices", intRange(0, nextEventIndex)),
                    rawField("hiddenIndices", intRange(nextEventIndex, EVENT_TIMES.length)),
                    field("nextEventIndexBefore", beforeIndex),
                    field("nextEventIndexAfter", nextEventIndex)));
        }

        return object(
                field("schemaVersion", 1),
                field("source", "Render.update_note_buffer HiSpeed stateful window"),
                field("viewport", VIEWPORT),
                field("measureSize", MEASURE_SIZE),
                field("speed", SPEED),
                field("bpm", BPM),
                rawField("eventTimesMs", doubleArray(EVENT_TIMES)),
                rawField("updates", array(updates)));
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

    private static String intArray(List<Integer> values) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < values.size(); i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(values.get(i).intValue());
        }
        out.append(']');
        return out.toString();
    }

    private static String intRange(int start, int end) {
        List<Integer> values = new ArrayList<Integer>();
        for (int i = start; i < end; i++) {
            values.add(Integer.valueOf(i));
        }
        return intArray(values);
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
}

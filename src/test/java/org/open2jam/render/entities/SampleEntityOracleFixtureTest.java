package org.open2jam.render.entities;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Event;
import org.open2jam.render.Render;
import org.open2jam.sound.SoundInstance;

import sun.misc.Unsafe;

class SampleEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/sample-entity-oracle.json");
    private static final int SAMPLE_ID = 42;
    private static final double SAMPLE_TIME_MS = 1000.0;

    @Test
    void sampleEntityOracleFixtureMatchesJavaAudioBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateSampleEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot sample entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("autosound_non_note", false, false, "autosound"));
        scenarios.add(snapshot("autosound_note_allowed", true, false, "autosound"));
        scenarios.add(snapshot("autosound_note_disabled", true, true, "autosound"));
        scenarios.add(snapshot("keysound_once", true, false, "keysound", "keysound"));
        scenarios.add(snapshot("extrasound_repeats", true, false, "extrasound", "extrasound"));
        scenarios.add(snapshot("missed_after_keysound", true, false, "keysound", "missed"));
        scenarios.add(snapshot("missed_before_keysound", true, false, "missed"));

        return object(
                field("schemaVersion", 1),
                field("source", "SampleEntity audio state transitions"),
                field("sampleId", SAMPLE_ID),
                field("sampleTimeMs", SAMPLE_TIME_MS),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, boolean note, boolean disableAutoSound, String... actions)
            throws Exception {
        RecordingRender render = newRecordingRender(disableAutoSound);
        SampleEntity entity = new SampleEntity(render, sample(), 0.0);
        entity.setTime(SAMPLE_TIME_MS);
        entity.setNote(note);

        List<String> actionJson = new ArrayList<String>();
        for (String action : actions) {
            if ("autosound".equals(action)) {
                entity.autosound();
            } else if ("keysound".equals(action)) {
                entity.keysound();
            } else if ("extrasound".equals(action)) {
                entity.extrasound();
            } else if ("missed".equals(action)) {
                entity.missed();
            } else if ("judgment".equals(action)) {
                entity.judgment();
            }
            actionJson.add(object(
                    field("action", action),
                    field("playCount", render.playCount),
                    field("stopCount", render.stopCount),
                    field("dead", entity.isDead())));
        }

        return object(
                field("name", name),
                field("note", note),
                field("disableAutoSound", disableAutoSound),
                rawField("actions", array(actionJson)),
                field("finalPlayCount", render.playCount),
                field("finalStopCount", render.stopCount),
                field("dead", entity.isDead()));
    }

    private static Event.SoundSample sample() {
        Event event = new Event(Event.Channel.NOTE_1, 0, 0.0, SAMPLE_ID, Event.Flag.NONE);
        event.setTime(SAMPLE_TIME_MS);
        return event.getSample();
    }

    private static RecordingRender newRecordingRender(boolean disableAutoSound) throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        RecordingRender render = (RecordingRender) unsafe.allocateInstance(RecordingRender.class);
        render.disableAutoSound = disableAutoSound;
        render.playCount = 0;
        render.stopCount = 0;
        return render;
    }

    private static final class RecordingRender extends Render {
        private boolean disableAutoSound;
        private int playCount;
        private int stopCount;

        @SuppressWarnings("unused")
        private RecordingRender() throws Exception {
            super(null, null, null);
        }

        @Override
        public boolean isDisableAutoSound() {
            return disableAutoSound;
        }

        @Override
        public SoundInstance queueSample(Event.SoundSample soundSample) {
            playCount++;
            return new RecordingSoundInstance(this);
        }
    }

    private static final class RecordingSoundInstance implements SoundInstance {
        private final RecordingRender render;

        private RecordingSoundInstance(RecordingRender render) {
            this.render = render;
        }

        @Override
        public void stop() {
            render.stopCount++;
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

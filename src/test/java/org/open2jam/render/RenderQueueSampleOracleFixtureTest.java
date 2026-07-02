package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Event;
import org.open2jam.sound.Sound;
import org.open2jam.sound.SoundChannel;
import org.open2jam.sound.SoundInstance;
import org.open2jam.sound.SoundSystemException;

import sun.misc.Unsafe;

class RenderQueueSampleOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/queue-sample-oracle.json");

    @Test
    void queueSampleOracleFixtureMatchesJavaRenderPlaybackParameters() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateQueueSampleOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot queue sample oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        List<String> cases = new ArrayList<String>();
        cases.add(caseJson("null_sample", 0, 0.0f, 0.0f, false, false, true));
        cases.add(caseJson("missing_sample", 404, 0.75f, 0.25f, false, false, false));
        cases.add(caseJson("key_sample_ignores_volume", 7, 0.25f, -0.5f, false, true, false));
        cases.add(caseJson("bgm_sample_raw_pan", 8, 0.4f, 1.25f, true, true, false));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.queueSample playback parameters"),
                rawField("cases", array(cases)));
    }

    private static String caseJson(String name, int sampleId, float sampleVolume, float pan, boolean bgm,
            boolean registerSound, boolean nullSample) throws Exception {
        Render render = newRenderWithoutConstructor();
        RecordingSound sound = new RecordingSound();
        Map<Integer, Sound> sounds = new HashMap<Integer, Sound>();
        if (registerSound) {
            sounds.put(Integer.valueOf(sampleId), sound);
        }
        setField(render, "sounds", sounds);

        Event.SoundSample sample = null;
        if (!nullSample) {
            Event event = new Event(Event.Channel.NOTE_1, 0, 0.0, sampleId, Event.Flag.NONE, sampleVolume, pan);
            sample = event.getSample();
            if (bgm) {
                sample.toBGM();
            }
        }

        SoundInstance instance = render.queueSample(sample);
        boolean played = instance != null;
        List<String> fields = new ArrayList<String>();
        fields.add(field("name", name));
        fields.add(field("sampleId", sampleId));
        fields.add(field("sampleVolume", sampleVolume));
        fields.add(field("pan", pan));
        fields.add(field("bgm", bgm));
        fields.add(field("played", played));
        fields.add(field("playCount", sound.playCount));
        if (sound.playCount > 0) {
            fields.add(field("channel", sound.channel.name()));
            fields.add(field("playVolume", sound.volume));
            fields.add(field("playPan", sound.pan));
        }
        return object(fields.toArray(new String[fields.size()]));
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

    private static final class RecordingSound implements Sound {
        int playCount;
        SoundChannel channel;
        float volume;
        float pan;

        @Override
        public SoundInstance play(SoundChannel soundChannel, float volume, float pan) throws SoundSystemException {
            this.playCount++;
            this.channel = soundChannel;
            this.volume = volume;
            this.pan = pan;
            return new SoundInstance() {
                @Override
                public void stop() {
                }
            };
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

    private static String field(String name, float value) {
        return quote(name) + ":" + Float.toString(value);
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

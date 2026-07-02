package org.open2jam.render.entities;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.parsers.Event;
import org.open2jam.render.Sprite;
import org.open2jam.render.SpriteList;
import org.open2jam.render.lwjgl.Texture;

class NoteEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/note-entity-oracle.json");
    private static final double X = 5.0;
    private static final double INITIAL_Y = 100.0;
    private static final double HIT_LINE_Y = 480.0;
    private static final double WIDTH = 28.0;
    private static final double HEIGHT = 7.0;
    private static final double NOTE_TIME_MS = 1000.0;

    @Test
    void noteEntityOracleFixtureMatchesJavaAnchorAndStateBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateNoteEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot note entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        NoteEntity entity = new NoteEntity(frames(), Event.Channel.NOTE_1, X, INITIAL_Y);
        entity.setTime(NOTE_TIME_MS);

        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("constructed", entity));
        entity.setPos(X, HIT_LINE_Y);
        scenarios.add(snapshot("after_set_pos_to_hit_line", entity));
        entity.updateHit(900.0, 2.0);
        scenarios.add(snapshot("after_update_hit", entity));
        entity.setState(NoteEntity.State.JUDGE);
        scenarios.add(snapshot("after_state_change", entity));

        NoteEntity copy = entity.copy();
        scenarios.add(snapshot("copy_preserves_position_and_state_only", copy));

        return object(
                field("schemaVersion", 1),
                field("source", "NoteEntity anchor and state behavior"),
                field("channel", "NOTE_1"),
                field("x", X),
                field("initialY", INITIAL_Y),
                field("hitLineY", HIT_LINE_Y),
                field("width", WIDTH),
                field("height", HEIGHT),
                field("noteTimeMs", NOTE_TIME_MS),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, NoteEntity entity) {
        return object(
                field("name", name),
                field("x", entity.getX()),
                field("y", entity.getY()),
                field("startY", entity.getStartY()),
                field("width", entity.getWidth()),
                field("height", entity.getHeight()),
                field("timeMs", entity.getTime()),
                field("timeToJudgeMs", entity.getTimeToJudge()),
                field("hitTimeMs", entity.getHitTime()),
                field("state", entity.getState().name()),
                field("channel", entity.getChannel().name()));
    }

    private static SpriteList frames() {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite(WIDTH, HEIGHT));
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

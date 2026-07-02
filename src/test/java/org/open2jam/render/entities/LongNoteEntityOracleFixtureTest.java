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

class LongNoteEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/long-note-entity-oracle.json");
    private static final double BASE_X = 42.0;
    private static final double BASE_Y = 100.0;
    private static final double NOTE_WIDTH = 28.0;
    private static final double HEAD_HEIGHT = 7.0;
    private static final double BODY_HEIGHT = 5.0;
    private static final double TAIL_HEIGHT = 7.0;
    private static final double NORMAL_HEIGHT = 13.0;
    private static final double END_DISTANCE = 64.0;
    private static final double FRAME_SPEED = 0.012;

    @Test
    void longNoteEntityOracleFixtureMatchesJavaDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateLongNoteEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot long note entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("frame_0", 0.0));
        scenarios.add(snapshot("frame_1", 100.0));
        scenarios.add(snapshot("frame_2", 200.0));
        scenarios.add(snapshot("looped_frame", 250.0));

        return object(
                field("schemaVersion", 1),
                field("source", "LongNoteEntity.draw"),
                field("baseX", BASE_X),
                field("baseY", BASE_Y),
                field("width", NOTE_WIDTH),
                field("headHeight", HEAD_HEIGHT),
                field("bodyHeight", BODY_HEIGHT),
                field("tailHeight", TAIL_HEIGHT),
                field("normalHeight", NORMAL_HEIGHT),
                field("endDistance", END_DISTANCE),
                field("frameSpeed", FRAME_SPEED),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, double elapsedMs) {
        ArrayList<DrawCall> draws = new ArrayList<DrawCall>();
        LongNoteEntity entity = new LongNoteEntity(
                frames("head", HEAD_HEIGHT, draws),
                frames("body", BODY_HEIGHT, draws),
                frames("tail", TAIL_HEIGHT, draws),
                frames("normal", NORMAL_HEIGHT, draws),
                Event.Channel.NOTE_1,
                BASE_X,
                BASE_Y);
        entity.setTime(1000.0);
        entity.setEndTime(2000.0);
        if (elapsedMs > 0.0) {
            entity.move(elapsedMs);
        }
        entity.setEndDistance(END_DISTANCE);
        entity.draw();

        List<String> drawJson = new ArrayList<String>();
        for (DrawCall draw : draws) {
            drawJson.add(object(
                    field("part", draw.part),
                    field("frame", draw.frame),
                    field("x", draw.x),
                    field("y", draw.y),
                    field("scaleX", draw.scaleX),
                    field("scaleY", draw.scaleY),
                    field("screenWidth", draw.width * draw.scaleX),
                    field("screenHeight", draw.height * draw.scaleY)));
        }

        return object(
                field("name", name),
                field("elapsedMs", elapsedMs),
                field("startY", BASE_Y),
                field("endY", BASE_Y - END_DISTANCE),
                rawField("draws", array(drawJson)));
    }

    private static SpriteList frames(String part, double height, ArrayList<DrawCall> draws) {
        SpriteList sprites = new SpriteList(FRAME_SPEED);
        for (int i = 0; i < 3; i++) {
            sprites.add(new RecordingSprite(part, i, NOTE_WIDTH, height, draws));
        }
        return sprites;
    }

    private static final class DrawCall {
        private final String part;
        private final int frame;
        private final double width;
        private final double height;
        private final double x;
        private final double y;
        private final float scaleX;
        private final float scaleY;

        private DrawCall(String part, int frame, double width, double height, double x, double y,
                float scaleX, float scaleY) {
            this.part = part;
            this.frame = frame;
            this.width = width;
            this.height = height;
            this.x = x;
            this.y = y;
            this.scaleX = scaleX;
            this.scaleY = scaleY;
        }
    }

    private static final class RecordingSprite implements Sprite {
        private final String part;
        private final int frame;
        private final double width;
        private final double height;
        private final ArrayList<DrawCall> draws;

        private RecordingSprite(String part, int frame, double width, double height, ArrayList<DrawCall> draws) {
            this.part = part;
            this.frame = frame;
            this.width = width;
            this.height = height;
            this.draws = draws;
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
            draw(x, y, getScaleX(), getScaleY());
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
            draws.add(new DrawCall(part, frame, width, height, x, y, scaleX, scaleY));
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height, ByteBuffer buffer) {
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

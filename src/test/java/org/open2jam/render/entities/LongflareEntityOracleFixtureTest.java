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

class LongflareEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/longflare-entity-oracle.json");
    private static final double NOTE_X = 123.0;
    private static final double NOTE_Y_AT_CREATION = 45.0;
    private static final double NOTE_Y_AFTER_MOVE = 70.0;
    private static final double NOTE_WIDTH = 20.0;
    private static final double NOTE_HEIGHT = 10.0;
    private static final double END_DISTANCE = 64.0;
    private static final double WIDTH = 50.0;
    private static final double HEIGHT = 20.0;
    private static final double FRAME_SPEED = 0.005;

    @Test
    void longflareEntityOracleFixtureMatchesJavaDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateLongflareEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot longflare entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("spawn", 0.0, NOTE_Y_AT_CREATION));
        scenarios.add(snapshot("second_frame", 200.0, NOTE_Y_AT_CREATION));
        scenarios.add(snapshot("looped_frame", 400.0, NOTE_Y_AT_CREATION));
        scenarios.add(snapshot("note_moved_after_spawn", 200.0, NOTE_Y_AFTER_MOVE));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.check_judgment EFFECT_LONGFLARE with AnimatedEntity.move"),
                field("noteX", NOTE_X),
                field("noteYAtCreation", NOTE_Y_AT_CREATION),
                field("noteWidth", NOTE_WIDTH),
                field("noteHeight", NOTE_HEIGHT),
                field("endDistance", END_DISTANCE),
                field("width", WIDTH),
                field("height", HEIGHT),
                field("frameSpeed", FRAME_SPEED),
                field("animationLoops", true),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, double elapsedMs, double currentNoteY) {
        ArrayList<DrawCall> draws = new ArrayList<DrawCall>();
        LongNoteEntity note = new LongNoteEntity(
                staticFrames(NOTE_WIDTH, NOTE_HEIGHT),
                staticFrames(NOTE_WIDTH, NOTE_HEIGHT),
                staticFrames(NOTE_WIDTH, NOTE_HEIGHT),
                staticFrames(NOTE_WIDTH, NOTE_HEIGHT),
                Event.Channel.NOTE_1,
                NOTE_X,
                NOTE_Y_AT_CREATION);
        note.setTime(1000.0);
        note.setEndTime(2000.0);
        note.setPos(note.getX(), NOTE_Y_AT_CREATION);
        note.setEndDistance(END_DISTANCE);
        AnimatedEntity flare = new AnimatedEntity(frames(draws), 0.0, 0.0, true);
        flare.setPos(note.getX() + note.getWidth() / 2.0 - flare.getWidth() / 2.0, note.getY());

        note.setPos(note.getX(), currentNoteY);
        note.setEndDistance(END_DISTANCE);
        if (elapsedMs > 0.0) {
            flare.move(elapsedMs);
        }
        if (!flare.isDead()) {
            flare.draw();
        }

        List<String> drawJson = new ArrayList<String>();
        for (DrawCall draw : draws) {
            drawJson.add(object(
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
                field("currentNoteY", currentNoteY),
                field("dead", flare.isDead()),
                rawField("draws", array(drawJson)));
    }

    private static SpriteList frames(ArrayList<DrawCall> draws) {
        SpriteList sprites = new SpriteList(FRAME_SPEED);
        for (int i = 0; i < 2; i++) {
            sprites.add(new RecordingSprite(i, WIDTH, HEIGHT, draws));
        }
        return sprites;
    }

    private static SpriteList staticFrames(double width, double height) {
        SpriteList sprites = new SpriteList(0.0);
        sprites.add(new RecordingSprite(0, width, height, new ArrayList<DrawCall>()));
        return sprites;
    }

    private static final class DrawCall {
        private final int frame;
        private final double width;
        private final double height;
        private final double x;
        private final double y;
        private final float scaleX;
        private final float scaleY;

        private DrawCall(int frame, double width, double height, double x, double y, float scaleX, float scaleY) {
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
        private final int frame;
        private final double width;
        private final double height;
        private final ArrayList<DrawCall> draws;

        private RecordingSprite(int frame, double width, double height, ArrayList<DrawCall> draws) {
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
            draws.add(new DrawCall(frame, width, height, x, y, scaleX, scaleY));
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

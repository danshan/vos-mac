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
import org.open2jam.render.Sprite;
import org.open2jam.render.lwjgl.Texture;

class BgaEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/bga-entity-oracle.json");

    @Test
    void bgaEntityOracleFixtureMatchesJavaQueueAndScaleBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateBgaEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot BGA entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        RecordingSprite base = new RecordingSprite("base", 320.0, 240.0);
        RecordingSprite first = new RecordingSprite("first", 160.0, 120.0);
        RecordingSprite second = new RecordingSprite("second", 640.0, 480.0);
        BgaEntity bga = new BgaEntity(base, 12.0, 34.0);

        List<String> snapshots = new ArrayList<String>();
        bga.draw();
        snapshots.add(snapshot("initial_draw", bga, base));

        bga.setSprite(first);
        bga.setTime(100.0);
        snapshots.add(queueSnapshot("first_queued", bga));
        bga.setSprite(second);
        bga.setTime(200.0);
        snapshots.add(queueSnapshot("second_queued", bga));

        bga.judgment();
        bga.draw();
        snapshots.add(snapshot("first_judgment", bga, first));

        bga.judgment();
        bga.draw();
        snapshots.add(snapshot("second_judgment", bga, second));

        bga.judgment();
        bga.draw();
        snapshots.add(snapshot("empty_queue_keeps_second", bga, second));

        return object(
                field("schemaVersion", 1),
                field("source", "BgaEntity.setSprite setTime judgment draw"),
                field("x", 12.0),
                field("y", 34.0),
                field("baseWidth", 320.0),
                field("baseHeight", 240.0),
                rawField("snapshots", array(snapshots)));
    }

    private static String queueSnapshot(String name, BgaEntity bga) {
        return object(
                field("name", name),
                field("nextTime", bga.getTime()));
    }

    private static String snapshot(String name, BgaEntity bga, RecordingSprite sprite) {
        return object(
                field("name", name),
                field("sprite", sprite.name),
                field("x", bga.getX()),
                field("y", bga.getY()),
                field("entityWidth", bga.getWidth()),
                field("entityHeight", bga.getHeight()),
                field("spriteWidth", sprite.getWidth()),
                field("spriteHeight", sprite.getHeight()),
                field("scaleX", sprite.getScaleX()),
                field("scaleY", sprite.getScaleY()),
                field("drawX", sprite.drawX),
                field("drawY", sprite.drawY),
                field("drawScaleX", sprite.drawScaleX),
                field("drawScaleY", sprite.drawScaleY));
    }

    private static final class RecordingSprite implements Sprite {
        private final String name;
        private final double width;
        private final double height;
        private float scaleX = 1.0f;
        private float scaleY = 1.0f;
        private double drawX;
        private double drawY;
        private float drawScaleX;
        private float drawScaleY;

        private RecordingSprite(String name, double width, double height) {
            this.name = name;
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
            scaleX = x;
            scaleY = y;
        }

        @Override
        public void setSlice(float x, float y) {
        }

        @Override
        public float getScaleX() {
            return scaleX;
        }

        @Override
        public float getScaleY() {
            return scaleY;
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
            draw(x, y, scaleX, scaleY);
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
            drawX = x;
            drawY = y;
            drawScaleX = scaleX;
            drawScaleY = scaleY;
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

    private static String field(String name, double value) {
        return quote(name) + ":" + Double.toString(value);
    }

    private static String field(String name, float value) {
        return quote(name) + ":" + Float.toString(value);
    }

    private static String field(String name, int value) {
        return quote(name) + ":" + value;
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

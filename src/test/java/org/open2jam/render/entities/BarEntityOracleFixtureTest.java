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
import org.open2jam.render.SpriteList;
import org.open2jam.render.entities.BarEntity.FillDirection;
import org.open2jam.render.lwjgl.Texture;

class BarEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/bar-entity-oracle.json");

    @Test
    void barEntityOracleFixtureMatchesJavaDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateBarEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot bar entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        addDirectionScenarios(scenarios, FillDirection.LEFT_TO_RIGHT, "left_to_right");
        addDirectionScenarios(scenarios, FillDirection.RIGHT_TO_LEFT, "right_to_left");
        addDirectionScenarios(scenarios, FillDirection.UP_TO_DOWN, "up_to_down");
        addDirectionScenarios(scenarios, FillDirection.DOWN_TO_UP, "down_to_up");
        return object(
                field("schemaVersion", 1),
                field("source", "BarEntity.draw"),
                field("baseX", 40.0),
                field("baseY", 70.0),
                field("width", 80.0),
                field("height", 20.0),
                field("limit", 100),
                rawField("scenarios", array(scenarios)));
    }

    private static void addDirectionScenarios(List<String> scenarios, FillDirection direction, String id) {
        scenarios.add(snapshot(id + "_empty", direction, id, 0, 100));
        scenarios.add(snapshot(id + "_quarter", direction, id, 25, 100));
        scenarios.add(snapshot(id + "_overfill", direction, id, 125, 100));
    }

    private static String snapshot(String name, FillDirection direction, String directionId, int value, int limit) {
        RecordingSprite sprite = new RecordingSprite(80.0, 20.0);
        SpriteList sprites = new SpriteList(0.0);
        sprites.add(sprite);
        BarEntity bar = new BarEntity(sprites, 40.0, 70.0, direction);
        bar.setLimit(limit);
        bar.setNumber(value);
        bar.draw();

        return object(
                field("name", name),
                field("fillDirection", directionId),
                field("requestedValue", value),
                field("storedValue", bar.getNumber()),
                field("limit", bar.getLimit()),
                field("sliceX", sprite.sliceX),
                field("sliceY", sprite.sliceY),
                field("drawX", sprite.drawX),
                field("drawY", sprite.drawY));
    }

    private static final class RecordingSprite implements Sprite {
        private final double width;
        private final double height;
        private float sliceX;
        private float sliceY;
        private double drawX;
        private double drawY;

        private RecordingSprite(double width, double height) {
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
            sliceX = x;
            sliceY = y;
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
            drawX = x;
            drawY = y;
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height, ByteBuffer buffer) {
            draw(x, y);
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

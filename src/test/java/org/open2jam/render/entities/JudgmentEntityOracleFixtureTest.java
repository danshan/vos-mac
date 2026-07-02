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
import org.open2jam.render.lwjgl.Texture;

class JudgmentEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/judgment-entity-oracle.json");
    private static final double BASE_X = 200.0;
    private static final double BASE_Y = 150.0;
    private static final double SPRITE_WIDTH = 128.0;
    private static final double SPRITE_HEIGHT = 64.0;

    @Test
    void judgmentEntityOracleFixtureMatchesJavaDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateJudgmentEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot judgment entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("spawn", 0.0));
        scenarios.add(snapshot("enter_midpoint", 50.0));
        scenarios.add(snapshot("enter_complete", 100.0));
        scenarios.add(snapshot("show_time_boundary", 3000.0));
        scenarios.add(snapshot("after_show_time", 3001.0));

        return object(
                field("schemaVersion", 1),
                field("source", "JudgmentEntity.draw"),
                field("baseX", BASE_X),
                field("baseY", BASE_Y),
                field("width", SPRITE_WIDTH),
                field("height", SPRITE_HEIGHT),
                field("showTimeMs", 3000.0),
                field("scaleRampMs", 100.0),
                field("initialScale", 0.5),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, double elapsedMs) {
        RecordingSprite sprite = new RecordingSprite(SPRITE_WIDTH, SPRITE_HEIGHT);
        SpriteList sprites = new SpriteList(0.0);
        sprites.add(sprite);
        JudgmentEntity entity = new JudgmentEntity(sprites, BASE_X, BASE_Y);
        if (elapsedMs > 0.0) {
            entity.move(elapsedMs);
        }

        if (!entity.isDead()) {
            entity.draw();
        }

        List<String> drawCalls = new ArrayList<String>();
        if (sprite.drawn) {
            drawCalls.add(object(
                    field("x", sprite.drawX),
                    field("y", sprite.drawY),
                    field("scaleX", sprite.drawScaleX),
                    field("scaleY", sprite.drawScaleY)));
        }

        return object(
                field("name", name),
                field("elapsedMs", elapsedMs),
                field("entityX", entity.getX()),
                field("entityY", entity.getY()),
                field("dead", entity.isDead()),
                rawField("draws", array(drawCalls)));
    }

    private static final class RecordingSprite implements Sprite {
        private final double width;
        private final double height;
        private boolean drawn;
        private double drawX;
        private double drawY;
        private float drawScaleX;
        private float drawScaleY;

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
            drawn = true;
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

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

class NumberEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/number-entity-oracle.json");

    @Test
    void numberEntityOracleFixtureMatchesJavaDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateNumberEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot number entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<DrawCall> drawCalls = new ArrayList<DrawCall>();
        List<RecordingEntity> digitEntities = digitEntities(drawCalls);
        NumberEntity counter = new NumberEntity(new ArrayList<Entity>(digitEntities), 250.0, 120.0);
        List<String> scenarios = new ArrayList<String>();

        counter.showDigits(1);
        counter.setNumber(7);
        scenarios.add(snapshot("single_digit", counter, drawCalls));

        counter.showDigits(3);
        counter.setNumber(7);
        scenarios.add(snapshot("padded_single_digit", counter, drawCalls));

        counter.showDigits(5);
        counter.setNumber(42);
        scenarios.add(snapshot("padded_two_digits", counter, drawCalls));

        counter.showDigits(2);
        counter.setNumber(12345);
        scenarios.add(snapshot("untrimmed_large_number", counter, drawCalls));

        return object(
                field("schemaVersion", 1),
                field("source", "NumberEntity.draw"),
                field("baseX", 250.0),
                field("baseY", 120.0),
                rawField("digitWidths", digitWidths(digitEntities)),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, NumberEntity counter, List<DrawCall> drawCalls) {
        drawCalls.clear();

        counter.draw();

        List<String> draws = new ArrayList<String>();
        for (DrawCall draw : drawCalls) {
            draws.add(object(
                    field("digit", draw.digit),
                    field("x", draw.x),
                    field("y", draw.y)));
        }

        return object(
                field("name", name),
                field("number", counter.getNumber()),
                field("showDigits", counter.show_digits),
                rawField("digits", array(draws)));
    }

    private static List<RecordingEntity> digitEntities(List<DrawCall> drawCalls) {
        List<RecordingEntity> entities = new ArrayList<RecordingEntity>();
        for (int i = 0; i < 10; i++) {
            double width = 10.0 + i;
            String digit = String.valueOf(i);
            entities.add(new RecordingEntity(digit, new RecordingSprite(digit, width, 24.0, drawCalls), 0.0, 0.0));
        }
        return entities;
    }

    private static String digitWidths(List<RecordingEntity> digitEntities) {
        List<String> fields = new ArrayList<String>();
        for (RecordingEntity entity : digitEntities) {
            fields.add(field(entity.name, entity.getWidth()));
        }
        return object(fields.toArray(new String[0]));
    }

    private static final class RecordingEntity extends Entity {
        private final String name;

        private RecordingEntity(String name, RecordingSprite sprite, double x, double y) {
            super(sprite, x, y);
            this.name = name;
        }
    }

    private static final class DrawCall {
        private final String digit;
        private final double x;
        private final double y;

        private DrawCall(String digit, double x, double y) {
            this.digit = digit;
            this.x = x;
            this.y = y;
        }
    }

    private static final class RecordingSprite implements Sprite {
        private final String digit;
        private final double width;
        private final double height;
        private final List<DrawCall> drawCalls;

        private RecordingSprite(String digit, double width, double height, List<DrawCall> drawCalls) {
            this.digit = digit;
            this.width = width;
            this.height = height;
            this.drawCalls = drawCalls;
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
            drawCalls.add(new DrawCall(digit, x, y));
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

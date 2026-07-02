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

class ComboCounterEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/combo-counter-oracle.json");

    @Test
    void comboCounterOracleFixtureMatchesJavaEntityDrawBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateComboCounterOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot combo counter oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        RecordingEntity title = new RecordingEntity("title", new RecordingSprite("title", 64.0, 64.0), 0.0, 0.0);
        List<RecordingEntity> digitEntities = digitEntities();
        ComboCounterEntity counter = new ComboCounterEntity(new ArrayList<Entity>(digitEntities), title, 99.0, 210.0);
        counter.setThreshold(2);

        List<String> steps = new ArrayList<String>();

        incrementTo(counter, 1);
        steps.add(snapshot("below_threshold", 0.0, 1, counter, title, digitEntities));

        incrementTo(counter, 12);
        steps.add(snapshot("combo_12_start", 83000.0, 12, counter, title, digitEntities));

        counter.move(10.0);
        steps.add(snapshot("combo_12_after_10ms", 83010.0, 12, counter, title, digitEntities));

        counter.move(10.0);
        steps.add(snapshot("combo_12_after_20ms", 83020.0, 12, counter, title, digitEntities));

        counter.move(3981.0);
        steps.add(snapshot("combo_12_after_show_time", 87001.0, 12, counter, title, digitEntities));

        counter.incNumber();
        steps.add(snapshot("combo_13_start", 87084.0, 13, counter, title, digitEntities));

        counter.move(21.0);
        steps.add(snapshot("combo_13_after_21ms", 87105.0, 13, counter, title, digitEntities));

        return object(
                field("schemaVersion", 1),
                field("source", "ComboCounterEntity.draw"),
                field("baseX", 99.0),
                field("baseY", 210.0),
                field("countThreshold", 2),
                field("digitWidth", 46.0),
                field("digitHeight", 71.0),
                field("titleWidth", 64.0),
                field("titleHeight", 64.0),
                rawField("steps", array(steps)));
    }

    private static void incrementTo(ComboCounterEntity counter, int value) {
        while (counter.getNumber() < value) {
            counter.incNumber();
        }
    }

    private static String snapshot(String name, double elapsedMs, int comboValue, ComboCounterEntity counter,
            RecordingEntity title, List<RecordingEntity> digitEntities) {
        title.clearDraws();
        for (RecordingEntity entity : digitEntities) {
            entity.clearDraws();
        }

        counter.draw();

        List<String> digitDraws = new ArrayList<String>();
        for (RecordingEntity entity : digitEntities) {
            for (DrawCall draw : entity.draws) {
                digitDraws.add(object(
                        field("digit", entity.name),
                        field("x", draw.x),
                        field("y", draw.y)));
            }
        }

        List<String> titleDraws = new ArrayList<String>();
        for (DrawCall draw : title.draws) {
            titleDraws.add(object(
                    field("x", draw.x),
                    field("y", draw.y)));
        }

        boolean visible = !digitDraws.isEmpty();
        String displayedText = visible ? String.valueOf(comboValue - 1) : "";
        return object(
                field("name", name),
                field("elapsedMs", elapsedMs),
                field("comboValue", comboValue),
                field("visible", visible),
                field("displayedText", displayedText),
                rawField("digits", array(digitDraws)),
                rawField("title", array(titleDraws)));
    }

    private static List<RecordingEntity> digitEntities() {
        List<RecordingEntity> entities = new ArrayList<RecordingEntity>();
        for (int i = 0; i < 10; i++) {
            entities.add(new RecordingEntity(String.valueOf(i), new RecordingSprite(String.valueOf(i), 46.0, 71.0),
                    0.0, 0.0));
        }
        return entities;
    }

    private static final class RecordingEntity extends Entity {
        private final String name;
        private final ArrayList<DrawCall> draws;

        private RecordingEntity(String name, RecordingSprite sprite, double x, double y) {
            super(sprite, x, y);
            this.name = name;
            this.draws = sprite.draws;
        }

        private void clearDraws() {
            draws.clear();
        }
    }

    private static final class DrawCall {
        private final double x;
        private final double y;

        private DrawCall(double x, double y) {
            this.x = x;
            this.y = y;
        }
    }

    private static final class RecordingSprite implements Sprite {
        private final String name;
        private final double width;
        private final double height;
        private final ArrayList<DrawCall> draws = new ArrayList<DrawCall>();

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
            draws.add(new DrawCall(x, y));
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

        @Override
        public String toString() {
            return name;
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
        return string(name) + ":" + string(value);
    }

    private static String field(String name, int value) {
        return string(name) + ":" + value;
    }

    private static String field(String name, double value) {
        return string(name) + ":" + value;
    }

    private static String field(String name, boolean value) {
        return string(name) + ":" + value;
    }

    private static String rawField(String name, String rawJson) {
        return string(name) + ":" + rawJson;
    }

    private static String string(String value) {
        StringBuilder out = new StringBuilder();
        out.append('"');
        for (int i = 0; i < value.length(); i++) {
            char c = value.charAt(i);
            switch (c) {
                case '"':
                    out.append("\\\"");
                    break;
                case '\\':
                    out.append("\\\\");
                    break;
                case '\n':
                    out.append("\\n");
                    break;
                case '\r':
                    out.append("\\r");
                    break;
                case '\t':
                    out.append("\\t");
                    break;
                default:
                    if (c < 0x20) {
                        out.append(String.format("\\u%04x", (int) c));
                    } else {
                        out.append(c);
                    }
                    break;
            }
        }
        out.append('"');
        return out.toString();
    }
}

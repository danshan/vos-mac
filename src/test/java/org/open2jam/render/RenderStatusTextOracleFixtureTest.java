package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

class RenderStatusTextOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/status-text-oracle.json");

    @Test
    void statusTextOracleFixtureMatchesJavaRenderDrawLoop() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateStatusTextOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot status text oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        StatusList statusList = new StatusList();
        statusList.add(item("HI-SPEED: x1.25", true));
        statusList.add(item("Hidden status should be removed", false));
        statusList.add(item("Current Measure: 7", true));
        statusList.add(item("Game Speed: -2", true));
        statusList.add(item("Press any note button to start the game.", true));

        RecordingTextRenderer textRenderer = new RecordingTextRenderer();
        int y = 300;
        for (String status : statusList) {
            textRenderer.drawString(780, y, status, 1, -1, TextRenderer.ALIGN_RIGHT);
            y += 30;
        }

        return object(
                field("schemaVersion", 1),
                field("source", "Render statusList draw loop"),
                rawField("layout", object(
                        field("rightX", 780.0),
                        field("startY", 300.0),
                        field("lineHeight", 30.0),
                        field("labelWidth", 260.0),
                        field("fontFamily", "Tahoma"),
                        field("fontSize", 14),
                        field("glyphHeight", 20.0),
                        field("bold", true),
                        field("antiAlias", false),
                        field("fontColor", "#ffffffff"),
                        field("horizontalAlignment", "right"),
                        field("scaleX", 1.0),
                        field("scaleY", -1.0))),
                rawField("draws", array(textRenderer.draws)));
    }

    private static StatusItem item(final String text, final boolean visible) {
        return new StatusItem() {
            @Override
            public String getText() {
                return text;
            }

            @Override
            public boolean isVisible() {
                return visible;
            }
        };
    }

    private static final class RecordingTextRenderer implements TextRenderer {
        private final List<String> draws = new ArrayList<String>();

        @Override
        public void drawString(float x, float y, String text, float scaleX, float scaleY) {
            drawString(x, y, text, scaleX, scaleY, ALIGN_LEFT);
        }

        @Override
        public void drawString(float x, float y, String text, float scaleX, float scaleY, int format) {
            draws.add(object(
                    field("text", text),
                    field("x", x),
                    field("y", y),
                    field("scaleX", scaleX),
                    field("scaleY", scaleY),
                    field("alignment", alignmentName(format))));
        }

        @Override
        public void destroy() {
        }
    }

    private static String alignmentName(int format) {
        if (format == TextRenderer.ALIGN_RIGHT) {
            return "right";
        }
        if (format == TextRenderer.ALIGN_CENTER) {
            return "center";
        }
        return "left";
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

    private static String field(String name, float value) {
        return quote(name) + ":" + Float.toString(value);
    }

    private static String field(String name, double value) {
        return quote(name) + ":" + Double.toString(value);
    }

    private static String field(String name, boolean value) {
        return quote(name) + ":" + value;
    }

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

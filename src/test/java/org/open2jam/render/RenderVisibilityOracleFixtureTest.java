package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.junit.jupiter.api.Test;
import org.open2jam.export.VosRenderMetadataExporter;

class RenderVisibilityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/visibility-oracle.json");
    private static final double OVERLAY_HEIGHT = 480.0;
    private static final double ALPHA_TOLERANCE = 0.005;
    private static final String[] MODIFIERS = {"Hidden", "Sudden", "Dark"};
    private static final double[] HIDDEN_SAMPLES = {0.0, 1.9, 1.95, 2.0, 3.5};
    private static final double[] SUDDEN_SAMPLES = {0.0, 1.9, 1.95, 2.0, 3.5};
    private static final double[] DARK_SAMPLES = {0.0, 1.3, 1.4, 1.5, 2.0, 2.5, 2.6, 2.7, 3.5};

    @Test
    void visibilityOracleFixtureMatchesJavaRenderMetadataAndLayerRules() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateVisibilityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot visibility oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        String metadata = new VosRenderMetadataExporter().exportDefaultMetadata();
        EntityData note = entity(metadata, "NOTE_1");
        EntityData judgmentLine = entity(metadata, "JUDGMENT_LINE");
        EntityData measure = entity(metadata, "MEASURE_MARK");
        EntityData jamBar = entity(metadata, "JAM_BAR");
        LaneData firstLane = lane(metadata, "NOTE_1", 0);
        int visibilityLayer = intField(metadata, "visibilityLayer");
        int laneCount = laneCount(metadata);

        return object(
                field("schemaVersion", 1),
                field("source", "VosRenderMetadataExporter visibilityMasks with Render.visibility layer rules"),
                field("overlayHeight", OVERLAY_HEIGHT),
                field("alphaTolerance", ALPHA_TOLERANCE),
                field("visibilityLayer", visibilityLayer),
                field("laneCount", laneCount),
                rawField("firstLane", object(
                        field("x", firstLane.x),
                        field("width", firstLane.width))),
                rawField("originalLayers", object(
                        field("note", note.layer),
                        field("judgmentLine", judgmentLine.layer),
                        field("measure", measure.layer),
                        field("jamBar", jamBar.layer))),
                rawField("masks", maskJson(metadata)),
                rawField("scenarios", scenarioJson(visibilityLayer, note, judgmentLine, measure, jamBar)));
    }

    private static String maskJson(String metadata) {
        List<String> masks = new ArrayList<String>();
        for (String modifier : MODIFIERS) {
            List<Point> points = maskPoints(metadata, modifier);
            masks.add(object(
                    field("modifier", modifier),
                    rawField("points", pointJson(points)),
                    rawField("samples", sampleJson(points, samplesFor(modifier)))));
        }
        return array(masks);
    }

    private static String pointJson(List<Point> points) {
        List<String> values = new ArrayList<String>();
        for (Point point : points) {
            values.add(object(
                    field("at", point.at),
                    field("alpha", point.alpha)));
        }
        return array(values);
    }

    private static String scenarioJson(int visibilityLayer, EntityData note, EntityData judgmentLine,
            EntityData measure, EntityData jamBar) {
        List<String> scenarios = new ArrayList<String>();
        for (String modifier : MODIFIERS) {
            int judgmentLayer = "Sudden".equals(modifier) ? effectiveLayer(judgmentLine.layer, visibilityLayer)
                    : visibilityLayer;
            scenarios.add(object(
                    field("modifier", modifier),
                    field("overlayLayer", visibilityLayer),
                    field("noteLayer", effectiveLayer(note.layer, visibilityLayer)),
                    field("judgmentLineLayer", judgmentLayer),
                    field("measureLayer", visibilityLayer),
                    field("jamBarLayer", effectiveLayer(jamBar.layer, visibilityLayer))));
        }
        return array(scenarios);
    }

    private static int effectiveLayer(int layer, int visibilityLayer) {
        if (layer >= visibilityLayer) {
            return layer + 1;
        }
        return layer;
    }

    private static String sampleJson(List<Point> points, double[] samples) {
        List<String> values = new ArrayList<String>();
        for (double sample : samples) {
            values.add(object(
                    field("at", sample),
                    field("y", sample * OVERLAY_HEIGHT / 4.0),
                    field("alpha", alphaAt(points, sample))));
        }
        return array(values);
    }

    private static double[] samplesFor(String modifier) {
        if ("Hidden".equals(modifier)) {
            return HIDDEN_SAMPLES;
        }
        if ("Sudden".equals(modifier)) {
            return SUDDEN_SAMPLES;
        }
        return DARK_SAMPLES;
    }

    private static double alphaAt(List<Point> points, double at) {
        Point previous = null;
        for (Point point : points) {
            if (at <= point.at) {
                if (previous == null || point.at == previous.at) {
                    return point.alpha;
                }
                double ratio = (at - previous.at) / (point.at - previous.at);
                return previous.alpha + (point.alpha - previous.alpha) * ratio;
            }
            previous = point;
        }
        return previous == null ? 0.0 : previous.alpha;
    }

    private static List<Point> maskPoints(String metadata, String modifier) {
        Matcher section = Pattern.compile("\"" + modifier + "\":\\[(.*?)\\]").matcher(metadata);
        if (!section.find()) {
            throw new IllegalArgumentException("Missing visibility mask: " + modifier);
        }

        List<Point> points = new ArrayList<Point>();
        Matcher point = Pattern.compile("\\{\"at\":(-?\\d+(?:\\.\\d+)?),\"alpha\":(-?\\d+(?:\\.\\d+)?)\\}")
                .matcher(section.group(1));
        while (point.find()) {
            points.add(new Point(Double.parseDouble(point.group(1)), Double.parseDouble(point.group(2))));
        }
        if (points.isEmpty()) {
            throw new IllegalArgumentException("Missing visibility mask points: " + modifier);
        }
        return points;
    }

    private static EntityData entity(String metadata, String id) {
        Pattern pattern = Pattern.compile("\"id\":\"" + id
                + "\",\"type\":\"[^\"]+\",\"layer\":(\\d+),\"x\":(-?\\d+(?:\\.\\d+)?),"
                + "\"y\":(-?\\d+(?:\\.\\d+)?),\"width\":(-?\\d+(?:\\.\\d+)?),"
                + "\"height\":(-?\\d+(?:\\.\\d+)?)");
        Matcher matcher = pattern.matcher(metadata);
        if (!matcher.find()) {
            throw new IllegalArgumentException("Missing entity: " + id);
        }
        return new EntityData(
                Integer.parseInt(matcher.group(1)),
                Double.parseDouble(matcher.group(2)),
                Double.parseDouble(matcher.group(3)),
                Double.parseDouble(matcher.group(4)),
                Double.parseDouble(matcher.group(5)));
    }

    private static LaneData lane(String metadata, String channel, int lane) {
        Pattern pattern = Pattern.compile("\\{\"channel\":\"" + channel + "\",\"lane\":" + lane
                + ",\"x\":(-?\\d+(?:\\.\\d+)?),\"width\":(-?\\d+(?:\\.\\d+)?)\\}");
        Matcher matcher = pattern.matcher(metadata);
        if (!matcher.find()) {
            throw new IllegalArgumentException("Missing lane: " + channel);
        }
        return new LaneData(Double.parseDouble(matcher.group(1)), Double.parseDouble(matcher.group(2)));
    }

    private static int intField(String json, String field) {
        Matcher matcher = Pattern.compile("\"" + field + "\":(\\d+)").matcher(json);
        if (!matcher.find()) {
            throw new IllegalArgumentException("Missing integer field: " + field);
        }
        return Integer.parseInt(matcher.group(1));
    }

    private static int laneCount(String metadata) {
        Matcher matcher = Pattern.compile("\\{\"channel\":\"NOTE_\\d+\",\"lane\":\\d+,\"x\":").matcher(metadata);
        int count = 0;
        while (matcher.find()) {
            count++;
        }
        return count;
    }

    private static final class Point {
        final double at;
        final double alpha;

        Point(double at, double alpha) {
            this.at = at;
            this.alpha = alpha;
        }
    }

    private static final class EntityData {
        final int layer;
        final double x;
        final double y;
        final double width;
        final double height;

        EntityData(int layer, double x, double y, double width, double height) {
            this.layer = layer;
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }

    private static final class LaneData {
        final double x;
        final double width;

        LaneData(double x, double width) {
            this.x = x;
            this.width = width;
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

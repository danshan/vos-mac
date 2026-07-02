package org.open2jam.game;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import org.junit.jupiter.api.Test;

class LatencyOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/latency-oracle.json");

    @Test
    void latencyOracleFixtureMatchesJavaAutosync() throws Exception {
        String expected = renderOracleJson();
        if (Boolean.getBoolean("open2jam.updateLatencyOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot latency oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String renderOracleJson() {
        return "{"
                + "\"schemaVersion\":1,"
                + "\"source\":\"Latency.autosync\","
                + "\"historySize\":64,"
                + "\"scenarios\":["
                + scenario("positive_start", 50.0, new double[] {10.0, -20.0, 0.0}) + ","
                + scenario("negative_start", -35.0, new double[] {15.0, 15.0})
                + "]"
                + "}";
    }

    private static String scenario(String name, double initialLatency, double[] hits) {
        Latency latency = new Latency(initialLatency);
        StringBuilder steps = new StringBuilder();
        for (int i = 0; i < hits.length; i++) {
            if (i > 0) {
                steps.append(',');
            }
            latency.autosync(hits[i]);
            steps.append("{\"hitMs\":")
                    .append(Double.toString(hits[i]))
                    .append(",\"latencyMs\":")
                    .append(Double.toString(latency.getLatency()))
                    .append('}');
        }
        return "{\"name\":\"" + name + "\",\"initialLatencyMs\":"
                + Double.toString(initialLatency)
                + ",\"steps\":["
                + steps
                + "]}";
    }
}

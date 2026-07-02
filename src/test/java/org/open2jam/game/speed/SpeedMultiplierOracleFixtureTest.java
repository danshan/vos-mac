package org.open2jam.game.speed;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

class SpeedMultiplierOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/speed-multiplier-oracle.json");

    @Test
    void speedMultiplierOracleFixtureMatchesJavaUpdateBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateSpeedMultiplierOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot speed multiplier oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(scenario("smooth_increase_and_decrease", 1.0,
                Action.increase(),
                Action.update(50.0),
                Action.update(100.0),
                Action.decrease(),
                Action.update(30.0),
                Action.update(200.0)));
        scenarios.add(scenario("upper_clamp", 10.0, Action.increase(), Action.decrease()));
        scenarios.add(scenario("lower_clamp", 0.5, Action.decrease(), Action.increase()));

        return object(
                field("schemaVersion", 1),
                field("source", "SpeedMultiplier Java update behavior"),
                rawField("scenarios", array(scenarios)));
    }

    private static String scenario(String name, double initialSpeed, Action... actions) {
        SpeedMultiplier speed = new SpeedMultiplier(initialSpeed);
        List<String> steps = new ArrayList<String>();
        steps.add(snapshot("initial", Action.none(), speed));
        for (Action action : actions) {
            action.apply(speed);
            steps.add(snapshot(action.label, action, speed));
        }
        return object(
                field("name", name),
                field("initialSpeed", initialSpeed),
                rawField("steps", array(steps)));
    }

    private static String snapshot(String label, Action action, SpeedMultiplier speed) {
        return object(
                field("label", label),
                field("action", action.name),
                field("deltaMs", action.deltaMs),
                field("targetSpeed", speed.getSpeed()),
                field("currentSpeed", speed.getCurrentSpeed()),
                field("statusText", "HI-SPEED: " + speed.toString()));
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

    private static final class Action {
        final String name;
        final String label;
        final double deltaMs;

        private Action(String name, String label, double deltaMs) {
            this.name = name;
            this.label = label;
            this.deltaMs = deltaMs;
        }

        static Action none() {
            return new Action("none", "initial", 0.0);
        }

        static Action increase() {
            return new Action("increase", "increase", 0.0);
        }

        static Action decrease() {
            return new Action("decrease", "decrease", 0.0);
        }

        static Action update(double deltaMs) {
            return new Action("update", "update_" + Double.toString(deltaMs), deltaMs);
        }

        void apply(SpeedMultiplier speed) {
            if ("increase".equals(name)) {
                speed.increase();
            } else if ("decrease".equals(name)) {
                speed.decrease();
            } else if ("update".equals(name)) {
                speed.update(deltaMs);
            }
        }
    }
}

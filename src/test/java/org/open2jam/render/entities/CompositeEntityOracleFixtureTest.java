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

class CompositeEntityOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/composite-entity-oracle.json");

    @Test
    void compositeEntityOracleFixtureMatchesJavaLifecycleBehavior() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateCompositeEntityOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot composite entity oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(snapshot("all_children_alive", false, false));
        scenarios.add(snapshot("first_child_dead", true, false));
        scenarios.add(snapshot("all_children_dead", true, true));
        scenarios.add(emptySnapshot());

        return object(
                field("schemaVersion", 1),
                field("source", "CompositeEntity.isDead with Render.frameRendering removal order"),
                rawField("scenarios", array(scenarios)));
    }

    private static String snapshot(String name, boolean firstDead, boolean secondDead) {
        RecordingSprite firstSprite = new RecordingSprite();
        RecordingSprite secondSprite = new RecordingSprite();
        Entity first = new Entity(firstSprite, 0.0, 0.0);
        Entity second = new Entity(secondSprite, 10.0, 0.0);
        first.setDead(firstDead);
        second.setDead(secondDead);
        CompositeEntity composite = new CompositeEntity(first, second);
        return renderLoopSnapshot(name, composite, firstSprite, secondSprite);
    }

    private static String emptySnapshot() {
        CompositeEntity composite = new CompositeEntity();
        return renderLoopSnapshot("empty_composite", composite);
    }

    private static String renderLoopSnapshot(String name, CompositeEntity composite, RecordingSprite... sprites) {
        composite.move(16.0);
        boolean deadBeforeDraw = composite.isDead();
        boolean removedByRenderLoop = false;
        boolean drawnByRenderLoop = false;
        if (deadBeforeDraw) {
            removedByRenderLoop = true;
        } else {
            composite.draw();
            drawnByRenderLoop = true;
        }

        int drawCount = 0;
        for (RecordingSprite sprite : sprites) {
            drawCount += sprite.drawCount;
        }

        return object(
                field("name", name),
                field("childCount", composite.getEntityList().size()),
                field("deadBeforeDraw", deadBeforeDraw),
                field("removedByRenderLoop", removedByRenderLoop),
                field("drawnByRenderLoop", drawnByRenderLoop),
                field("drawCount", drawCount));
    }

    private static final class RecordingSprite implements Sprite {
        private int drawCount;

        @Override
        public double getWidth() {
            return 1.0;
        }

        @Override
        public double getHeight() {
            return 1.0;
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
            drawCount++;
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
            draw(x, y);
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
            drawCount++;
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height,
                ByteBuffer buffer) {
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

    private static String rawField(String name, String value) {
        return quote(name) + ":" + value;
    }

    private static String quote(String value) {
        return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
    }
}

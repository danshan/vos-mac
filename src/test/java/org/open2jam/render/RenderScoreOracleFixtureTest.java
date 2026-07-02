package org.open2jam.render;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.LinkedList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.game.judgment.JudgmentResult;
import org.open2jam.parsers.Event;
import org.open2jam.render.entities.BarEntity;
import org.open2jam.render.entities.ComboCounterEntity;
import org.open2jam.render.entities.Entity;
import org.open2jam.render.entities.NoteEntity;
import org.open2jam.render.entities.NumberEntity;
import org.open2jam.render.lwjgl.Texture;

import sun.misc.Unsafe;

class RenderScoreOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/score-oracle.json");

    @Test
    void scoreOracleFixtureMatchesJavaRenderSetNoteJudgment() throws Exception {
        String expected = renderOracleJson();
        if (Boolean.getBoolean("open2jam.updateScoreOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot score oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String renderOracleJson() throws Exception {
        List<String> scenarios = new ArrayList<String>();
        scenarios.add(scenarioJson("basic_judgment_flow", 0,
                JudgmentResult.COOL,
                JudgmentResult.GOOD,
                JudgmentResult.BAD,
                JudgmentResult.MISS));
        scenarios.add(scenarioJson("jam_combo_and_pills", 0, cools(26)));
        scenarios.add(scenarioJson("pill_converts_bad_to_good", 0, append(cools(15), JudgmentResult.BAD)));
        scenarios.add(scenarioJson("hard_rank_life_recovery", 2,
                JudgmentResult.BAD,
                JudgmentResult.COOL));
        scenarios.add(scenarioJson("java_judgment_result_names", 0,
                JudgmentResult.PERFECT,
                JudgmentResult.COOL));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.setNoteJudgment"),
                rawField("scenarios", array(scenarios)));
    }

    private static String scenarioJson(String name, int rank, JudgmentResult... inputs) throws Exception {
        RenderHarness harness = new RenderHarness(rank);
        String initial = harness.initialSnapshotJson();
        List<String> steps = new ArrayList<String>();
        for (JudgmentResult input : inputs) {
            steps.add(harness.apply(input));
        }
        return object(
                field("name", name),
                field("rank", rank),
                rawField("initial", initial),
                rawField("steps", array(steps)));
    }

    private static JudgmentResult[] cools(int count) {
        JudgmentResult[] results = new JudgmentResult[count];
        for (int i = 0; i < count; i++) {
            results[i] = JudgmentResult.COOL;
        }
        return results;
    }

    private static JudgmentResult[] append(JudgmentResult[] prefix, JudgmentResult last) {
        JudgmentResult[] results = new JudgmentResult[prefix.length + 1];
        System.arraycopy(prefix, 0, results, 0, prefix.length);
        results[results.length - 1] = last;
        return results;
    }

    private static final class RenderHarness {
        private final Render render;
        private final EnumMap<JudgmentResult, NumberEntity> noteCounter;
        private final NumberEntity score;
        private final ComboCounterEntity jamCombo;
        private final BarEntity jamBar;
        private final BarEntity life;
        private final LinkedList<Entity> pills;
        private final ComboCounterEntity combo;
        private final NumberEntity maxCombo;

        RenderHarness(int rank) throws Exception {
            render = newRenderWithoutConstructor();
            noteCounter = new EnumMap<JudgmentResult, NumberEntity>(JudgmentResult.class);
            score = numberEntity();
            jamCombo = comboCounter();
            jamCombo.setThreshold(1);
            jamBar = barEntity();
            jamBar.setLimit(50);
            life = barEntity();
            life.setLimit(lifeLimitForRank(rank));
            life.setNumber(lifeLimitForRank(rank));
            pills = new LinkedList<Entity>();
            combo = comboCounter();
            combo.setThreshold(2);
            maxCombo = numberEntity();

            Skin skin = new Skin();
            skin.judgment_line = 480;
            skin.getEntityMap().put("EFFECT_JUDGMENT_PERFECT", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_COOL", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_GOOD", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_BAD", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_MISS", entity());
            skin.getEntityMap().put("EFFECT_CLICK", entity());
            for (int i = 1; i <= 5; i++) {
                skin.getEntityMap().put("PILL_" + i, entity());
            }

            for (JudgmentResult result : JudgmentResult.values()) {
                noteCounter.put(result, numberEntity());
            }

            setField(render, "rank", rank);
            setField(render, "skin", skin);
            setField(render, "entities_matrix", new EntityMatrix());
            setField(render, "note_counter", noteCounter);
            setField(render, "score_entity", score);
            setField(render, "jamcombo_entity", jamCombo);
            setField(render, "jambar_entity", jamBar);
            setField(render, "lifebar_entity", life);
            setField(render, "pills_draw", pills);
            setField(render, "combo_entity", combo);
            setField(render, "maxcombo_entity", maxCombo);
        }

        String initialSnapshotJson() throws Exception {
            return snapshotJson(null, null);
        }

        String apply(JudgmentResult input) throws Exception {
            EnumMap<JudgmentResult, Integer> before = judgmentCounts();
            render.setNoteJudgment(new NoteEntity(spriteList(8.0, 8.0), Event.Channel.NOTE_1, 10.0, 10.0), input);
            JudgmentResult result = changedJudgment(before);
            return snapshotJson(input, result);
        }

        private JudgmentResult changedJudgment(EnumMap<JudgmentResult, Integer> before) {
            for (JudgmentResult result : JudgmentResult.values()) {
                if (noteCounter.get(result).getNumber() > before.get(result)) {
                    return result;
                }
            }
            throw new IllegalStateException("No judgment counter changed");
        }

        private EnumMap<JudgmentResult, Integer> judgmentCounts() {
            EnumMap<JudgmentResult, Integer> counts = new EnumMap<JudgmentResult, Integer>(JudgmentResult.class);
            for (JudgmentResult result : JudgmentResult.values()) {
                counts.put(result, noteCounter.get(result).getNumber());
            }
            return counts;
        }

        private String snapshotJson(JudgmentResult input, JudgmentResult result) throws Exception {
            List<String> fields = new ArrayList<String>();
            if (input != null) {
                fields.add(field("input", resultName(input)));
            }
            if (result != null) {
                fields.add(field("result", resultName(result)));
            }
            fields.add(field("score", score.getNumber()));
            fields.add(field("combo", combo.getNumber()));
            fields.add(field("maxCombo", maxCombo.getNumber()));
            fields.add(field("life", life.getNumber()));
            fields.add(field("lifeLimit", life.getLimit()));
            fields.add(field("jamBar", jamBar.getNumber()));
            fields.add(field("jamBarLimit", jamBar.getLimit()));
            fields.add(field("jamCombo", jamCombo.getNumber()));
            fields.add(field("consecutiveCools", (Integer) getField(render, "consecutive_cools")));
            fields.add(field("pills", pills.size()));
            fields.add(rawField("judgments", judgmentCountsJson()));
            return object(fields);
        }

        private String judgmentCountsJson() {
            return object(
                    field("perfect", noteCounter.get(JudgmentResult.PERFECT).getNumber()),
                    field("cool", noteCounter.get(JudgmentResult.COOL).getNumber()),
                    field("good", noteCounter.get(JudgmentResult.GOOD).getNumber()),
                    field("bad", noteCounter.get(JudgmentResult.BAD).getNumber()),
                    field("miss", noteCounter.get(JudgmentResult.MISS).getNumber()));
        }
    }

    private static Render newRenderWithoutConstructor() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        return (Render) unsafe.allocateInstance(Render.class);
    }

    private static int lifeLimitForRank(int rank) {
        if (rank >= 2) {
            return 48000;
        }
        if (rank >= 1) {
            return 36000;
        }
        return 24000;
    }

    private static NumberEntity numberEntity() {
        return new NumberEntity(digitEntities(), 0.0, 0.0);
    }

    private static ComboCounterEntity comboCounter() {
        return new ComboCounterEntity(digitEntities(), null, 0.0, 0.0);
    }

    private static BarEntity barEntity() {
        return new BarEntity(spriteList(12.0, 12.0), 0.0, 0.0);
    }

    private static Entity entity() {
        return new Entity(spriteList(8.0, 8.0), 0.0, 0.0);
    }

    private static List<Entity> digitEntities() {
        List<Entity> digits = new ArrayList<Entity>();
        for (int i = 0; i < 10; i++) {
            digits.add(entity());
        }
        return digits;
    }

    private static SpriteList spriteList(double width, double height) {
        SpriteList list = new SpriteList(0.0);
        list.add(new FakeSprite(width, height));
        return list;
    }

    private static String resultName(JudgmentResult result) {
        return result.name().toLowerCase();
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static Object getField(Object target, String fieldName) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        return field.get(target);
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

    private static String object(List<String> fields) {
        return object(fields.toArray(new String[0]));
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

    private static final class FakeSprite implements Sprite {
        private final double width;
        private final double height;

        private FakeSprite(double width, double height) {
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
        }

        @Override
        public void draw(double x, double y, int width, int height, ByteBuffer buffer) {
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY) {
        }

        @Override
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height, ByteBuffer buffer) {
        }
    }
}

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
import org.open2jam.game.judgment.TimeJudgment;
import org.open2jam.parsers.Event;
import org.open2jam.render.entities.BarEntity;
import org.open2jam.render.entities.ComboCounterEntity;
import org.open2jam.render.entities.Entity;
import org.open2jam.render.entities.LongNoteEntity;
import org.open2jam.render.entities.NoteEntity;
import org.open2jam.render.entities.NumberEntity;
import org.open2jam.render.lwjgl.Texture;

import sun.misc.Unsafe;

class RenderLongNoteReleaseOracleFixtureTest {
    private static final Path FIXTURE = Path.of("rewrite/godot/test/fixtures/long-note-release-oracle.json");
    private static final double START_MS = 1000.0;
    private static final double END_MS = 1300.0;
    private static final int LANE = 2;
    private static final int SAMPLE_ID = 3;
    private static final Event.Channel CHANNEL = Event.Channel.NOTE_3;

    @Test
    void longNoteReleaseOracleFixtureMatchesJavaRenderReleaseJudgment() throws Exception {
        String expected = oracleJson();
        if (Boolean.getBoolean("open2jam.updateLongNoteReleaseOracleFixture")) {
            Files.createDirectories(FIXTURE.getParent());
            Files.writeString(FIXTURE, expected + "\n", StandardCharsets.UTF_8);
        }

        assertTrue(Files.exists(FIXTURE), "Missing Godot long note release oracle fixture: " + FIXTURE);
        assertEquals(expected, Files.readString(FIXTURE, StandardCharsets.UTF_8).trim());
    }

    private static String oracleJson() throws Exception {
        List<String> cases = new ArrayList<String>();
        cases.add(releaseCase("tail_cool", END_MS));
        cases.add(releaseCase("tail_late_bad", END_MS + 130.0));
        cases.add(releaseCase("tail_early_miss", END_MS - 200.0));
        cases.add(releaseCase("tail_late_miss", END_MS + 180.0));

        return object(
                field("schemaVersion", 1),
                field("source", "Render.check_keyboard release with Render.check_judgment JUDGE"),
                field("judgmentType", "time"),
                field("rank", 0),
                field("lane", LANE),
                field("sampleId", SAMPLE_ID),
                field("startMs", START_MS),
                field("endMs", END_MS),
                field("pressMs", START_MS),
                rawField("cases", array(cases)));
    }

    private static String releaseCase(String name, double releaseMs) throws Exception {
        RenderHarness harness = new RenderHarness();
        LongNoteEntity note = longNote();
        note.setTime(START_MS);
        note.setEndTime(END_MS);
        note.setHitTime(0.0);
        note.setState(NoteEntity.State.LN_HEAD_JUDGE);

        harness.render.check_judgment(note, START_MS);
        Snapshot afterHead = harness.snapshot(note, harness.latestLongflare(CHANNEL));
        EnumMap<JudgmentResult, Integer> beforeRelease = harness.judgmentCounts();

        Entity longflare = harness.latestLongflare(CHANNEL);
        harness.releaseHeldLongNote(note, CHANNEL, releaseMs);
        Snapshot afterRelease = harness.snapshot(note, longflare);
        JudgmentResult tailResult = harness.addedJudgment(beforeRelease);

        return object(
                field("name", name),
                field("releaseMs", releaseMs),
                field("tailHitTimeMs", END_MS - releaseMs),
                field("tailResult", resultName(tailResult)),
                rawField("afterHead", afterHead.toJson()),
                rawField("afterRelease", afterRelease.toJson()));
    }

    private static LongNoteEntity longNote() {
        return new LongNoteEntity(
                spriteList(24.0, 12.0),
                spriteList(24.0, 10.0),
                spriteList(24.0, 8.0),
                spriteList(24.0, 12.0),
                CHANNEL,
                100.0,
                480.0);
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
        private final EnumMap<Event.Channel, Entity> longflare;

        RenderHarness() throws Exception {
            render = newRenderWithoutConstructor();
            noteCounter = new EnumMap<JudgmentResult, NumberEntity>(JudgmentResult.class);
            score = numberEntity();
            jamCombo = comboCounter();
            jamCombo.setThreshold(1);
            jamBar = barEntity();
            jamBar.setLimit(50);
            life = barEntity();
            life.setLimit(24000);
            life.setNumber(24000);
            pills = new LinkedList<Entity>();
            combo = comboCounter();
            combo.setThreshold(2);
            maxCombo = numberEntity();
            longflare = new EnumMap<Event.Channel, Entity>(Event.Channel.class);

            Skin skin = new Skin();
            skin.judgment_line = 480;
            skin.getEntityMap().put("EFFECT_JUDGMENT_COOL", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_GOOD", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_BAD", entity());
            skin.getEntityMap().put("EFFECT_JUDGMENT_MISS", entity());
            skin.getEntityMap().put("EFFECT_CLICK", entity());
            skin.getEntityMap().put("EFFECT_LONGFLARE", entity());
            for (int i = 1; i <= 5; i++) {
                skin.getEntityMap().put("PILL_" + i, entity());
            }

            for (JudgmentResult result : JudgmentResult.values()) {
                noteCounter.put(result, numberEntity());
            }

            setField(render, "rank", 0);
            setField(render, "skin", skin);
            setField(render, "entities_matrix", new EntityMatrix());
            setField(render, "judge", new TimeJudgment());
            setField(render, "effectiveJudgmentFactor", 1.0);
            setField(render, "longflare", longflare);
            setField(render, "note_counter", noteCounter);
            setField(render, "score_entity", score);
            setField(render, "jamcombo_entity", jamCombo);
            setField(render, "jambar_entity", jamBar);
            setField(render, "lifebar_entity", life);
            setField(render, "pills_draw", pills);
            setField(render, "combo_entity", combo);
            setField(render, "maxcombo_entity", maxCombo);
        }

        Entity latestLongflare(Event.Channel channel) {
            return longflare.get(channel);
        }

        void releaseHeldLongNote(LongNoteEntity note, Event.Channel channel, double releaseMs) {
            Entity lf = longflare.remove(channel);
            if (lf != null) {
                lf.setDead(true);
            }
            note.updateHit(releaseMs, 1.0);
            note.setState(NoteEntity.State.JUDGE);
            render.check_judgment(note, releaseMs);
        }

        EnumMap<JudgmentResult, Integer> judgmentCounts() {
            EnumMap<JudgmentResult, Integer> counts = new EnumMap<JudgmentResult, Integer>(JudgmentResult.class);
            for (JudgmentResult result : JudgmentResult.values()) {
                counts.put(result, noteCounter.get(result).getNumber());
            }
            return counts;
        }

        JudgmentResult addedJudgment(EnumMap<JudgmentResult, Integer> previousCounts) {
            for (JudgmentResult result : JudgmentResult.values()) {
                int before = previousCounts.get(result);
                int after = noteCounter.get(result).getNumber();
                if (after > before) {
                    return result;
                }
            }
            throw new IllegalStateException("No tail judgment was added");
        }

        Snapshot snapshot(LongNoteEntity note, Entity observedLongflare) {
            return new Snapshot(
                    stateName(note.getState()),
                    note.getHitTime(),
                    longflare.containsKey(note.getChannel()),
                    observedLongflare != null && observedLongflare.isDead(),
                    score.getNumber(),
                    combo.getNumber(),
                    maxCombo.getNumber(),
                    life.getNumber(),
                    life.getLimit(),
                    jamBar.getNumber(),
                    jamBar.getLimit(),
                    jamCombo.getNumber(),
                    pills.size(),
                    judgmentCountsJson());
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

    private static final class Snapshot {
        private final String noteState;
        private final double hitTimeMs;
        private final boolean longflarePresent;
        private final boolean observedLongflareDead;
        private final int score;
        private final int combo;
        private final int maxCombo;
        private final int life;
        private final int lifeLimit;
        private final int jamBar;
        private final int jamBarLimit;
        private final int jamCombo;
        private final int pills;
        private final String judgments;

        Snapshot(String noteState, double hitTimeMs, boolean longflarePresent, boolean observedLongflareDead,
                int score, int combo, int maxCombo, int life, int lifeLimit, int jamBar, int jamBarLimit,
                int jamCombo, int pills, String judgments) {
            this.noteState = noteState;
            this.hitTimeMs = hitTimeMs;
            this.longflarePresent = longflarePresent;
            this.observedLongflareDead = observedLongflareDead;
            this.score = score;
            this.combo = combo;
            this.maxCombo = maxCombo;
            this.life = life;
            this.lifeLimit = lifeLimit;
            this.jamBar = jamBar;
            this.jamBarLimit = jamBarLimit;
            this.jamCombo = jamCombo;
            this.pills = pills;
            this.judgments = judgments;
        }

        String toJson() {
            return object(
                    field("noteState", noteState),
                    field("hitTimeMs", hitTimeMs),
                    field("longflarePresent", longflarePresent),
                    field("observedLongflareDead", observedLongflareDead),
                    field("score", score),
                    field("combo", combo),
                    field("maxCombo", maxCombo),
                    field("life", life),
                    field("lifeLimit", lifeLimit),
                    field("jamBar", jamBar),
                    field("jamBarLimit", jamBarLimit),
                    field("jamCombo", jamCombo),
                    field("pills", pills),
                    rawField("judgments", judgments));
        }
    }

    private static Render newRenderWithoutConstructor() throws Exception {
        Field field = Unsafe.class.getDeclaredField("theUnsafe");
        field.setAccessible(true);
        Unsafe unsafe = (Unsafe) field.get(null);
        return (Render) unsafe.allocateInstance(Render.class);
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

    private static String stateName(NoteEntity.State state) {
        return state.name();
    }

    private static String resultName(JudgmentResult result) {
        return result.name().toLowerCase();
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Field field = Render.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }

    private static final class FakeSprite implements Sprite {
        private final double width;
        private final double height;

        FakeSprite(double width, double height) {
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
        public void draw(double x, double y, float scaleX, float scaleY, int width, int height,
                ByteBuffer buffer) {
        }
    }

    private static String array(List<String> items) {
        StringBuilder out = new StringBuilder();
        out.append('[');
        for (int i = 0; i < items.size(); i++) {
            if (i > 0) {
                out.append(',');
            }
            out.append(items.get(i));
        }
        out.append(']');
        return out.toString();
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

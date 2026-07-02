package org.open2jam.render.entities;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;
import org.open2jam.render.Sprite;
import org.open2jam.render.SpriteList;
import org.open2jam.render.lwjgl.Texture;

class MeasureEntityTest {
    @Test
    void measureOnlyAdvancesCurrentMeasureWhenJudgmentIsInvoked() {
        AtomicInteger currentMeasure = new AtomicInteger(0);
        MeasureEntity measure = new MeasureEntity(spriteList(), 0.0, 0.0);
        measure.setTime(0.0);
        measure.setOnJudge(currentMeasure::incrementAndGet);

        measure.move(1000.0);

        assertEquals(0, currentMeasure.get());
        assertFalse(measure.isDead());

        measure.judgment();

        assertEquals(1, currentMeasure.get());
        assertTrue(measure.isDead());
    }

    private static SpriteList spriteList() {
        SpriteList sprites = new SpriteList(0.0);
        sprites.add(new FakeSprite());
        return sprites;
    }

    private static final class FakeSprite implements Sprite {
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

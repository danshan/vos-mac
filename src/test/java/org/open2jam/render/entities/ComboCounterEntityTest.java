package org.open2jam.render.entities;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.open2jam.render.Sprite;
import org.open2jam.render.lwjgl.Texture;

class ComboCounterEntityTest {
    @Test
    void moveKeepsJavaOvershootWhenWobblePassesBasePosition() {
        ComboCounterEntity counter = new ComboCounterEntity(digitEntities(), null, 100.0, 210.0);

        counter.incNumber();
        counter.move(21.0);

        assertEquals(209.5, counter.getY(), 0.0001);
    }

    private static List<Entity> digitEntities() {
        List<Entity> entities = new ArrayList<Entity>();
        for (int i = 0; i < 10; i++) {
            entities.add(new Entity(new FakeSprite(46.0, 71.0), 0.0, 0.0));
        }
        return entities;
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

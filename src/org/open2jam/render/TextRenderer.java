package org.open2jam.render;

public interface TextRenderer {
    int ALIGN_LEFT = 0;
    int ALIGN_RIGHT = 1;
    int ALIGN_CENTER = 2;

    void drawString(float x, float y, String text, float scaleX, float scaleY);
    void drawString(float x, float y, String text, float scaleX, float scaleY, int format);
    void destroy();
}

package org.open2jam.render.lwjgl;

import java.awt.Font;
import org.open2jam.render.TextRenderer;

public class LWJGLTextRenderer implements TextRenderer {
    private final TrueTypeFont font;

    public LWJGLTextRenderer(Font font, boolean antiAlias) {
        this.font = new TrueTypeFont(font, antiAlias);
    }

    @Override
    public void drawString(float x, float y, String text, float scaleX, float scaleY) {
        font.drawString(x, y, text, scaleX, scaleY);
    }

    @Override
    public void drawString(float x, float y, String text, float scaleX, float scaleY, int format) {
        int lwjglFormat = TrueTypeFont.ALIGN_LEFT;
        if(format == ALIGN_RIGHT) {
            lwjglFormat = TrueTypeFont.ALIGN_RIGHT;
        } else if(format == ALIGN_CENTER) {
            lwjglFormat = TrueTypeFont.ALIGN_CENTER;
        }
        font.drawString(x, y, text, scaleX, scaleY, lwjglFormat);
    }

    @Override
    public void destroy() {
        font.destroy();
    }
}

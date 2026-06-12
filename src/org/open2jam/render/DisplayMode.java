package org.open2jam.render;

public class DisplayMode {
    private final int width;
    private final int height;
    private final int bitsPerPixel;
    private final int frequency;
    private final boolean fullscreenCapable;

    public DisplayMode(int width, int height) {
        this(width, height, 0, 0, true);
    }

    public DisplayMode(int width, int height, int bitsPerPixel, int frequency, boolean fullscreenCapable) {
        this.width = width;
        this.height = height;
        this.bitsPerPixel = bitsPerPixel;
        this.frequency = frequency;
        this.fullscreenCapable = fullscreenCapable;
    }

    public int getWidth() {
        return width;
    }

    public int getHeight() {
        return height;
    }

    public int getBitsPerPixel() {
        return bitsPerPixel;
    }

    public int getFrequency() {
        return frequency;
    }

    public boolean isFullscreenCapable() {
        return fullscreenCapable;
    }

    @Override
    public String toString() {
        String suffix = frequency > 0 ? " @" + frequency + "Hz" : "";
        return width + "x" + height + suffix;
    }
}

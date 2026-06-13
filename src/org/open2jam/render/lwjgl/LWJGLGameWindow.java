package org.open2jam.render.lwjgl;

import static org.lwjgl.opengl.GL11.GL_BLEND;
import static org.lwjgl.opengl.GL11.GL_COLOR_BUFFER_BIT;
import static org.lwjgl.opengl.GL11.GL_DEPTH_TEST;
import static org.lwjgl.opengl.GL11.GL_MODELVIEW;
import static org.lwjgl.opengl.GL11.GL_ONE;
import static org.lwjgl.opengl.GL11.GL_ONE_MINUS_SRC_ALPHA;
import static org.lwjgl.opengl.GL11.GL_PROJECTION;
import static org.lwjgl.opengl.GL11.GL_SCISSOR_TEST;
import static org.lwjgl.opengl.GL11.GL_TEXTURE_2D;
import static org.lwjgl.opengl.GL11.glBlendFunc;
import static org.lwjgl.opengl.GL11.glClear;
import static org.lwjgl.opengl.GL11.glClearColor;
import static org.lwjgl.opengl.GL11.glDisable;
import static org.lwjgl.opengl.GL11.glEnable;
import static org.lwjgl.opengl.GL11.glLoadIdentity;
import static org.lwjgl.opengl.GL11.glMatrixMode;
import static org.lwjgl.opengl.GL11.glOrtho;
import static org.lwjgl.opengl.GL11.glScalef;
import static org.lwjgl.opengl.GL11.glScissor;
import static org.lwjgl.opengl.GL11.glViewport;

import java.awt.BorderLayout;
import java.awt.Dimension;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.geom.AffineTransform;
import java.awt.event.KeyAdapter;
import java.awt.event.KeyEvent;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.lang.reflect.InvocationTargetException;
import java.util.HashSet;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JFrame;
import javax.swing.SwingUtilities;
import javax.swing.Timer;
import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.awt.AWTGLCanvas;
import org.lwjgl.opengl.awt.GLData;
import org.open2jam.input.Keys;
import org.open2jam.render.DisplayMode;
import org.open2jam.render.GameWindow;
import org.open2jam.render.GameWindowCallback;

public class LWJGLGameWindow implements GameWindow {
    private static final Logger LOG = Logger.getLogger(LWJGLGameWindow.class.getName());

    private final Set<Integer> keysDown = new HashSet<Integer>();
    private final Object closeLock = new Object();
    private GameWindowCallback callback;
    private volatile boolean gameRunning = true;
    private volatile boolean closed;
    private boolean renderingFrame;
    private boolean closeRequested;
    private boolean closeRequestedNotifyCallback;
    private volatile Throwable renderingFailure;
    private int width = 800;
    private int height = 600;
    private boolean fullscreen;
    private boolean vsync = true;
    private JFrame frame;
    private GameCanvas canvas;
    private Timer renderTimer;
    private String title = "open2jam";
    private TextureLoader textureLoader;
    private float scaleX = 1f;
    private float scaleY = 1f;
    private GraphicsDevice fullscreenDevice;

    TextureLoader getTextureLoader() {
        return textureLoader;
    }

    @Override
    public void setTitle(String title) {
        this.title = title;
        if(frame != null) {
            SwingUtilities.invokeLater(() -> frame.setTitle(title));
        }
    }

    @Override
    public void setDisplay(DisplayMode dm, boolean vsync, boolean fs) {
        width = dm.getWidth();
        height = dm.getHeight();
        this.vsync = vsync;
        fullscreen = fs;
    }

    @Override
    public int getResolutionHeight() {
        return height;
    }

    @Override
    public int getResolutionWidth() {
        return width;
    }

    @Override
    public void startRendering() {
        if(callback == null) throw new RuntimeException("Need callback to start rendering");
        gameRunning = true;
        closed = false;
        renderingFailure = null;

        runOnEventDispatchThread(this::createWindow);
        waitForClose();
        if(renderingFailure != null) {
            throw new IllegalStateException("Game window failed", renderingFailure);
        }
    }

    @Override
    public void initScales(double width, double height) {
        scaleX = (float)(this.width / width);
        scaleY = (float)(this.height / height);
    }

    @Override
    public void setGameWindowCallback(GameWindowCallback callback) {
        this.callback = callback;
    }

    @Override
    public boolean isKeyDown(int keyCode) {
        synchronized(keysDown) {
            return keysDown.contains(keyCode);
        }
    }

    @Override
    public void destroy() {
        closeWindow(true);
    }

    @Override
    public void update() {
        GameCanvas currentCanvas = canvas;
        if(currentCanvas != null) currentCanvas.swapBuffers();
    }

    @Override
    public void pollInput() {
    }

    private void createWindow() {
        GLData data = new GLData();
        data.doubleBuffer = true;
        data.majorVersion = 2;
        data.minorVersion = 1;
        data.swapInterval = vsync ? 1 : 0;

        canvas = new GameCanvas(data);
        canvas.setPreferredSize(new Dimension(width, height));
        canvas.setSize(width, height);
        canvas.setFocusable(true);
        canvas.addKeyListener(new GameKeyListener());

        frame = new JFrame(title);
        frame.setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
        frame.addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                closeWindow(true);
            }
        });
        frame.addKeyListener(new GameKeyListener());
        frame.setLayout(new BorderLayout());
        frame.add(canvas, BorderLayout.CENTER);

        if(fullscreen) {
            fullscreenDevice = GraphicsEnvironment.getLocalGraphicsEnvironment()
                    .getDefaultScreenDevice();
            frame.setUndecorated(true);
            fullscreenDevice.setFullScreenWindow(frame);
        } else {
            frame.pack();
            frame.setLocationRelativeTo(null);
        }

        renderTimer = new Timer(1, event -> {
            if(gameRunning && canvas != null && canvas.isDisplayable()) {
                canvas.render();
            }
        });
        renderTimer.setCoalesce(true);

        frame.setVisible(true);
        canvas.requestFocusInWindow();
        renderTimer.start();
    }

    private void configureOpenGL() {
        GL.createCapabilities();
        glEnable(GL_TEXTURE_2D);
        glDisable(GL_DEPTH_TEST);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
        glEnable(GL_SCISSOR_TEST);
        configureViewportAndProjection();
        textureLoader = new TextureLoader();
    }

    private void renderFrame() {
        if(!gameRunning) return;

        configureViewportAndProjection();
        glClear(GL_COLOR_BUFFER_BIT);
        glLoadIdentity();
        glScalef(scaleX, scaleY, 1);
        callback.frameRendering();
    }

    private void configureViewportAndProjection() {
        int framebufferWidth = getFramebufferWidth();
        int framebufferHeight = getFramebufferHeight();
        glViewport(0, 0, framebufferWidth, framebufferHeight);
        glScissor(0, 0, framebufferWidth, framebufferHeight);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, width, height, 0, -1, 1);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
    }

    private int getFramebufferWidth() {
        return Math.max(1, Math.round(getCanvasWidth() * getScaleX()));
    }

    private int getFramebufferHeight() {
        return Math.max(1, Math.round(getCanvasHeight() * getScaleY()));
    }

    private int getCanvasWidth() {
        return canvas == null || canvas.getWidth() <= 0 ? width : canvas.getWidth();
    }

    private int getCanvasHeight() {
        return canvas == null || canvas.getHeight() <= 0 ? height : canvas.getHeight();
    }

    private float getScaleX() {
        return getDefaultTransformScaleX();
    }

    private float getScaleY() {
        return getDefaultTransformScaleY();
    }

    private float getDefaultTransformScaleX() {
        if(canvas == null || canvas.getGraphicsConfiguration() == null) return 1f;
        AffineTransform transform = canvas.getGraphicsConfiguration().getDefaultTransform();
        return (float)Math.max(1.0, transform.getScaleX());
    }

    private float getDefaultTransformScaleY() {
        if(canvas == null || canvas.getGraphicsConfiguration() == null) return 1f;
        AffineTransform transform = canvas.getGraphicsConfiguration().getDefaultTransform();
        return (float)Math.max(1.0, transform.getScaleY());
    }

    private void closeWindow(boolean notifyCallback) {
        if(SwingUtilities.isEventDispatchThread()) {
            if(renderingFrame) {
                closeRequested = true;
                closeRequestedNotifyCallback |= notifyCallback;
                gameRunning = false;
                return;
            }
            doCloseWindow(notifyCallback);
        } else {
            SwingUtilities.invokeLater(() -> doCloseWindow(notifyCallback));
        }
    }

    private void doCloseWindow(boolean notifyCallback) {
        if(closed) return;

        closeRequested = false;
        closeRequestedNotifyCallback = false;
        closed = true;
        gameRunning = false;
        synchronized(keysDown) {
            keysDown.clear();
        }
        if(renderTimer != null) {
            renderTimer.stop();
            renderTimer = null;
        }
        if(fullscreenDevice != null && fullscreenDevice.getFullScreenWindow() == frame) {
            fullscreenDevice.setFullScreenWindow(null);
            fullscreenDevice = null;
        }
        if(frame != null) {
            frame.dispose();
            frame = null;
        }
        canvas = null;
        try {
            if(notifyCallback && callback != null) callback.windowClosed();
        } catch (Throwable failure) {
            LOG.log(Level.SEVERE, "Game window close callback failed", failure);
        } finally {
            synchronized(closeLock) {
                closeLock.notifyAll();
            }
        }
    }

    private void waitForClose() {
        synchronized(closeLock) {
            while(!closed) {
                try {
                    closeLock.wait();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    closeWindow(true);
                    break;
                }
            }
        }
    }

    private void runOnEventDispatchThread(Runnable task) {
        if(SwingUtilities.isEventDispatchThread()) {
            task.run();
            return;
        }
        try {
            SwingUtilities.invokeAndWait(task);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Interrupted while creating game window", e);
        } catch (InvocationTargetException e) {
            throw new IllegalStateException("Unable to create game window", e.getCause());
        }
    }

    private final class GameCanvas extends AWTGLCanvas {
        private GameCanvas(GLData data) {
            super(data);
        }

        @Override
        public void initGL() {
            try {
                configureOpenGL();
                callback.initialise();
            } catch (Throwable failure) {
                renderingFailure = failure;
                LOG.log(Level.SEVERE, "Game window initialization failed", failure);
                closeWindow(true);
            }
        }

        @Override
        public void paintGL() {
            renderingFrame = true;
            try {
                renderFrame();
                swapBuffers();
            } catch (Throwable failure) {
                renderingFailure = failure;
                LOG.log(Level.SEVERE, "Game window rendering failed", failure);
                closeRequested = true;
                closeRequestedNotifyCallback = true;
                gameRunning = false;
            } finally {
                renderingFrame = false;
            }
            if(closeRequested) {
                SwingUtilities.invokeLater(() -> doCloseWindow(closeRequestedNotifyCallback));
            }
        }
    }

    private final class GameKeyListener extends KeyAdapter {
        @Override
        public void keyPressed(KeyEvent event) {
            int key = Keys.fromAwtKeyCode(event.getKeyCode(), event.getKeyLocation());
            if(key == Keys.NONE) return;

            synchronized(keysDown) {
                keysDown.add(key);
            }
            if(key == Keys.getIndex("ESCAPE")) {
                closeWindow(true);
            }
        }

        @Override
        public void keyReleased(KeyEvent event) {
            int key = Keys.fromAwtKeyCode(event.getKeyCode(), event.getKeyLocation());
            if(key == Keys.NONE) return;

            synchronized(keysDown) {
                keysDown.remove(key);
            }
        }
    }
}

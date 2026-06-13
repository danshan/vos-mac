package org.open2jam.render.lwjgl;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.junit.jupiter.api.Test;
import org.open2jam.render.GameWindowCallback;

class LWJGLGameWindowTest {
    @Test
    void closeStillCompletesWhenCallbackThrows() throws Exception {
        LWJGLGameWindow window = new LWJGLGameWindow();
        window.setGameWindowCallback(new ThrowingCloseCallback());

        Method close = LWJGLGameWindow.class.getDeclaredMethod("doCloseWindow", boolean.class);
        close.setAccessible(true);

        Logger logger = Logger.getLogger(LWJGLGameWindow.class.getName());
        Level previousLevel = logger.getLevel();
        logger.setLevel(Level.OFF);
        try {
            assertDoesNotThrow(() -> close.invoke(window, true));
        } finally {
            logger.setLevel(previousLevel);
        }
        assertTrue(closed(window));
    }

    private static boolean closed(LWJGLGameWindow window) throws Exception {
        Field closed = LWJGLGameWindow.class.getDeclaredField("closed");
        closed.setAccessible(true);
        return closed.getBoolean(window);
    }

    private static final class ThrowingCloseCallback implements GameWindowCallback {
        @Override
        public void initialise() {
        }

        @Override
        public void frameRendering() {
        }

        @Override
        public void windowClosed() {
            throw new IllegalStateException("close callback failed");
        }
    }
}

package org.open2jam.input;

import java.awt.event.KeyEvent;
import java.util.HashMap;
import java.util.Map;
import org.lwjgl.glfw.GLFW;

public final class Keys {
    public static final int NONE = -1;

    private static final Map<Integer, String> NAMES = new HashMap<Integer, String>();
    private static final Map<String, Integer> CODES = new HashMap<String, Integer>();

    static {
        register(GLFW.GLFW_KEY_ESCAPE, "ESCAPE");
        register(GLFW.GLFW_KEY_ENTER, "RETURN");
        register(GLFW.GLFW_KEY_SPACE, "SPACE");
        register(GLFW.GLFW_KEY_LEFT_SHIFT, "LSHIFT");
        register(GLFW.GLFW_KEY_RIGHT_SHIFT, "RSHIFT");
        register(GLFW.GLFW_KEY_LEFT_CONTROL, "LCONTROL");
        register(GLFW.GLFW_KEY_RIGHT_CONTROL, "RCONTROL");
        register(GLFW.GLFW_KEY_LEFT_ALT, "LMENU");
        register(GLFW.GLFW_KEY_RIGHT_ALT, "RMENU");
        register(GLFW.GLFW_KEY_UP, "UP");
        register(GLFW.GLFW_KEY_DOWN, "DOWN");
        register(GLFW.GLFW_KEY_LEFT, "LEFT");
        register(GLFW.GLFW_KEY_RIGHT, "RIGHT");
        register(GLFW.GLFW_KEY_TAB, "TAB");
        register(GLFW.GLFW_KEY_BACKSPACE, "BACK");
        register(GLFW.GLFW_KEY_DELETE, "DELETE");
        register(GLFW.GLFW_KEY_HOME, "HOME");
        register(GLFW.GLFW_KEY_END, "END");
        register(GLFW.GLFW_KEY_PAGE_UP, "PRIOR");
        register(GLFW.GLFW_KEY_PAGE_DOWN, "NEXT");
        register(GLFW.GLFW_KEY_MINUS, "MINUS");
        register(GLFW.GLFW_KEY_EQUAL, "EQUALS");
        register(GLFW.GLFW_KEY_COMMA, "COMMA");
        register(GLFW.GLFW_KEY_PERIOD, "PERIOD");
        register(GLFW.GLFW_KEY_SLASH, "SLASH");
        register(GLFW.GLFW_KEY_SEMICOLON, "SEMICOLON");
        register(GLFW.GLFW_KEY_APOSTROPHE, "APOSTROPHE");
        register(GLFW.GLFW_KEY_LEFT_BRACKET, "LBRACKET");
        register(GLFW.GLFW_KEY_RIGHT_BRACKET, "RBRACKET");
        register(GLFW.GLFW_KEY_BACKSLASH, "BACKSLASH");

        for(int key = GLFW.GLFW_KEY_A; key <= GLFW.GLFW_KEY_Z; key++) {
            register(key, Character.toString((char)('A' + key - GLFW.GLFW_KEY_A)));
        }
        for(int key = GLFW.GLFW_KEY_0; key <= GLFW.GLFW_KEY_9; key++) {
            register(key, Character.toString((char)('0' + key - GLFW.GLFW_KEY_0)));
        }
        for(int key = GLFW.GLFW_KEY_F1; key <= GLFW.GLFW_KEY_F12; key++) {
            register(key, "F" + (key - GLFW.GLFW_KEY_F1 + 1));
        }
    }

    private Keys() {
    }

    public static String getName(int code) {
        String name = NAMES.get(code);
        return name == null ? "UNKNOWN" : name;
    }

    public static int getIndex(String name) {
        if(name == null) return NONE;
        Integer code = CODES.get(name.toUpperCase());
        return code == null ? NONE : code;
    }

    public static int fromAwtKeyCode(int keyCode, int keyLocation) {
        if(keyCode >= KeyEvent.VK_A && keyCode <= KeyEvent.VK_Z) {
            return GLFW.GLFW_KEY_A + keyCode - KeyEvent.VK_A;
        }
        if(keyCode >= KeyEvent.VK_0 && keyCode <= KeyEvent.VK_9) {
            return GLFW.GLFW_KEY_0 + keyCode - KeyEvent.VK_0;
        }
        if(keyCode >= KeyEvent.VK_F1 && keyCode <= KeyEvent.VK_F12) {
            return GLFW.GLFW_KEY_F1 + keyCode - KeyEvent.VK_F1;
        }

        switch(keyCode) {
            case KeyEvent.VK_ESCAPE: return GLFW.GLFW_KEY_ESCAPE;
            case KeyEvent.VK_ENTER: return GLFW.GLFW_KEY_ENTER;
            case KeyEvent.VK_SPACE: return GLFW.GLFW_KEY_SPACE;
            case KeyEvent.VK_SHIFT:
                return keyLocation == KeyEvent.KEY_LOCATION_RIGHT
                        ? GLFW.GLFW_KEY_RIGHT_SHIFT
                        : GLFW.GLFW_KEY_LEFT_SHIFT;
            case KeyEvent.VK_CONTROL:
                return keyLocation == KeyEvent.KEY_LOCATION_RIGHT
                        ? GLFW.GLFW_KEY_RIGHT_CONTROL
                        : GLFW.GLFW_KEY_LEFT_CONTROL;
            case KeyEvent.VK_ALT:
                return keyLocation == KeyEvent.KEY_LOCATION_RIGHT
                        ? GLFW.GLFW_KEY_RIGHT_ALT
                        : GLFW.GLFW_KEY_LEFT_ALT;
            case KeyEvent.VK_UP: return GLFW.GLFW_KEY_UP;
            case KeyEvent.VK_DOWN: return GLFW.GLFW_KEY_DOWN;
            case KeyEvent.VK_LEFT: return GLFW.GLFW_KEY_LEFT;
            case KeyEvent.VK_RIGHT: return GLFW.GLFW_KEY_RIGHT;
            case KeyEvent.VK_TAB: return GLFW.GLFW_KEY_TAB;
            case KeyEvent.VK_BACK_SPACE: return GLFW.GLFW_KEY_BACKSPACE;
            case KeyEvent.VK_DELETE: return GLFW.GLFW_KEY_DELETE;
            case KeyEvent.VK_HOME: return GLFW.GLFW_KEY_HOME;
            case KeyEvent.VK_END: return GLFW.GLFW_KEY_END;
            case KeyEvent.VK_PAGE_UP: return GLFW.GLFW_KEY_PAGE_UP;
            case KeyEvent.VK_PAGE_DOWN: return GLFW.GLFW_KEY_PAGE_DOWN;
            case KeyEvent.VK_MINUS: return GLFW.GLFW_KEY_MINUS;
            case KeyEvent.VK_EQUALS: return GLFW.GLFW_KEY_EQUAL;
            case KeyEvent.VK_COMMA: return GLFW.GLFW_KEY_COMMA;
            case KeyEvent.VK_PERIOD: return GLFW.GLFW_KEY_PERIOD;
            case KeyEvent.VK_SLASH: return GLFW.GLFW_KEY_SLASH;
            case KeyEvent.VK_SEMICOLON: return GLFW.GLFW_KEY_SEMICOLON;
            case KeyEvent.VK_QUOTE: return GLFW.GLFW_KEY_APOSTROPHE;
            case KeyEvent.VK_OPEN_BRACKET: return GLFW.GLFW_KEY_LEFT_BRACKET;
            case KeyEvent.VK_CLOSE_BRACKET: return GLFW.GLFW_KEY_RIGHT_BRACKET;
            case KeyEvent.VK_BACK_SLASH: return GLFW.GLFW_KEY_BACKSLASH;
            default: return NONE;
        }
    }

    private static void register(int code, String name) {
        NAMES.put(code, name);
        CODES.put(name, code);
    }
}

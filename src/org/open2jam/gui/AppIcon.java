package org.open2jam.gui;

import java.awt.Image;
import java.awt.Taskbar;
import java.io.IOException;
import java.io.InputStream;
import javax.imageio.ImageIO;
import org.open2jam.util.Logger;

public final class AppIcon
{
    private static final String ICON_RESOURCE = "/resources/vosmac_icon.png";

    private AppIcon()
    {
    }

    public static Image load()
    {
        try (InputStream icon = AppIcon.class.getResourceAsStream(ICON_RESOURCE)) {
            if (icon == null) {
                Logger.global.warning("Application icon resource not found: " + ICON_RESOURCE);
                return null;
            }
            return ImageIO.read(icon);
        } catch (IOException e) {
            Logger.global.warning("Unable to load application icon: " + e.getMessage());
            return null;
        }
    }

    public static void installDockIcon()
    {
        Image icon = load();
        if (icon == null || !Taskbar.isTaskbarSupported()) {
            return;
        }

        try {
            Taskbar taskbar = Taskbar.getTaskbar();
            if (taskbar.isSupported(Taskbar.Feature.ICON_IMAGE)) {
                taskbar.setIconImage(icon);
            }
        } catch (UnsupportedOperationException | SecurityException e) {
            Logger.global.info("Unable to set Dock icon: " + e.getMessage());
        }
    }
}

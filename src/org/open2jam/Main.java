package org.open2jam;

import java.awt.EventQueue;
import java.io.File;
import java.io.PrintStream;
import java.util.logging.Handler;
import java.util.logging.Level;
import javax.swing.UIManager;
import org.open2jam.gui.Interface;
import org.open2jam.sound.SoundSystemException;
import org.open2jam.sound.VosAudioValidator;
import org.open2jam.util.Logger;

public class Main implements Runnable
{
    public static void main(String []args)
    {
        int cliStatus = runCli(args, System.out, System.err);
        if (cliStatus >= 0) {
            System.exit(cliStatus);
        }

        setupMacOSJava2DCompatibility();
        
        Config.openDB();
        
        setupLogging();

        trySetLAF();
        
        EventQueue.invokeLater(new Main());
    }

    static int runCli(String[] args, PrintStream out, PrintStream err) {
        if (args == null || args.length == 0) {
            return -1;
        }
        if (!"--validate-vos-audio".equals(args[0])) {
            return -1;
        }
        if (args.length != 2) {
            err.println("Usage: open2jam --validate-vos-audio <file.vos>");
            return 2;
        }
        try {
            VosAudioValidator.Result result = VosAudioValidator.validate(new File(args[1]));
            out.println("VOS audio validation OK");
            out.println("Title: " + result.title);
            out.println("Playable notes: " + result.playableNotes);
            out.println("MIDI samples: " + result.samples);
            out.println("Background MIDI notes: " + result.backgroundMidiNotes);
            out.println("Live MIDI notes: " + result.liveMidiNotes);
            out.println("Combined MIDI notes: " + (result.backgroundMidiNotes + result.liveMidiNotes));
            out.println("Performance signature: " + (result.performanceSignatureMatches ? "OK" : "FAILED"));
            out.println("Rendered MIDI samples: " + result.renderedSamples);
            out.println("PCM format: " + result.sampleRate + " Hz, " + result.channels + " channels, "
                    + result.bitsPerSample + " bit");
            out.println("Background PCM bytes: " + result.backgroundPcmBytes);
            out.println("Live PCM bytes: " + result.livePcmBytes);
            out.println("Total PCM bytes: " + result.totalPcmBytes);
            return 0;
        } catch (SoundSystemException e) {
            err.println("VOS audio validation failed: " + e.getMessage());
            return 1;
        }
    }

    private static void setupMacOSJava2DCompatibility()
    {
        if(!"macosx".equals(getOS()))return;

        if(System.getProperty("sun.java2d.opengl") == null) {
            System.setProperty("sun.java2d.opengl", "false");
        }
    }
    
    @Override
    public void run() {
        new Interface().setVisible(true);
    }

    private static void setupLogging()
    {
        //Config c = Config.get();
        //if(c.log_handle != null)Logger.global.addHandler(c.log_handle);
        for(Handler h : Logger.global.getHandlers())h.setLevel(Level.INFO);
        Logger.global.setLevel(Level.INFO);
    }

    private static void trySetLAF()
    {
        if("macosx".equals(getOS()))return;

        try {
            for(UIManager.LookAndFeelInfo info : UIManager.getInstalledLookAndFeels())
            {
                if("Nimbus".equals(info.getName())){
                    UIManager.setLookAndFeel(info.getClassName());
                    return;
                }
            }
            UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        } catch (Throwable e) {
            Logger.global.info(e.toString());
        }
    }

    private static String getOS()
    {
        String os = System.getProperty("os.name").toLowerCase();
        if(os.contains("win")){
            return "windows";
        }else if(os.contains("mac")){
            return "macosx";
        }else if(os.contains("nix") || os.contains("nux")){
            return "linux";
        }else if(os.contains("solaris")){
            return "solaris";
        }else{
            return os;
        }
    }
}

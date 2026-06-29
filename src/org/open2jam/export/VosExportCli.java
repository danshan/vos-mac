package org.open2jam.export;

import java.io.File;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;

public final class VosExportCli {
    private static final int STATUS_SUCCESS = 0;
    private static final int STATUS_EXPORT_FAILURE = 1;
    private static final int STATUS_USAGE_ERROR = 2;

    private static final String EXPORT_CATALOG = "--export-vos-catalog";
    private static final String EXPORT_GAMEPLAY = "--export-vos-gameplay";
    private static final String EXPORT_AUDIO = "--export-vos-audio";
    private static final String EXPORT_SELECTED = "--export-vos-selected";

    private VosExportCli() {
    }

    public static boolean isExportCommand(String arg) {
        return EXPORT_CATALOG.equals(arg)
                || EXPORT_GAMEPLAY.equals(arg)
                || EXPORT_AUDIO.equals(arg)
                || EXPORT_SELECTED.equals(arg);
    }

    public static int run(String[] args, PrintStream out, PrintStream err) {
        if (args == null || args.length == 0 || !isExportCommand(args[0])) {
            err.println("Usage: open2jam <vos-export-command>");
            return STATUS_USAGE_ERROR;
        }
        try {
            if (EXPORT_CATALOG.equals(args[0])) {
                return exportCatalog(args, err);
            }
            if (EXPORT_GAMEPLAY.equals(args[0])) {
                return exportGameplay(args, err);
            }
            if (EXPORT_AUDIO.equals(args[0])) {
                return exportAudio(args, err);
            }
            return exportSelected(args, err);
        } catch (Exception e) {
            err.println("VOS export failed: " + e.getMessage());
            return STATUS_EXPORT_FAILURE;
        }
    }

    private static int exportCatalog(String[] args, PrintStream err) throws Exception {
        if (args.length != 4 || !"--output".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-catalog --output <file> <file-or-directory>");
            return STATUS_USAGE_ERROR;
        }
        writeJson(new File(args[2]), new VosCatalogExporter().exportCatalog(new File(args[3])));
        return STATUS_SUCCESS;
    }

    private static int exportGameplay(String[] args, PrintStream err) throws Exception {
        if (args.length != 4 || !"--output".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-gameplay --output <file> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        writeJson(new File(args[2]), new VosGameplayExporter().exportGameplay(new File(args[3])));
        return STATUS_SUCCESS;
    }

    private static int exportAudio(String[] args, PrintStream err) throws Exception {
        if (args.length != 6 || !"--output".equals(args[1]) || !"--asset-dir".equals(args[3])) {
            err.println("Usage: open2jam --export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        writeJson(new File(args[2]), new VosAudioExporter().exportAudio(new File(args[5]), new File(args[4])));
        return STATUS_SUCCESS;
    }

    private static int exportSelected(String[] args, PrintStream err) throws Exception {
        if (args.length != 4 || !"--out-dir".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-selected --out-dir <directory> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        File outDir = ExportPaths.ensureDirectory(new File(args[2]));
        File input = new File(args[3]);
        File audioDir = ExportPaths.child(outDir, "audio");

        writeJson(ExportPaths.child(outDir, "catalog.json"), new VosCatalogExporter().exportCatalog(input));
        writeJson(ExportPaths.child(outDir, "gameplay.json"), new VosGameplayExporter().exportGameplay(input));
        writeJson(ExportPaths.child(outDir, "audio-manifest.json"), new VosAudioExporter().exportAudio(input, audioDir));
        return STATUS_SUCCESS;
    }

    private static void writeJson(File output, String json) throws Exception {
        File parent = output.getParentFile();
        if (parent != null) {
            ExportPaths.ensureDirectory(parent);
        }
        Files.write(output.toPath(), json.getBytes(StandardCharsets.UTF_8));
    }
}

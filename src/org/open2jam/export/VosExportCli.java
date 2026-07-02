package org.open2jam.export;

import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import javax.imageio.ImageIO;
import org.open2jam.Config;
import org.open2jam.GameOptions;
import org.open2jam.game.judgment.TimeJudgment;
import org.open2jam.parsers.Chart;
import org.open2jam.parsers.utils.SampleData;
import org.open2jam.render.DisplayMode;
import org.open2jam.render.Render;
import org.open2jam.render.lwjgl.LWJGLGameWindow;
import org.open2jam.sound.Sound;
import org.open2jam.sound.SoundChannel;
import org.open2jam.sound.SoundInstance;
import org.open2jam.sound.SoundSystem;
import org.open2jam.sound.SoundSystemException;

public final class VosExportCli {
    private static final int STATUS_SUCCESS = 0;
    private static final int STATUS_EXPORT_FAILURE = 1;
    private static final int STATUS_USAGE_ERROR = 2;

    private static final String EXPORT_CATALOG = "--export-vos-catalog";
    private static final String EXPORT_GAMEPLAY = "--export-vos-gameplay";
    private static final String EXPORT_AUDIO = "--export-vos-audio";
    private static final String EXPORT_RENDER_METADATA = "--export-vos-render-metadata";
    private static final String EXPORT_SELECTED = "--export-vos-selected";
    private static final String CAPTURE_GAMEPLAY_SCREENSHOT = "--capture-vos-gameplay-screenshot";
    private static final String CAPTURE_USAGE = "Usage: open2jam --capture-vos-gameplay-screenshot "
            + "--output <png> [--chart-index <index>] [--delay-ms <millis>] [--frame <frame>] "
            + "[--game-time-ms <millis>] <file.vos>";
    private static final String COMPARE_GAMEPLAY_SCREENSHOTS = "--compare-vos-gameplay-screenshots";
    private static final String COMPARE_USAGE = "Usage: open2jam --compare-vos-gameplay-screenshots "
            + "--java <png> --godot <png> --out-dir <directory> [--pixel-tolerance <0-255>]";

    private VosExportCli() {
    }

    public static boolean isExportCommand(String arg) {
        return EXPORT_CATALOG.equals(arg)
                || EXPORT_GAMEPLAY.equals(arg)
                || EXPORT_AUDIO.equals(arg)
                || EXPORT_RENDER_METADATA.equals(arg)
                || EXPORT_SELECTED.equals(arg)
                || CAPTURE_GAMEPLAY_SCREENSHOT.equals(arg)
                || COMPARE_GAMEPLAY_SCREENSHOTS.equals(arg);
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
            if (EXPORT_RENDER_METADATA.equals(args[0])) {
                return exportRenderMetadata(args, err);
            }
            if (CAPTURE_GAMEPLAY_SCREENSHOT.equals(args[0])) {
                return captureGameplayScreenshot(args, err);
            }
            if (COMPARE_GAMEPLAY_SCREENSHOTS.equals(args[0])) {
                return compareGameplayScreenshots(args, err);
            }
            return exportSelected(args, err);
        } catch (Exception e) {
            err.println("VOS export failed: " + e.getMessage());
            if (Boolean.getBoolean("open2jam.export.printStack")) {
                e.printStackTrace(err);
            }
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
        if ((args.length != 4 && args.length != 6) || !"--output".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-gameplay --output <file> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        int chartIndex = 0;
        String inputPath = args[3];
        if (args.length == 6) {
            if (!"--chart-index".equals(args[3])) {
                err.println("Usage: open2jam --export-vos-gameplay --output <file> <file.vos>");
                return STATUS_USAGE_ERROR;
            }
            chartIndex = parseChartIndex(args[4], err, "Usage: open2jam --export-vos-gameplay --output <file> <file.vos>");
            if (chartIndex < 0) {
                return STATUS_USAGE_ERROR;
            }
            inputPath = args[5];
        }
        writeJson(new File(args[2]), new VosGameplayExporter().exportGameplay(new File(inputPath), chartIndex));
        return STATUS_SUCCESS;
    }

    private static int exportAudio(String[] args, PrintStream err) throws Exception {
        if ((args.length != 6 && args.length != 8) || !"--output".equals(args[1])
                || !"--asset-dir".equals(args[3])) {
            err.println("Usage: open2jam --export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        int chartIndex = 0;
        String inputPath = args[5];
        if (args.length == 8) {
            if (!"--chart-index".equals(args[5])) {
                err.println("Usage: open2jam --export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>");
                return STATUS_USAGE_ERROR;
            }
            chartIndex = parseChartIndex(args[6], err,
                    "Usage: open2jam --export-vos-audio --output <manifest> --asset-dir <directory> <file.vos>");
            if (chartIndex < 0) {
                return STATUS_USAGE_ERROR;
            }
            inputPath = args[7];
        }
        writeJson(new File(args[2]), new VosAudioExporter().exportAudio(new File(inputPath), new File(args[4]),
                chartIndex));
        return STATUS_SUCCESS;
    }

    private static int exportRenderMetadata(String[] args, PrintStream err) throws Exception {
        if (args.length != 3 || !"--output".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-render-metadata --output <file>");
            return STATUS_USAGE_ERROR;
        }
        writeJson(new File(args[2]), new VosRenderMetadataExporter().exportDefaultMetadata());
        return STATUS_SUCCESS;
    }

    private static int captureGameplayScreenshot(String[] args, PrintStream err) throws Exception {
        CaptureRequest request = CaptureRequest.parse(args);
        if (request == null) {
            err.println(CAPTURE_USAGE);
            return STATUS_USAGE_ERROR;
        }

        String oldOutput = System.getProperty(LWJGLGameWindow.CAPTURE_OUTPUT_PROPERTY);
        String oldDelay = System.getProperty(LWJGLGameWindow.CAPTURE_DELAY_MILLIS_PROPERTY);
        String oldFrame = System.getProperty(LWJGLGameWindow.CAPTURE_FRAME_PROPERTY);
        try {
            System.setProperty(LWJGLGameWindow.CAPTURE_OUTPUT_PROPERTY, request.output.getCanonicalPath());
            System.setProperty(LWJGLGameWindow.CAPTURE_DELAY_MILLIS_PROPERTY,
                    Long.toString(request.delayMillis));
            System.setProperty(LWJGLGameWindow.CAPTURE_FRAME_PROPERTY, Integer.toString(request.frame));

            Config.openDB();
            Chart chart = PlayableChartSelector.select(request.input, request.chartIndex);
            GameOptions options = captureOptions();
            Render render = new Render(chart, options, new DisplayMode(800, 600), new CaptureSoundSystem());
            render.setRank(0);
            render.setJudge(new TimeJudgment());
            if (request.gameTimeMillis >= 0) {
                render.setFixedCaptureGameTime(request.gameTimeMillis);
            }
            render.startRendering();
        } finally {
            restoreProperty(LWJGLGameWindow.CAPTURE_OUTPUT_PROPERTY, oldOutput);
            restoreProperty(LWJGLGameWindow.CAPTURE_DELAY_MILLIS_PROPERTY, oldDelay);
            restoreProperty(LWJGLGameWindow.CAPTURE_FRAME_PROPERTY, oldFrame);
        }

        if (!request.output.isFile()) {
            err.println("VOS gameplay screenshot was not created: " + request.output);
            return STATUS_EXPORT_FAILURE;
        }
        return STATUS_SUCCESS;
    }

    private static int compareGameplayScreenshots(String[] args, PrintStream err) throws Exception {
        CompareRequest request = CompareRequest.parse(args);
        if (request == null) {
            err.println(COMPARE_USAGE);
            return STATUS_USAGE_ERROR;
        }

        BufferedImage javaImage = ImageIO.read(request.javaImage);
        BufferedImage godotImage = ImageIO.read(request.godotImage);
        if (javaImage == null || godotImage == null) {
            err.println("Unable to read one or more gameplay screenshots");
            return STATUS_EXPORT_FAILURE;
        }

        ExportPaths.ensureDirectory(request.outDir);
        File sideBySide = ExportPaths.child(request.outDir, "side-by-side.png");
        File diff = ExportPaths.child(request.outDir, "diff.png");
        File diffComponents = ExportPaths.child(request.outDir, "diff-components.json");
        File summary = ExportPaths.child(request.outDir, "summary.json");
        ComparisonResult result = compareImages(javaImage, godotImage, sideBySide, diff, request.pixelTolerance);
        writeJson(diffComponents, result.diffComponents.toJson());
        writeJson(summary, result.summary.toJson(request.javaImage, request.godotImage, sideBySide, diff,
                diffComponents));
        return STATUS_SUCCESS;
    }

    private static GameOptions captureOptions() {
        GameOptions options = new GameOptions();
        options.setAutoplay(true);
        options.setAutosound(false);
        options.setDisplayFullscreen(false);
        options.setDisplayVsync(false);
        options.setMasterVolume(0f);
        options.setBGMVolume(0f);
        options.setKeyVolume(0f);
        options.setSpeedMultiplier(1.0);
        options.setSpeedType(GameOptions.SpeedType.HiSpeed);
        options.setJudgmentType(GameOptions.JudgmentType.TimeJudgment);
        return options;
    }

    private static int exportSelected(String[] args, PrintStream err) throws Exception {
        if ((args.length != 4 && args.length != 6) || !"--out-dir".equals(args[1])) {
            err.println("Usage: open2jam --export-vos-selected --out-dir <directory> <file.vos>");
            return STATUS_USAGE_ERROR;
        }
        File outDir = ExportPaths.ensureDirectory(new File(args[2]));
        int chartIndex = 0;
        String inputPath = args[3];
        if (args.length == 6) {
            if (!"--chart-index".equals(args[3])) {
                err.println("Usage: open2jam --export-vos-selected --out-dir <directory> <file.vos>");
                return STATUS_USAGE_ERROR;
            }
            chartIndex = parseChartIndex(args[4], err,
                    "Usage: open2jam --export-vos-selected --out-dir <directory> <file.vos>");
            if (chartIndex < 0) {
                return STATUS_USAGE_ERROR;
            }
            inputPath = args[5];
        }
        File input = new File(inputPath);
        File audioDir = ExportPaths.child(outDir, "audio");
        File bgaDir = ExportPaths.child(outDir, "bga");

        writeJson(ExportPaths.child(outDir, "catalog.json"), new VosCatalogExporter().exportCatalog(input));
        writeJson(ExportPaths.child(outDir, "gameplay.json"),
                new VosGameplayExporter().exportGameplay(input, bgaDir, chartIndex));
        writeJson(ExportPaths.child(outDir, "audio-manifest.json"),
                new VosAudioExporter().exportAudio(input, audioDir, chartIndex));
        writeJson(ExportPaths.child(outDir, "render-metadata.json"),
                new VosRenderMetadataExporter().exportDefaultMetadata());
        return STATUS_SUCCESS;
    }

    private static int parseChartIndex(String value, PrintStream err, String usage) {
        try {
            int chartIndex = Integer.parseInt(value);
            if (chartIndex >= 0) {
                return chartIndex;
            }
        } catch (NumberFormatException e) {
            // Fall through to usage.
        }
        err.println(usage);
        return -1;
    }

    private static void restoreProperty(String name, String oldValue) {
        if (oldValue == null) {
            System.clearProperty(name);
        } else {
            System.setProperty(name, oldValue);
        }
    }

    private static void writeJson(File output, String json) throws Exception {
        File parent = output.getParentFile();
        if (parent != null) {
            ExportPaths.ensureDirectory(parent);
        }
        Files.write(output.toPath(), json.getBytes(StandardCharsets.UTF_8));
    }

    private static final class CaptureSoundSystem implements SoundSystem {
        private static final Sound SOUND = new CaptureSound();

        @Override
        public Sound load(SampleData sample) {
            return SOUND;
        }

        @Override
        public void release() {
        }

        @Override
        public void update() {
        }

        @Override
        public void setBGMVolume(float factor) {
        }

        @Override
        public void setKeyVolume(float factor) {
        }

        @Override
        public void setMasterVolume(float factor) {
        }

        @Override
        public void setSpeed(float factor) {
        }
    }

    private static final class CaptureSound implements Sound {
        private static final SoundInstance INSTANCE = new CaptureSoundInstance();

        @Override
        public SoundInstance play(SoundChannel soundChannel, float volume, float pan) throws SoundSystemException {
            return INSTANCE;
        }
    }

    private static final class CaptureSoundInstance implements SoundInstance {
        @Override
        public void stop() {
        }
    }

    private static ComparisonResult compareImages(BufferedImage javaImage, BufferedImage godotImage,
            File sideBySide, File diff, int pixelTolerance) throws Exception {
        int width = Math.min(javaImage.getWidth(), godotImage.getWidth());
        int height = Math.min(javaImage.getHeight(), godotImage.getHeight());
        BufferedImage sideImage = new BufferedImage(javaImage.getWidth() + godotImage.getWidth(),
                Math.max(javaImage.getHeight(), godotImage.getHeight()), BufferedImage.TYPE_INT_RGB);
        Graphics2D graphics = sideImage.createGraphics();
        try {
            graphics.setColor(Color.BLACK);
            graphics.fillRect(0, 0, sideImage.getWidth(), sideImage.getHeight());
            graphics.drawImage(javaImage, 0, 0, null);
            graphics.drawImage(godotImage, javaImage.getWidth(), 0, null);
        } finally {
            graphics.dispose();
        }
        ImageIO.write(sideImage, "png", sideBySide);

        BufferedImage diffImage = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        long differingPixels = 0;
        long significantDifferingPixels = 0;
        long totalAbsDelta = 0;
        long significantTotalAbsDelta = 0;
        int maxChannelDelta = 0;
        boolean[] different = new boolean[width * height];
        int[] pixelAbsDelta = new int[width * height];
        int[] pixelMaxDelta = new int[width * height];
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int javaRgb = javaImage.getRGB(x, y);
                int godotRgb = godotImage.getRGB(x, y);
                int dr = Math.abs(((javaRgb >> 16) & 0xff) - ((godotRgb >> 16) & 0xff));
                int dg = Math.abs(((javaRgb >> 8) & 0xff) - ((godotRgb >> 8) & 0xff));
                int db = Math.abs((javaRgb & 0xff) - (godotRgb & 0xff));
                int maxDelta = Math.max(dr, Math.max(dg, db));
                if (maxDelta > 0) {
                    differingPixels++;
                }
                if (maxDelta > pixelTolerance) {
                    significantDifferingPixels++;
                    int pixelIndex = y * width + x;
                    different[pixelIndex] = true;
                    int absDelta = dr + dg + db;
                    significantTotalAbsDelta += absDelta;
                    pixelAbsDelta[pixelIndex] = absDelta;
                    pixelMaxDelta[pixelIndex] = maxDelta;
                }
                totalAbsDelta += dr + dg + db;
                maxChannelDelta = Math.max(maxChannelDelta, maxDelta);
                diffImage.setRGB(x, y, (maxDelta << 16));
            }
        }
        ImageIO.write(diffImage, "png", diff);
        ComparisonSummary summary = new ComparisonSummary(width, height, differingPixels,
                significantDifferingPixels, totalAbsDelta, significantTotalAbsDelta, maxChannelDelta,
                javaImage.getWidth(), javaImage.getHeight(), godotImage.getWidth(), godotImage.getHeight(),
                pixelTolerance);
        return new ComparisonResult(summary, collectDiffComponents(width, height, different, pixelAbsDelta,
                pixelMaxDelta));
    }

    private static DiffComponents collectDiffComponents(int width, int height, boolean[] different,
            int[] pixelAbsDelta, int[] pixelMaxDelta) {
        boolean[] visited = new boolean[different.length];
        List<DiffComponent> components = new ArrayList<>();
        ArrayDeque<Integer> queue = new ArrayDeque<>();
        for (int index = 0; index < different.length; index++) {
            if (!different[index] || visited[index]) {
                continue;
            }
            visited[index] = true;
            queue.add(index);
            int minX = width;
            int minY = height;
            int maxX = -1;
            int maxY = -1;
            int pixels = 0;
            long totalAbsDelta = 0;
            int maxChannelDelta = 0;
            while (!queue.isEmpty()) {
                int current = queue.removeFirst();
                int x = current % width;
                int y = current / width;
                minX = Math.min(minX, x);
                minY = Math.min(minY, y);
                maxX = Math.max(maxX, x);
                maxY = Math.max(maxY, y);
                pixels++;
                totalAbsDelta += pixelAbsDelta[current];
                maxChannelDelta = Math.max(maxChannelDelta, pixelMaxDelta[current]);
                addNeighbor(current - 1, x > 0, different, visited, queue);
                addNeighbor(current + 1, x + 1 < width, different, visited, queue);
                addNeighbor(current - width, y > 0, different, visited, queue);
                addNeighbor(current + width, y + 1 < height, different, visited, queue);
            }
            components.add(new DiffComponent(minX, minY, maxX - minX + 1, maxY - minY + 1, pixels,
                    totalAbsDelta, maxChannelDelta));
        }
        components.sort(Comparator.comparingInt((DiffComponent component) -> component.pixels)
                .reversed()
                .thenComparingInt(component -> component.y)
                .thenComparingInt(component -> component.x));
        return new DiffComponents(components);
    }

    private static void addNeighbor(int index, boolean inBounds, boolean[] different, boolean[] visited,
            ArrayDeque<Integer> queue) {
        if (inBounds && different[index] && !visited[index]) {
            visited[index] = true;
            queue.add(index);
        }
    }

    private static final class CaptureRequest {
        final File output;
        final File input;
        final int chartIndex;
        final long delayMillis;
        final int frame;
        final double gameTimeMillis;

        private CaptureRequest(File output, File input, int chartIndex, long delayMillis, int frame,
                double gameTimeMillis) {
            this.output = output;
            this.input = input;
            this.chartIndex = chartIndex;
            this.delayMillis = delayMillis;
            this.frame = frame;
            this.gameTimeMillis = gameTimeMillis;
        }

        static CaptureRequest parse(String[] args) {
            File output = null;
            File input = null;
            int chartIndex = 0;
            long delayMillis = 1500;
            int frame = 2;
            double gameTimeMillis = -1.0;

            for (int i = 1; i < args.length; i++) {
                String arg = args[i];
                if ("--output".equals(arg)) {
                    if (++i >= args.length) return null;
                    output = new File(args[i]);
                } else if ("--chart-index".equals(arg)) {
                    if (++i >= args.length) return null;
                    chartIndex = parseNonNegativeInt(args[i]);
                    if (chartIndex < 0) return null;
                } else if ("--delay-ms".equals(arg)) {
                    if (++i >= args.length) return null;
                    delayMillis = parseNonNegativeLong(args[i]);
                    if (delayMillis < 0) return null;
                } else if ("--frame".equals(arg)) {
                    if (++i >= args.length) return null;
                    frame = parsePositiveInt(args[i]);
                    if (frame < 0) return null;
                } else if ("--game-time-ms".equals(arg)) {
                    if (++i >= args.length) return null;
                    gameTimeMillis = parseNonNegativeDouble(args[i]);
                    if (gameTimeMillis < 0) return null;
                } else if (arg.startsWith("--") || input != null) {
                    return null;
                } else {
                    input = new File(arg);
                }
            }

            if (output == null || input == null) return null;
            return new CaptureRequest(output, input, chartIndex, delayMillis, frame, gameTimeMillis);
        }

        private static int parseNonNegativeInt(String value) {
            try {
                int parsed = Integer.parseInt(value);
                return parsed >= 0 ? parsed : -1;
            } catch (NumberFormatException e) {
                return -1;
            }
        }

        private static long parseNonNegativeLong(String value) {
            try {
                long parsed = Long.parseLong(value);
                return parsed >= 0 ? parsed : -1;
            } catch (NumberFormatException e) {
                return -1;
            }
        }

        private static int parsePositiveInt(String value) {
            try {
                int parsed = Integer.parseInt(value);
                return parsed >= 1 ? parsed : -1;
            } catch (NumberFormatException e) {
                return -1;
            }
        }

        private static double parseNonNegativeDouble(String value) {
            try {
                double parsed = Double.parseDouble(value);
                return parsed >= 0.0 ? parsed : -1.0;
            } catch (NumberFormatException e) {
                return -1.0;
            }
        }
    }

    private static final class CompareRequest {
        final File javaImage;
        final File godotImage;
        final File outDir;
        final int pixelTolerance;

        private CompareRequest(File javaImage, File godotImage, File outDir, int pixelTolerance) {
            this.javaImage = javaImage;
            this.godotImage = godotImage;
            this.outDir = outDir;
            this.pixelTolerance = pixelTolerance;
        }

        static CompareRequest parse(String[] args) {
            File javaImage = null;
            File godotImage = null;
            File outDir = null;
            int pixelTolerance = 0;
            for (int i = 1; i < args.length; i++) {
                String arg = args[i];
                if ("--java".equals(arg)) {
                    if (++i >= args.length) return null;
                    javaImage = new File(args[i]);
                } else if ("--godot".equals(arg)) {
                    if (++i >= args.length) return null;
                    godotImage = new File(args[i]);
                } else if ("--out-dir".equals(arg)) {
                    if (++i >= args.length) return null;
                    outDir = new File(args[i]);
                } else if ("--pixel-tolerance".equals(arg)) {
                    if (++i >= args.length) return null;
                    pixelTolerance = parsePixelTolerance(args[i]);
                    if (pixelTolerance < 0) return null;
                } else {
                    return null;
                }
            }
            if (javaImage == null || godotImage == null || outDir == null) return null;
            return new CompareRequest(javaImage, godotImage, outDir, pixelTolerance);
        }

        private static int parsePixelTolerance(String value) {
            try {
                int parsed = Integer.parseInt(value);
                return parsed >= 0 && parsed <= 255 ? parsed : -1;
            } catch (NumberFormatException e) {
                return -1;
            }
        }
    }

    private static final class ComparisonSummary {
        final int comparedWidth;
        final int comparedHeight;
        final long differingPixels;
        final long significantDifferingPixels;
        final long totalAbsDelta;
        final long significantTotalAbsDelta;
        final int maxChannelDelta;
        final int javaWidth;
        final int javaHeight;
        final int godotWidth;
        final int godotHeight;
        final int pixelTolerance;

        ComparisonSummary(int comparedWidth, int comparedHeight, long differingPixels,
                long significantDifferingPixels, long totalAbsDelta, long significantTotalAbsDelta,
                int maxChannelDelta, int javaWidth, int javaHeight, int godotWidth, int godotHeight,
                int pixelTolerance) {
            this.comparedWidth = comparedWidth;
            this.comparedHeight = comparedHeight;
            this.differingPixels = differingPixels;
            this.significantDifferingPixels = significantDifferingPixels;
            this.totalAbsDelta = totalAbsDelta;
            this.significantTotalAbsDelta = significantTotalAbsDelta;
            this.maxChannelDelta = maxChannelDelta;
            this.javaWidth = javaWidth;
            this.javaHeight = javaHeight;
            this.godotWidth = godotWidth;
            this.godotHeight = godotHeight;
            this.pixelTolerance = pixelTolerance;
        }

        String toJson(File javaImage, File godotImage, File sideBySide, File diff, File diffComponents)
                throws Exception {
            long comparedPixels = (long) comparedWidth * comparedHeight;
            double meanAbsDelta = comparedPixels == 0 ? 0.0 : totalAbsDelta / (double) (comparedPixels * 3);
            double significantMeanAbsDelta = comparedPixels == 0 ? 0.0
                    : significantTotalAbsDelta / (double) (comparedPixels * 3);
            return JsonWriter.object(
                    JsonWriter.field("schemaVersion", 1),
                    JsonWriter.field("javaScreenshot", javaImage.getCanonicalPath()),
                    JsonWriter.field("godotScreenshot", godotImage.getCanonicalPath()),
                    JsonWriter.field("sideBySide", sideBySide.getCanonicalPath()),
                    JsonWriter.field("diff", diff.getCanonicalPath()),
                    JsonWriter.field("diffComponents", diffComponents.getCanonicalPath()),
                    JsonWriter.field("javaWidth", javaWidth),
                    JsonWriter.field("javaHeight", javaHeight),
                    JsonWriter.field("godotWidth", godotWidth),
                    JsonWriter.field("godotHeight", godotHeight),
                    JsonWriter.field("comparedWidth", comparedWidth),
                    JsonWriter.field("comparedHeight", comparedHeight),
                    JsonWriter.field("differingPixels", differingPixels),
                    JsonWriter.field("significantDifferingPixels", significantDifferingPixels),
                    JsonWriter.field("pixelTolerance", pixelTolerance),
                    JsonWriter.field("meanAbsDelta", meanAbsDelta),
                    JsonWriter.field("significantMeanAbsDelta", significantMeanAbsDelta),
                    JsonWriter.field("maxChannelDelta", maxChannelDelta));
        }
    }

    private static final class ComparisonResult {
        final ComparisonSummary summary;
        final DiffComponents diffComponents;

        ComparisonResult(ComparisonSummary summary, DiffComponents diffComponents) {
            this.summary = summary;
            this.diffComponents = diffComponents;
        }
    }

    private static final class DiffComponents {
        final List<DiffComponent> components;

        DiffComponents(List<DiffComponent> components) {
            this.components = components;
        }

        String toJson() {
            String[] componentJson = new String[components.size()];
            for (int i = 0; i < components.size(); i++) {
                componentJson[i] = components.get(i).toJson();
            }
            return JsonWriter.object(
                    JsonWriter.field("schemaVersion", 1),
                    JsonWriter.field("componentCount", components.size()),
                    JsonWriter.rawField("components", JsonWriter.array(componentJson)));
        }
    }

    private static final class DiffComponent {
        final int x;
        final int y;
        final int width;
        final int height;
        final int pixels;
        final long totalAbsDelta;
        final int maxChannelDelta;

        DiffComponent(int x, int y, int width, int height, int pixels, long totalAbsDelta, int maxChannelDelta) {
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
            this.pixels = pixels;
            this.totalAbsDelta = totalAbsDelta;
            this.maxChannelDelta = maxChannelDelta;
        }

        String toJson() {
            double meanAbsDelta = pixels == 0 ? 0.0 : totalAbsDelta / (double) (pixels * 3);
            return JsonWriter.object(
                    JsonWriter.field("x", x),
                    JsonWriter.field("y", y),
                    JsonWriter.field("width", width),
                    JsonWriter.field("height", height),
                    JsonWriter.field("pixels", pixels),
                    JsonWriter.field("meanAbsDelta", meanAbsDelta),
                    JsonWriter.field("maxChannelDelta", maxChannelDelta));
        }
    }
}

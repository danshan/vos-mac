package org.open2jam.parsers;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

public final class OsuFixtureFactory {
    private OsuFixtureFactory() {
    }

    public static File writeSevenKeyOsu(File directory, String name) throws Exception {
        File audio = new File(directory, "audio.wav");
        writeSilentWav(audio);
        File chart = new File(directory, name);
        Files.writeString(chart.toPath(), sevenKeyContent(audio.getName()), StandardCharsets.UTF_8);
        return chart;
    }

    public static File writeSevenKeyOsz(File directory, String name) throws Exception {
        File archive = new File(directory, name);
        try (ZipOutputStream zip = new ZipOutputStream(Files.newOutputStream(archive.toPath()))) {
            writeEntry(zip, "audio.wav", silentWav());
            writeEntry(zip, "seven-key.osu", sevenKeyContent("audio.wav").getBytes(StandardCharsets.UTF_8));
        }
        return archive;
    }

    public static String sevenKeyContent(String audioFilename) {
        return "osu file format v14\n\n"
                + "[General]\nAudioFilename: " + audioFilename + "\nMode: 3\n\n"
                + "[Metadata]\nTitle:Seven Key Fixture\nArtist:Fixture Artist\n"
                + "Creator:Fixture Creator\nVersion:Test 7K\n\n"
                + "[Difficulty]\nHPDrainRate:5\nCircleSize:7\nOverallDifficulty:8\n\n"
                + "[TimingPoints]\n0,500,4,2,1,60,1,0\n\n"
                + "[HitObjects]\n"
                + "36,192,0,1,0,0:0:0:0:\n"
                + "109,192,250,1,0,0:0:0:0:\n"
                + "182,192,500,1,0,0:0:0:0:\n"
                + "256,192,750,1,0,0:0:0:0:\n"
                + "329,192,1000,1,0,0:0:0:0:\n"
                + "402,192,1250,1,0,0:0:0:0:\n"
                + "475,192,1500,1,0,0:0:0:0:\n"
                + "256,192,2000,128,0,3000:0:0:0:0:\n";
    }

    private static void writeEntry(ZipOutputStream zip, String name, byte[] bytes) throws Exception {
        zip.putNextEntry(new ZipEntry(name));
        zip.write(bytes);
        zip.closeEntry();
    }

    private static void writeSilentWav(File file) throws Exception {
        Files.write(file.toPath(), silentWav());
    }

    private static byte[] silentWav() {
        return new byte[] {
                'R', 'I', 'F', 'F', 38, 0, 0, 0, 'W', 'A', 'V', 'E',
                'f', 'm', 't', ' ', 16, 0, 0, 0, 1, 0, 1, 0,
                64, 31, 0, 0, -128, 62, 0, 0, 2, 0, 16, 0,
                'd', 'a', 't', 'a', 2, 0, 0, 0, 0, 0
        };
    }
}

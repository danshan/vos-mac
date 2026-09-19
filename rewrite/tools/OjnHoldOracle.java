import java.io.OutputStream;
import java.io.PrintStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Random;
import org.open2jam.parsers.Event;
import org.open2jam.parsers.EventList;

// Migration-only oracle generator. Rust tests consume the frozen JSON without Java.
class OjnHoldOracle {
    public static void main(String[] args) throws Exception {
        System.setOut(new PrintStream(OutputStream.nullOutputStream()));
        Random random = new Random(20260919L);
        Event.Channel[] channels = {Event.Channel.NOTE_1, Event.Channel.NOTE_2,
                Event.Channel.NOTE_3, Event.Channel.AUTO_PLAY};
        Event.Flag[] flags = {Event.Flag.NONE, Event.Flag.HOLD, Event.Flag.RELEASE};
        StringBuilder json = new StringBuilder("{\"seed\":20260919,\"cases\":[\n");
        for (int c = 0; c < 64; c++) {
            if (c != 0) json.append(",\n");
            json.append("{\"input\":[");
            EventList events = new EventList();
            for (int i = 0; i < 24; i++) {
                int sample = random.nextInt(4);
                int lane = random.nextInt(4);
                Event.Flag flag = flags[random.nextInt(3)];
                events.add(new Event(channels[lane], 0, i / 24.0, sample, flag));
                if (i != 0) json.append(',');
                json.append('[').append(sample).append(',').append(lane == 3 ? -1 : lane)
                        .append(',').append(type(flag)).append(']');
            }
            events.fixEventList(EventList.FixMethod.OPEN2JAM, true);
            json.append("],\"expected\":[");
            boolean first = true;
            for (Event event : events) {
                if (!first) json.append(',');
                first = false;
                int lane = -1;
                for (int i = 0; i < 3; i++) if (event.getChannel() == channels[i]) lane = i;
                json.append('[').append(Math.round(event.getPosition() * 24)).append(',')
                        .append((int) event.getValue()).append(',').append(lane).append(',')
                        .append(type(event.getFlag())).append(']');
            }
            json.append("]}");
        }
        Files.writeString(Path.of(args[0]), json.append("\n]}\n").toString());
    }

    private static int type(Event.Flag flag) {
        return flag == Event.Flag.HOLD ? 2 : flag == Event.Flag.RELEASE ? 3 : 0;
    }
}

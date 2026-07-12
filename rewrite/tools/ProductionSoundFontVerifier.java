import java.nio.file.Path;

/** Runs the fixed production SoundFont contract and a final completed-snapshot audit. */
public final class ProductionSoundFontVerifier {
    private ProductionSoundFontVerifier() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "usage: ProductionSoundFontVerifier <manifest> <payload-root> <snapshot-root>");
        }
        Path manifest = Path.of(args[0]).toAbsolutePath().normalize();
        Path payloadRoot = Path.of(args[1]).toAbsolutePath().normalize();
        Path snapshot = Path.of(args[2]).toAbsolutePath().normalize();
        SoundFontContractVerifier.verify(
                manifest,
                payloadRoot,
                snapshot,
                SoundFontContractVerifier.VerificationObserver.NONE);
        SoundFontContractVerifier.checkCompletedSnapshot(snapshot);
        System.out.printf(
                "Production SoundFont completed snapshot audit passed; location=%s.%n",
                snapshot);
    }
}

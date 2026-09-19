"""Create self-authored M30 banks from the existing licensed Vorbis test tone."""
import pathlib
import struct

fixture_root = pathlib.Path(__file__).resolve().parents[2] / "native/crates/open2jam-core/tests/fixtures/ojn"
audio = (fixture_root / "tone.ogg").read_bytes()
for flag, mask, name in [(0, None, "plain"), (16, b"nami", "nami"), (32, b"0412", "0412")]:
    bank = bytearray(struct.pack("<4s6I", b"M30\0", 1, flag, 2, 28, 0, 0))
    # Deliberately store the background reference before the key-sound reference.
    for codec, reference in [(0, 3), (5, 7)]:
        payload = bytearray(audio)
        if mask:
            for index in range(len(payload) // 4 * 4):
                payload[index] ^= mask[index % 4]
        bank += struct.pack("<32sIHHIhhI", b"tone.ogg", len(payload), codec, 0, 0, reference, 0, 4416)
        bank += payload
    struct.pack_into("<I", bank, 20, len(bank) - 28)
    (fixture_root / f"m30-{name}.ojm").write_bytes(bank)

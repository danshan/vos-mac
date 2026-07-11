---
status: accepted
---

# Use a deterministic SoundFont for VOS audio parity

The Java renderer loads the host macOS `gs_instruments.dls`, so its synthesized PCM depends on the operating system and cannot be a portable bit-exact contract. Ship a fixed, redistributable SoundFont and require deterministic behavioral parity for MIDI tempo, event order, bank and program, note, velocity, pan, duration, minimum gate, tail, and 44.1 kHz stereo signed 16-bit PCM; include the SoundFont version and hash in every gameplay artifact cache key, and accept one documented canonical timbre change from the legacy system DLS.

## Consequences

- Java PCM byte equality is not a Java-removal gate.
- Duration, onset, channel behavior, silence, clipping, and deterministic cross-run output require automated verification.
- Replacing or upgrading the SoundFont invalidates every affected cached artifact and is a product-level audio change.

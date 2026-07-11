---
status: accepted
---

# Use a Rust native converter with a CLI boundary

The Godot product must become fully Java-free while preserving raw VOS, OJN/OJM, and osu!mania import. Implement parsing, timing compilation, audio preparation, and relocatable bundle generation in a shared Rust core exposed first through a native CLI; keep catalog orchestration, cache policy, progress presentation, resource loading, and gameplay in Godot, and add a thin GDExtension adapter only if measured CLI and file-exchange overhead prevents an accepted performance budget.

## Considered Options

- Pure GDScript minimizes packaging work but is unsuitable for complex binary parsing, MIDI synthesis, OJM decryption, and high-volume audio conversion.
- A direct GDExtension minimizes IPC but increases crash impact, ABI coupling, and cross-platform signing complexity before those costs are justified by measurements.

## Consequences

- The CLI protocol must support structured progress, cancellation, version reporting, and transactional bundle output.
- The first release must package and sign the macOS arm64 converter inside the Godot application, while the Rust core and bundle contract remain portable for later platform releases.
- Migration tests must compare Rust output with frozen Java goldens before all Java, Maven, and JAR surfaces are removed.

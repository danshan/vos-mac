---
status: accepted
---

# Cache gameplay export artifacts

Entering gameplay currently repeats Java export and resource preparation on the critical path, which cannot reliably meet the accepted warm-load budget. Persist gameplay JSON, the audio manifest, and prepared audio and BGA resources under a cache key composed of `chartId`, the source fingerprint, and the exporter schema version; validate a rebuilt artifact in a temporary directory before atomically publishing it, and automatically rebuild missing, stale, or corrupt entries so the cache remains an optional performance layer rather than a source of truth.

## Considered Options

- Export and prepare every time: simple invalidation semantics, but repeats the dominant work and misses the warm-load target.
- Reuse artifacts without validation: fastest lookup, but can launch gameplay with stale or partial data.

## Consequences

- The exporter must publish and evolve an explicit schema version.
- Cache lookup and each rebuild stage must report real loading progress.
- Cache failures must fall back to a safe rebuild instead of blocking gameplay permanently.

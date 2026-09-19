#!/usr/bin/env python3
"""Verify first/repeated/reversed prototype WAVs and print measured evidence."""

import argparse
import hashlib
import json
import re
import wave
from pathlib import Path


def verify(root, profile):
    reports = []
    for run in ("first", "repeat", "reversed"):
        name = f"{profile}-{run}"
        report = json.loads((root / f"{name}.json").read_text())
        hashes = []
        for sample in report["samples"]:
            digest = hashlib.sha256()
            with wave.open(str(root / name / f'{sample["index"]}.wav'), "rb") as audio:
                if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (2, 2, 44100):
                    raise ValueError(f"{name}: incorrect PCM format")
                if audio.getnframes() != sample["frames"]:
                    raise ValueError(f"{name}: incorrect frame count")
                while block := audio.readframes(4096):
                    digest.update(block)
            if digest.hexdigest() != sample["pcm_sha256"] or sample["clipped_values"] != 0:
                raise ValueError(f"{name}: corrupt or clipped PCM")
            hashes.append(digest.hexdigest())
        if sum(s["pcm_bytes"] for s in report["samples"]) != report["total_pcm_bytes"]:
            raise ValueError(f"{name}: incorrect PCM total")
        timing = (root / f"{name}.time").read_text()
        rss = re.search(r"(\d+)\s+maximum resident set size", timing)
        wall = re.search(r"([\d.]+)\s+real", timing)
        if not rss or not wall:
            raise ValueError(f"{name}: missing process resource measurements")
        reports.append((report, hashes, int(rss[1]), float(wall[1])))
    if reports[0][1] != reports[1][1] or reports[0][1] != list(reversed(reports[2][1])):
        raise ValueError(f"{profile}: repeated or reversed output is not identical")
    print(json.dumps({
        "profile": profile,
        "samples": len(reports[0][1]),
        "distinct_pcm": len(set(reports[0][1])),
        "pcm_bytes": reports[0][0]["total_pcm_bytes"],
        "audio_seconds": sum(s["frames"] for s in reports[0][0]["samples"]) / 44100,
        "wall_seconds": [r[0]["wall_seconds"] for r in reports],
        "process_seconds": [r[3] for r in reports],
        "rss_bytes": [r[2] for r in reports],
        "deterministic": True,
    }))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("profiles", nargs="+")
    args = parser.parse_args()
    for profile in args.profiles:
        verify(args.root, profile)


if __name__ == "__main__":
    main()

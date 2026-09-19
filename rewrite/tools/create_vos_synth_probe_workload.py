#!/usr/bin/env python3
"""Write reproducible, independent MIDI event samples for the offline probe."""

import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("representative", "stress"))
    parser.add_argument("output", type=Path)
    parser.add_argument("--reverse", action="store_true")
    args = parser.parse_args()
    programs = (0, 4, 8, 16, 24, 40, 48, 80)
    keys = range(60, 68) if args.profile == "representative" else range(40, 104)
    velocities = (100,) if args.profile == "representative" else (64, 100)
    samples = []
    for program in programs:
        for key in keys:
            for velocity in velocities:
                samples.append({
                    "division": 480,
                    "end_tick": 240,
                    "events": [
                        {"tick": 0, "kind": "tempo", "micros_per_quarter": 500000},
                        {"tick": 0, "kind": "midi", "channel": 0,
                         "command": 192, "data1": program, "data2": 0},
                        {"tick": 0, "kind": "midi", "channel": 0,
                         "command": 144, "data1": key, "data2": velocity},
                        {"tick": 240, "kind": "midi", "channel": 0,
                         "command": 128, "data1": key, "data2": 0},
                    ],
                })
    if args.reverse:
        samples.reverse()
    with args.output.open("x") as output:
        json.dump(samples, output, separators=(",", ":"))
        output.write("\n")
    print(f"{args.profile}: {len(samples)} independent samples")


if __name__ == "__main__":
    main()

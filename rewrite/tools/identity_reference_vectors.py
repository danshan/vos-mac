#!/usr/bin/env python3
"""Print independently framed identity vectors; never rewrite test expectations."""
import hashlib
import json
import struct


def field(value):
    return struct.pack(">Q", len(value)) + value


def vector(preimage):
    return {"preimageHex": preimage.hex(), "sha256": hashlib.sha256(preimage).hexdigest()}


source = b"open2jam.source-id.v1\0" + struct.pack(">H", 1) + field(bytes(32))
sample = b"open2jam.sample-id.v1\0" + field(bytes(32))
song = (
    b"open2jam.song-id.v2\0"
    + struct.pack(">H", 2)
    + field(bytes([1]) * 32)
    + struct.pack(">H", 2)
    + field(b"album/song.ojn")
)
chart = (
    b"open2jam.chart-id.v2\0"
    + struct.pack(">H", 2)
    + field(hashlib.sha256(song).digest())
    + struct.pack(">HH", 2, 0)
)
print(json.dumps({"source": vector(source), "sample": vector(sample), "song": vector(song), "chart": vector(chart)}, indent=2))

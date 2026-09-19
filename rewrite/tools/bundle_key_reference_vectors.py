#!/usr/bin/env python3
"""Print independently framed bundle keys; never rewrite test expectations."""
import hashlib
import json
import struct


def field(value):
    return struct.pack(">Q", len(value)) + value


prefix = (
    b"open2jam.bundle-key.v1\0"
    + struct.pack(">HH", 1, 2)
    + field(b"0.1.0")
    + field(b"open2jam-gameplay-assets-v1")
    + field(bytes([2]) * 32)
    + field(bytes([1]) * 32)
    + field(bytes([4]) * 32)
)
selectors = {
    "vos": struct.pack(">HH", 1, 0),
    "ojn": struct.pack(">HH", 2, 2),
    "osu": struct.pack(">H", 3) + field(b"set/hard.osu"),
    "bundle": struct.pack(">H", 4) + field(bytes([4]) * 32),
}
vectors = {}
for name, selector in selectors.items():
    preimage = prefix + selector + field(bytes([3]) * 32)
    vectors[name] = {
        "preimageHex": preimage.hex(),
        "sha256": hashlib.sha256(preimage).hexdigest(),
    }
print(json.dumps(vectors, indent=2))

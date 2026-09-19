#!/usr/bin/env python3
"""Build independent malformed bundles for the public Godot loader boundary."""
import hashlib
import json
import os
import pathlib
import shutil
import struct
import sys

source, destination = map(pathlib.Path, sys.argv[1:])
destination.mkdir()
for case in ["incomplete", "key", "schema", "extra", "missing", "corrupt", "symlink", "unknown", "sample", "volume", "tail", "format", "duplicate", "escaped-duplicate", "trailing-comma", "nul", "number", "bad-ratio", "fifo", "invalid-audio", "root-link"]:
    root = destination / case
    if case == "root-link":
        root.symlink_to(source.resolve(), target_is_directory=True)
        continue
    shutil.copytree(source, root)
    manifest = json.loads((root / "bundle.json").read_text())
    chart = json.loads((root / "gameplay.json").read_text())
    if case == "incomplete":
        manifest["complete"] = False
    elif case == "key":
        manifest["bundleKey"] = "sha256:" + "00" * 32
    elif case == "schema":
        manifest["schemaVersion"] = 3
    elif case == "extra":
        (root / "extra").write_bytes(b"extra")
    elif case == "missing":
        (root / "audio/tone.wav").unlink()
    elif case == "corrupt":
        (root / "audio/tone.wav").write_bytes(b"bad")
    elif case == "invalid-audio":
        data = b"not a decodable WAV"
        digest = hashlib.sha256(data).digest()
        sample = "sample:sha256:" + hashlib.sha256(b"open2jam.sample-id.v1\0" + struct.pack(">Q", 32) + digest).hexdigest()
        chart["samples"] = [sample]
        for event in chart["notes"] + chart["autoPlayEvents"]:
            event["sampleId"] = sample
        audio = json.loads((root / "audio-manifest.json").read_text())
        audio["assets"][0]["sampleId"] = sample
        replacements = {"audio/tone.wav": data, "gameplay.json": json.dumps(chart).encode(), "audio-manifest.json": json.dumps(audio).encode()}
        for entry in manifest["files"]:
            payload = replacements[entry["path"]]
            (root / entry["path"]).write_bytes(payload)
            entry["sizeBytes"] = len(payload)
            entry["sha256"] = "sha256:" + hashlib.sha256(payload).hexdigest()
    elif case == "fifo":
        (root / "audio/tone.wav").unlink()
        os.mkfifo(root / "audio/tone.wav")
    elif case == "symlink":
        (root / "audio/tone.wav").unlink()
        (root / "audio/tone.wav").symlink_to((source / "audio/tone.wav").resolve())
    else:
        if case == "unknown":
            chart["unexpected"] = True
        elif case == "sample":
            chart["notes"][0]["sampleId"] = "sample:sha256:" + "00" * 32
        elif case == "volume":
            chart["notes"][0]["volume"]["numerator"] = 17
        elif case == "tail":
            chart["notes"][1]["tail"]["eventOrder"] = 5
        elif case == "format":
            chart["format"] = "VOS"
        elif case == "nul":
            chart["title"] = "bad\x00title"
        elif case == "bad-ratio":
            chart["notes"][0]["volume"]["numerator"] = []
        text = json.dumps(chart, separators=(",", ":"))
        if case == "duplicate":
            text = '{"keys":7,' + text[1:]
        elif case == "escaped-duplicate":
            text = '{"\\u006beys":7,' + text[1:]
        elif case == "trailing-comma":
            text = text[:-1] + ",}"
        elif case == "number":
            text = text.replace('"keys":7', '"keys":7.0')
        data = text.encode()
        (root / "gameplay.json").write_bytes(data)
        for entry in manifest["files"]:
            if entry["path"] == "gameplay.json":
                entry["sizeBytes"] = len(data)
                entry["sha256"] = "sha256:" + hashlib.sha256(data).hexdigest()
    (root / "bundle.json").write_text(json.dumps(manifest))

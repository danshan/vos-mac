#!/usr/bin/env python3
"""Controlled hostile timing fixture, never used by the application."""
import json
import os
import pathlib
import shutil
import sys
import time

request_path = pathlib.Path(sys.argv[sys.argv.index("--request") + 1])
request = json.loads(request_path.read_text())
job_dir = request_path.parent
work = job_dir.parent
mode = pathlib.Path(sys.argv[0]).name
(work / (mode + ".pid")).write_text(str(os.getpid()))
if mode == "source-change-helper":
    source = pathlib.Path(request["sourcePath"])
    shutil.copytree(pathlib.Path(sys.argv[0]).parent / "version-source", source, dirs_exist_ok=True)
if mode in ["late-helper", "source-change-helper"] or "progress-helper" in mode:
    source = pathlib.Path(request["sourcePath"])
    staged = pathlib.Path(request["stagingRoot"]) / request["jobId"]
    shutil.copytree(source, staged)
    manifest = json.loads((source / "bundle.json").read_text())
    result = {"schemaVersion": 1, "jobId": request["jobId"], "command": "BUNDLE", "status": "SUCCEEDED", "error": None,
              "output": {"stagingPath": str(staged), "bundleKey": manifest["bundleKey"], "manifestPath": str(staged / "bundle.json")}}
    (job_dir / "result.json").write_text(json.dumps(result))
    if mode == "source-change-helper":
        sys.exit(0)
    if "progress-helper" in mode:
        event = {"schemaVersion": 1, "jobId": request["jobId"], "command": "BUNDLE", "phase": "VERIFY_BUNDLE",
                 "completedUnits": 1, "totalUnits": 1, "unit": "bundle", "currentItem": None}
        with (job_dir / "progress.jsonl").open("w") as stream:
            for sequence in range(1, 301):
                stream.write(json.dumps(dict(event, sequence=sequence)) + "\n")
            if mode == "bad-progress-helper":
                stream.write(json.dumps(dict(event, sequence=999)) + "\n")
            else:
                stream.write('{"schemaVersion":1')
        sys.exit(0)
    (work / (mode + ".ready")).write_text("ready")
    while not (job_dir / "cancel").exists():
        time.sleep(0.005)
    (job_dir / "progress.jsonl").write_text(json.dumps({"schemaVersion": 1, "jobId": request["jobId"], "command": "BUNDLE",
        "sequence": 1, "phase": "VERIFY_BUNDLE", "completedUnits": 1, "totalUnits": 1, "unit": "bundle", "currentItem": None}) + "\n")
    time.sleep(0.05)
    sys.exit(0)
if mode == "marker-error-helper":
    (job_dir / "cancel").mkdir()
(work / (mode + ".ready")).write_text("ready")
deadline = time.monotonic() + 10
while time.monotonic() < deadline:
    # Exceed pipe capacity so the owner must drain both streams without blocking frames.
    os.write(1, b"x" * 4096)
    os.write(2, b"y" * 4096)
    time.sleep(0.005)

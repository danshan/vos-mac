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
if mode == "late-helper":
    source = pathlib.Path(request["sourcePath"])
    staged = pathlib.Path(request["stagingRoot"]) / request["jobId"]
    shutil.copytree(source, staged)
    manifest = json.loads((source / "bundle.json").read_text())
    result = {"schemaVersion": 1, "jobId": request["jobId"], "command": "BUNDLE", "status": "SUCCEEDED", "error": None,
              "output": {"stagingPath": str(staged), "bundleKey": manifest["bundleKey"], "manifestPath": str(staged / "bundle.json")}}
    (job_dir / "result.json").write_text(json.dumps(result))
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

#!/usr/bin/env python3
"""Simulator selection, bounded process execution, and strict native artifact validation."""
import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path


LAYOUT_ERRORS = re.compile(
    r"Unable to simultaneously satisfy constraints|probably at least one of the constraints|"
    r"unsatisfiable constraints|has an ambiguous (?:layout|width|height)|"
    r"UIViewAlertForUnsatisfiableConstraints|NSInternalInconsistencyException|"
    r"unrecognized selector sent to instance|Terminating app due to uncaught exception|"
    r"Unbalanced calls to begin/end appearance transitions|"
    r"Finishing up a navigation transition in an unexpected state|"
    r"whose view is not in the window hierarchy|HARNESS_FAILURE", re.I)


def choose_simulator(path):
    data = json.loads(path.read_text())
    runtimes = {runtime["identifier"]: runtime for runtime in data["runtimes"]
                if runtime.get("isAvailable") and ".iOS-" in runtime["identifier"]}
    types = data.get("devicetypes", [])
    by_name = {kind["name"]: kind["identifier"] for kind in types}
    candidates = []
    for runtime_id, devices in data["devices"].items():
        runtime = runtimes.get(runtime_id)
        if runtime is None:
            continue
        version = tuple(int(part) for part in runtime.get("version", "0").split("."))
        if version < (15,):
            continue
        for device in devices:
            name = device.get("name", "")
            if not device.get("isAvailable") or not name.startswith("iPhone"):
                continue
            type_id = device.get("deviceTypeIdentifier") or by_name.get(name)
            if not type_id:
                continue
            large = "Pro Max" in name or "Plus" in name or "Max" in name
            candidates.append(((large, version, name), type_id, runtime_id))
    if not candidates:
        raise ValueError("No available iPhone with an installed iOS >=15 runtime; no runtime will be downloaded")
    _, type_id, runtime_id = max(candidates)
    print(type_id)
    print(runtime_id)


def run_bounded(seconds, command):
    try:
        return subprocess.run(command, timeout=seconds, check=False).returncode
    except subprocess.TimeoutExpired:
        print(f"Timed out after {seconds:g}s: {command[0]}", file=sys.stderr)
        return 124


def poll_report(udid, output):
    deadline = time.monotonic() + 180
    container = None
    while time.monotonic() < deadline:
        if container is None:
            # This UDID was freshly created for this run. Read its data-container
            # metadata directly so a busy CoreSimulator service cannot abort polling.
            base = Path.home() / "Library/Developer/CoreSimulator/Devices" / udid / "data/Containers/Data/Application"
            if base.is_dir():
                import plistlib
                for candidate in base.iterdir():
                    metadata = candidate / ".com.apple.mobile_container_manager.metadata.plist"
                    try:
                        info = plistlib.loads(metadata.read_bytes())
                    except (OSError, ValueError, plistlib.InvalidFileException):
                        continue
                    if info.get("MCMMetadataIdentifier") == "dev.dopamine.layout-harness":
                        container = candidate
                        break
            if container is None:
                try:
                    query = subprocess.run(["xcrun", "simctl", "get_app_container", udid,
                                            "dev.dopamine.layout-harness", "data"],
                                           capture_output=True, text=True, timeout=30, check=False)
                    candidate = Path(query.stdout.strip())
                    if query.returncode == 0 and candidate.is_dir():
                        container = candidate
                except subprocess.TimeoutExpired:
                    continue
        if container is not None:
            report = container / "Documents/report.json"
            if report.is_file():
                payload = json.loads(report.read_text())
                if payload.get("complete") is True:
                    print(container)
                    return 0
        time.sleep(0.25)
    (output / "timeout.txt").write_text("No complete harness report within 180s after launch.\n")
    raise ValueError("UIKit harness did not publish report.json within 180s; see simulator logs")


def png_info(path):
    raw = path.read_bytes()
    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError(f"Not a PNG screenshot: {path.name}")
    offset, compressed, size, colors = 8, bytearray(), None, None
    ended = False
    while offset < len(raw):
        if offset+12 > len(raw):
            raise ValueError(f"Truncated PNG: {path.name}")
        length = struct.unpack_from(">I", raw, offset)[0]
        kind = raw[offset+4:offset+8]
        content = raw[offset+8:offset+8+length]
        if offset+12+length > len(raw):
            raise ValueError(f"Truncated PNG chunk: {path.name}")
        crc = struct.unpack_from(">I", raw, offset+8+length)[0]
        if zlib.crc32(kind+content) & 0xffffffff != crc:
            raise ValueError(f"Corrupt PNG chunk: {path.name}")
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", content)
            size = (width, height)
            colors = color
            if depth != 8 or interlace != 0 or color not in (0, 2, 4, 6):
                # UIKit normally emits non-interlaced 8-bit RGB/RGBA. Other valid encodings remain inspectable.
                size = (width, height)
        elif kind == b"IDAT":
            compressed.extend(content)
        elif kind == b"IEND":
            ended = True
        offset += length+12
    if size is None or not ended or not compressed or min(size) <= 0:
        raise ValueError(f"Incomplete PNG image: {path.name}")
    pixels = zlib.decompress(compressed)
    if not pixels:
        raise ValueError(f"Empty PNG pixel stream: {path.name}")
    return {"file": path.name, "width": size[0], "height": size[1],
            "colorType": colors, "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def verify(output):
    report = json.loads((output / "report.json").read_text())
    errors, images = [], []
    checks = report.get("checks", [])
    if not bool(report.get("complete")) or not bool(report.get("passed")):
        errors.append("Harness did not pass all native layout checks")
    failures = [item for item in checks if item.get("passed") is not True]
    if failures or report.get("failureCount") != 0 or len(checks) < 500:
        errors.append(f"Invalid/incomplete assertion coverage: {len(checks)} assertions, {len(failures)} failures")
    coverage = report.get("coverage", {})
    if coverage.get("themes") != 5 or coverage.get("expectedScreenshots") != 85:
        errors.append("Unexpected five-theme screenshot matrix")
    screenshots = report.get("screenshots", [])
    if len(screenshots) != 85 or len({shot.get("file") for shot in screenshots}) != 85:
        errors.append(f"Expected 85 unique native screenshots, got {len(screenshots)}")
    for shot in screenshots:
        name = shot.get("file", "")
        if Path(name).name != name or not name.endswith(".png"):
            errors.append(f"Invalid screenshot name: {name!r}")
            continue
        try:
            image = png_info(output / name)
            if (image["width"], image["height"]) != (shot["pixelWidth"], shot["pixelHeight"]):
                errors.append(f"Screenshot size differs from native renderer report: {name}")
            if shot.get("passed") is not True or shot.get("sampledColors", 0) <= 4:
                errors.append(f"Native screenshot is blank or could not be drawn: {name}")
            images.append(image)
        except (OSError, ValueError, zlib.error, KeyError) as error:
            errors.append(str(error))
    manifest = report.get("sourceManifest", {})
    disk_manifest = json.loads((output / "source-manifest.json").read_text())
    if manifest != disk_manifest or len(manifest.get("production_sources", [])) != 7:
        errors.append("Compiled production-source manifest mismatch")
    if len(manifest.get("production_swift", [])) != 35 or len(manifest.get("production_metal", [])) != 1:
        errors.append("Missing actual Theseus Swift/Metal production coverage")
    hits = []
    for log_name in ("app.stdout.log", "app.stderr.log", "simulator.log"):
        path = output / log_name
        if not path.is_file():
            errors.append(f"Missing diagnostic log: {log_name}")
            continue
        for number, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
            if LAYOUT_ERRORS.search(line):
                hits.append({"file": log_name, "line": number, "text": line[:2000]})
    if hits:
        errors.append(f"Found {len(hits)} layout/exception diagnostics in native simulator logs")
    if not (output / "app.stderr.log").is_file() or "HARNESS_COMPLETE" not in (output / "app.stderr.log").read_text(errors="replace"):
        errors.append("Missing HARNESS_COMPLETE sentinel in native app console")
    if not (output / "simulator-log-status.txt").is_file() or (output / "simulator-log-status.txt").read_text().strip() != "0":
        errors.append("Could not collect complete simulator process logs")
    if not (output / "simulator-screen.png").is_file():
        errors.append("Missing simctl full-screen screenshot")
    else:
        try:
            images.append(png_info(output / "simulator-screen.png"))
        except (OSError, ValueError, zlib.error) as error:
            errors.append(str(error))
    result = {"passed": not errors, "errors": errors, "nativeFailureCount": len(failures),
              "assertionCount": len(checks), "screenshotCount": len(screenshots),
              "layoutLogFindings": hits, "images": images,
              "scope": "Production shared UIKit on iOS Simulator; Preferences/PSListController and full business pages are not executed"}
    (output / "verification.json").write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n")
    print(json.dumps({key: result[key] for key in ("passed", "assertionCount", "screenshotCount", "errors")}, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    sub.add_parser("choose").add_argument("json", type=Path)
    bounded = sub.add_parser("bounded")
    bounded.add_argument("seconds", type=float)
    bounded.add_argument("command", nargs=argparse.REMAINDER)
    poll = sub.add_parser("poll")
    poll.add_argument("udid")
    poll.add_argument("output", type=Path)
    sub.add_parser("check").add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        if args.operation == "choose":
            choose_simulator(args.json)
        elif args.operation == "bounded":
            command = args.command[1:] if args.command[:1] == ["--"] else args.command
            sys.exit(run_bounded(args.seconds, command))
        elif args.operation == "poll":
            sys.exit(poll_report(args.udid, args.output))
        else:
            sys.exit(verify(args.output))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"UIKit harness error: {error}", file=sys.stderr)
        sys.exit(1)

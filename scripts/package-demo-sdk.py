#!/usr/bin/env python3
"""Package the public Engine distribution consumed by the standalone demos."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
FFI = "libflare_im_core_sdk_ffi"
HEADER = "flare_im_core_sdk_ffi.h"
ANDROID_ABIS = ("armeabi-v7a", "arm64-v8a", "x86_64")


def run(*command):
    subprocess.run(command, check=True)


def pack(output, files):
    with output.open("wb") as stream, gzip.GzipFile(fileobj=stream, mode="wb", mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode="w") as archive:
            for name, source in files:
                archive.add(source, arcname=name)
    with output.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def apple_files(dist, stage):
    header = dist / "include" / HEADER
    headers = stage / "include"
    headers.mkdir()
    shutil.copyfile(header, headers / HEADER)
    (headers / "module.modulemap").write_text(
        f'module CFlareImCoreSdkFFI {{ header "{HEADER}" export * }}\n'
    )
    ios = dist / "ios"
    device = ios / "aarch64-apple-ios" / f"{FFI}.a"
    simulator = stage / f"{FFI}.a"
    run("lipo", "-create", str(ios / "aarch64-apple-ios-sim" / f"{FFI}.a"),
        str(ios / "x86_64-apple-ios" / f"{FFI}.a"), "-output", str(simulator))
    framework = stage / "FlareCoreFFI.xcframework"
    run("xcodebuild", "-create-xcframework", "-library", str(device), "-headers", str(headers),
        "-library", str(simulator), "-headers", str(headers), "-output", str(framework))
    return [(framework.name, framework)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, default=ROOT.parent / "flare-core-sdk-engine")
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--platform", action="append", choices=("wasm", "android", "apple"))
    args = parser.parse_args()
    dist = args.engine / "dist"
    if (dist / ".commercial-sdk").exists():
        raise SystemExit("Only the public Engine distribution can be packaged")
    args.out.mkdir(parents=True, exist_ok=True)
    wasm = args.engine / "bindings/wasm/pkg"
    wasm_files = [(name, wasm / name) for name in ("flare_im_core_sdk.js", "flare_im_core_sdk_bg.wasm")]
    if (wasm / "snippets").is_dir():
        wasm_files.append(("snippets", wasm / "snippets"))
    android = [(f"{abi}/{FFI}.so", dist / "android" / abi / f"{FFI}.so") for abi in ANDROID_ABIS]
    release_lock = args.out / "dependencies.lock.json"
    lock = json.loads((release_lock if release_lock.is_file() else ROOT / "demos/dependencies.lock.json").read_text())
    engine_revision = subprocess.check_output(["git", "-C", args.engine, "rev-parse", "HEAD"], text=True).strip()
    if engine_revision != lock["repositories"]["flare-core-sdk-engine"]:
        raise SystemExit("Engine checkout does not match the public dependency lock")
    if subprocess.check_output(["git", "-C", args.engine, "status", "--porcelain"], text=True).strip():
        raise SystemExit("Engine build must use a clean checkout")
    with TemporaryDirectory() as directory:
        release = args.platform or ("wasm", "android", "apple")
        files = {"wasm": wasm_files, "android": android}
        if "apple" in release:
            files["apple"] = apple_files(dist, Path(directory))
        for platform in release:
            output = args.out / f"core-{platform}.tar.gz"
            lock["artifacts"][platform] = {"tag": args.tag, "file": output.name, "sha256": pack(output, files[platform])}
            print(output)
    release_lock.write_text(json.dumps(lock, indent=2) + "\n")


if __name__ == "__main__":
    main()

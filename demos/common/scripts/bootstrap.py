#!/usr/bin/env python3
"""Restore the public sources and native artifacts pinned by this demo."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
from tempfile import TemporaryDirectory
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_ORG = "https://github.com/flare-im"
SOURCE_HOST = "https://codeload.github.com/flare-im"


def download(url, path):
    with urlopen(url, timeout=90) as response, path.open("wb") as output:
        shutil.copyfileobj(response, output)


def restore(destination, version, archive_source, checksum=None, strip_root=False):
    stamp = destination / ".flare-version"
    if stamp.is_file() and stamp.read_text() == version:
        return
    if destination.exists() and not stamp.is_file():
        raise ValueError(f"Refusing to replace an unmanaged directory: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=destination.parent) as temporary:
        stage = Path(temporary)
        archive = stage / "download.tar.gz"
        if isinstance(archive_source, Path):
            shutil.copyfile(archive_source, archive)
        else:
            download(archive_source, archive)
        if checksum:
            with archive.open("rb") as stream:
                actual = hashlib.file_digest(stream, "sha256").hexdigest()
            if actual != checksum:
                raise ValueError(f"SHA-256 mismatch for {destination.name}")
        unpacked = stage / "unpacked"
        with tarfile.open(archive, "r:gz") as bundle:
            bundle.extractall(unpacked, filter="data")
        if strip_root:
            [unpacked] = unpacked.iterdir()
        (unpacked / stamp.name).write_text(version)
        if destination.exists():
            shutil.rmtree(destination)
        unpacked.rename(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-directory", type=Path, help="Verify a locally staged SDK release")
    args = parser.parse_args()
    lock = json.loads((ROOT / "demo.lock.json").read_text())
    for repository, revision in lock["repositories"].items():
        if not re.fullmatch(r"flare-[a-z0-9-]+", repository) or not re.fullmatch(r"[0-9a-f]{40}", revision):
            raise ValueError(f"Invalid public source pin: {repository}")
        restore(ROOT / ".flare/sources" / repository, revision,
                f"{SOURCE_HOST}/{repository}/tar.gz/{revision}", strip_root=True)
        print(f"{repository} at {revision[:12]}")
    for platform, artifact in lock["artifacts"].items():
        tag, filename, checksum = artifact["tag"], artifact["file"], artifact["sha256"]
        if not re.fullmatch(r"[a-z0-9-]+", platform) or not re.fullmatch(r"[a-zA-Z0-9.-]+", tag):
            raise ValueError(f"Invalid native artifact pin: {platform}")
        if not re.fullmatch(r"[a-z0-9-]+\.tar\.gz", filename) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
            raise ValueError(f"Invalid filename or checksum for {platform}")
        source = args.artifact_directory / filename if args.artifact_directory else (
            f"{PUBLIC_ORG}/flare-core-sdk/releases/download/{tag}/{filename}"
        )
        restore(ROOT / ".flare/artifacts" / platform, checksum, source, checksum=checksum)
        print(f"{platform} SDK artifacts at {tag}")
    if lock["platform"] in {"web", "electron", "tauri"}:
        tokens = ROOT / ".flare/sources/flare-im-design/tokens"
        subprocess.run(["node", "build.mjs"], cwd=tokens, check=True)
    if lock["platform"] == "android":
        native = ROOT / ".flare/sources/flare-core-sdk/native/artifacts/android"
        artifacts = ROOT / ".flare/artifacts/android"
        shutil.copytree(artifacts, native, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".flare-version"))
        jni_libraries = ROOT / ".flare/sources/flare-core-sdk/packages/flare-core-android-sdk/src/main/jniLibs"
        shutil.copytree(artifacts, jni_libraries, dirs_exist_ok=True, ignore=shutil.ignore_patterns(".flare-version"))


if __name__ == "__main__":
    main()

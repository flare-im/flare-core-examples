#!/usr/bin/env python3
"""Export the public Core platform demo from the local examples repository."""

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
DEMOS = ROOT / "demos"
PLATFORMS = json.loads((DEMOS / "platforms.json").read_text())
DESKTOP_ROOTS = {"src", "assets", "public", "electron", "src-tauri"}
DESKTOP_FILES = {"index.html", "tsconfig.electron.json"}
SDK_SOURCES = ".flare/sources"
COMMERCIAL = re.compile(r"flare-commercial-client-runtime|flare-plugins-commercial|@flare-im/core-web-update")
TEXT = {".ts", ".mts", ".mjs", ".vue", ".json", ".kt", ".swift", ".dart", ".toml", ".yaml", ".kts", ".rs"}


def tracked_files():
    names = subprocess.check_output(["git", "-C", ROOT, "ls-files", "-z", "--cached", "--others", "--exclude-standard"])
    return sorted({PurePosixPath(name) for name in names.decode().split("\0") if name})


def copy_files(files, source_prefix, destination, include=lambda path: True, rewrite=False):
    prefix = PurePosixPath(source_prefix)
    for name in files:
        if not name.is_relative_to(prefix):
            continue
        relative = name.relative_to(prefix)
        source = ROOT / name
        if not include(relative) or not source.is_file():
            continue
        if source.is_symlink():
            raise ValueError(f"Export sources cannot be symbolic links: {name}")
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if rewrite and target.suffix in TEXT:
            content = source.read_text()
            content = re.sub(r"(?:\.\./)+shared/vue-reference/", "@reference/", content)
            target.write_text(content)
        else:
            shutil.copy2(source, target)


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def desktop_sources(files, platform, target):
    source = f"apps/flare-core-{platform}-app"

    def include(path):
        if path.as_posix() in {"src/sw.ts", "src-tauri/Cargo.lock"}:
            return False
        if path.name.endswith((".test.ts", ".spec.ts", ".test.mjs")):
            return False
        return path.parts[0] in DESKTOP_ROOTS or path.name in DESKTOP_FILES

    copy_files(files, source, target, include, rewrite=True)
    copy_files(files, "shared/vue-reference", target / "reference",
               lambda path: not path.name.endswith((".test.ts", ".spec.ts", ".test.mjs")))
    copy_files(files, "demos/desktop", target)
    manifest = json.loads((ROOT / source / "package.json").read_text())
    manifest["name"] = f"flare-core-{platform}-demo"
    dependencies = manifest["dependencies"]
    for name in ("@flare-im/core-web-update", "@tauri-apps/plugin-updater", "@tauri-apps/plugin-process"):
        dependencies.pop(name, None)
    dependencies.update({
        "@flare-im/sdk": f"file:{SDK_SOURCES}/flare-core-sdk/packages/flare-core-typescript-sdk",
        "@flare-im/vue-ui": f"file:{SDK_SOURCES}/flare-im-design/packages/vue-im-ui",
        "@flare-im/tokens": f"file:{SDK_SOURCES}/flare-im-design/tokens",
        "vue": "^3.5.42",
    })
    scripts = manifest["scripts"]
    for key in list(scripts):
        if key.startswith(("test", "verify:", "check:")):
            del scripts[key]
    if platform == "web":
        scripts["build:web"] = "vue-tsc --noEmit && vite build"
    if platform == "electron":
        manifest["build"].update(appId="im.flare.core.demo.electron", productName="Flare Core Demo")
    if platform == "tauri":
        scripts.update(dev="npm run tauri -- dev", build="vue-tsc --noEmit && vite build",
                       tauri="tauri", **{"tauri:build": "tauri build"})
    manifest["demoPlatform"] = platform
    write_json(target / "package.json", manifest)
    if platform == "tauri":
        tauri_config = target / "src-tauri/tauri.conf.json"
        data = json.loads(tauri_config.read_text())
        data.update(identifier="im.flare.core.demo.tauri", productName="Flare Core Tauri Demo")
        data["build"].update(beforeDevCommand="npm run dev:renderer", beforeBuildCommand="npm run build")
        write_json(tauri_config, data)


def verify_export(target):
    for path in target.rglob("*"):
        if path.is_file() and path.suffix in TEXT and COMMERCIAL.search(path.read_text()):
            raise ValueError(f"Private dependency in export: {path.relative_to(target)}")
    if not (target / "README.md").is_file():
        raise ValueError("Demo must have a standalone README.md")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=PLATFORMS)
    parser.add_argument("output", type=Path)
    parser.add_argument("--lock", type=Path, default=DEMOS / "dependencies.lock.json")
    args = parser.parse_args()
    destination = args.output.resolve()
    if destination.exists():
        raise SystemExit(f"Choose a new export directory: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    files = tracked_files()
    platform = PLATFORMS[args.platform]
    dependencies = json.loads(args.lock.read_text())
    try:
        lock = {"platform": args.platform,
                "repositories": {name: dependencies["repositories"][name] for name in platform["sources"]},
                "artifacts": {name: dependencies["artifacts"][name] for name in platform["native"]}}
    except KeyError as error:
        raise SystemExit(f"Public SDK dependency missing from release lock: {error}") from error
    with TemporaryDirectory(dir=destination.parent) as temporary:
        target = Path(temporary) / destination.name
        target.mkdir()
        copy_files(files, "demos/common", target)
        if platform.get("desktop"):
            desktop_sources(files, args.platform, target)
        if args.platform in {"android", "flutter"}:
            target_android = target / "android" if args.platform == "flutter" else target
            copy_files(files, "apps/flare-core-android-app", target_android,
                       lambda path: path.parts[0] in {"gradlew", "gradlew.bat", "gradle"})
        copy_files(files, f"demos/{args.platform}", target)
        write_json(target / "demo.lock.json", lock)
        verify_export(target)
        target.rename(destination)
    print(destination)


if __name__ == "__main__":
    main()

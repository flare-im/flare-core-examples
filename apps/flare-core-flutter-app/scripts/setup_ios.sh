#!/usr/bin/env bash
# iOS 首次运行 / 清理后：同步 Rust FFI + CocoaPods
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_SDK_ROOT="$(cd "$APP_ROOT/../.." && pwd)"

echo "==> flutter pub get"
(cd "$APP_ROOT" && flutter pub get)

echo "==> sync Flutter FFI (iOS simulator → ios/FFI/build/)"
HOST_ARCH="$(uname -m)"
FLARE_IOS_PLATFORM=simulator ARCHS="${ARCHS:-$HOST_ARCH}" "$APP_ROOT/scripts/ensure_ios_ffi_staticlib.sh"

echo "==> pod install"
(cd "$APP_ROOT/ios" && pod install)

echo "Done. Run: flutter run -d \"iPhone 17 Pro\""

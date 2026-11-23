#!/usr/bin/env bash
# Embed the SDK's prepared host artifact; building the app does not invoke a removed root xtask.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKSPACE_ROOT="$(cd "$APP_ROOT/../../.." && pwd)"
SOURCE_LIB="${FLARE_CORE_FFI_DYLIB:-$WORKSPACE_ROOT/flare-core-sdk/native/artifacts/host/libflare_im_core_sdk_ffi.dylib}"

if [[ ! -f "$SOURCE_LIB" ]]; then
  printf 'error: [macos-ffi] SDK host artifact missing: %s. Prepare the Core SDK native artifact or set FLARE_CORE_FFI_DYLIB.\n' "$SOURCE_LIB" >&2
  exit 1
fi

for arch in ${ARCHS:-$(uname -m)}; do
  lipo "$SOURCE_LIB" -verify_arch "$arch" >/dev/null
done

# Validate the generated public C ABI before embedding a stale-but-loadable dylib.
ABI_HEADER="$WORKSPACE_ROOT/flare-core-sdk/native/abi/flare_im_core_sdk_ffi.h"
EXPORTED_SYMBOLS="$(nm -gU "$SOURCE_LIB" | awk '{print $NF}')"
REQUIRED_SYMBOLS="$(sed -nE '/^[[:space:]]*[[:alnum:]_]/s/.*(flare_[[:alnum:]_]+)\(.*/\1/p' "$ABI_HEADER")"
[[ -n "$REQUIRED_SYMBOLS" ]] || { printf 'error: [macos-ffi] No C ABI symbols found in SDK header.\n' >&2; exit 1; }
for symbol in $REQUIRED_SYMBOLS; do
  if ! printf '%s\n' "$EXPORTED_SYMBOLS" | grep -x "_$symbol" >/dev/null; then
    printf 'error: [macos-ffi] SDK host artifact is stale: missing %s. Rebuild the Core FFI and run make sync-host in flare-core-sdk.\n' "$symbol" >&2
    exit 1
  fi
done

DEST_DIR="${TARGET_BUILD_DIR:?TARGET_BUILD_DIR is required}/${WRAPPER_NAME:?WRAPPER_NAME is required}/Contents/MacOS"
mkdir -p "$DEST_DIR"
cp "$SOURCE_LIB" "$DEST_DIR/libflare_im_core_sdk_ffi.dylib"
if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "NO" ]]; then
  codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$DEST_DIR/libflare_im_core_sdk_ffi.dylib"
fi
printf '[macos-ffi] Embedded Core SDK host artifact.\n'

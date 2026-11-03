#!/usr/bin/env bash
# Build and verify the Rust FFI static library required by the Flutter iOS app.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_SDK_ROOT="$(cd "$APP_ROOT/../.." && pwd)"
FLARE_IM_ROOT="$(cd "$CLIENT_SDK_ROOT/.." && pwd)"
CORE_SDK_ROOT="$FLARE_IM_ROOT/flare-core-sdk-engine"
CORE_MANIFEST="$CORE_SDK_ROOT/Cargo.toml"
FFI_PACKAGE="flare-im-core-sdk-ffi"
STATIC_LIB="libflare_im_core_sdk_ffi.a"
OUT_DIR="$APP_ROOT/ios/FFI/build"
OUT_LIB="$OUT_DIR/$STATIC_LIB"

log() {
  printf '[ios-ffi] %s\n' "$*"
}

fail() {
  printf 'error: [ios-ffi] %s\n' "$*" >&2
  exit 1
}

resolve_target_root() {
  if [[ -n "${CARGO_TARGET_DIR:-}" ]]; then
    case "$CARGO_TARGET_DIR" in
      /*) printf '%s' "$CARGO_TARGET_DIR" ;;
      *) printf '%s' "$CORE_SDK_ROOT/$CARGO_TARGET_DIR" ;;
    esac
    return
  fi

  local metadata target_dir
  metadata="$(
    cd "$CORE_SDK_ROOT"
    cargo metadata --format-version 1 --no-deps --manifest-path "$CORE_MANIFEST"
  )"
  target_dir="$(printf '%s' "$metadata" | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p')"
  [[ -n "$target_dir" ]] || fail "unable to resolve Cargo target_directory from cargo metadata"
  printf '%s' "$target_dir"
}

TARGET_ROOT="$(resolve_target_root)"

platform_hint() {
  local value="${FLARE_IOS_PLATFORM:-${SDK_NAME:-${EFFECTIVE_PLATFORM_NAME:-${PLATFORM_NAME:-${SDKROOT:-}}}}}"
  printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}

is_device_build() {
  local hint
  hint="$(platform_hint)"
  [[ "$hint" == *iphoneos* || "$hint" == "device" ]]
}

is_simulator_build() {
  local hint
  hint="$(platform_hint)"
  [[ "$hint" == *iphonesimulator* || "$hint" == *simulator* || "$hint" == "sim" ]]
}

parse_arches() {
  local raw="${ARCHS:-${CURRENT_ARCH:-}}"
  local arch
  local arches=()

  for arch in $raw; do
    case "$arch" in
      arm64|x86_64)
        if [[ " ${arches[*]-} " != *" $arch "* ]]; then
          arches+=("$arch")
        fi
        ;;
    esac
  done

  if (( ${#arches[@]} == 0 )); then
    if is_device_build; then
      arches=(arm64)
    else
      case "$(uname -m)" in
        x86_64) arches=(x86_64) ;;
        *) arches=(arm64) ;;
      esac
    fi
  fi

  printf '%s\n' "${arches[@]}"
}

target_for_arch() {
  local arch="$1"
  if is_device_build; then
    [[ "$arch" == "arm64" ]] || fail "iOS device builds only support arm64, got $arch"
    printf 'aarch64-apple-ios'
    return
  fi

  case "$arch" in
    arm64) printf 'aarch64-apple-ios-sim' ;;
    x86_64) printf 'x86_64-apple-ios' ;;
    *) fail "unsupported iOS simulator architecture: $arch" ;;
  esac
}

archive_has_arches() {
  local archive="$1"
  shift
  [[ -f "$archive" ]] || return 1
  command -v lipo >/dev/null 2>&1 || return 0
  lipo "$archive" -verify_arch "$@" >/dev/null 2>&1
}

archive_first_object_otool() (
  set -euo pipefail

  local archive="$1"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/flare-ios-ffi.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT

  local inspect_archive="$archive"
  if command -v lipo >/dev/null 2>&1 && lipo -info "$archive" 2>/dev/null | grep -q 'Architectures in the fat file'; then
    local arch="${REQUIRED_ARCHES[0]:-}"
    [[ -n "$arch" ]] || return 1
    inspect_archive="$tmp/thin.a"
    lipo "$archive" -thin "$arch" -output "$inspect_archive" >/dev/null 2>&1
  fi

  local member
  member="$(ar -t "$inspect_archive" 2>/dev/null | awk '/\.o$/ { print; exit }' || true)"
  [[ -n "$member" ]] || return 1

  (
    cd "$tmp"
    ar -x "$inspect_archive" "$member" >/dev/null 2>&1
    {
      otool -l "$member" 2>/dev/null | awk '
        /^[[:space:]]*platform[[:space:]]+/ { print; exit }
        /LC_VERSION_MIN_IPHONEOS|LC_VERSION_MIN_IPHONESIMULATOR/ { print; exit }
      '
    } || true
  )
)

archive_matches_platform() {
  local archive="$1"
  [[ -f "$archive" ]] || return 1
  command -v otool >/dev/null 2>&1 || return 0
  command -v ar >/dev/null 2>&1 || return 0

  local output
  output="$(archive_first_object_otool "$archive" || true)"
  [[ -n "$output" ]] || return 1
  if is_device_build; then
    printf '%s\n' "$output" | grep -E 'platform[[:space:]]+(2|IOS)([[:space:]]|$)|LC_VERSION_MIN_IPHONEOS' >/dev/null
    return
  fi
  if is_simulator_build; then
    printf '%s\n' "$output" | grep -E 'platform[[:space:]]+(7|IOSSIMULATOR)([[:space:]]|$)|LC_VERSION_MIN_IPHONESIMULATOR' >/dev/null
    return
  fi
  return 0
}

rust_inputs_newer_than_archive() {
  [[ -f "$OUT_LIB" ]] || return 0

  local file
  for file in \
    "$CORE_MANIFEST" \
    "$FLARE_IM_ROOT/Cargo.lock" \
    "$CORE_SDK_ROOT/bindings/c/Cargo.toml" \
    "$CORE_SDK_ROOT/bindings/c/build.rs" \
    "$CORE_SDK_ROOT/bindings/shared/Cargo.toml" \
    "$CORE_SDK_ROOT/storage/sqlite/Cargo.toml" \
    "$FLARE_IM_ROOT/flare-transport/Cargo.toml" \
    "$FLARE_IM_ROOT/flare-protocol/Cargo.toml" \
    "$FLARE_IM_ROOT/flare-protocol-grpc/Cargo.toml"; do
    [[ -e "$file" && "$file" -nt "$OUT_LIB" ]] && return 0
  done

  local newer
  newer="$(
    find \
      "$CORE_SDK_ROOT/src" \
      "$CORE_SDK_ROOT/bindings/c/src" \
      "$CORE_SDK_ROOT/bindings/shared/src" \
      "$CORE_SDK_ROOT/storage/sqlite/src" \
      "$FLARE_IM_ROOT/flare-transport/src" \
      "$FLARE_IM_ROOT/flare-protocol/src" \
      "$FLARE_IM_ROOT/flare-protocol-grpc/src" \
      -type f \( -name '*.rs' -o -name '*.proto' \) \
      -newer "$OUT_LIB" \
      -print \
      -quit 2>/dev/null
  )"
  [[ -n "$newer" ]]
}

rustup_target_add() {
  local target="$1"
  if command -v rustup >/dev/null 2>&1; then
    rustup target add "$target" >/dev/null
  fi
}

build_target() {
  local target="$1"
  local sdk_name sdk_root deployment_target target_key clang clangxx archive_tool

  case "$target" in
    aarch64-apple-ios)
      sdk_name="iphoneos"
      ;;
    aarch64-apple-ios-sim|x86_64-apple-ios)
      sdk_name="iphonesimulator"
      ;;
    *)
      fail "unsupported Rust iOS target: $target"
      ;;
  esac

  sdk_root="$(xcrun --sdk "$sdk_name" --show-sdk-path)"
  clang="$(xcrun --sdk "$sdk_name" --find clang)"
  clangxx="$(xcrun --sdk "$sdk_name" --find clang++)"
  archive_tool="$(xcrun --sdk "$sdk_name" --find ar)"
  deployment_target="${FLARE_IOS_DEPLOYMENT_TARGET:-15.0}"
  target_key="${target//-/_}"

  rustup_target_add "$target"
  log "cargo build -p $FFI_PACKAGE --target $target"
  (
    cd "$CORE_SDK_ROOT"
    env \
      -u MACOSX_DEPLOYMENT_TARGET \
      -u CC \
      -u CXX \
      -u AR \
      -u CFLAGS \
      -u CXXFLAGS \
      -u CPPFLAGS \
      -u LDFLAGS \
      "SDKROOT=$sdk_root" \
      "IPHONEOS_DEPLOYMENT_TARGET=$deployment_target" \
      "CC_${target_key}=$clang" \
      "CXX_${target_key}=$clangxx" \
      "AR_${target_key}=$archive_tool" \
      RUSTC_WRAPPER= \
      cargo build --release --target "$target" --manifest-path "$CORE_MANIFEST" -p "$FFI_PACKAGE"
  )
}

copy_or_lipo() {
  local sources=("$@")
  mkdir -p "$OUT_DIR"
  if (( ${#sources[@]} == 1 )); then
    cp "${sources[0]}" "$OUT_LIB"
    return
  fi
  command -v lipo >/dev/null 2>&1 || fail "lipo is required to create a universal iOS simulator static library"
  lipo -create "${sources[@]}" -output "$OUT_LIB"
}

REQUIRED_ARCHES=()
while IFS= read -r arch; do
  [[ -n "$arch" ]] && REQUIRED_ARCHES+=("$arch")
done < <(parse_arches)

if (( ${#REQUIRED_ARCHES[@]} == 0 )); then
  fail "unable to determine the target iOS architecture from ARCHS/CURRENT_ARCH"
fi

EXISTING_COMPATIBLE=0
if archive_has_arches "$OUT_LIB" "${REQUIRED_ARCHES[@]}" && archive_matches_platform "$OUT_LIB"; then
  EXISTING_COMPATIBLE=1
fi

if [[ "${FLARE_IOS_SKIP_RUST_BUILD:-0}" == "1" ]]; then
  if [[ "$EXISTING_COMPATIBLE" == "1" ]]; then
    log "using existing $OUT_LIB (${REQUIRED_ARCHES[*]})"
    exit 0
  fi
  fail "missing or incompatible $OUT_LIB; unset FLARE_IOS_SKIP_RUST_BUILD to build it"
fi

if [[ "$EXISTING_COMPATIBLE" == "1" && "${FLARE_IOS_REUSE_EXISTING_RUST_FFI:-0}" == "1" ]]; then
  log "using existing $OUT_LIB (${REQUIRED_ARCHES[*]})"
  exit 0
fi

if [[ "$EXISTING_COMPATIBLE" == "1" ]] && ! rust_inputs_newer_than_archive; then
  log "using existing $OUT_LIB (${REQUIRED_ARCHES[*]})"
  exit 0
fi

log "syncing $STATIC_LIB for ${FLARE_IOS_PLATFORM:-${PLATFORM_NAME:-${SDK_NAME:-iOS simulator}}} (${REQUIRED_ARCHES[*]})"

SOURCES=()
for arch in "${REQUIRED_ARCHES[@]}"; do
  target="$(target_for_arch "$arch")"
  build_target "$target"
  source_lib="$TARGET_ROOT/$target/release/$STATIC_LIB"
  [[ -f "$source_lib" ]] || fail "cargo build finished but staticlib was not found: $source_lib"
  SOURCES+=("$source_lib")
done

copy_or_lipo "${SOURCES[@]}"
archive_has_arches "$OUT_LIB" "${REQUIRED_ARCHES[@]}" || fail "$OUT_LIB does not contain required architecture(s): ${REQUIRED_ARCHES[*]}"
archive_matches_platform "$OUT_LIB" || fail "$OUT_LIB was built for a different Apple platform"
log "ready: $OUT_LIB"

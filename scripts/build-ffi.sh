#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="${1:-debug}"
TARGET_DIR="${PROJECT_ROOT}/target"
GENERATED_DIR="${PROJECT_ROOT}/macos/Pustaka/Generated"

mkdir -p "${GENERATED_DIR}"

echo "==> Building Rust pustaka-ffi in ${MODE} mode..."
if [ "${MODE}" = "release" ]; then
    cargo build -p pustaka-ffi --release
    DYLIB_PATH="${TARGET_DIR}/release/libpustaka_ffi.dylib"
else
    cargo build -p pustaka-ffi
    DYLIB_PATH="${TARGET_DIR}/debug/libpustaka_ffi.dylib"
fi

echo "==> Generating UniFFI Swift bindings..."
cargo run -p pustaka-ffi --bin uniffi-bindgen -- generate \
    "${DYLIB_PATH}" \
    --language swift \
    --out-dir "${GENERATED_DIR}"

echo "==> UniFFI bindings generated in ${GENERATED_DIR}:"
ls -la "${GENERATED_DIR}"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/native"
if command -v brew >/dev/null 2>&1; then
  export CMAKE_PREFIX_PATH="$(brew --prefix opencascade):${CMAKE_PREFIX_PATH:-}"
fi
cmake -S "$ROOT/src/native" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
  -DJET_CAD_BUILD_TESTS=ON "$@"
cmake --build "$BUILD" --parallel
ctest --test-dir "$BUILD" --output-on-failure
echo "native library: $(ls "$BUILD"/libjet_cad_native.*)"

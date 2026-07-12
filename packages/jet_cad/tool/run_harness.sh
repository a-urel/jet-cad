#!/usr/bin/env bash
# Builds the native shim, then runs the dev harness with the dylib path
# exported. Run from anywhere; paths are resolved from this script.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg_dir="$(dirname "$script_dir")"
repo_dir="$(cd "$pkg_dir/../.." && pwd)"

"$script_dir/build_native.sh"

export JET_CAD_NATIVE_LIB="$pkg_dir/build/native/libjet_cad_native.dylib"
cd "$repo_dir/apps/dev_harness"
flutter run -d macos "$@"

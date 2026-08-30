#!/bin/sh
# Compiles the shader bundle. Checked in so the committed bundle is
# reproducible rather than a binary somebody once produced.
#
# `impellerc` ships in the engine artifacts and is not on PATH.
# `--runtime-stage-gles` is the stage `flutter_scene`'s web loader reads
# (`entry.openglEs`, then `transpileGlslEs100To300`); the metal and vulkan
# stages serve native.
#
# The committed `assets/shaders/cad.shaderbundle` was built with Flutter SDK
# 3.47.1 (`flutter --version`). Its engine artifacts live under a directory
# named `3.27.3` -- that is the Homebrew *cask* version at install time, not
# the SDK version, and is unrelated to the number above; do not read it as a
# stale toolchain.
set -e

# Portable equivalent of `readlink -f`, which is GNU/newer-BSD only and
# degrades silently to a relative path where it is absent (reviewer
# reproduced this) rather than failing loudly. `pwd -P` and bare `readlink`
# are POSIX.
resolve_path() {
  target="$1"
  while [ -L "$target" ]; do
    dir="$(cd "$(dirname "$target")" && pwd -P)"
    target="$(readlink "$target")"
    case "$target" in
      /*) ;;
      *) target="$dir/$target" ;;
    esac
  done
  dir="$(cd "$(dirname "$target")" && pwd -P)"
  echo "$dir/$(basename "$target")"
}

FLUTTER_BIN="$(resolve_path "$(command -v flutter)")"
FLUTTER_ROOT="$(dirname "$(dirname "$FLUTTER_BIN")")"

# The engine artifact directory is per-host-platform (`darwin-x64`,
# `darwin-arm64`, `linux-x64`, `android-arm64`, ...), not a fixed name, so it
# is selected from what the active SDK actually shipped rather than
# hard-coded to `darwin-x64`.
IMPELLERC=""
for candidate in $(ls "$FLUTTER_ROOT"/bin/cache/artifacts/engine/*/impellerc 2>/dev/null | sort); do
  if [ -x "$candidate" ]; then
    IMPELLERC="$candidate"
    break
  fi
done
if [ -z "$IMPELLERC" ]; then
  echo "impellerc not found under $FLUTTER_ROOT/bin/cache/artifacts/engine/*/impellerc" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
"$IMPELLERC" \
  --runtime-stage-metal --runtime-stage-vulkan --runtime-stage-gles \
  --shader-bundle='{"CadStrokeVertex":{"type":"vertex","file":"shaders/cad_stroke.vert"},"CadStrokeFragment":{"type":"fragment","file":"shaders/cad_stroke.frag"}}' \
  --sl=assets/shaders/cad.shaderbundle
echo "wrote assets/shaders/cad.shaderbundle"

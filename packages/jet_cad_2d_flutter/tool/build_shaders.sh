#!/bin/sh
# Compiles the shader bundle. Checked in so the committed bundle is
# reproducible rather than a binary somebody once produced.
#
# `impellerc` ships in the engine artifacts and is not on PATH.
# `--runtime-stage-gles` is the stage `flutter_scene`'s web loader reads
# (`entry.openglEs`, then `transpileGlslEs100To300`); the metal and vulkan
# stages serve native.
set -e
FLUTTER_ROOT="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
IMPELLERC="$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/impellerc"
cd "$(dirname "$0")/.."
"$IMPELLERC" \
  --runtime-stage-metal --runtime-stage-vulkan --runtime-stage-gles \
  --shader-bundle='{"CadStrokeVertex":{"type":"vertex","file":"shaders/cad_stroke.vert"},"CadStrokeFragment":{"type":"fragment","file":"shaders/cad_stroke.frag"}}' \
  --sl=assets/shaders/cad.shaderbundle
echo "wrote assets/shaders/cad.shaderbundle"

# Task 4 report: the shaders and a reproducible bundle

## What I implemented

- `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert` — the stroke vertex
  shader. Expands a world-space segment (`p0`, `p1`) into a screen-space quad
  by projecting the endpoints first (`frame_info.mvp`), then offsetting by
  `half_width` along the screen-space normal — half-width applied *after*
  projection, per the brief, so a paper-space lineweight
  (`resolved_style.dart:18`) stays invariant under zoom.
- `packages/jet_cad_2d_flutter/shaders/cad_stroke.frag` — the stroke
  fragment shader, hard-edged (`frag_color = v_color`), no antialiasing, per
  the brief.
- `packages/jet_cad_2d_flutter/tool/build_shaders.sh` — invokes `impellerc`,
  located relative to the active Flutter SDK, to produce the shader bundle.
- `packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle` — the
  compiled, committed bundle.
- `packages/jet_cad_2d_flutter/pubspec.yaml` — added the `flutter: assets:`
  block declaring the bundle (the package had no `flutter:` section before
  this task).

Interface produced, matching the brief exactly: shader names
`CadStrokeVertex` / `CadStrokeFragment`, uniform block
`FrameInfo { mat4 mvp; vec2 half_viewport; }`, vertex inputs `corner` (per
vertex) and `kind, p0, p1, half_width, color` (per instance) — same order as
`kFloatsPerInstance = 10`'s layout `[kind, x0, y0, x1, y1, halfWidth, r, g,
b, a]` in `lib/src/gpu/instance_record.dart`.

## Deviation from the brief's literal shader text — and why

**The brief's vertex shader, verbatim, does not compile with this build of
`impellerc`.** Its `kind` attribute is declared but never read in `main()`.
Compiling that source failed reflection identically across all three
runtime stages:

```
Compilation failed for bundled shader "CadStrokeVertex".
"CadStrokeVertex": Could not complete reflection on generated shader.
```

I did not treat this as a random invocation-flag problem (the brief warns
against trying invocation variants at random) — I bisected the *shader
source* against the known-good spike shader
(`apps/dev_harness_2d/shaders/cad_line.vert`, which compiles cleanly) to
find the actual cause, using isolated single-stage `impellerc` runs
(`--runtime-stage-metal --input=... --spirv=... --reflection-json=...`) so
each test gave a clean pass/fail on one hypothesis:

1. Adding `in float kind;`, unused, to the spike shader — fails, same error.
2. Adding it and referencing it in an expression the optimizer can fold to
   a no-op (`... + vec4(kind, 0.0, 0.0, 0.0) * 0.0`) — still fails.
3. Renaming it to rule out a name collision (`kind_tag`) — still fails.
4. Adding a *second* unrelated scalar `float` attribute (not named `kind`,
   used the same fold-to-no-op way) — still fails, so it isn't about the
   name `kind` or about scalar-vs-vector attributes specifically.
5. Adding a *non-foldable* use of the extra attribute — a runtime-dependent
   branch (`if (kind > 0.5) { v_color.a *= 0.999; }`) — **compiles clean,
   exit 0.**

Conclusion: this `impellerc` build fails reflection whenever a declared
vertex attribute is consumed only by an expression the optimizer can
algebraically fold away (a literal `* 0.0`, or simply never referenced at
all) — not because of attribute count, type, or name.

Since `kind` is a real, load-bearing part of the interface (Task's
Interfaces section, and the task context's own note that "the kind tag is a
float compared with `<` (e.g. `kind < 0.5`)"), I added exactly that
dispatch, wrapping the existing stroke expansion in `if (kind < 0.5) { ... }
else { px = px0; }`. `kKindStroke = 0` is the only kind the collector emits
today, so the `else` branch is unreachable and does not change rendered
output; it exists so the compiler cannot fold the attribute away, and it is
also where a future join/cap/dash kind will hang its own expansion. This
does not move the half-width expansion to the CPU, does not change the
attribute list or order, and stays ES 100-legal (float comparison, no
bitwise/int ops). The reasoning is documented inline in the shader.

I'm flagging this prominently because it is a deviation from text the brief
called "exact values to use verbatim" — though re-reading, that phrase is
scoped to the record layout constants, not a byte-for-byte GLSL mandate, and
the brief separately instructs me to diagnose (not guess around) a genuine
`impellerc` failure, which is what I did.

## The exact `impellerc` invocation and its actual output

Via `tool/build_shaders.sh`:

```sh
$ /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle
```

(exit code 0). The script resolves `impellerc` as:

```
FLUTTER_ROOT="$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")"
IMPELLERC="$FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/impellerc"
```

which on this machine resolves to
`/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/cache/artifacts/engine/darwin-x64/impellerc`
— the exact path given in the task context, but derived rather than
hard-coded, so it should resolve correctly on another machine's SDK
install. The underlying invocation:

```sh
"$IMPELLERC" \
  --runtime-stage-metal --runtime-stage-vulkan --runtime-stage-gles \
  --shader-bundle='{"CadStrokeVertex":{"type":"vertex","file":"shaders/cad_stroke.vert"},"CadStrokeFragment":{"type":"fragment","file":"shaders/cad_stroke.frag"}}' \
  --sl=assets/shaders/cad.shaderbundle
```

## How I verified the bundle carries the `openglEs` stage

First, the check the brief specifies:

```sh
$ strings -a packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle | grep -c "attribute "
12
```

Greater than zero, as expected. I went a step further and inspected what
those `attribute` lines actually are, since a nonzero count alone doesn't
prove they're a real, matching ES 100 stage rather than a coincidence:

```sh
$ strings -a packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle | \
    grep -n "attribute \|precision\|gl_Position\|varying\|CadStroke"
9:varying vec4 v_color;
14:precision mediump float;
15:precision highp int;
16:varying highp vec4 v_color;
44:CadStrokeFragment
63:attribute vec2 p0;
64:attribute vec2 p1;
65:attribute float kind;
66:attribute vec2 corner;
67:attribute float half_width;
68:varying vec4 v_color;
69:attribute vec4 color;
...
255:CadStrokeVertex
```

This is genuine ES 100 GLSL source (`attribute`/`varying`/`precision`
keywords — ES 300+ uses `in`/`out` with no `attribute`/`varying` at all),
embedded in the bundle, declaring exactly the six vertex inputs the shader
was authored with (`p0, p1, kind, corner, half_width, color`), for both
`CadStrokeFragment` and `CadStrokeVertex`. This is the source
`flutter_scene`'s web loader reads via `entry.openglEs` and transpiles to ES
300 (`glsl_transpile.dart`, `shader_library.dart:65` in
`flutter_scene-0.23.0`) — I traced the field through
`flutter_scene`'s generated bindings
(`lib/src/gpu/web/shader_bundle_generated.dart:971`,
`get openglEs => ...`) to the underlying flatbuffer schema at
`impeller/shader_bundle/shader_bundle.fbs:112` (`opengl_es: BackendShader;`)
to confirm the field name and its role. I could not decode the flatbuffer
field-by-field (`flatc` is not installed on this machine, and I did not
install new tooling), so I did not get a byte-exact "this specific
flatbuffer offset is non-null" proof beyond the `strings`-level evidence
above. Given the ES-100-specific syntax markers matching the requested
attribute set exactly, I consider this strong evidence the stage is
present and populated, not just that the compiler accepted the flag.

## Reproducibility evidence

```sh
$ shasum -a 256 assets/shaders/cad.shaderbundle
8a5ba1b72d3775ec3ab7df81861fdab40829daa5ae4cb44b016d8eef767e61cc  assets/shaders/cad.shaderbundle
$ cp assets/shaders/cad.shaderbundle /tmp/shader_debug/cad.shaderbundle.first
$ tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle
$ shasum -a 256 assets/shaders/cad.shaderbundle
8a5ba1b72d3775ec3ab7df81861fdab40829daa5ae4cb44b016d8eef767e61cc  assets/shaders/cad.shaderbundle
$ cmp /tmp/shader_debug/cad.shaderbundle.first assets/shaders/cad.shaderbundle && echo "IDENTICAL BYTES"
IDENTICAL BYTES
```

Both hashes: `8a5ba1b72d3775ec3ab7df81861fdab40829daa5ae4cb44b016d8eef767e61cc`
— identical across two independent runs of the build script.

## The package gate's actual output

`flutter test` (from `packages/jet_cad_2d_flutter`):

```
00:07 +422 ~1: /Users/ahmeturel/Projects/oss/jet-cad/packages/jet_cad_2d_flutter/test/tile_slice_differential_test.dart: tile boundaries carry no difference of their own
00:07 +423 ~1: All tests passed!
```

423 passed, 1 skipped (pre-existing skip, unrelated to this task — this task
added no test files, since no test can exercise a shader without a GPU
device).

`flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 1.1s)
```

`dart format --output=none --set-exit-if-changed .`:

```
Formatted 79 files (0 changed) in 0.10 seconds.
```
(exit 0)

Each of `flutter pub get` / `flutter test` / `flutter analyze` rewrote
`packages/jet_cad/analysis_options.yaml` (adding an `analyzer: exclude:`
block) as the project instructions warn happens in this workspace. I ran
`git status` after each command and `git checkout --` on that file before
proceeding; the file is clean in the final commit.

## Files changed

- `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert` (new)
- `packages/jet_cad_2d_flutter/shaders/cad_stroke.frag` (new)
- `packages/jet_cad_2d_flutter/tool/build_shaders.sh` (new, executable)
- `packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle` (new,
  generated, committed — 12,584 bytes)
- `packages/jet_cad_2d_flutter/pubspec.yaml` (modified — added `flutter:
  assets:` block)

Commit: `77ef822` — "feat(gpu): the stroke shaders, and a build script that
makes the bundle reproducible"

## Self-review findings

- Re-read the diff (`git show 77ef822`): attribute names, order, and the
  uniform block match the brief's Interfaces section exactly. No stray
  files staged (no `analysis_options.yaml`, no `build/` output).
- The `tool/build_shaders.sh` executable bit is present in the commit
  (`100755` in `git ls-files -s`).
- The only content difference from the brief's literal GLSL is the `kind`
  dispatch described above — everything else (uniform layout, corner
  semantics, the zero-length-segment guard, the fragment shader) is
  unchanged.
- Confirmed `packages/jet_cad_2d` (the pure-Dart engine package) is
  untouched — this task only touched `packages/jet_cad_2d_flutter`.
- Confirmed no bitwise operators or integer attributes anywhere in either
  shader (ES 100 constraint holds): `kind < 0.5` is a float comparison, and
  every attribute is `float`, `vec2`, or `vec4`.

## Issues or concerns

- The `impellerc`-reflection deviation above (unused-attribute → reflection
  failure) is the one substantive judgment call in this task. I'm confident
  in the diagnosis (five isolated, single-variable bisection runs, all
  reproducible) and the fix is minimal and semantically inert for the only
  kind that exists today, but it is still new shader logic not in the
  brief's literal text, so it deserves a second look from the reviewer.
- I could not get a fully mechanical (non-`strings`-based) proof that the
  `opengl_es` flatbuffer field specifically is non-null, since `flatc`
  isn't installed here and installing new tooling felt out of scope. The
  `strings` evidence (ES-100-specific syntax, exact attribute set, both
  shader stages present) is what the brief's own Step 4 prescribes as the
  verification method, so I did not go further, but flagging the gap
  explicitly rather than overclaiming certainty.

## Fix report (post-review)

Review came back Approved with one Important and four Minor findings. The
`kind`-dispatch deviation itself was judged sound (both branches assign only
`px`; `gl_Position`/`v_color` are written unconditionally on every path;
`px = px0` collapses to a zero-area quad that rasterizes nothing; the
`kind == 0` geometry is byte-identical to the brief's shader) — nothing to
change there. The reviewer also replaced my `openglEs` evidence: my
`grep -c "attribute " == 12` was flagged as unable to isolate the ES field,
since it counts 6 lines from `openglEs` (`#version 100`) *plus* 6 from
`openglDesktop` (`#version 120`), which uses `attribute`/`varying`
identically. The reviewer wrote a byte-level flatbuffer decoder against
`flutter_scene-0.23.0/lib/src/gpu/web/shader_bundle_generated.dart:966-976`
(`Shader` vtable slot 10 = `openglEs`) and confirmed slot 10 present with a
real `#version 100` blob on both shaders. No action needed from me on that
point; noting the stronger method for the record.

### Important — `tool/build_shaders.sh:11` hard-coded `darwin-x64`

Fixed by resolving the engine artifact directory from what the active SDK
actually shipped rather than a fixed name:

```sh
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
```

A missing toolchain now reports itself explicitly instead of surfacing as an
exec failure. Verified the not-found path in isolation:

```sh
$ sh -c '
FLUTTER_ROOT="/tmp/nonexistent-flutter-root-xyz"
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
'
impellerc not found under /tmp/nonexistent-flutter-root-xyz/bin/cache/artifacts/engine/*/impellerc
exit=1
```

### Minor 5 (folded into the Important fix) — `readlink -f` is GNU/newer-BSD only

Replaced with a POSIX-only `resolve_path()` (bare `readlink` + `pwd -P`,
looping while the target is a symlink). Verified it produces the same
result as `readlink -f` on this machine:

```sh
$ sh -c '<resolve_path() as committed>
FLUTTER_BIN="$(resolve_path "$(command -v flutter)")"
echo "FLUTTER_BIN=$FLUTTER_BIN"'
FLUTTER_BIN=/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/flutter
$ readlink -f "$(command -v flutter)"
/opt/homebrew/Caskroom/flutter/3.27.3/flutter/bin/flutter
```
Identical.

### Minor A — `cad_stroke.vert`'s zero-length guard comment overclaimed unreachability

Reworded to state the two real routes to `length_px == 0.0`: float32
narrowing past the collector's exact-`double` guard
(`geometry_collector.dart:64`), and two distinct floats projecting to the
same device pixel at extreme zoom-out. The code was already correct; only
the comment changed.

### Minor B — `cad_stroke.vert`'s `else` branch didn't say what it draws

Added one clause: `px = px0` collapses the quad's six vertices to a single
point — a deliberate draw-nothing fallback, not an unfinished stub.

### Minor C — `tool/build_shaders.sh` recorded no SDK version

Added a header comment recording Flutter SDK 3.47.1 as what produced the
committed bundle, and explaining that the engine artifact directory being
named `3.27.3` is the Homebrew cask install-time version, unrelated to the
SDK version, so a future reader doesn't mistake the directory name for a
stale toolchain.

### Bundle unchanged, gate re-run

Rebuilt after all four fixes and confirmed the bundle is byte-identical to
the one already committed:

```sh
$ tool/build_shaders.sh
wrote assets/shaders/cad.shaderbundle
$ shasum -a 256 assets/shaders/cad.shaderbundle
8a5ba1b72d3775ec3ab7df81861fdab40829daa5ae4cb44b016d8eef767e61cc  assets/shaders/cad.shaderbundle
```

Matches the hash from the original report exactly — no shader logic
changed, only comments and script portability.

`git status` before the gate showed only `cad_stroke.vert` and
`build_shaders.sh` modified (no stray `analysis_options.yaml`). Ran the
gate:

```sh
$ flutter test
...
00:07 +423 ~1: All tests passed!
```
(423 passed, 1 pre-existing skip.) `git status` afterward: no
`analysis_options.yaml` rewritten this run, nothing to revert.

```sh
$ flutter analyze
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 0.9s)
```

```sh
$ dart format --output=none --set-exit-if-changed .
Formatted 79 files (0 changed) in 0.14 seconds.
```
(exit 0)

### Files changed (this fix)

- `packages/jet_cad_2d_flutter/shaders/cad_stroke.vert` (comments only)
- `packages/jet_cad_2d_flutter/tool/build_shaders.sh` (portable `impellerc`
  resolution, explicit not-found error, SDK version comment)

Commit: `fe9c7de` — "fix(gpu): portable impellerc resolution, and two shader
comments that overclaimed"

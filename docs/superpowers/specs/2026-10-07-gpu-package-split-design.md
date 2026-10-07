# The GPU renderer in its own package — design

**Date:** 2026-10-07. **Status:** design, **revision 2**. Revision 1
(`567fbf9`) was reviewed independently: *Approved with fixes*, V-1 to
V-15. The fixes are folded in here; see [Review](#review).

**Asked by the human:** *"POS entegrasyonuna geç"*, then, at the question
of where to start, *"Önce jet-cad ön koşulu"*. The POS, Monépro
(`jetronik-io/monepro-frontend`), names this as its first jet-cad
prerequisite for the floor view, in spec 103 §10 (`develop @ 88c96e0`):
*"the GPU renderer split out of `jet_cad_2d_flutter` so `flutter_scene`'s
build hook never enters Monépro's build"*.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `23a8950`.
**Size:** M.

**Packages touched:**
- `jet_cad_2d_flutter`: the GPU code leaves; a registry is added.
- `jet_cad_2d_gpu`: new.
- `apps/dev_harness_2d`.
- The root workspace.
- CI and the host probe.
- Docs.

## Why

Today every host that depends on the planner resolves `flutter_scene` and
runs its build hook. The host probe shows it (F-6):
- `flutter_scene` 0.23.0 is in its lock;
- its hook ran;
- its web build ships 12 MB of `flutter_scene` assets.

The hook compiles shader bundles with the engine's `impellerc` (F-7). The
package also raises every host's floor to Flutter 3.47, while the host
guide says 3.44.

No host uses the GPU path. It is the measurement harness's, chosen only
by `RenderBackend.residentGpu`, never by default (F-3).

## Facts (at `23a8950`)

- **F-1. One file imports `flutter_scene`.** It is
  `jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart`, and it re-exports the
  package's `flutter_gpu` shim. It defines:
  - `GpuContextFactory`;
  - `debugSetGpuFactory`;
  - `gpuAvailable()`;
  - `debugSetGpuAvailable`.
- **F-2. What reaches the facade:**
  - **`resident_geometry.dart` (461 lines):**
    - `ResidentGeometry.create` loads `packages/jet_cad_2d_flutter/assets/shaders/cad.shaderbundle`.
    - Five getters are typed with `gpu` types.
    - `kInstanceVertexLayout` is a `gpu` type.
    - The pure statics `kCornerVertices`, `kFloatsPerCorner`,
      `cornerVertexCount` and `byteLengthFor` need no GPU.
  - **`gpu_draw_backend.dart` (692 lines):** `GpuDrawBackend implements
    ResidentFramePainter`, plus two pure functions, `buildFrameInfo` and
    `dashScaleFor`.
  - **`resident_rebuilder.dart`:**
    - `uploadResidentCollection` (`:49-66`), the only code that names
      `ResidentGeometry.create` and `GpuDrawBackend`.
    - GPU-free: `ResidentFramePainter`, `ResidentUploader` and
      `ResidentRebuilder`.
  - **`resident_collection.dart`:** reaches the facade only through
    `ResidentGeometry.byteLengthFor`.
  - **`render_backend.dart`:** `resolveBackend` calls `gpuAvailable()`.
  - **`draft_canvas.dart`:** imports the rebuilder and the backend; its
    default uploader closure names `uploadResidentCollection` (`:357-370`).
  - **The rest of `lib/src/gpu/`** (about 2,200 lines) is GPU-free:
    - `GeometryCollector`;
    - the collection;
    - text patches;
    - the compositor.
- **F-3. Who chooses the GPU.**
  - `enum RenderBackend { canvas, vertices, residentGpu }`; the default is
    `vertices`.
  - `resolveBackend(residentGpu)` gives `vertices` when no GPU is
    available, and `DraftCanvas` reports that fallback once per process.
  - The planner, the apps and the probe never name a backend.
  - `apps/dev_harness_2d` chooses `residentGpu`:
    - `gpu_arm.dart:569`;
    - `BACKEND=residentGpu`;
    - `GpuDrawBackend`;
    - `ResidentGeometry`.
- **F-4. The barrel** exports from `gpu/`:
  - every file except `instance_record.dart`;
  - `debugSetGpuAvailable` from the facade.
- **F-5. The tests.** `test/gpu/` is 24 files and runs on Linux CI, with
  the GPU forced off or faked. The ones that need the facade:
  - `gpu_facade_test`;
  - `backend_selection_test`;
  - `resident_geometry_test`;
  - `render_backend_test`;
  - `draft_canvas_fallback_test`;
  - `draft_canvas_resident_test`.

  The ladder goldens loop over `RenderBackend.values`, skipping
  `residentGpu`. Their names carry `(RenderBackend.canvas)`, and so does
  the standing list.
- **F-6. The host probe at HEAD.**
  - Its lock lists, as transitive dependencies:
    - `flutter_scene`;
    - `flutter_gpu` (sdk);
    - `flutter_gpu_shaders`;
    - `scene`;
    - `hooks`;
    - `code_assets`;
    - `data_assets`;
    - `record_use`;
    - `flat_buffers`;
    - `yaml_edit`.
  - `.dart_tool/hooks_runner/flutter_scene/` exists.
  - `build/web/assets/packages/flutter_scene/` is 12 MB, and so is the
    same directory in the floor planner's and the demo's web builds.
  - `main.dart.js` contains the `cad.shaderbundle` load path:
    `DraftCanvas` reaches it.
- **F-7. The hook.** `flutter_scene`'s `hook/build.dart` compiles its
  engine shader bundle through `flutter_gpu_shaders`, which needs the
  SDK's `impellerc`. The pubspec requires `flutter >=3.47.0`.
- **F-8. The asset.** `jet_cad_2d_flutter` declares
  `assets/shaders/cad.shaderbundle` (37 KB), which is GPU-only. Its source
  is `shaders/cad_stroke.{vert,frag}`, built by `tool/build_shaders.sh`.
- **F-9. The lock.** A pub workspace has a single lock, so only an
  out-of-workspace app (the host probe) can show what a host resolves.
  **But build hooks follow the built app's own dependencies.** The
  reviewer's experiment E3: a workspace member that does not depend on
  `flutter_scene` builds for the web without running the hook, even
  when a sibling member does depend on it. So after the split, the floor
  planner's and the demo's web builds lose the hook and the 12 MB too.
- **F-10. The trial split** (the reviewer's E1 and E2, in a clone):
  - **The lock.** With `flutter_scene` gone from core, the probe's lock
    holds none of F-6's names. It was the only package with a build
    hook: `pdf`, `printing`, `image`, `archive`, `posix` and `ffi` have
    none.
  - **The web build.**
    - The log reads "No packages with native assets".
    - There is no `.dart_tool/hooks_runner` and no
      `assets/packages/flutter_scene`.
    - `main.dart.js` names `cad.shaderbundle` zero times, against two at
      HEAD.
    - `build/web` falls from 54 MB to 42 MB.
  - **The SDK floor.** After `flutter pub downgrade` it is Dart 3.12 and
    Flutter 3.44. A fresh lock says Dart 3.13 only because pub picks the
    newest `xml` and `petitparser`.
- **F-11. What the new package needs from core.**
  - **Not exported:** `kFloatsPerInstance` and `InstanceFieldOffset`
    (`instance_record.dart`). The trial split had 21 analyzer errors,
    all on these two.
  - **`@visibleForTesting`:** `kCornerVertices` carries it, so reading it
    from another package warns.
- **F-12. Core's tests that read GPU files.**
  - `test/support/instance_expander.dart` is the Dart copy of
    `shaders/cad_stroke.vert`, and `instance_expander_test.dart:428`
    reads that shader source by a path relative to core.
  - Tests that use the pure statics or functions:
    - `instance_expander_test` and `resident_collection_test:139`;
    - `frame_info_test`;
    - `gpu_comparison.dart:775`.
  - `render_backend_test.dart:6` imports the facade directly.

## Decisions

- **S1. A new package, `packages/jet_cad_2d_gpu`.** It depends on
  `jet_cad_2d_flutter`, `jet_cad_2d` and `flutter_scene`. It receives:
  - the facade, unchanged;
  - `ResidentGeometry`, without its pure statics (S3);
  - `GpuDrawBackend`, without its pure functions (S3);
  - `uploadResidentCollection`;
  - the bundle and `tool/build_shaders.sh`.

  The asset key becomes `packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle`.

  **The shader sources `shaders/cad_stroke.{vert,frag}` stay in core**
  (V-5): core's Dart expander (`test/support/instance_expander.dart`)
  mirrors them, and `instance_expander_test` reads them. The build script
  compiles `../jet_cad_2d_flutter/shaders/`, which works inside the
  workspace, where the harness builds.

  The package's pubspec:
  - environment: `flutter: ">=3.47.0"`, which is `flutter_scene`'s own
    floor (V-13);
  - its error reports name `library: 'jet_cad_2d_gpu'`.

  `installResidentGpu()` is idempotent.

  It has its own barrel, `package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart`, and
  its own `analysis_options.yaml`, created like its siblings' and never
  committed when `pub get` rewrites it. It joins the root workspace.
  `publish_to: none` follows the siblings' convention.
- **S2. `jet_cad_2d_flutter` loses `flutter_scene`.**
  - Its pubspec no longer names `flutter_scene`, and no file under its
    `lib/` imports `flutter_scene`, `flutter_gpu` or `jet_cad_2d_gpu`.
  - It keeps every GPU-free type in place, under the same names:
    - `RenderBackend`, with all three values: the standing names do not
      move;
    - `ResidentFramePainter`, `ResidentUploader` and `ResidentRebuilder`;
    - `ResidentCollection` and `GeometryCollector`;
    - the text patches and the compositor;
    - `DraftCanvas`.
- **S3. The pure helpers stay in core**, and the core barrel exports
  them.
  - `buildFrameInfo` and `dashScaleFor` move to
    `lib/src/gpu/frame_info.dart`.
  - `ResidentGeometry`'s pure statics move to `ResidentLayout`, in
    `lib/src/gpu/resident_layout.dart`, with the same members:
    `kCornerVertices`, `kFloatsPerCorner`, `cornerVertexCount(…)` and
    `byteLengthFor(…)`. `kCornerVertices` loses `@visibleForTesting`
    (F-11).
  - There are no forwarding statics: the harness (`gpu_arm.dart:349,
    466`) and core's tests switch to `ResidentLayout` (V-14).
  - `kFloatsPerInstance` and `InstanceFieldOffset` are exported from the
    barrel with `show` (F-11, V-3). The GPU package imports only core's
    barrel.
  - The import cycle between the rebuilder and the GPU backend goes away
    with the move. The rebuilder drops the imports it no longer uses.
- **S4. A registry is the seam.** Core gains a small registry in
  `lib/src/gpu/resident_gpu.dart`:
  - `abstract interface class ResidentGpu`, with:
    - `bool get available`;
    - `upload(ResidentCollection, Size viewport, {measurer,
      textStyleOf})`, which returns `Future<ResidentFramePainter?>` (the
      signature of today's `uploadResidentCollection`).
  - `registerResidentGpu(ResidentGpu?)`, and the registered value.
  - The behaviour of `residentGpu`:
    - `resolveBackend(residentGpu)` gives `residentGpu` only when a
      `ResidentGpu` is registered and `available`; otherwise `vertices`,
      with the fallback reported once, as today.
    - `DraftCanvas`'s default uploader is the registered one's `upload`.
    - `DraftCanvas.residentUploader` stays the test seam.
  - In the GPU package, `installResidentGpu()` registers the real one:
    `available` is `gpuAvailable()`, and `upload` is
    `uploadResidentCollection`.
  - The harness calls `installResidentGpu()` at startup. No host does.

  Core's tests that used `debugSetGpuAvailable(true)` register a fake
  `ResidentGpu` instead, and reset it in `tearDown`. Registering `null`
  clears the registration.
  - **The fallback report** (`draft_canvas.dart:334`, which names
    `gpuAvailable()` today) gains two wordings, still reported once per
    process (V-9):
    - "no resident GPU is installed";
    - "the installed resident GPU is unavailable".
  - **The widget's own `residentUploader`**, when given, wins over the
    registry.
  - **The harness** calls `installResidentGpu()` first in `main()`, before
    each of its `runApp` branches, and in
    `integration_test/frame_timing_test.dart`, which pumps `HarnessApp`
    itself (V-11).
- **S5. Behaviour is unchanged.** A process that calls
  `installResidentGpu()` draws exactly as today in every backend. One
  that does not draws exactly as today in `canvas` and `vertices`. When
  it asks for `residentGpu`, it gets today's no-GPU fallback.
- **S6. Tests move with their code.**
  - `gpu_facade_test` and the GPU half of `resident_geometry_test` move to
    `jet_cad_2d_gpu/test/`, as does an install test: after
    `installResidentGpu()`, `resolveBackend` follows `gpuAvailable()`.
  - Core keeps `backend_selection`, `render_backend`,
    `draft_canvas_fallback` and `draft_canvas_resident`, rewritten on the
    registry. `render_backend_test` no longer imports the facade.
  - Core's tests of the pure helpers (F-12) switch to `ResidentLayout`
    and `frame_info.dart`; `instance_expander_test` keeps reading the
    shader source from core.
  - Every test stays green, and the goldens and the standing sets are
    unchanged.
- **S7. A guard in core.** A source test in `jet_cad_2d_flutter` fails if
  either of these holds:
  - its pubspec has `flutter_scene`, `flutter_gpu` or `jet_cad_2d_gpu` as
    a dependency key, matched as a key rather than as free text. The
    pubspec's comment naming `flutter_scene` goes.
  - a file under `lib/` has a `package:` URI to any of them, whether in an
    import, an export or a conditional import (V-12).
- **S8. A guard in CI.**
  - **`check_host_lock.dart`** is new in `tool/ci`. Given a `pubspec.lock`,
    it exits 1 if any of these is a key under `packages:`:
    - `flutter_scene`;
    - `flutter_gpu`;
    - `flutter_gpu_shaders`;
    - `scene`;
    - `jet_cad_2d_gpu`.

    It matches keys exactly, not text. Its tests (V-2):
    - one red fixture per name;
    - a green fixture recorded after the split, with look-alike names
      added (`scene_x`, `my_flutter_scene_tools`).

    The fixtures are named `*.lock.txt`, because `*.lock` is git-ignored.
  - **`host_probe.sh`** (V-8):
    - first removes `build`, `.dart_tool` and `pubspec.lock`, because
      stale output survives a build (the reviewer's E4);
    - runs the check, by absolute path, after `pub get`;
    - after the web build, asserts that none of these hold:
      - `.dart_tool/hooks_runner` exists, which is the POS's literal
        requirement;
      - `build/web/assets/packages/flutter_scene` exists;
      - `main.dart.js` contains `cad.shaderbundle`.
  - **`ci.yml`:**
    - the analysis and format lists name `check_host_lock.dart`;
    - the matrix gains `packages/jet_cad_2d_gpu`;
    - the web job asserts that the floor planner's and the demo's builds
      have no `assets/packages/flutter_scene` (F-9, V-7).
- **S9. Docs.**
  - **CHANGELOG, Unreleased:**
    - the split;
    - the host's graph without `flutter_scene`;
    - **breaking for anyone who imported the GPU types** from
      `jet_cad_2d_flutter`'s barrel: `GpuDrawBackend`,
      `ResidentGeometry`, `debugSetGpuAvailable` and
      `uploadResidentCollection`. No host did.
  - **The host guide:** "Flutter 3.44" becomes true again. It is
    measured by `flutter pub downgrade` in the probe (F-10). The CHANGELOG
    says the host floor falls from 3.47 to 3.44, and that
    `jet_cad_2d_gpu` is not a host package. Its breaking names include
    `ResidentPatch` (V-1, V-13).
  - **CLAUDE.md and AGENTS.md:** "every task ends green" names the new
    package's gate (V-13).
  - **The roadmap:**
    - its package bullets;
    - its line on `.vscode/launch.json`, which was already wrong (V-15);
    - its "web included" line: `flutter_scene`'s shim has a WebGL2 path,
      and the GPU is used only where `installResidentGpu()` was called.

## Invariants

- **I-1.** The allocation invariants and the goldens are untouched. The
  `vertices` and `canvas` paths do not change.
- **I-2.** Draw order and the resident path's output are unchanged.
  Moving code changes no arithmetic, and the differential tests stay
  green.
- **I-3.** No host code changes, and B1 is unchanged.

## Testing and named mutants

- **M-G1, `flutter_scene` back in core.**
  - The test: S7.
  - Mutants:
    - the dependency re-added to the pubspec;
    - one `lib/` file importing `jet_cad_2d_gpu`.
- **M-G2, the lock guard.**
  - The test: S8's `check_host_lock` on the recorded locks; a script test
    by exit code, as SC1–SC8 do.
  - Mutants:
    - the check dropped;
    - each name missing from the list, in turn;
    - text matching instead of keys, which the look-alike names catch.
- **M-G3, the registry.**
  - The tests:
    - with nothing registered, `residentGpu` falls back to `vertices`,
      reported once;
    - with an available fake registered, `DraftCanvas` uses its uploader
      and paints through its painter;
    - with an unavailable fake, it falls back.
    - registering `null` clears it;
    - the widget's own `residentUploader` wins.

    These tests pass no `residentUploader`, except the one that
    exercises it.
  - Mutants:
    - `resolveBackend` ignoring `available`;
    - `DraftCanvas` ignoring the registered uploader;
    - the two fallback wordings swapped.
- **M-G4, the install.**
  - The tests (V-10):
    - after `installResidentGpu()`, the registered `ResidentGpu`'s
      `available` follows `debugSetGpuAvailable`, flipped after install;
    - `upload` returns null with a throwing factory;
    - installing twice registers one.
  - Mutant: `available` hard-coded to true.
- **The probe, the real acceptance.** Built at the commit, its lock holds
  none of the four names. Its web build has no
  `assets/packages/flutter_scene`, and the size difference is recorded.
  This is run locally, with `file://` and the SHA, before CI.

## Risks

- **R-1. Asset key.** The bundle's key changes with the package. A
  missed key fails only on a real GPU, which no test has. The plan
  greps for the old key; the harness on a device is owed to the human,
  as GPU runs always were.
- **R-2. Global registration.** A process-wide registry is global state,
  as `debugSetGpuAvailable` was. Tests reset it in `tearDown`.
- **R-3. Breaking barrel names.** The GPU names leave the core barrel. Only
  the harness used them.

## Review

Revision 1 (`567fbf9`) was reviewed independently: *Approved with fixes*.
The reviewer ran four experiments in clones:
- the probe's lock without `flutter_scene`;
- a trial split and its web build;
- a minimal workspace;
- stale build output.

Their results are F-9, F-10 and S8. No finding was critical.

| # | Finding | Disposition |
|---|---|---|
| V-1 important | The floor came from a fresh lock: Dart 3.13 is pub's newest `xml`, not the floor. | Measured by `flutter pub downgrade`: 3.44 (F-10, S9). |
| V-2 important | "One name missing" survived a fixture holding all four names. | One red fixture per name; look-alikes; `jet_cad_2d_gpu` listed; keys matched exactly. |
| V-3 important | `kFloatsPerInstance` and `InstanceFieldOffset` are not exported. | Exported with `show` (S3). |
| V-4 important | `kCornerVertices` is `@visibleForTesting`. | Dropped (S3). |
| V-5 important | `instance_expander_test` reads the shader source from core. | The sources stay in core (S1). |
| V-6 minor | Core tests unnamed. | F-12, S6. |
| V-7 minor | In-workspace apps also lose the hook (E3). | F-9; the web job asserts it. |
| V-8 minor | Stale output, the hook directory, the shader path in JS, the analysis list. | S8. |
| V-9 minor | The fallback wording names `gpuAvailable()`. | Two wordings (S4). |
| V-10 minor | Mutant gaps in M-G3 and M-G4. | Added. |
| V-11 minor | The harness's four `runApp` branches and its integration test. | S4. |
| V-12 minor | The S7 guard matched text, imports only. | Keys and every `package:` URI (S7). |
| V-13 nit | The new package's floor, the gate lines, the CHANGELOG, the report's library. | S1, S9. |
| V-14 nit | S3 left open. | Decided: `ResidentLayout`, no forwarding. |
| V-15 nit | The roadmap's launch-entry line and its web line. | S9. |

The registry seam (S4) was judged the right shape. The alternative, a
public uploader with an availability callback, would have to be threaded
through every `DraftCanvas` the planner builds.

## Not in scope

- Any change to the GPU path's behaviour.
- A web GPU path.
- The POS's floor view itself, which is Monépro's phase 2.
- Monépro's other prerequisites. Touch, a git-consumable version, an
  outside-app resolution and open/save are already met. Zones are a
  later question.

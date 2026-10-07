# The GPU renderer in its own package — design

**Date:** 2026-10-07. **Status:** design, revision 1, for review.

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

## Decisions

- **S1. A new package, `packages/jet_cad_2d_gpu`.** It depends on
  `jet_cad_2d_flutter`, `jet_cad_2d` and `flutter_scene`. It receives:
  - the facade, unchanged;
  - `ResidentGeometry`, without its pure statics (S3);
  - `GpuDrawBackend`, without its pure functions (S3);
  - `uploadResidentCollection`;
  - the shader sources, the bundle and `tool/build_shaders.sh`.

  The asset key becomes `packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle`.

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
- **S3. The pure helpers stay in core.**
  - `buildFrameInfo` and `dashScaleFor` move to a GPU-free file in
    `jet_cad_2d_flutter`.
  - `ResidentGeometry`'s pure statics move to a new core class,
    `ResidentLayout`, with the same members: `kCornerVertices`,
    `kFloatsPerCorner`, `cornerVertexCount(…)` and `byteLengthFor(…)`.
    `ResidentCollection` uses it.
  - `ResidentGeometry` keeps forwarding statics for the harness, or the
    harness is updated; the plan decides.
  - The tests of these helpers stay where they are.
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
  `ResidentGpu` instead, and reset it in `tearDown`.
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
    registry.
  - Every test stays green, and the goldens and the standing sets are
    unchanged.
- **S7. A guard in core.** A source test in `jet_cad_2d_flutter` fails if
  either of these holds:
  - its pubspec names `flutter_scene`, `flutter_gpu` or `jet_cad_2d_gpu`;
  - a file under `lib/` imports any of them.
- **S8. A guard in CI.**
  - `tool/ci` gains `check_host_lock.dart`. Given a `pubspec.lock`, it
    exits 1 if any of `flutter_scene`, `flutter_gpu`,
    `flutter_gpu_shaders` or `scene` is in it. It is tested on a lock
    recorded before the split (red) and one recorded after (green).
  - `host_probe.sh` runs it after `pub get`, and after the web build
    asserts that `build/web/assets/packages/flutter_scene` does not exist.
  - The CI matrix gains `packages/jet_cad_2d_gpu`.
- **S9. Docs.**
  - **CHANGELOG, Unreleased:**
    - the split;
    - the host's graph without `flutter_scene`;
    - **breaking for anyone who imported the GPU types** from
      `jet_cad_2d_flutter`'s barrel: `GpuDrawBackend`,
      `ResidentGeometry`, `debugSetGpuAvailable` and
      `uploadResidentCollection`. No host did.
  - **The host guide:** the floor is set by the remaining dependencies,
    measured from the probe's fresh lock; the guide says what it is.
  - **The roadmap:** its package bullets, and its "web included" line
    (`flutter_scene`'s shim has a WebGL2 path).

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
  - Mutants: the check dropped; one name missing from the list.
- **M-G3, the registry.**
  - The tests:
    - with nothing registered, `residentGpu` falls back to `vertices`,
      reported once;
    - with an available fake registered, `DraftCanvas` uses its uploader
      and paints through its painter;
    - with an unavailable fake, it falls back.
  - Mutants:
    - `resolveBackend` ignoring `available`;
    - `DraftCanvas` ignoring the registered uploader.
- **M-G4, the install.**
  - The test: `installResidentGpu()` registers a `ResidentGpu` whose
    `available` follows `debugSetGpuFactory`.
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

## Not in scope

- Any change to the GPU path's behaviour.
- A web GPU path.
- The POS's floor view itself, which is Monépro's phase 2.
- Monépro's other prerequisites. Touch, a git-consumable version, an
  outside-app resolution and open/save are already met. Zones are a
  later question.

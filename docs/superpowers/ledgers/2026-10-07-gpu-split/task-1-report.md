# Task 1 report: the split (S1 to S7)

Implementer: Task 1 of `docs/superpowers/plans/2026-10-07-gpu-package-split.md`.
Branch `claude/exciting-pasteur-9m22jv`, from HEAD `64100c0`.

**I did not commit.** While my gates were running, a commit appeared:
`f6ee45f` "feat: the GPU renderer in its own package, jet_cad_2d_gpu (GPU split
Task 1)", authored 16:53 UTC. The controller made it, not me. The working tree
is now clean against it, so it holds every edit described below.
`packages/jet_cad_2d_gpu/analysis_options.yaml` is not in it: it is untracked
and listed in `.git/info/exclude:7`. My only index changes were the `git mv`
renames, which stage by nature.

## Files

**Moved with `git mv`:**
- `jet_cad_2d_flutter/lib/src/gpu/gpu_facade.dart` → `jet_cad_2d_gpu/lib/src/gpu_facade.dart`. Content unchanged.
- `…/gpu/resident_geometry.dart` → `jet_cad_2d_gpu/lib/src/resident_geometry.dart`, with these changes:
  - the four pure statics left for `ResidentLayout`;
  - imports now come from core's barrel;
  - the asset key is `packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle`, and its doc comment is updated;
  - errors report `library: 'jet_cad_2d_gpu'`;
  - the `tool/build_shaders.sh:63` line reference is updated.
- `…/gpu/gpu_draw_backend.dart` → `jet_cad_2d_gpu/lib/src/gpu_draw_backend.dart`, with these changes:
  - `buildFrameInfo`, `composeTransforms` and `dashScaleFor` left for core;
  - it imports core's barrel;
  - it uses `ResidentLayout.cornerVertexCount`.
- `jet_cad_2d_flutter/assets/shaders/cad.shaderbundle` → `jet_cad_2d_gpu/assets/shaders/cad.shaderbundle`.
- `jet_cad_2d_flutter/tool/build_shaders.sh` → `jet_cad_2d_gpu/tool/build_shaders.sh`. It now compiles `../jet_cad_2d_flutter/shaders/cad_stroke.{vert,frag}`, and a comment explains why.
- `jet_cad_2d_flutter/test/gpu/gpu_facade_test.dart` → `jet_cad_2d_gpu/test/gpu_facade_test.dart`. Only the import changed.
- `jet_cad_2d_flutter/test/gpu/resident_geometry_test.dart` → `jet_cad_2d_gpu/test/resident_geometry_test.dart`. It keeps the GPU half: the two "`create` returns null" tests and the `kInstanceVertexLayout` group.

**Created in `jet_cad_2d_gpu`:**
- `pubspec.yaml`: `publish_to: none`, `resolution: workspace`, `flutter: ">=3.47.0"`. Dependencies: flutter, `jet_cad_2d`, `jet_cad_2d_flutter` (path), meta, vector_math, `flutter_scene ^0.23.0` (with its old comment). Dev: flutter_test, lints. Assets: `assets/shaders/cad.shaderbundle`.
- The barrel `lib/jet_cad_2d_gpu.dart` exports:
  - `gpu_draw_backend`, `install`, `resident_geometry`, `resident_upload`;
  - from the facade, only `GpuContextFactory`, `debugSetGpuAvailable`, `debugSetGpuFactory` and `gpuAvailable`, via `show`, so the shim is not republished.
- `lib/src/resident_upload.dart`: `uploadResidentCollection`, moved from the rebuilder with its body unchanged.
- `lib/src/install.dart`: a private `const _FlutterGpuResident implements ResidentGpu`. Its `available` calls `gpuAvailable()` on each read, and its `upload` is `uploadResidentCollection`. `installResidentGpu()` is idempotent: it registers the same const instance and returns early if that instance is already registered.
- `test/install_test.dart` (M-G4).
- `analysis_options.yaml`, copied from `jet_cad_2d_flutter`'s. **Uncommitted**, at `/home/user/jet-cad/packages/jet_cad_2d_gpu/analysis_options.yaml`.

**Created in core `jet_cad_2d_flutter`:**
- `lib/src/gpu/frame_info.dart`: `buildFrameInfo`, `composeTransforms` and `dashScaleFor`, with their doc comments unchanged.
- `lib/src/gpu/resident_layout.dart`: `abstract final class ResidentLayout`, holding `kCornerVertices` (no `@visibleForTesting`, with a comment saying why), `kFloatsPerCorner`, `cornerVertexCount` and `byteLengthFor`.
- `lib/src/gpu/resident_gpu.dart`:
  - `abstract interface class ResidentGpu { bool get available; Future<ResidentFramePainter?> upload(ResidentCollection, Size, {required FlutterTextMeasurer measurer, required TextStyleRecord Function(Handle) textStyleOf}); }`;
  - `registerResidentGpu(ResidentGpu?)`, where `null` clears;
  - the getter `registeredResidentGpu`.
- `test/gpu/draft_canvas_registry_test.dart` (M-G3, 5 tests).
- `test/gpu/resident_layout_test.dart`: the pure half of the old `resident_geometry_test`, on `ResidentLayout`.
- `test/invariants/no_gpu_dependency_test.dart` (S7). It has 2 real checks, plus self-tests of its matchers:
  - one red case per name per section;
  - one red case per name for import, export and conditional import;
  - green look-alikes: a comment, a description, a path value, a nested key, `flutter_scene_extras`, `my_flutter_gpu`, and a doc comment naming `package:jet_cad_2d_gpu/`.

**Changed in core:**
- `pubspec.yaml`: `flutter_scene`, its comment and the `flutter: assets:` block are gone.
- `lib/jet_cad_2d_flutter.dart`:
  - removed the facade (`debugSetGpuAvailable`), `gpu_draw_backend` and `resident_geometry` exports;
  - added `frame_info`, `resident_gpu`, `resident_layout`, and `instance_record.dart show kFloatsPerInstance, InstanceFieldOffset`;
  - rewrote the comment.
- `lib/src/render_backend.dart`: `resolveBackend` returns `residentGpu` only when one is registered and `available`. Doc comments updated.
- `lib/src/draft_canvas.dart`:
  - it reads the registry once per `_attach`;
  - it gives two fallback wordings, still with one report per process;
  - the default uploader is `residentGpu!.upload(...)`, and `widget.residentUploader ??` still wins;
  - doc comments updated.
- `lib/src/gpu/resident_rebuilder.dart`: `uploadResidentCollection` is gone, and so are the imports `dart:math`, `../flutter_text_measurer.dart`, `gpu_draw_backend.dart` and `resident_geometry.dart`.
- `lib/src/gpu/resident_collection.dart`: uses `ResidentLayout.byteLengthFor`.

**Core tests changed** (each change follows a moved name or the registry):
- `backend_selection_test`: rewritten on the registry with `FakeResidentGpu`. 8 tests: nothing registered, unavailable, available, availability read at resolution, null clears, last wins, default, explicit never rerouted.
- `render_backend_test`: the facade import is gone; `debugSetGpuFactory(throw)` became `registerResidentGpu(null)`.
- `draft_canvas_fallback_test`:
  - `debugSetGpuAvailable(false)` → `registerResidentGpu(null)`, and its assertion `contains('gpuAvailable')` → `contains('no resident GPU is installed')`;
  - `debugSetGpuAvailable(true)` → `registerResidentGpu(FakeResidentGpu())`;
  - tearDown resets.
- `draft_canvas_resident_test`: setUp registers `FakeResidentGpu()` and its tearDown resets.
- `instance_expander_test`, `support/instance_expander.dart` and `resident_collection_test`: switched to `ResidentLayout`. `instance_expander_test` still reads core's `shaders/`.
- `support/gpu_comparison.dart`, `support/instance_expander.dart` and `classify_grid_test`: each dropped an `src/gpu/instance_record.dart` import that the new barrel export made unnecessary. The analyzer flagged them as `unnecessary_import`.
- `support/recording_frame_painter.dart`: adds `FakeResidentGpu`, whose `available` is a mutable field and whose `upload` forwards to a `FakeUploader` and counts calls.

**Root and harness:**
- Root `pubspec.yaml`: the workspace lists `packages/jet_cad_2d_gpu`. `flutter pub get` was run at the root.
- `apps/dev_harness_2d`:
  - `pubspec.yaml` depends on `jet_cad_2d_gpu` (path);
  - `main.dart` calls `installResidentGpu()` as its first statement, before every `runApp` branch, and imports the GPU barrel;
  - `integration_test/frame_timing_test.dart` calls `installResidentGpu()` right after `ensureInitialized()`;
  - `gpu_arm.dart` imports the GPU barrel and uses `ResidentLayout.byteLengthFor` (2 sites);
  - `allocation_probe.dart` adds `'package:jet_cad_2d_gpu/'` to `kProbedLibraryPrefixes`.

## Decisions and deviations

1. **`composeTransforms` moved to core's `frame_info.dart` too.** The spec names only `buildFrameInfo` and `dashScaleFor`. But `dashScaleFor` calls `composeTransforms`, and five core test files use it: `frame_info_test`, `collection_frame_test`, `resident_collection_test` and `gpu_comparison`. It is pure.
2. **The allocation probe now counts `package:jet_cad_2d_gpu/`.** Without it, a device run would silently stop counting `GpuDrawBackend`'s per-frame objects, because they changed library. It keeps the measurement equivalent.
3. **The GPU package's `resident_geometry_test` imports `writeStroke` and `kKindStroke` from `jet_cad_2d_flutter/src/gpu/instance_record.dart`** with `// ignore: implementation_imports` and a stated reason. The test cross-checks the vertex layout against the writer. The spec exports only `kFloatsPerInstance` and `InstanceFieldOffset`, so I did not widen core's barrel. Production code in the GPU package imports only core's barrel.
4. **The fallback for a failed upload is unchanged.** Its message still says "ResidentGeometry.create returned null" as text, and no URI is involved.
5. **The GPU barrel exports `GpuContextFactory`, `debugSetGpuFactory` and `gpuAvailable`** besides `debugSetGpuAvailable`, all via `show`. It is not a host package.
6. **The shader bundle reproduces byte for byte from the new script paths.** I ran Linux `impellerc` with the script's new `--shader-bundle` JSON from `packages/jet_cad_2d_gpu`, writing to scratch. `cmp` against the committed 37,200-byte bundle printed IDENTICAL. I did not overwrite the committed bundle.
7. **The core guard parses the pubspec by lines, not YAML.** `yaml` is not a dependency of core. It takes top-level sections, then two-space-indented keys under `dependencies`, `dev_dependencies` and `dependency_overrides`. The URI check skips whole-line `//` comments and matches `'package:<name>/` or `"package:<name>/` in string literals.

## Mutants

Each one was applied, run, seen red, and reverted by byte copy from a scratch backup; `cmp` confirmed each restore.

| Mutant | Test that went red | Failure line |
|---|---|---|
| M-G1a: `flutter_scene: ^0.23.0` re-added under core's `dependencies:` | `no_gpu_dependency_test`: "the pubspec names no GPU package as a dependency" | `Expected: empty / Actual: ['flutter_scene']` |
| M-G1b: `import 'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart';` in `lib/src/gpu/resident_gpu.dart` | the same file: "no file under lib/ reaches a GPU package by a package: URI" | `Actual: ['lib/src/gpu/resident_gpu.dart: package:jet_cad_2d_gpu/']` |
| M-G1b′: the same as an `export` | same | same |
| M-G1b″: `import 'resident_layout.dart' if (dart.library.io) 'package:jet_cad_2d_gpu/…';` | same | same |
| M-G3a: `resolveBackend` ignores `available` (`return gpu != null ? …`) | `backend_selection_test`: "…installed one is unavailable", "availability is read at resolution…", "the last registration wins". `draft_canvas_registry_test`: "an unavailable GPU registered…" | `Expected: RenderBackend.vertices / Actual: RenderBackend.residentGpu` |
| M-G3b: `DraftCanvas` ignores the registered uploader (default becomes `(c, v) async => null`) | `draft_canvas_registry_test`: "an available GPU registered: its uploader is used…"; "registering null clears it…" | `Expected: <1> / Actual: <0>`, the `uploads` count |
| M-G3b′ (V-10 precedence): the registry preferred, `widget.residentUploader ??` dropped | `draft_canvas_registry_test`: "the widget's own residentUploader wins over the registry's" | `Expected: an object with length of <1> / Actual: []` |
| M-G3c: the two fallback wordings swapped (`residentGpu != null ? …`) | `draft_canvas_registry_test`: "nothing registered…", "an unavailable GPU registered…", "registering null clears it…". `draft_canvas_fallback_test`: "no GPU: two canvases…" | `Expected: contains 'no resident GPU is installed' / Actual: '…but the installed resident GPU is…'` and the reverse |
| M-G4: `available => true` | `install_test`: "…availability follows the probe, flipped after install"; "with a factory that throws, the installed GPU is unavailable" | `Expected: false / Actual: <true>` |
| M-G4′: `available => false` | `install_test`: "…flipped after install" | `Expected: true / Actual: <false>` |
| M-G4″: availability captured at install (a final field) | `install_test`: "…flipped after install" | `Expected: true / Actual: <false>` |
| M-G4‴: `upload` unwired (`throw UnimplementedError()`) | `install_test`: "upload returns null, not a throw, where the GPU factory throws" | `UnimplementedError` |
| M-G4⁗: install not idempotent (a new instance per call) | `install_test`: "installing twice registers one, the same instance" | `Expected: same instance as <Instance of '_FlutterGpuResident'>` |

## Gates

Actual output lines:

- **`packages/jet_cad_2d_flutter`:**
  - `flutter test --file-reporter json:/tmp/r.json`: `02:23 +1344 ~1 -7: Some tests failed.`
  - `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/r.json`: `packages/jet_cad_2d_flutter: 1352 tests; the standing failures and skips, exactly`
  - `flutter analyze`: `No issues found!`. It was re-run after a final doc-comment rewrap in `draft_canvas.dart`.
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 221 files (0 changed)`, exit 0.
- **`packages/jet_cad_2d_gpu`:** `flutter test`: `00:01 +16: All tests passed!`; analyze: `No issues found!`; format: `Formatted 9 files (0 changed)`, exit 0.
- **`packages/jet_cad_floor_plan`:** `08:24 +1380: All tests passed!`; `No issues found!`; `Formatted 237 files (0 changed)`.
- **`packages/jet_cad_restaurant_symbols`:** `00:05 +97: All tests passed!`; `No issues found!`; `Formatted 15 files (0 changed)`.
- **`apps/floor_planner`:** `03:24 +212: All tests passed!`; `No issues found!`; `Formatted 47 files (0 changed)`.
- **`apps/restaurant_demo`:** `00:46 +37: All tests passed!`; `No issues found!`; `Formatted 4 files (0 changed)`.
- **`apps/dev_harness_2d`:** `flutter analyze`: `No issues found!`; format: `Formatted 22 files (0 changed)`. Extra, not required: `flutter test`: `01:11 +82: All tests passed!`
- **`packages/jet_cad_2d`:**
  - `dart test --file-reporter json`: `00:43 +1253 -2: Some tests failed.` These are the two standing fingerprints.
  - `expect_failures`: `packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly`
  - `dart analyze`: `No issues found!`; format: `Formatted 169 files (0 changed)`.
- **`tool/ci`:** `dart test`: `00:06 +32: All tests passed!`. `standing_failures.txt` still names `text ladder rung N (RenderBackend.canvas)`, and the render comparison matched them exactly.
- **Grep for the old key:** neither `git grep "packages/jet_cad_2d_flutter/assets"` outside `docs/` and `STATUS-HISTORY.md`, nor a grep of the code and config files, finds a hit.

## The web build check (`apps/floor_planner`, not committed)

- The existing `build/` was stale and pre-split: `build/web` was **54M** and `assets/packages/` held `flutter_scene`. I removed it with `rm -rf build`.
- `flutter build web --no-pub` printed `✓ Built build/web`.
- `build/web/assets/packages/` now holds only `jet_cad_floor_plan` and `jet_cad_restaurant_symbols`. **`flutter_scene` is absent.**
- `du -sh build/web` gives **42M**, against 54M before.
- `grep -c cad.shaderbundle build/web/main.dart.js` gives **0**.
- The log did not print "No packages with native assets", even when I grepped for it, so I cannot quote that line.
- **The root `.dart_tool/hooks_runner/flutter_scene` exists, but the web build did not run it.** It holds files from 10-03, plus two from today, both written before the web build started (about 17:01 UTC; `main.dart.js` was written at 17:03:52):
  - `stdout.txt` at 16:36:14, matching my first `flutter test` in `jet_cad_2d_gpu`;
  - `shared/.lock` at 16:59:29, around the end of the gate run; the harness's test run was its last step.

  Both packages depend on `flutter_scene`, so their builds run its hook, as they should. The probe's own hook check is Task 2's.

## Surprising, or not done

- **The commit `f6ee45f` was made by someone else while I worked** (see the top). Its message still says "the apps' run continues". The gates above are now complete.
- **Not done, by brief:** S8 (`check_host_lock`, the probe, `ci.yml`), the S9 docs, the CHANGELOG, `CLAUDE.md` and `AGENTS.md`.
- **Owed to the human:** a device run of the harness's GPU arm, which exercises the new asset key (R-1).
- **`git mv` stages renames**, which was unavoidable. Nothing else was staged.

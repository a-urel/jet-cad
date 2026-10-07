# Spec review: 2026-10-07-gpu-package-split-design.md (revision 1)

Reviewer: independent. HEAD `567fbf9` (the spec's facts are about `23a8950`; the code is the same).
Experiments were run under `/tmp/gpu-split-review/` on Flutter 3.47.6 / Dart 3.13.5. Nothing in the repo was edited except this file.

## Verdict: **Approved with fixes**

The design holds, and experiments confirm the central claim. With `flutter_scene` out of
`jet_cad_2d_flutter`, the out-of-workspace host graph loses all ten packages and the hook.
`flutter_scene` is the **only** package in the probe's lock that has a `hook/` directory.
`pdf`, `printing`, `image`, `archive`, `posix` and `ffi` carry no hook and no `hooks` or
`code_assets` dependency. The fixes below are the decisions the spec leaves open, plus one
wrong method (the SDK floor) and one mutant the planned fixtures cannot kill.

## Experiments (results of record)

- **E1. The host lock without `flutter_scene`.** In a clone I deleted the pubspec line, committed,
  and resolved the probe by `file://` at that SHA. The lock holds none of `flutter_scene`,
  `flutter_gpu`, `flutter_gpu_shaders`, `scene`, `hooks`, `code_assets`, `data_assets`,
  `record_use`, `flat_buffers` or `yaml_edit`.
  - The fresh lock's `sdks:` reads `dart >=3.13.0`, `flutter >=3.44.0`.
  - After `flutter pub downgrade` it reads `dart >=3.12.0`, `flutter >=3.44.0`.
- **E2. A trial split, then the probe's web build.** I moved the facade, `ResidentGeometry` and
  `GpuDrawBackend` into `packages/jet_cad_2d_gpu` and stubbed core's uploader and availability.
  The build logged `No packages with native assets. Skipping native assets compilation.`
  - No `.dart_tool/hooks_runner` directory.
  - No `assets/packages/flutter_scene`.
  - `main.dart.js` holds `cad.shaderbundle` 0 times; the probe built at HEAD holds it 2 times.
  - `build/web` is 42 MB, down from 54 MB.
- **E3. A workspace member's hooks.** I built a minimal workspace with members `a` (Flutter only)
  and `b` (with `flutter_scene`).
  - `flutter build web` in `a` logged "No packages with native assets", created no
    `hooks_runner`, and shipped no `flutter_scene` assets.
  - `b`, the positive control, ran the hook and shipped 12 MB.
  - Flutter runs hooks only for the built app's own dependency closure, not for the whole
    workspace lock. After the split, the floor planner's and the demo's web builds also lose the
    hook and the 12 MB.
- **E4. A stale probe build.** I put a dummy `build/web/assets/packages/flutter_scene/stale` in
  place and ran `flutter build web`. The file was still there afterwards.

## Facts

| Fact | Verdict | Evidence |
|---|---|---|
| F-1 | ✓ | `gpu_facade.dart:18,21` import and re-export the shim; `:24` `GpuContextFactory`; `:34` `debugSetGpuFactory`; `:45` `gpuAvailable`; `:72` `debugSetGpuAvailable`. |
| F-2 | ✓ with a nit | 461 and 692 lines ✓. `_bundlePath` `resident_geometry.dart:74-75` ✓. `uploadResidentCollection` `resident_rebuilder.dart:49-66` ✓. `draft_canvas.dart:357-370` ✓. `resident_collection.dart:61` ✓. The rest is 2,204 lines ✓. **Nit:** `draft_canvas.dart` imports `render_backend.dart`, not `gpu_draw_backend.dart` (`:12-13`). `ResidentPatch`, also GPU-typed (`resident_geometry.dart:13-28`), goes unmentioned. |
| F-3 | ✓ | `gpu_arm.dart:569`; `main.dart:136-158`. No `RenderBackend` or `backend:` appears in floor_plan, symbols, apps or the probe. |
| F-4 | ✓ | `jet_cad_2d_flutter.dart:49-58`. |
| F-5 | ✓ but incomplete | 24 files ✓. The ladder skips are at `text_ladder:469`, `fill:327`, `dash:233` and `text_lod:332` ✓. Missing from the list: see V-6. |
| F-6 | ✓ | The probe lock and `hooks_runner/flutter_scene` are present. All three web builds are 12 MB. `main.dart.js` has 2 hits. **Nit:** the local probe artifacts were built at ref `29820b6` (its `pubspec.yaml`), not at `23a8950`. |
| F-7 | ✓ | `flutter_scene-0.23.0/hook/build.dart` calls `flutter_gpu_shaders` `findImpellerC` (`build.dart:162`). The pubspec requires `flutter: ">=3.47.0"`. |
| F-8 | ✓ | 37,200 bytes. `pubspec.yaml:41`. `tool/build_shaders.sh` cds to `$(dirname $0)/..`, so it survives a `git mv`. |
| F-9 | ✓ | There is one root lock (`.gitignore:3` ignores `*.lock`). |

## Findings

**V-1 (important). S9's method for the floor is wrong.**
- **Evidence:** "Measured from the probe's fresh lock" yields `dart >=3.13.0` (E1). Pub picks the
  newest `xml` 7.1.0 and `petitparser` 7.1.0, both `sdk: ^3.13.0`, and that Dart is Flutter 3.47.
  Older versions satisfy every constraint: `xml` 7.0.1 needs `^3.11.0` and `petitparser` 7.0.2
  needs `^3.8.0`. HEAD's lock reads 3.13 for the same reason. The real floor is set by `pdf` and
  `printing` (Dart >=3.12.0, printing flutter >=3.41) and by the packages' own `flutter: >=3.44.0`.
- **Fix:** measure the floor with `flutter pub downgrade` in the probe, which gives
  `dart >=3.12.0` / `flutter >=3.44.0` (E1), or derive it from the declared lower bounds.
  - Record that the guide's existing "3.44" becomes *true* with this change; at HEAD it was 3.47.
  - The CHANGELOG says the floor drops from 3.47 to 3.44.

**V-2 (important). M-G2's "one name missing from the list" mutant survives, and the fixtures are git-ignored.**
- **Evidence:** the red fixture, a lock recorded before the split, contains all four names. Drop
  any one name from the list and the other three still exit 1. This is the degenerate-fixture
  failure mode CLAUDE.md names. Separately, `.gitignore:3` `*.lock` ignores any `*.lock` fixture
  (`git check-ignore` confirms `tool/ci/test/fixtures/x.pubspec.lock`), so CI's checkout would
  not have them.
- **Fix:**
  - Use one red case per name: a lock holding only that name, generated in the test from a
    template, or four small fixtures.
  - Add a green fixture with look-alike names (`scene_kit:`, `flutter_scene_extras:`, a
    `path:` value containing `flutter_scene`). It kills a substring implementation; match only
    `^  <name>:$` keys under `packages:`.
  - Name the fixtures `*.lock.txt`, or state `git add -f`.
  - Add `jet_cad_2d_gpu` to the list. It is the direct cause, and the error should name it.

**V-3 (important). The GPU package needs symbols core does not export.**
- **Evidence:** the trial split's `dart analyze lib` in `jet_cad_2d_gpu` gave 21 errors, all
  `kFloatsPerInstance` / `InstanceFieldOffset` (`resident_geometry.dart:211-251,358-370`). They
  live in `instance_record.dart`, which is deliberately unexported (F-4). Importing
  `package:jet_cad_2d_flutter/src/gpu/instance_record.dart` from another package trips
  `implementation_imports`. I confirmed that is an info, and `flutter analyze` fails on infos.
  The `kInstanceVertexLayout` test group, which moves, needs the same symbols.
- **Fix:** the spec decides one of these:
  - (a) `export 'src/gpu/instance_record.dart' show kFloatsPerInstance, InstanceFieldOffset;`
    and amend the barrel comment;
  - (b) a second public library for the GPU package, e.g. `lib/resident_support.dart`, so the
    host barrel stays clean;
  - (c) an `// ignore: implementation_imports` with a stated reason (precedent: `gpu_facade.dart:17`).

  I recommend (b) or (a).

**V-4 (important). `@visibleForTesting` cannot move to `ResidentLayout` as-is.**
- **Evidence:** `ResidentGeometry._upload` reads `kCornerVertices` (`resident_geometry.dart:345`).
  The read is legal today only because it is in the same library. From `jet_cad_2d_gpu`'s `lib/`
  it gives `invalid_use_of_visible_for_testing_member` (a warning, reproduced).
- **Fix:** S3 states that `ResidentLayout.kCornerVertices` drops `@visibleForTesting`. It is now
  production data read across packages. "With the same members" should say "same names and values".

**V-5 (important). Moving `shaders/` breaks a core test.**
- **Evidence:** `test/gpu/instance_expander_test.dart:428` reads `File('shaders/cad_stroke.vert')`
  relative to core. The expander (`test/support/instance_expander.dart`) is the Dart transcription
  of that shader, used by core's differential tests (`gpu_comparison.dart`). Neither can move,
  because the GPU package cannot import another package's `test/`.
- **Fix:** S6 names the test. It reads `../jet_cad_2d_gpu/shaders/cad_stroke.vert`, which works
  in the workspace only and needs a comment saying so. The other option is to keep the shader
  sources in core and point `build_shaders.sh` at them. The spec chooses.

**V-6 (minor). F-5 and S6 omit core tests that name the moved symbols.**
- **Evidence:**
  - `test/support/instance_expander.dart:63-66,114` and `test/gpu/instance_expander_test.dart:86,107,118,396` use `ResidentGeometry.kFloatsPerCorner`, `kCornerVertices` and `cornerVertexCount`.
  - `test/gpu/resident_collection_test.dart:139` uses `ResidentGeometry.byteLengthFor`.
  - `test/gpu/frame_info_test.dart` and `test/support/gpu_comparison.dart:775` reach `buildFrameInfo` and `dashScaleFor` through the barrel.
  - `test/render_backend_test.dart:6` imports `src/gpu/gpu_facade.dart` directly.
- **Fix:**
  - List these in S6: rewritten on `ResidentLayout`, and the pure half of `resident_geometry_test` becomes `resident_layout_test`.
  - S3 names the new pure file (`lib/src/gpu/frame_info.dart`, matching `frame_info_test`) and states that the barrel exports it, along with `resident_layout.dart` and `resident_gpu.dart`.

**V-7 (minor). The in-workspace apps lose the hook too, and the spec does not say so.**
- **Evidence:** E3.
- **Fix:**
  - Add to S5: the floor planner's and the demo's web builds drop `assets/packages/flutter_scene`.
  - Optionally, CI's `web` job asserts its absence after both builds. That second guard is free, in-workspace, and runs on every push.

**V-8 (minor). Probe-guard robustness.**
- **Evidence:** E4. Stale `build/` survives a rebuild, and the local probe directory already holds
  a 12 MB `build/web/assets/packages/flutter_scene` from earlier runs. `host_probe.sh` does not
  clean, so the local acceptance run would be falsely red and its size difference wrong.
- **Fix:**
  - (a) `host_probe.sh` runs `rm -rf build .dart_tool pubspec.lock` before `pub get`.
  - (b) After the build, also assert that `.dart_tool/hooks_runner` does not exist. That is the
    POS's literal requirement ("build hook never enters"), and it catches any future
    hook-carrying dependency, not just four names (E2: absent).
  - (c) Assert that `build/web/main.dart.js` does not contain `cad.shaderbundle`. That proves the
    core no longer reaches the GPU path (E2: 0, against 2 at HEAD).
  - (d) Add `check_host_lock.dart` to the `ci-tools` job's explicit `dart analyze` / `dart format`
    file lists (`ci.yml`), and call it by an absolute path, since `host_probe.sh` cds into the probe.
  - The lock check is adequate: an out-of-workspace lock *is* the host graph. `pub deps --json`
    adds nothing here.

**V-9 (minor). The fallback message.**
- **Evidence:** `draft_canvas.dart:334-337` says "(gpuAvailable() is false)". Core can no longer
  name that function, and "no `ResidentGpu` registered" (a wiring bug in the caller) is a
  different diagnosis from "registered but unavailable".
- **Fix:** keep two messages and still one report per process. Tests assert each message.

**V-10 (minor). Gaps in the M-G3 / M-G4 mutants.**
- **M-G3:**
  - "DraftCanvas ignoring the registered uploader" is killed only if that test passes **no**
    `residentUploader`; say so.
  - Add a precedence test: both are given and the widget's `residentUploader` wins. Its mutant is
    the registry preferred.
  - Add `registerResidentGpu(null)` clears the registration.
- **M-G4:**
  - "Hard-coded true" is killed. "Hard-coded false" needs `debugSetGpuAvailable(true)` →
    `available` is true.
  - "Captured at install time" needs a flip after install.
  - `upload` with a throwing factory returns `null`, which kills an unwired `upload`.

**V-11 (minor). Name the harness entry points.**
- **Evidence:** `installResidentGpu()` must run at the top of `main()`, before all four `runApp`
  branches (`main.dart:828-882`). It must also run in `integration_test/frame_timing_test.dart`'s
  own `main`, which pumps `HarnessApp` directly (`:126`). Otherwise `BACKEND=residentGpu` falls
  back: a FlutterError in tests, and silently vertices numbers in a profile run.
- **Fix:** S4 names both. `Info.plist` `FLTEnableFlutterGPU` stays as it is (harness only).

**V-12 (minor). Precision of the S7 guard.**
- **Evidence:** core's `pubspec.yaml:20-26` comment names `flutter_scene` and `flutter_gpu`.
- **Fix:**
  - The comment goes with the dependency.
  - The guard matches dependency keys (`^\s+(flutter_scene|flutter_gpu|jet_cad_2d_gpu):`) in every
    dependency section, not free text.
  - The `lib/` check matches any `package:flutter_scene/`, `package:flutter_gpu/` or
    `package:jet_cad_2d_gpu/` URI, so it covers export and conditional `if (dart.library…)`, not
    just `^import`.
  - Add per-name red cases as in V-2.

**V-13 (nit). Small omissions.**
- `jet_cad_2d_gpu` declares `flutter: ">=3.47.0"` (the truth, from `flutter_scene`).
- Add its gate to CLAUDE.md and AGENTS.md "Every task ends green".
- In the CHANGELOG:
  - list `ResidentPatch` among the breaking names;
  - say `jet_cad_2d_gpu` is not a host package (the "four packages" sentence stays true).
- `ResidentGeometry.create`'s `library: 'jet_cad_2d_flutter'` (`:305`) becomes `jet_cad_2d_gpu`.

**V-14 (nit). Decide S3's options in the spec.**
- **Fix:** update the harness (`gpu_arm.dart:349,466` `ResidentGeometry.byteLengthFor`) and core's
  tests to `ResidentLayout`. Do not add forwarding statics, which would duplicate the API.
- `ResidentLayout` is a fair name. It holds the corner table and the per-record price; put it in
  `lib/src/gpu/resident_layout.dart`.
- The `resident_rebuilder.dart` ↔ `gpu_draw_backend.dart` import cycle disappears by
  construction. The rebuilder must also drop `dart:math`, `../flutter_text_measurer.dart`,
  `gpu_draw_backend.dart` and `resident_geometry.dart`. `unused_import` is an error here
  (seen in the trial).

**V-15 (nit). Stale docs to fix while editing.**
- `roadmap/00-README.md:349-351` says the harness's GPU entries are in `.vscode/launch.json`.
  `launch.json` says they were removed. Fix it with the package bullets.
- The `:87` line should add "and only where `installResidentGpu()` was called".
- `packages/jet_cad` and `apps/dev_harness` have no reference to `jet_cad_2d_flutter` or the GPU.
  The harness README has none either.

## S4: the registry seam

It is the right shape.

The alternative is a public `DraftCanvas.residentUploader` plus an availability callback. That
would have to be threaded through every `DraftCanvas` that floor_plan builds internally, or else
`resolveBackend` cannot decide without the registry. The registry keeps host code untouched and
confines `installResidentGpu()` to the harness.

On global state:
- It is the same kind of state as `gpuAvailable`'s cache and `_residentFallbackReported` today.
- `flutter test` runs each file in its own isolate. Within a file, `tearDown` resets it.
- Hot restart reruns `main` and re-registers. Hot reload keeps the registration, which is correct.
- Last registration wins. Make `installResidentGpu()` idempotent and say so.

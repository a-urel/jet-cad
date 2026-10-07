# Task 2 report — the guards (S8)

Branch `claude/exciting-pasteur-9m22jv`, on top of 2b35b69. Nothing committed,
staged or pushed. No analysis_options.yaml touched.

## Files

- new `tool/ci/lib/host_lock.dart` — `forbiddenHostPackages` (flutter_scene,
  flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu); `lockPackages(lock)`
  returns the exact keys of the top-level `packages:` map (line-based: the
  map's first child indent, comments skipped, quoted keys unquoted, ends at the
  next column-0 key; throws FormatException when there is no top-level
  `packages:`; `packages: {}` is empty); `forbiddenInLock(lock)` = the keys in
  the list, lock order.
- new `tool/ci/check_host_lock.dart <pubspec.lock>` — exit 0 with
  "`<path>: N packages, none of …`"; exit 1 with one
  "`<path>: a host must not resolve <name>`" line per finding; exit 2 on bad
  arguments, a missing file, or a file with no `packages:` key.
- new fixtures (`*.lock.txt`, verified not git-ignored):
  - `tool/ci/test/fixtures/host_post_split.lock.txt` — the probe's lock as
    recorded at 2b35b69 by the new host_probe.sh (40 packages) plus two
    hand-added look-alikes: `my_flutter_scene_tools` (git entry whose path is
    `"vendor/flutter_gpu_shaders/jet_cad_2d_gpu"` and url
    `"https://example.com/tools.git#description: name: flutter_scene"`) and
    `scene_x` (hosted). Between them every forbidden name occurs as text, none
    as a key. A header comment says so.
  - `tool/ci/test/fixtures/host_pre_split.lock.txt` — the probe's lock as
    recorded at 64100c0 (53 packages), header comment added.
- new `tool/ci/test/host_lock_test.dart` — HL1–HL7:
  - HL1 green lock: 42 keys (40 + 2 look-alikes), no `sdks`/`dart`, nothing forbidden.
  - HL2 every forbidden name is in the green lock as text, none as a key; the
    `description: name: flutter_scene` text is present.
  - HL3 (group, one test per name, names spelled literally in the test, not read
    from the list under test): the green lock with that package's entry inserted
    at its sorted position (the four from the pre-split lock; jet_cad_2d_gpu as
    the jet_cad_2d_flutter git entry renamed) → `forbiddenInLock == [name]`.
  - HL4 pre-split lock: 53 keys incl. hooks, code_assets, data_assets;
    findings `[flutter_gpu, flutter_gpu_shaders, flutter_scene, scene]` (F-6).
  - HL5 a forbidden name as a key under `sdks:` or as a package's field is not
    a package.
  - HL6 a quoted key (`"scene":`) is the same key.
  - HL7 no `packages:` → FormatException; `packages: {}` → empty.
- `tool/ci/test/scripts_test.dart` — group `check_host_lock.dart`, SC9–SC13 by
  exit code via `dart run` as SC1–SC8: SC9 green fixture exit 0 ("42 packages,
  none of flutter_scene, "); SC10 pre-split exit 1, each of the four named;
  SC11 jet_cad_2d_gpu key alone (temp file) exit 1; SC12 missing file / not a
  lock exit 2; SC13 no args / two args exit 2. Header comment updated.
- `tool/ci/host_probe.sh` — `set -euo pipefail` kept. Removes
  `build`, `.dart_tool`, `pubspec.lock` in the probe first; after
  `flutter pub get` runs `dart run "$ci/check_host_lock.dart"
  "$probe/pubspec.lock"` (absolute paths); after `flutter build web` checks
  `.dart_tool/hooks_runner`, `build/web/assets/packages/flutter_scene` and
  `grep -q cad.shaderbundle build/web/main.dart.js`, printing every one that
  holds before exiting 1; on success prints
  `host probe: no GPU renderer, no build hook; build/web is <du -sh>`.
- `.github/workflows/ci.yml` — matrix gains `packages/jet_cad_2d_gpu` (flutter);
  ci-tools analyze and format lists name `check_host_lock.dart` (now folded
  `>-` scalars); web job: each of restaurant_demo and floor_planner runs
  `flutter build web` then `test ! -e build/web/assets/packages/flutter_scene`
  (Actions' default bash runs with -e, so the test fails the step); host-probe
  step renamed "Resolve, check, analyze and build the probe". Parsed with
  python3 `yaml.safe_load`: matrix = [jet_cad_2d, jet_cad_2d_flutter,
  jet_cad_2d_gpu, jet_cad_floor_plan, jet_cad_restaurant_symbols,
  apps/floor_planner, apps/restaurant_demo]; analyze run = `dart analyze
  --fatal-infos lib test expect_failures.dart check_guide.dart
  check_host_lock.dart`; format run = `dart format --output=none
  --set-exit-if-changed lib test expect_failures.dart check_guide.dart
  check_host_lock.dart host_probe/lib`.

## Local acceptance

Note: the probe needs the FULL sha. With `2b35b69` (short) `pub get` fails:
"jet_cad_restaurant_symbols … depends on jet_cad_floor_plan from git … at
2b35b69931d6… and host_probe depends on … at 2b35b69 … version solving
failed" (the probe's pubspec ref vs the nested dependency's resolved ref). CI
passes `git rev-parse HEAD`, which is full, so this is not a CI issue. Runs
below use `git rev-parse`.

**2b35b69931d6acdb03c219a38c923a8fd3fdc50c (post-split): exit 0, 5m04s.**
- check: `…/host_probe/pubspec.lock: 40 packages, none of flutter_scene,
  flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu`
- `flutter analyze`: No issues found.
- last line: `host probe: no GPU renderer, no build hook; build/web is 42M`
- the lock's 40 packages: archive args async barcode bidi characters clock
  collection crypto ffi flutter flutter_localizations flutter_web_plugins http
  http_parser image intl jet_cad_2d jet_cad_2d_flutter jet_cad_floor_plan
  jet_cad_restaurant_symbols material_color_utilities meta path path_parsing
  pdf pdf_widget_wrapper petitparser plugin_platform_interface posix printing
  qr sky_engine source_span string_scanner term_glyph typed_data vector_math
  web xml. A grep for the keys hooks, code_assets, data_assets, record_use,
  flat_buffers, yaml_edit and the five forbidden names found none.
  `sdks: dart ">=3.13.0 <4.0.0"`, `flutter ">=3.44.0"`.
- `.dart_tool` holds dartpad, flutter_build, package_config.json,
  package_graph.json, version — no hooks_runner.
  `build/web/assets/packages` holds only jet_cad_floor_plan and
  jet_cad_restaurant_symbols. `grep -c cad.shaderbundle main.dart.js` = 0.
  (The build log has no "native assets" line at all on this Flutter.)
- build/web 42M, against 54M pre-split (below) — the review's 54 → 42 MB.

**64100c09b714d4fc8daf36a45b4f2dbdd99fdad9 (pre-split): exit 1 at the lock
check, 11.6s** (after "Changed 53 dependencies!"):
```
/home/user/jet-cad/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_gpu
/home/user/jet-cad/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_gpu_shaders
/home/user/jet-cad/tool/ci/host_probe/pubspec.lock: a host must not resolve flutter_scene
/home/user/jet-cad/tool/ci/host_probe/pubspec.lock: a host must not resolve scene
```
This run also showed the clean step: the 2b35b69 build/ from the run before
was gone afterwards (no build dir; .dart_tool without hooks_runner).

The probe dir was cleaned at the end (build, .dart_tool, pubspec.lock,
pubspec.yaml, .flutter-plugins-dependencies removed; left: .gitignore, lib,
pubspec.yaml.in, web).

## Named mutants (M-G2)

Each applied, run, and reverted from a scratch copy (`cmp` confirmed the
restore); the gates below ran after all reverts.

1. **The check dropped from host_probe.sh** — run as a copy
   `tool/ci/host_probe_mutant_nocheck.sh` (the one `dart run …check_host_lock`
   line removed; deleted afterwards) at 64100c0: the lock step no longer stops
   it — pub get, then `flutter analyze` "No issues found!", then the web build
   (237s) — and it is caught only after the build by the post-build checks,
   exit 1:
   ```
   host probe: a build hook ran (.dart_tool/hooks_runner exists)
   host probe: the web build ships flutter_scene's assets
   host probe: main.dart.js loads cad.shaderbundle
   ```
   (pre-split build/web 54M; hooks_runner held flutter_scene and shared;
   cad.shaderbundle occurs 2 times in main.dart.js.) The tool/ci tests cannot
   see this mutant; only a probe run does (the post-build checks are the
   backstop).
2. **Each name missing from `forbiddenHostPackages`** (`dart test
   test/host_lock_test.dart test/scripts_test.dart`):
   - flutter_scene: red HL3 flutter_scene, HL4, SC9, SC10 (+20 -4)
   - flutter_gpu: red HL3 flutter_gpu, HL4, SC10 (+21 -3)
   - flutter_gpu_shaders: red HL3 flutter_gpu_shaders, HL4, SC10 (+21 -3)
   - scene: red HL3 scene, HL4, HL6, SC10 (+20 -4)
   - jet_cad_2d_gpu: red HL3 jet_cad_2d_gpu, SC11 (+22 -2)
   Each name's own HL3 case is red.
3. **Text matching instead of keys** (`for name in forbiddenHostPackages if
   lock.contains(name)`): red HL1, all five HL3, HL4, HL5, HL6, SC9
   (+14 -10) — HL1 and SC9 via the look-alikes in the green lock.
   Extra variant, key-shaped text at any indent
   (`RegExp('^\\s*"?$name"?:', multiLine: true)`): red HL4 (order), HL5
   (+22 -2).

## Gates (tool/ci, after all reverts)

- `dart test` → `00:28 +48: All tests passed!` (exit 0)
- `dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart
  check_host_lock.dart` → `No issues found!` (exit 0)
- `dart format --output=none --set-exit-if-changed lib test expect_failures.dart
  check_guide.dart check_host_lock.dart host_probe/lib` → `Formatted 11 files
  (0 changed) in 0.06 seconds.` (exit 0)
- `bash -n tool/ci/host_probe.sh`: ok. shellcheck is not installed.

Also, for the new matrix row: in packages/jet_cad_2d_gpu, `flutter test
--file-reporter json:…` → `+16: All tests passed!`, and `dart run
tool/ci/expect_failures.dart --package packages/jet_cad_2d_gpu --root
packages/jet_cad_2d_gpu <json>` → `packages/jet_cad_2d_gpu: 16 tests; the
standing failures and skips, exactly`.

## Not done / for the reviewer

- I did not run CI's analysis of jet_cad_2d_gpu without its (untracked)
  analysis_options.yaml. That was accepted in the brief.
- I did not build restaurant_demo or floor_planner for the web locally to
  exercise the new web-job assertion. Task 3's exit covers it ("both web
  builds without flutter_scene assets").
- I did not measure the size of the pre-split `assets/packages/flutter_scene`
  on its own: `du` of a nested directory printed nothing, and the directory
  was deleted with the cleanup. F-6 says 12 MB.

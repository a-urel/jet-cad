# Final review: the GPU split, `23a8950..02bd3c7`

Reviewer: independent; I wrote none of it. I worked in two clones:
- `/tmp/gpu-final-review/repo` at `02bd3c7`, for the gates and the probe;
- `/tmp/gpu-final-review/mut`, for the mutants and the baseline count at `23a8950`.

Flutter 3.47.6 (CI's pin), `CI=true`. I committed nothing. The only file I
wrote under `/home/user/jet-cad` is this one. Every output quoted below is
from a command I ran. Where a number comes from someone else's run, the text
says so.

The container restarted mid-review, which killed my first render run. I
re-ran it to completion; the outputs below are from the second run.

## Verdict: **Approved with fixes**

The split is faithful, and S1–S9 are met. The probe at `02bd3c7` exits 0:
- 40 packages, none of the five names;
- no `hooks_runner`;
- no `flutter_scene` assets;
- `cad.shaderbundle` 0 times in `main.dart.js`;
- 42M.

The host's floor really is Dart 3.12 and Flutter 3.44, by
`flutter pub downgrade`. CI was green on `02bd3c7` (run 37664166707, all 10
jobs, `packages/jet_cad_2d_gpu` included).

The moved build script reproduces the committed bundle **byte for byte**.

I found no defect in behaviour. The fixes I ask for are small:
- **F-1:** a test that pins the asset key. It is the one runtime-visible
  change on the GPU path, and today nothing but a device run checks it.
- **F-2:** a correction to the results note's M-G4 claim.

The rest are minor hardening or nits, to take or record.

## Findings

**F-1 (minor, fix asked). The new asset key is checked by nothing that runs off a device.**
- **Where:**
  - `packages/jet_cad_2d_gpu/lib/src/resident_geometry.dart:80-81` (`_bundlePath`);
  - `packages/jet_cad_2d_gpu/pubspec.yaml:38-40`.
- **What survives:**
  - MU2 changes the key back to `packages/jet_cad_2d_flutter/...`. It survives `flutter test` (`+16: All tests passed!`).
  - MU3 drops the `flutter: assets:` declaration. It survives both `flutter test` and `flutter analyze`.
- **Scenario:** a later edit typos the key, or drops the declaration while editing the pubspec. Then:
  - CI stays green;
  - the harness's `BACKEND=residentGpu` gets `null` from `ResidentGeometry.create` and falls back to `vertices`;
  - the harness says so once, but a profile run silently prices the wrong backend.
- **Context:** this is spec risk R-1, and the device run is owed. But the check is cheap and needs no GPU. Expose the key as a `@visibleForTesting static const`. Then, in `jet_cad_2d_gpu/test/`:
  - read `pubspec.yaml`'s `name:` and its single `flutter.assets` entry;
  - assert `key == 'packages/$name/$asset'`;
  - assert `File(asset).existsSync()`.

  That kills MU2 and MU3.

**F-2 (minor, fix asked). The results note overstates M-G4's "`upload` unwired".**
- **Where:** `docs/superpowers/notes/2026-10-07-gpu-split-results.md:92`, which says it is killed by `install_test`.
- **What the implementer ran:** the variant `throw UnimplementedError()`. Its report, `task-1-report.md:120`, is red as claimed.
- **What survives:**
  - MU1: `upload` returns `Future.value(null)`. `flutter test` passes (`+16`). Only `flutter analyze` catches it, and only by accident: the import of `resident_upload.dart` becomes unused.
  - MU1b: `upload` forwards `Size.zero` as the viewport. It passes both `flutter test` and `flutter analyze`.
- **Scenario:** in the harness on a device, every resident upload returns null, or every patch target is capped at 1×1. Nothing in CI sees it.
- **Fix:** reword the row to "`upload` throwing". Optionally, add an `install_test` case: a counting factory that throws, then `upload`, then assert the factory was consulted. That would catch MU1. I did not run that test, so it is a suggestion, not a verified kill.

**F-3 (minor). No test reads `.github/workflows/ci.yml`, and parts of `host_probe.sh` are unguarded.**
- **The workflow,** where nothing reads the file:
  - MU4 deletes the `packages/jet_cad_2d_gpu` matrix row (`ci.yml:41-42`). It survives `tool/ci`'s `dart test` (`+50`). The GPU package's tests, analysis and format then silently leave CI. Note that a *wrong path* (MU4b) fails closed in CI, because the working directory would be missing. Deletion is the silent case.
  - MU5 deletes the web job's `test ! -e …/flutter_scene` (`ci.yml:96`). It survives.
- **The probe script:** SC14 checks the order pub get < check < analyze < build, and nothing else. So these survive:
  - MU6 deletes the clean step (`host_probe.sh:21`). It is harmless in CI, which checks out fresh, but it matters in a local rerun (spec E4).
  - MU7 drops `fail=1` from the `flutter_scene`-assets branch (`host_probe.sh:39`).
- **Exposure is small.** The lock check, which SC14 pins, is the primary guard.
- **Fix (cheap):** an SC test in the style of SC14 that greps `ci.yml` for the row and the two `test ! -e` lines, and `host_probe.sh` for the `rm -rf` line and a `fail=1` in each branch.
- **Optional:** the web job could also assert `test ! -e ../../.dart_tool/hooks_runner`. The workspace's hook output lives at the root, and only the web job builds there.

**F-4 (nit). S7's red cases iterate the list under test.**
- **Where:** `packages/jet_cad_2d_flutter/test/invariants/no_gpu_dependency_test.dart:320,386` loop over `kForbiddenPackages` (`:15`).
- **What survives:** MU8 drops `'flutter_gpu'` from that list. It survives (`+19: All tests passed!`).
- **The contrast:** `tool/ci`'s tests spell the names out separately (V-2), and the section list here is spelled out on purpose (MU9 is red, 12 failures). The names are not.
- **The backstop:** the host lock check still forbids `flutter_gpu`.
- **Fix:** spell the three names in the test, as `sections` is.

**F-5 (nit). "Read once, at attach" is not pinned.**
- **Where:** `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:338,382`.
- **What survives:** MU13 re-reads `registeredResidentGpu!` inside the uploader closure. It survives the three DraftCanvas registry, fallback and resident tests (`+17`).
- **Scenario:** a canvas attaches with a GPU registered. Later `registerResidentGpu(null)` runs, then a band exit or a document change triggers a rebuild. With the mutant, that rebuild throws on `!`. Today's code keeps the GPU it attached with, which is correct.
- **Context:** only the harness registers, and it never unregisters. A test could clear the registry after the first upload, trigger a rebuild, and expect a second upload on the original fake.

**F-6 (nit). The CHANGELOG's API list is incomplete.**
- **Where:** `CHANGELOG.md:40-45`.
- **What it says:** the breaking list is right about the five names that left the barrel. I confirmed against the old barrel and the old `resident_geometry.dart`, whose only top-level classes were `ResidentPatch` and `ResidentGeometry`.
- **What it omits:**
  - `ResidentGeometry.kCornerVertices`, `kFloatsPerCorner`, `cornerVertexCount` and `byteLengthFor` did not move to the GPU package. They moved to core's `ResidentLayout`, so "now come from `jet_cad_2d_gpu`" is wrong for them.
  - Core's barrel also *gained* `ResidentGpu`, `registerResidentGpu`, `registeredResidentGpu`, `ResidentLayout`, `kFloatsPerInstance` and `InstanceFieldOffset`.
  - The GPU barrel newly exports `gpuAvailable`, `debugSetGpuFactory` and `GpuContextFactory`, which no barrel exported before.
- **Fix:** one line each.

**F-7 (nit). The host guide's floor sentence reads wrong for the release it covers.**
- **Where:** `docs/host-guide.md:52-56`.
- **The problem:** the guide "covers release 0.1.0", and it opens with "The packages need Flutter 3.44 or later". For 0.1.0 that is false: `flutter_scene` 0.23.0 requires Flutter 3.47. The next sentence corrects it.
- **Also:** "On `main` since the GPU split" is true only after the merge.
- **Fix:** lead with the 0.1.0 truth: "0.1.0 needs 3.47; from the next release, 3.44".

### Checked and fine (no finding)

**Faithful moves.** I diffed each moved file against `23a8950`, with doc lines filtered out.
- `gpu_facade.dart`: identical.
- `gpu_draw_backend.dart` changed only in:
  - its imports, now the core barrel;
  - lines 12-169 removed (the frame-info block, now `frame_info.dart`);
  - three `ResidentGeometry.` → `ResidentLayout.` renames.
- `frame_info.dart`: the removed block, verbatim.
- `resident_geometry.dart` changed only in:
  - its imports;
  - the four statics removed;
  - the key;
  - `library: 'jet_cad_2d_gpu'`;
  - a script line reference;
  - three `ResidentLayout.` qualifications.
- `ResidentLayout`: the same four members, verbatim, without `@visibleForTesting`.
- `uploadResidentCollection`: the body is identical.
- `gpu_facade_test`: only its import changed.

**The bundle and its build script.**
- The bundle's blob is the same object, `cea47f1d…`, before and after.
- `build_shaders.sh` changed only in the two source paths and a comment.
- Run in the mut clone, it wrote a bundle that `cmp` finds identical to the committed one.

**Untouched (I-1, I-2).** `git diff --stat 23a8950..02bd3c7` prints nothing for:
- `packages/jet_cad_2d` (the engine);
- the standing lists;
- `paint_allocation_test.dart`.

No golden or PNG appears anywhere in the range's diffstat. The `canvas` and `vertices` paths in `draft_canvas.dart` are unchanged. The only `draft_canvas.dart` edits are:
- the registry read;
- the two fallback wordings;
- the uploader closure.

`resolveBackend` changes only its `residentGpu` branch.

**Nothing registered.** Then `residentGpu` resolves to `vertices`, and `canvas`/`vertices` are never rerouted (`backend_selection_test`).

**Fallback reported once per process.** `_residentFallbackReported` is static and unchanged, with one report whichever wording fires first. The earlier reviewers' mutant removing the guard was red.

**Registry state.**
- It is a library-private top-level variable, so its scope is one isolate. `flutter test` runs each test file in its own `flutter_tester` process, so nothing leaks between files.
- Within a file, the resets *are* load-bearing. MU11c removes the registry test's `setUp`/`tearDown` resets: it is green in file order, but red under `--test-randomize-ordering-seed=2` and `=4` ("nothing registered…" fails).
- With the resets in place, seeds 1-5 over the five registry-touching files all pass (`+31` each). The plain-order survivors MU11, MU11b and MU11c therefore do not matter.
- The harness and its integration test install on the main isolate, where `DraftCanvas` lives.

**The asset key.**
- The only loader is `resident_geometry.dart:254` (`loadShaderLibraryAsync(_bundlePath)`). The harness and the tests never load the bundle themselves.
- `git grep "jet_cad_2d_flutter/assets"` hits only archived ledgers, old notes, old plans, and the spec's F-2, which states a fact about `23a8950`.
- Core's pubspec has no `flutter:` assets block, and no file remains under `packages/jet_cad_2d_flutter/assets`. The GPU pubspec declares the asset.

**Public API.**
- The GPU package's `lib/` imports only core's barrel. One test imports `jet_cad_2d_flutter/src/gpu/instance_record.dart` for `writeStroke` and `kKindStroke`, under a documented `ignore: implementation_imports`. That is acceptable.
- MU12 drops `InstanceFieldOffset` from the barrel's `show`. It is red in `jet_cad_2d_gpu`'s analyze (`undefined_identifier`), so the export is needed and used.
- Nothing core now exports needs `@internal`. `registeredResidentGpu` is required by `installResidentGpu`'s idempotence.
- The GPU barrel `show`s the facade, so `flutter_scene`'s shim is not republished.

**No host path to `flutter_scene`.**
- No `dependency_overrides` exists in any pubspec.
- The planner, the symbols, both apps and the probe template name no GPU symbol or package.
- The root workspace lists `packages/jet_cad_2d_gpu`.
- `jet_cad_2d_gpu/analysis_options.yaml` is committed and `cmp`-identical to core's.

**CI.**
- In the web job, `run: |` runs under Actions' `bash -e`, and `test ! -e` is each step's last command.
- In the probe:
  - `set -euo pipefail`;
  - `ci` and `probe` are absolute;
  - the clean step precedes `pub get`;
  - the check runs between `pub get` and `analyze`;
  - the missing-`main.dart.js` case is handled.

**The results note's numbers,** re-checked:
- render 1362 tests, and 1342 at `23a8950` (I ran the baseline);
- GPU 16, planner 1380, harness 82, `tool/ci` 50;
- probe 40 packages and 42M; floor Dart 3.12 / Flutter 3.44;
- CI green on `7aeaa5b` and on `02bd3c7`.

Not re-run by me: the symbols' 97, the apps' 212 and 37 tests, the pre-split probe, and the 54M → 42M before-size (that is the Task 1 reviewer's 55,403,880 B).

**Docs.**
- The roadmap's `.vscode/launch.json` line is true: the file exists, names no harness entry, and `89e26fc` dropped the entries.
- STATUS, CLAUDE.md and AGENTS.md gate lines: true. I ran the new gate line green.

## Mutants

Each mutant was applied in `/tmp/gpu-final-review/mut` by an exact single-occurrence replacement, run, then restored from a scratch copy. `cmp` confirmed each restore, and `git status --short` was empty at the end.

| # | Mutant | Run | Result | Matters? |
|---|---|---|---|---|
| MU1 | `install.dart` `upload` → `Future.value(null)` | gpu `flutter test` | **survived** (`+16`) | yes, F-2 |
| MU1a | MU1 | gpu `flutter analyze` | red, by accident (`unused_import` on `resident_upload.dart`) | F-2 |
| MU1b | `upload` forwards `Size.zero` | gpu test + analyze | **survived** | minor, F-2 (device-only effect) |
| MU2 | asset key typo'd (`jet_cad_2d_flutter` prefix) | gpu `flutter test` | **survived** | yes, F-1 |
| MU3 | `flutter: assets:` dropped from the gpu pubspec | gpu test + analyze | **survived** | yes, F-1 |
| MU4 | `packages/jet_cad_2d_gpu` matrix row deleted | `tool/ci` `dart test` | **survived** | minor, F-3 |
| MU4b | the matrix row's path wrong (`…_gpux`) | `tool/ci` `dart test` | **survived** | no: fails closed in CI (missing working directory) |
| MU5 | web job's `test ! -e …flutter_scene` deleted | `tool/ci` `dart test` | **survived** | minor, F-3 |
| MU6 | the probe's clean step deleted | `tool/ci` `dart test` | **survived** | low (CI is fresh), F-3 |
| MU7 | `fail=1` dropped from the `flutter_scene`-assets branch | `tool/ci` `dart test` | **survived** | low (the lock check is primary), F-3 |
| MU8 | `'flutter_gpu'` dropped from S7's `kForbiddenPackages` | `no_gpu_dependency_test` | **survived** (`+19`) | nit, F-4 (lock-check backstop) |
| MU9 | `'dependency_overrides'` dropped from S7's sections | `no_gpu_dependency_test` | red (`+8 -12`, "is red on each name under each section: …") | — |
| MU10 | `check_host_lock`: findings exit 2 instead of 1 | `tool/ci` `dart test` | red (`+48 -2`: SC10, SC11) | — |
| MU10c | `check_host_lock`: not-a-lock exit 1 instead of 2 | `tool/ci` `dart test` | red (`+49 -1`: SC12) | — |
| MU11 | `backend_selection_test` tearDown reset removed | that file | survived (`+8`) | no: order-hidden, see MU11c |
| MU11b | `draft_canvas_fallback_test` reset removed | that file | survived (`+4`) | no |
| MU11c | `draft_canvas_registry_test` setUp/tearDown resets removed | that file, in order / seeds 1-4 | survived in order; **red at seeds 2 and 4** ("nothing registered…") | no: the resets are load-bearing and present |
| MU12 | barrel `show kFloatsPerInstance, InstanceFieldOffset` → `show kFloatsPerInstance` | gpu `flutter analyze` | red (`undefined_identifier InstanceFieldOffset`) | — |
| MU13 | uploader closure re-reads `registeredResidentGpu!` at upload time | 3 DraftCanvas registry/fallback/resident tests | **survived** (`+17`) | nit, F-5 |

## Gate outputs (all run by me, at `02bd3c7`)

Setup: `flutter pub get` at the workspace root gave `Changed 134 dependencies!`. `git status --short` was empty afterwards.

**Render, `packages/jet_cad_2d_flutter`:**
```
$ flutter test --file-reporter json:/tmp/gpu-final-review/render.json
01:34 +1354 ~1 -7: Some tests failed.
test-exit=1
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter /tmp/gpu-final-review/render.json
packages/jet_cad_2d_flutter: 1362 tests; the standing failures and skips, exactly
expect-exit=0
$ flutter analyze
No issues found! (ran in 18.3s)
$ dart format --output=none --set-exit-if-changed .
Formatted 221 files (0 changed) in 0.83 seconds.
```
Baseline at `23a8950`, in the mut clone: `01:34 +1334 ~1 -7: Some tests failed.`, then `packages/jet_cad_2d_flutter: 1342 tests; the standing failures and skips, exactly`.

**GPU, `packages/jet_cad_2d_gpu`:**
```
$ flutter test --file-reporter json:/tmp/gpu-final-review/gpu.json
00:04 +16: All tests passed!
test-exit=0
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d_gpu --root packages/jet_cad_2d_gpu /tmp/gpu-final-review/gpu.json
packages/jet_cad_2d_gpu: 16 tests; the standing failures and skips, exactly
expect-exit=0
$ flutter analyze
No issues found! (ran in 5.0s)
$ dart format --output=none --set-exit-if-changed .
Formatted 9 files (0 changed) in 0.05 seconds.
```

**`tool/ci`:**
```
$ dart test
00:06 +50: All tests passed!
test-exit=0
$ dart analyze --fatal-infos lib test expect_failures.dart check_guide.dart check_host_lock.dart
No issues found!
analyze-exit=0
$ dart format --output=none --set-exit-if-changed lib test expect_failures.dart check_guide.dart check_host_lock.dart host_probe/lib
Formatted 11 files (0 changed) in 0.05 seconds.
$ dart run tool/ci/check_guide.dart          # from the root
docs/host-guide.md: all 14 code blocks are in the host probe
guide-exit=0
$ bash -n tool/ci/host_probe.sh
bash-n=0
```

**`apps/dev_harness_2d`:**
```
$ flutter test
00:38 +82: All tests passed!
test-exit=0
$ flutter analyze
No issues found! (ran in 5.6s)
$ dart format --output=none --set-exit-if-changed .
Formatted 22 files (0 changed) in 0.14 seconds.
```

**Planner, `packages/jet_cad_floor_plan`** (the full suite):
```
$ flutter test --file-reporter json:/tmp/gpu-final-review/planner.json
05:16 +1380: All tests passed!
test-exit=0
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan /tmp/gpu-final-review/planner.json
packages/jet_cad_floor_plan: 1380 tests; the standing failures and skips, exactly
$ flutter analyze
No issues found! (ran in 15.2s)
$ dart format …
Formatted 237 files (0 changed) in 1.35 seconds.
```

**Analyze and format only:**
| Package | `flutter analyze` | `dart format` |
|---|---|---|
| `packages/jet_cad_restaurant_symbols` | `No issues found! (ran in 8.0s)` | `Formatted 15 files (0 changed)` |
| `apps/floor_planner` | `No issues found! (ran in 8.6s)` | `Formatted 47 files (0 changed)` |
| `apps/restaurant_demo` | `No issues found! (ran in 5.3s)` | `Formatted 4 files (0 changed)` |

**Engine:** `git diff --stat 23a8950..02bd3c7 -- packages/jet_cad_2d` prints nothing (exit 0). I did not run its suite.

**The probe**, `tool/ci/host_probe.sh "file://$PWD" "$(git rev-parse HEAD)"` at `02bd3c7`. The `+ pkg` lines are filtered out below:
```
Changed 40 dependencies!
/tmp/gpu-final-review/repo/tool/ci/host_probe/pubspec.lock: 40 packages, none of flutter_scene, flutter_gpu, flutter_gpu_shaders, scene, jet_cad_2d_gpu
Analyzing host_probe...
No issues found! (ran in 7.2s)
Compiling lib/main.dart for the Web...                             95.3s
✓ Built build/web
host probe: no GPU renderer, no build hook; build/web is 42M

real	1m49.807s
EXIT=0
```

What I inspected after the probe:
- `.dart_tool` holds `dartpad flutter_build package_config.json package_graph.json version`, with no `hooks_runner`.
- `build/web/assets/packages` holds `jet_cad_floor_plan` and `jet_cad_restaurant_symbols`.
- `grep -c cad.shaderbundle main.dart.js` gives `0`.
- `du -sb build/web` gives `43517478`.
- The lock's `sdks:` reads `dart ">=3.13.0 <4.0.0"`, `flutter ">=3.44.0"`.

Then I ran `flutter pub downgrade` in the probe. The lock's `sdks:` read `dart ">=3.12.0 <4.0.0"`, `flutter ">=3.44.0"`, and `check_host_lock` still gave `40 packages, none of …` (exit 0).

Afterwards I removed the probe's `build`, `.dart_tool`, `pubspec.lock`, `pubspec.yaml` and `.flutter-plugins-dependencies`. `git status --short --ignored tool/ci/host_probe` is empty.

**CI on GitHub** (`gh run view 37664166707`): head `02bd3c78…`, all 10 jobs `success`, including:
- `packages/jet_cad_2d_gpu`;
- `web builds, dev_harness_2d`;
- `an external host, by git`.

---

## Controller's disposition

- F-1, F-2, F-4, F-5: applied in `2fa292f` (final-fixes-report.md).
  MU1b survives; it needs a device and is owed with the harness's GPU run.
- F-3, F-6, F-7: applied by the controller in `de0315e` (SC14 extended,
  SC15-SC17; the CHANGELOG; the host guide). MU4-MU7 red.
- The results note was corrected (F-2's M-G4 row) and records the review.

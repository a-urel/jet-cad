# The GPU renderer in its own package: results

**Asked by the human:** *"POS entegrasyonuna geç"*, then, at the question
of where to start, *"Önce jet-cad ön koşulu"* (2026-10-07). Monépro's
spec 103 §10 lists the split first among jet-cad's prerequisites.

**Spec:** [2026-10-07-gpu-package-split-design.md](../specs/2026-10-07-gpu-package-split-design.md),
revision 2. Revision 1 was reviewed independently (V-1 to V-15) and the
fixes are folded in.

**Plan:** [2026-10-07-gpu-package-split.md](../plans/2026-10-07-gpu-package-split.md).

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `23a8950`.

**Process.** Tasks 1 and 2 each had a fresh implementer, then an
independent reviewer working in its own clone. Task 3 (docs and exit) was
the controller's. An independent review of the whole range closes the
slice.

## What changed

- **`packages/jet_cad_2d_gpu`**, new. It holds:
  - the `flutter_gpu` facade (`flutter_scene`'s shim only);
  - `ResidentGeometry`, `ResidentPatch`, `GpuDrawBackend` and
    `uploadResidentCollection`;
  - `installResidentGpu()`, which registers the real GPU with core;
  - `assets/shaders/cad.shaderbundle`, moved byte-identical. Its asset key
    is now `packages/jet_cad_2d_gpu/assets/shaders/cad.shaderbundle`, and
    `tool/build_shaders.sh` compiles core's shader sources.
- **`jet_cad_2d_flutter`** no longer depends on `flutter_scene`. It keeps:
  - the resident layout and the frame info (`composeTransforms`);
  - a registry: `ResidentGpu` and `registerResidentGpu`. `resolveBackend`
    and `DraftCanvas` read it, and fall back to `vertices` with one of
    two wordings: nothing installed, or installed but unavailable;
  - the shader sources.

  A guard test (S7) fails on any GPU package in its pubspec or `lib/`.
- **The dev harness** depends on `jet_cad_2d_gpu` and calls
  `installResidentGpu()` first in `main()` and in its integration test.
- **CI:**
  - `tool/ci/check_host_lock.dart` reads the host probe's lock by key, and
    fails on `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`, `scene`
    or `jet_cad_2d_gpu`.
  - `host_probe.sh` starts clean and runs the check after `pub get`. After
    the build it fails on any of:
    - a `hooks_runner`;
    - `flutter_scene` assets;
    - `cad.shaderbundle` in `main.dart.js`;
    - a missing `main.dart.js`.
  - The package matrix gains `jet_cad_2d_gpu`.
  - Both app web builds assert that no `flutter_scene` assets ship.
- **Docs:**
  - CHANGELOG *Unreleased*;
  - the host guide (on `main` there is no build hook; 0.1.0 itself still
    needs Flutter 3.47);
  - the roadmap;
  - the gate lines in `CLAUDE.md` and `AGENTS.md`;
  - STATUS.

**What a host sees:**
- Its graph holds no GPU package and runs no build hook.
- Its web build is about 12 MB smaller: 54 MB → 42 MB for the probe.
- Its Flutter floor is 3.44 again, measured by `flutter pub downgrade` in
  the probe at `e1ddf4e`: Dart 3.12, Flutter 3.44, the lock still clean.
- Nothing it draws changes: the GPU path was only ever chosen by the
  harness.

## The tasks

| Task | Commits | Review | Fixes |
|---|---|---|---|
| 1, the split (S1–S7) | `2b35b69` | **Approved with fixes.** (1) The new package's `analysis_options.yaml` was left untracked, so CI and fresh checkouts would analyse it with Dart's defaults; all nine siblings' are tracked. (2) Nothing checked the arguments `DraftCanvas` passes to the registered upload. (3) The S7 guard missed quoted, re-indented and flow-map pubspec keys. (5) Stale comments. | `e1ddf4e`: the file committed once, at scaffold, per plan 01's Ruling 01-1; the plan's constraint was wrong and is corrected. `6a2b3b2`: (2), (3), (5). |
| 2, the guards (S8) | `d399303` | **Approved with fixes**, R-1 to R-5. Nothing CI runs saw the check dropped from the probe; a missing `main.dart.js` passed the probe silently; two lock layouts pub never writes passed as clean; no look-alike key ended in a forbidden name; the full-sha requirement was undocumented. | `c0248b3`: all five. |
| 3, docs and exit (S9) | `7aeaa5b`, this note | — | — |

Per-task reports, reviews and fix records:
`.superpowers/sdd/2026-10-07-gpu-split/` (git-ignored), archived to
`docs/superpowers/ledgers/` on merge.

## Named mutants (all red)

| Mutant | Killed by |
|---|---|
| M-G1: `flutter_scene` re-added to core's pubspec; a `lib/` import or export of `jet_cad_2d_gpu`, including a conditional import | S7 (`no_gpu_dependency_test`) |
| M-G1, after review: the dependency quoted, re-indented, in a flow map, in each of the three sections; a directive split across lines (K1–K8, U1–U2) | S7's synthetic fixtures; the real pubspec and `lib/` mutated too |
| M-G2: the check dropped from the probe; dropped, or moved after `analyze` | a probe run at `64100c0` (the post-build checks fail); SC14 |
| M-G2: each name missing from the list, in turn | its own HL3 case, plus HL4, HL6, SC9–SC11 |
| M-G2: text matching instead of keys; a match on a key's start or end | HL1, HL3, HL4, HL5, HL6, SC9 (the look-alikes, `my_scene` among them) |
| M-G2, after review: a flow map accepted; a shallow key skipped; the `{}` branch dropped | HL8, HL7 |
| M-G3: `resolveBackend` ignoring `available`; `DraftCanvas` ignoring the registered uploader, or preferring it over the widget's; the fallback wordings swapped | `backend_selection_test`, `draft_canvas_registry_test`, `draft_canvas_fallback_test` |
| M-G3, after review: the upload given `Size.zero`, a fresh `FlutterTextMeasurer`, a foreign `textStyleOf` | `draft_canvas_registry_test` |
| M-G4: `available` true; false; captured at install; `upload` unwired; install not idempotent | `install_test` |

The reviewers' own mutants are in their reviews. Their survivors are all
red now, except three. Removing install's early return is equivalent: the
same `const` instance is re-registered. The probe's `hooks_runner` check
depends on Flutter's folder name; a comment says so, and the lock check is
the main guard. Where the harness calls `installResidentGpu()` relative to
`runApp` is checked only by the `unused_import` its removal causes; it is
correct today (`main.dart` installs before all four `runApp` calls).

## The probe's acceptance

| | Before (`64100c0`) | After (`2b35b69`) |
|---|---|---|
| The lock check | exit 1: `flutter_gpu`, `flutter_gpu_shaders`, `flutter_scene`, `scene` | exit 0: 40 packages, none of the five |
| `hooks`, `code_assets`, `data_assets` in the lock | present | absent |
| `.dart_tool/hooks_runner` | present | absent |
| `build/web/assets/packages/flutter_scene` | 12 MB | absent |
| `cad.shaderbundle` in `main.dart.js` | 2 | 0 |
| `build/web` | 54 MB | 42 MB |

The implementer and the reviewer each ran it, in separate clones, at the
full sha. A short sha fails `pub get`: the restaurant package reaches the
planner at the full sha. CI passes `git rev-parse HEAD`, and the script's
usage says so. CI's probe was green at `7aeaa5b`.

## Gates (at `6a2b3b2`, `tool/ci` at `c0248b3`)

| Package | Result |
|---|---|
| engine `packages/jet_cad_2d` | "1255 tests; the standing failures and skips, exactly". Analyze and format clean. |
| render `packages/jet_cad_2d_flutter` | "1362 tests; the standing failures and skips, exactly" (1342 before the split: the registry and guard tests). Analyze and format clean. |
| GPU `packages/jet_cad_2d_gpu` | **16 passed**. Analyze (with its committed options) and format clean. |
| planner `packages/jet_cad_floor_plan` | **1,380 passed**. Analyze and format clean. |
| restaurant symbols | **97 passed**. Analyze and format clean. |
| app `apps/floor_planner` | **212 passed**. Analyze and format clean. `flutter build web` ✓: no `flutter_scene` assets, `cad.shaderbundle` 0 times, 42M. |
| demo `apps/restaurant_demo` | **37 passed**. Analyze and format clean. `flutter build web` ✓, from a clean `build/`: the same, 42M. |
| harness `apps/dev_harness_2d` | **82 passed**. Analyze and format clean. |
| `tool/ci` | **50 passed**. Analyze and format clean. `check_guide`: all 14 code blocks in the probe. |

The allocation invariant tests and the goldens are untouched. The
standing sets are unchanged: engine 2, render 7 plus 1 skip.

**A trap seen on the way.** `flutter build web` does not empty
`build/web`. The demo's working copy kept a `flutter_scene` folder from a
build on 2026-10-03, so the new assertion went red on stale output. It
passed after `rm -rf build`. CI checks out fresh, and the probe now starts
clean; a local run should do the same.

## Found, not fixed

- **The harness's install placement** is guarded only by an
  `unused_import`; see the mutants above.
- **The S7 guard reads `pubspec.yaml` by hand**, because `package:yaml` is
  not a dependency of core and adding one for a test was not worth it.
  Its fixtures cover every shape pub accepts that the review named.

## Owed to the human

- **A GPU run of the harness on a device** (macOS): `BACKEND=residentGpu`
  now loads the bundle from `jet_cad_2d_gpu`'s asset key. Every GPU run
  was the human's.
- **The merge**, on the human's word. No release and no tag: the split is
  unreleased on `main` (CHANGELOG *Unreleased*), as are schema 8 and the
  separator.

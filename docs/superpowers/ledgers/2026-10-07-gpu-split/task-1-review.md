# Task 1 review: the split (S1 to S7), commit `2b35b69`

Reviewer: independent; I wrote none of it. Clones: `/tmp/gpu-t1-review/repo` (gates, probe)
and `/tmp/gpu-t1-review/mut` (mutants, baseline probe), both at `2b35b69` with the
untracked `jet_cad_2d_gpu/analysis_options.yaml` copied in. Nothing under
`/home/user/jet-cad` was run or edited except this file.

## Verdict: **Approved with fixes**

The move is faithful, the registry is correct and well tested, and the probe confirms
the goal. One Important finding concerns the plan's premise, not the code: the new
package's `analysis_options.yaml` is not in git, while every sibling's is. Two Minor
test gaps follow.

## Findings

**1. Important. `packages/jet_cad_2d_gpu/analysis_options.yaml` is untracked, so a
fresh checkout and CI analyse that package with Dart's defaults.**
- `git ls-files | grep analysis_options` lists all 9 siblings as **tracked**. The plan's
  "left uncommitted, as its siblings' are" is factually wrong. CLAUDE.md's rule is
  about not committing the rewrites `pub get` makes. It does not mean the files are absent.
- Experiment in the mut clone: I appended `int debugStrictCastProbe(dynamic x) => x;` to
  `lib/src/install.dart`.
  - With the file: `error • ... return_of_invalid_type`.
  - Without it, as in a fresh checkout: `No issues found!`.

  So `strict-casts`, `strict-inference`, `strict-raw-types`, `lints/recommended` and
  `unused_import: error` all go unenforced in Task 2's CI matrix entry.
- Fix: commit the file, which is byte-identical to core's. Drop
  `packages/jet_cad_2d_gpu/analysis_options.yaml` from `.git/info/exclude:7`. Correct the
  plan's constraint and S1's wording ("created like its siblings'", which are committed).
  This is the controller's or human's call, because the brief calls the untracked state
  deliberate.

**2. Minor. What `DraftCanvas` passes to the registered `upload` is never asserted.**
`FakeResidentGpu.upload` ignores `viewport`, `measurer` and `textStyleOf`.
`painter.lastViewport` is the *paint* viewport, not the upload's. Two of my mutants
survived all 233 tests in `test/gpu/`:
- OWN-viewport: `residentGpu!.upload(collection, Size.zero, …)`. All passed.
- OWN-measurer: `measurer: FlutterTextMeasurer()`. All passed.

The upload viewport is the patch-target ceiling, and the measurer drives the text
patches. Before the split this was untestable, because the call went to
`uploadResidentCollection`. The registry now makes it cheap to test.
- Fix: `FakeResidentGpu` records `lastViewport`, `lastMeasurer` and `lastTextStyleOf`.
- Then, in `draft_canvas_registry_test` "an available GPU registered…", assert:
  - `gpu.lastViewport == kCanvas`;
  - `same(measurer)` (the document's measurer);
  - `gpu.lastTextStyleOf == doc.textStyleOf` (tear-offs of one receiver compare equal).

**3. Minor. The S7 key matcher has false negatives on valid YAML that `pub` accepts.**
`^ {2}([A-Za-z_]\w*)\s*:` sees only unquoted keys indented exactly two spaces. These all
stay green:
- a dependency block indented 4 spaces;
- a quoted key, `"flutter_scene": ^0.23.0`;
- a flow map, `dependencies: {flutter_scene: ^0.23.0}`.

False positives fail loud, so they are benign: a block comment, or a trailing `//`
comment on a code line that holds `'package:jet_cad_2d_gpu/`.

Watch one case. `draft_canvas.dart:349`'s fallback text, `'package:jet_cad_2d_gpu first)…'`,
passes only because a space follows the name, not `/`. A reword to
`package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart` would turn the guard red.

The URI matcher's checks are fine: import, export, both halves of a conditional, and the
look-alikes. Task 2's lock check is the end-to-end backstop.
- Fix (optional): find the section's first key indent instead of fixing it at 2, strip
  quotes, and treat a `{…}` flow value as keys. Or parse with `package:yaml` as a dev
  dependency. Add one red fixture for each of the three shapes above.

**4. Minor, accepted. Where the harness installs the GPU is guarded only by accident.**
- Removing `installResidentGpu();` from `main.dart` gives `warning • Unused import:
  'package:jet_cad_2d_gpu/jet_cad_2d_gpu.dart' • unused_import`. I verified this.
  `frame_timing_test.dart` is the same: the barrel is used only for the install.
- Moving the call below a `runApp` would not be caught by anything.
- Placement is correct today: `main.dart:833` comes before all four `runApp` branches
  (`:839`, `:854`, `:884`, `:887`), and `frame_timing_test.dart:108` follows
  `ensureInitialized()`.
- The device run (R-1, the new asset key) is still owed to the human.

**5. Nit. Stale pointers in comments.**
- `jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart:141` says `buildFrameInfo` is
  in `gpu_draw_backend.dart`; it is now in `frame_info.dart`.
- `frame_info.dart:26` and `apps/dev_harness_2d/lib/gpu_arm.dart:385` cite
  `resident_geometry.dart` without saying it now lives in `jet_cad_2d_gpu`.
- The implementer's report names commit `f6ee45f`. The commit is `2b35b69`, with an
  identical tree: `git diff f6ee45f 2b35b69` is empty.

**6. Info. An equivalent mutant.** Deleting the `identical(…) return` early-out in
`installResidentGpu` survives `install_test`. It is equivalent, because the same `const`
instance is re-registered. The meaningful mutant is the implementer's M-G4⁗ (a new
instance per call), which goes red.

**7. Docs for Task 3** (listed only):
- `roadmap/00-README.md:342-348`: core "depends on `flutter_scene`", the facade path, the
  bundle path, and no `jet_cad_2d_gpu` bullet.
- `docs/host-guide.md:53`.
- `STATUS.md:97-110`: the package tree.
- CLAUDE.md and AGENTS.md: the "every task ends green" lines lack `jet_cad_2d_gpu`.
- The CHANGELOG.

`git grep "jet_cad_2d_flutter/assets/shaders"` hits only archived ledgers, notes, old
plans, and the spec's F-2, which states a fact about `23a8950`. No code or config hits.

## What I verified

**(1) Behaviour unchanged (S5).** I diffed each moved file against `64100c0`.
- `gpu_facade.dart`: byte-identical.
- `gpu_draw_backend.dart`: the imports changed (`../flutter_text_measurer.dart` and
  `../viewport_transform.dart` became the core barrel). Old lines 12-169 left. Three
  `ResidentGeometry.`→`ResidentLayout.` renames (`:306`, `:309`, `:441`). Nothing else.
- `frame_info.dart`: identical to the removed block (`buildFrameInfo`,
  `composeTransforms`, `dashScaleFor`) apart from a new header and new imports.
  `composeTransforms` moving with `dashScaleFor`, which calls it, is justified.
- `resident_geometry.dart`: changes only in the following.
  - The imports.
  - The four statics left.
  - The asset key is `packages/jet_cad_2d_gpu/...`.
  - `library: 'jet_cad_2d_gpu'`.
  - The line reference `:63`, checked against the script.
  - Three `ResidentLayout.` qualifications.
- `ResidentLayout`: the four members verbatim, minus `@visibleForTesting`.
- `uploadResidentCollection`: body identical.
- `cad.shaderbundle`: byte-identical.
- `build_shaders.sh`: only the two source paths and a comment changed. The shaders have
  no `#include`.
- The registry:
  - `resolveBackend` gives `gpu != null && gpu.available`.
  - `DraftCanvas` reads `registeredResidentGpu` once per `_attach`.
  - `widget.residentUploader ??` wins.
  - Two wordings, keyed on `residentGpu == null`, still behind
    `_residentFallbackReported`.
  - `_FlutterGpuResident.available` reads `gpuAvailable()` live, and install is
    idempotent.
- Tests: the old `resident_geometry_test` had 18 tests and groups. They split 8 to the
  GPU package and 10 to `resident_layout_test`, with renames only. The other core test
  diffs are renames, or imports made redundant by the new `show` export.

**(2) Core has no path to `flutter_scene`.**
- `git grep "package:(flutter_scene|flutter_gpu|jet_cad_2d_gpu)/"` in core `lib/` finds one
  hit only: a `///` doc line in `resident_gpu.dart`. The pubspec has no key, no comment
  and no assets block.
- The host probe at the full SHA, from a clean state (`build`, `.dart_tool` and
  `pubspec.lock` removed):
  `tool/ci/host_probe.sh file:///tmp/gpu-t1-review/repo 2b35b69931d6…` exits 0.
  - Note: a **short** SHA fails version solving. `restaurant_symbols`' own git reference
    pins the full SHA, so the two refs conflict. Task 2 and CI should pass
    `git rev-parse` output, which CI already does.

| | `64100c0` (baseline, same method) | `2b35b69` |
|---|---|---|
| lock keys: `flutter_scene`, `flutter_gpu`, `flutter_gpu_shaders`, `scene`, `hooks`, `code_assets`, `data_assets`, `record_use`, `flat_buffers`, `yaml_edit`, `jet_cad_2d_gpu` | 10 present | **0** |
| `.dart_tool/hooks_runner` | present (`flutter_scene/`, `shared/`) | **absent** |
| `build/web/assets/packages/flutter_scene` | 12M | **absent** |
| `assets/packages/` | + `flutter_scene`, `jet_cad_2d_flutter` (52K) | `jet_cad_floor_plan`, `jet_cad_restaurant_symbols` |
| `main.dart.js` `cad.shaderbundle` count | 2 | **0** |
| `build/web` | 55,403,880 B (54M) | 43,517,478 B (42M), −11,886,402 B |

- The lock's `sdks:` reads `dart >=3.13.0`, `flutter >=3.44.0`. The probe's `flutter analyze`
  gave `No issues found!`. "No packages with native assets" was not printed, as the
  implementer also found.

**(3) Mutants I applied.** Each was restored with `git show HEAD:path > path` and checked
clean with `git diff --quiet`.

| Mutant | Result |
|---|---|
| M-G1a: `flutter_scene: ^0.23.0` under core `dependencies:` | red: "the pubspec names no GPU package…" |
| M-G1b: `import 'package:jet_cad_2d_gpu/…'` in `resident_gpu.dart` | red: "no file under lib/ reaches…" |
| M-G3a: `resolveBackend` ignoring `available` | red: 3 in `backend_selection_test`, 1 in `draft_canvas_registry_test` |
| M-G3b: the default uploader is `(c, v) async => null` | red: "an available GPU registered…", "registering null clears it…" |
| M-G3c: the wordings swapped (`!= null`) | red: 3 in the registry test, 1 in the fallback test |
| M-G4: `available => true` | red: "…flipped after install", "with a factory that throws…" |
| own: `register(null)` does not clear (`gpu ?? _registered`) | red: 1 in `backend_selection`, 1 in the registry test |
| own: the once-per-process guard removed | red: the registry test "nothing registered…", the fallback test "no GPU: two canvases…" |
| own: the upload viewport is `Size.zero` | **survived** (finding 2) |
| own: a fresh `FlutterTextMeasurer` passed to upload | **survived** (finding 2) |
| own: install's early return removed | survived; equivalent (finding 6) |
| own: harness `main` without `installResidentGpu()` | caught only by `unused_import` (finding 4) |

- Registry leakage between tests: each test file runs in its own isolate. Every file that
  registers also resets in `tearDown`, and the registry test resets in `setUp` too. No
  leak path between files exists, and none was seen.
- The fixtures are not degenerate. `textOverlapFixture` at a fit camera, and the install
  test's `generateDocument(40, dashedFraction: 0.5)`, carry an anti-vacuity
  `instanceCount > 0`.

**(4) The S7 guard.** See finding 3. Its self-tests cover one red case per name per
section and per URI form, plus green look-alikes.

**(5) The harness.** See finding 4. `allocation_probe` adds `package:jet_cad_2d_gpu/`,
which is correct: `GpuDrawBackend`'s per-frame objects changed library.

**(7) Gates, run in my clone.**

| Package | Command | Result |
|---|---|---|
| `packages/jet_cad_2d_flutter` | `flutter test --file-reporter json` | `05:07 +1344 ~1 -7: Some tests failed.` |
| | `expect_failures.dart --package packages/jet_cad_2d_flutter --root packages/jet_cad_2d_flutter` | `packages/jet_cad_2d_flutter: 1352 tests; the standing failures and skips, exactly` |
| | `flutter analyze` | `No issues found!` |
| | `dart format` | `Formatted 221 files (0 changed)` |
| `packages/jet_cad_2d_gpu` | `flutter test` | `00:11 +16: All tests passed!` |
| | `flutter analyze` | `No issues found!` (with the copied options) |
| | `dart format` | `Formatted 9 files (0 changed)` |
| `apps/floor_planner` | `flutter analyze` | `No issues found!` |
| `packages/jet_cad_floor_plan` | `flutter analyze` | `No issues found!` |
| `apps/dev_harness_2d` | `flutter analyze` | `No issues found!` |

---

## Controller's disposition

- Finding 1 (the options file): applied in `e1ddf4e`. Plan 01's Ruling
  01-1 settles it: a package's `analysis_options.yaml` is committed once,
  at scaffold. The plan's constraint was corrected.
- Findings 2, 3, 5: applied in `6a2b3b2` (task-1-fixes-report.md).
- Finding 4: recorded in the results note (install placement guarded
  only by `unused_import`).
- Finding 6: equivalent; recorded.
- Finding 7: done in Task 3 (`7aeaa5b`).

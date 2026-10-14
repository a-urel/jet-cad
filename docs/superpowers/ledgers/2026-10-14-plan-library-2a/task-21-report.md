# Task 21 report: the exit gate

Status: DONE (no gate failed outside the standing environmental failures).
Commit: `ca81499d docs: the plan library in design mode, results of record` on `e1e577d5`.
Note: `docs/superpowers/notes/2026-10-14-plan-library-2a-results.md` (staged by explicit path, trailer as required). Nothing pushed, tagged, merged or published.

## Commands and outputs (all run on HEAD e1e577d5, 2026-10-14)

Step 1:
- `git status --short`: printed nothing.
- `git log --name-only --format= main..HEAD | grep analysis_options`: `packages/jet_cad_2d_plan/analysis_options.yaml` (one line).
- `git log --format='%H %s' main..HEAD | wc -l`: `45`; `git rev-parse HEAD`: `e1e577d522c59a6376823ca7dc3cad4fa534310f`. Local `main` 60839065 is an ancestor of HEAD; origin/main 27244bf2 is an ancestor of local main.

Step 2:
- jet_cad_2d_kit: `flutter test` -> `00:04 +314: All tests passed!` (exit 0); `flutter analyze` -> `No issues found! (ran in 5.1s)`; format -> `Formatted 68 files (0 changed) in 0.13 seconds.` (exit 0).
- jet_cad_2d_plan: `flutter test` -> `00:42 +723: All tests passed!` (exit 0; no skip); `flutter analyze` -> `No issues found! (ran in 5.2s)`; format -> `Formatted 177 files (0 changed) in 0.61 seconds.` (exit 0). CV-alloc passed inside the run.

Step 3:
- `cd tool/ci && dart test` -> `00:49 +116: All tests passed!` (exit 0).
- `dart run tool/ci/check_kit_deps.dart` -> `kit dependencies: 1 package(s) checked, none names the plan library or another kit` (exit 0).
- `check_readmes.dart` -> `package READMEs: all 6 code blocks are in the probes` (exit 0); `check_screenshots.dart` -> `screenshots: every rule holds` (exit 0).

Step 4:
- jet_cad_2d `dart test` -> `00:08 +1322 -2: Some tests failed.` (exit 1); failing: exactly the two `generate_document_test.dart` lines of standing_failures.txt. query_allocation_test: no [E]. `dart analyze` -> `No issues found!`; format `Formatted 184 files (0 changed) in 0.59 seconds.` (exit 0).
- jet_cad_2d_flutter `flutter test` -> `00:26 +1450 ~1 -5: Some tests failed.` (exit 1); failing: `text_ladder_golden_test.dart` rungs 1-5 (RenderBackend.canvas), all in standing_failures.txt; the list's two `text_lod_ladder` lines passed locally (same as Tasks 1-2 recorded); `~1` = standing_skips.txt's paint microbench rig. paint_allocation_test: no [E]. `flutter analyze` -> `No issues found! (ran in 5.2s)`; format `Formatted 234 files (0 changed) in 0.53 seconds.` (exit 0).
- jet_cad_2d_gpu -> `00:00 +20: All tests passed!`; `No issues found! (ran in 3.6s)`; `Formatted 10 files (0 changed) in 0.02 seconds.` (all exit 0).
- jet_cad_floor_plan `flutter test` -> `02:01 +2008 ~4: All tests passed!` (exit 0).

Step 5:
- jet_cad_2d_kit `dart pub publish --dry-run`: exit 0, `Package has 0 warnings.`
- jet_cad_2d_plan `dart pub publish --dry-run`: exit 0, `Package has 0 warnings.`; file list holds CHANGELOG.md, LICENSE, README.md, example/main.dart, lib/jet_cad_2d_plan.dart, lib/fonts/Roboto-Regular.ttf, assets/fonts/Roboto_LICENSE.txt, pubspec.yaml.
- `cmp LICENSE packages/jet_cad_2d_plan/LICENSE`, `cmp LICENSE packages/jet_cad_2d_kit/LICENSE`: printed nothing, exit 0.

Step 6:
- `git diff --stat main -- packages/jet_cad_floor_plan packages/jet_cad_restaurant_symbols packages/jet_cad_2d_gpu packages/jet_cad_2d_flutter apps`: printed nothing (exit 0).
- Engine commits: 3d84a62c (T1), 40912bf7 (T2), 7ba09b31 (T2 fix round 1). Nothing else.
- Old-package grep: 99 lines, all `//`/`///` comments (the `grep -v ":[0-9]*: *//"` filter printed nothing); import grep printed nothing.
- Contract-deps grep, purity greps, `dart:io` grep: each printed nothing.
- Versions: kit 0.1.0, engine 0.7.2, plan 0.8.0, flutter 0.7.2; `3:## Unreleased` in the engine CHANGELOG.
- `packages/jet_cad_2d_plan/test/invariants/` holds canvas_paint_allocation_test.dart (and theme_colours_test.dart).
- Sample kit: `sample kit: 4 symbols written` (exit 0); `git diff --quiet` on sample.jetlib and sample_snapshot.json: exit 0.
- `git status --short`: printed nothing after every pub operation and after all checks; empty again after the commit.

Step 7: every test id the coverage table names (168 distinct ids, including each range's first and last) was found by one grep over packages/jet_cad_2d/test, packages/jet_cad_2d_kit/test, packages/jet_cad_2d_plan/test and tool/ci/test (`comm` of the list against the hits printed nothing). No `missing` row.

Step 8-9: note written, committed as ca81499d.

## Concerns

1. Flutter-layer standing comparison is not "exactly" the list: locally the two `text_lod_ladder` lines pass (5 of the 7 listed failures fail). This is the known macOS-vs-Linux difference Tasks 1-2 also recorded; no failure outside the list. On CI's exact comparison the list holds for Linux.
2. The mutation table in the note groups each task's ids by file and test; the exact edit and quoted red line per id stay in the task reports (none re-run here). Ported-test counts are the reports' own; several reports give no per-file count, and the note says "not counted in the report" there.
3. The 99 old-package mentions were verified to be comment lines, not each read for its citation.
4. Items for the human, recorded in the note: RV6's retired half (selectTool true with no view: a host-API difference awaiting the human's word, A14); tool settings surviving a swap (deliberate); panel fields using the language's separator; the retired mixed-case tag test (F-1); the moved assertions.

## Invariant re-runs (controller check)

The note's first version quoted three lines grepped from the full-suite logs, which this report did not quote. Each invariant file was run on its own; the note now quotes these final lines.

```
$ cd packages/jet_cad_2d_plan && flutter test test/invariants/canvas_paint_allocation_test.dart
00:00 +0: CV-alloc a rebuilt steady-state PlanCanvas frame allocates O(1) per flush, not O(entities) (M-CV-alloc-1, M-CV-alloc-2)
00:01 +1: All tests passed!
exit 0

$ cd packages/jet_cad_2d && dart test test/invariants/query_allocation_test.dart
00:05 +6: (tearDownAll)
00:05 +6: All tests passed!
exit 0

$ cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
LOAD fills=5000 elapsed=75ms
00:00 +3: All tests passed!
exit 0
```

## Transcript excerpts the note quotes (from this task's own full-suite logs)

`packages/jet_cad_2d` `dart test`, the tail as printed:
```
00:08 +1322 -2: Some tests failed.

Failing tests:
  test/testing/generate_document_test.dart: both text fractions default to zero and change nothing
  test/testing/generate_document_test.dart: the default document is the one Plan 2 measured, byte for byte
```

`packages/jet_cad_2d_flutter` `flutter test`, the tail as printed:
```
00:26 +1450 ~1 -5: Some tests failed.

Failing tests:
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
flutter test exit 1
```

`packages/jet_cad_2d_plan` `dart pub publish --dry-run`, the head of the file list and the closing lines as printed:
```
Publishing jet_cad_2d_plan 0.8.0 to https://pub.dev:
├── CHANGELOG.md (1 KB)
├── LICENSE (11 KB)
├── README.md (2 KB)
├── analysis_options.yaml (<1 KB)
├── assets
│   └── fonts
│       ├── README.md (<1 KB)
│       └── Roboto_LICENSE.txt (11 KB)
├── example
│   └── main.dart (1 KB)
├── lib
│   ├── fonts
│   │   └── Roboto-Regular.ttf (167 KB)
│   ├── jet_cad_2d_plan.dart (2 KB)
│   └── src
...
├── pubspec.yaml (<1 KB)
...
Total compressed archive size: 491 KB.
...
Package has 0 warnings.
```

Other figures in the note are either quoted above or in the "Commands and outputs" section, or they are labelled "report" (from task-N-report.md): Tasks 1-2's `+1450 ~1 -5` and `+2008 ~4`, the ported-test counts, the mutation ids and run counts, and Task 20's expect-comparison totals.

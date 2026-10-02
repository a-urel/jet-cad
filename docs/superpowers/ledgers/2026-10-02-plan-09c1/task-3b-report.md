# Task 3b report: review fixes for Task 3 (spec D2, D9, D10)

Status: **done** (implementer). Commit `7dbfc88` test(app): pin the pre-09c symbols and R03d's duplicate tag. Not pushed.

## Files (all staged by explicit path, 3 files, +75)
- `apps/floor_planner/test/fixtures/furniture_pre_09c.jetlib` (new). Made with `git show 9414208:apps/floor_planner/assets/library/furniture.jetlib`, 44229 bytes. Its git blob `8e0693aa…` is the same blob at `9414208` and at `main` `4d6b78f`, so **this is also the branch point's asset**. It is not under `assets/` and not in the pubspec (the pubspec still lists only `assets/library/furniture.jetlib`).
  - **For Task 11:** use this file for "a plan saved before 09c (the real 27-symbol definitions)". The path is exported as `pre09cLibraryPath` / `pre09cLibrary()` in `furniture_library_test.dart`. A test in another file can read the path directly.
- `apps/floor_planner/test/symbols/furniture_library_test.dart`: the top-level `pre09cLibraryPath` and `pre09cLibrary()` (they decode through the real `SymbolLibrary.decode`), plus a new group, "the 27 symbols shipped before 09c (spec 09c D2, D10)", with three tests:
  1. "the fixture decodes to the 27 pre-09c symbols, none tagged by 09c": 27 entries, none with `against-wall` or `family:`.
  2. "each keeps its name, category, version, base point and leaves": for each fixture entry, the current asset entry with the same key must match exactly:
     - name, category and version;
     - base point x and y;
     - leaf count;
     - each leaf pairwise in ascending-handle order: `kind`, then `EntityRecord ==` after `copyWith(handle, owner, geomIndex)` takes the fixture's values (so every other field is compared with exact `==`), then `coords` and `scalars` with `orderedEquals` (exact `==`).
  3. "its tags are the old tags with new ones appended only": the current tags are at least as long, and `take(old.length)` equals the old tags in order.
- `apps/floor_planner/test/symbols/symbol_library_test.dart`: the test "R03d a symbol with two family tags is refused" gains a second case. The nightstand is tagged `['nightstand', 'family:x', 'against-wall', 'family:x']`, and the error must name `nightstand.single@2` and `2 family tags ("family:x", "family:x")`.

## Gates (real runs, this container, `export PATH=/root/flutter/bin:$PATH`, `CI=true`)
- App `flutter test`: `07:29 +1095: All tests passed!` (exit 0). This ran in the shared worktree, so the count includes other agents' uncommitted, in-progress work (Task 10's files, plus modified `test/support/wall_attach_fixture.dart`, `test/symbols/wall_faces_test.dart` and an untracked `zz_task4b_debug_test.dart`). My two test files alone: `00:02 +204: All tests passed!` (151 furniture_library + 53 symbol_library; it was 148 + 53 = 201 before this task).
- App `flutter analyze`: the first whole-app run printed "1 issue found." Two later runs printed `No issues found!`, and `flutter analyze` on my two files printed `No issues found!`. My files did not change between those runs. The transient issue was in a file another agent was editing at the time; I could not capture which one.
- App `dart format --output=none --set-exit-if-changed .`: `Formatted 180 files (0 changed)`, exit 0.
- Engine, render and web build: not affected (test files and a fixture only, nothing under `packages/` or `lib/`), so I did not re-run them.

## Mutants
For each catalog mutant I backed up the catalog and asset with `cp`, mutated with a one-occurrence replace, regenerated with `dart run tool/generate_furniture_library.dart` and ran `test/symbols/furniture_library_test.dart`. I then copied both files back. Every time, `diff` on the catalog, `cmp` on the asset and `git diff --quiet -- lib/symbols/furniture_catalog.dart assets` all exited 0. Script: `scratchpad/task3b/mut.sh`. Logs: `scratchpad/task3b/mut_*.log`.

| Mutant | Site | Change | Result | Red test | Output excerpt |
|---|---|---|---|---|---|
| wardrobe loop (review's) | `furniture_catalog.dart:233` `_wardrobe` | `x < w` → `x <= w` (asset 63657 bytes) | **red** `00:01 +150 -1` | each keeps its name, … leaves | `Expected: <6> Actual: <7>` `bed.wardrobe` |
| double-bed pillow gap | `_doubleBed` | `200 + pillow` → `210 + pillow` | **red** `+150 -1` | same | `at location [0] is <860.0> instead of <850.0>` `bed.double leaf 2` |
| single-bed leaf moved | `_singleBed` | pillow `_rect(120, 1680, …)` → `1690` | **red** `+150 -1` | same | `at location [1] is <1690.0> instead of <1680.0>` `bed.single leaf 1` |
| old desk drawer line moved | `_desk` | `LineShape(w - 400, 230, w, 230)` → `w == 1400 ? 240 : 230` (only `office.desk@1`) | **red** `+150 -1` | same | `Expected: equals [1000.0, 230.0, 1400.0, 230.0] … Actual: [1000.0, 240.0, 1400.0, 240.0]` `office.desk leaf 2` |
| tag removed from an old symbol | `bath.tub` tags | `'bath'` removed | **red** `+150 -1` | its tags are the old tags with new ones appended only | `at location [1] is 'sanitary' instead of 'bath'` `bath.tub` |
| tag prepended (extra) | `bath.tub` tags | `'tub'` first | **red** `+150 -1` | same | `at location [0] is 'tub' instead of 'bathtub'` `bath.tub` |
| old name changed (extra) | `office.desk` | `'Desk'` → `'Desk 1400'` | **red** `+150 -1` | each keeps its name, … | `Expected: 'Desk' Actual: 'Desk 1400'` `office.desk` |
| R03d duplicate (review's) | `symbol_library.dart:161` | `families.length > 1` → `families.toSet().length > 1` | **red** `00:00 +52 -1` (symbol_library_test) | R03d a symbol with two family tags is refused | `the library was accepted; expected a rejection naming [nightstand.single@2, 2 family tags ("family:x", "family:x")]` at `symbol_library_test.dart 241:7` (the new case) |

In each catalog mutant, the only failing test in the file is the new pre-09c test. In the review, the wardrobe mutant survived the whole app suite, so the new group is what catches it. I ran the R03d mutant the same way: `cp` backup, run the test, `cp` back, then `diff` exit 0 and `git diff --quiet` clean.

## Notes
- The leaf-count check uses `expect(n.leaves.length, o.leaves.length)`, not `hasLength`, so a failure prints `<6>`/`<7>` and not the whole leaf list.
- Review notes 3–5 were not acted on, because they are not owed by the brief: the new desks' interiors, the 2400 wardrobe's handles (for the human's look list) and the unused constants.

# Task 13 report: Opening geometry and cuts (spec 3a C3.3, C1.5, C7)

Status: DONE. Commit `597ae10c feat(architecture): opening parameters, geometry and the wall's cut (spec 3a C3.3)`.

## Implementation summary

- `lib/src/opening/opening.dart`: ported from `jet_cad_floor_plan/lib/src/parametric/opening.dart`. The header comment is rewritten as the brief gives it, the imports become `../ids.dart`, `../wall/wall.dart`, `opening_geometry.dart`, and `componentTypeId = ArchitectureTypes.opening`. Every other line is unchanged (checked with `diff`).
- `lib/src/opening/opening_geometry.dart`: source lines 1-599 and 618-698 are copied unchanged. The port line is inserted after line 13. The imports are `../ids.dart`, `../live.dart`, `../wall/wall.dart`, `../wall/wall_geometry.dart` and `opening.dart`.
  - `wallsInView` (600-617) and `wallsInDocument` (699-728) are dropped. Both are Task 11's, in `wall_geometry.dart`.
  - The three document adapters (`hostFrameInDocument`, `layoutInDocument`, `openingsInDocument`) are replaced with the brief's `LiveTypeOf` versions (R13-1).
  - No reader bypasses `WallBands._refresh`: the opening geometry does not read the bands at all.
- `lib/src/wall/wall.dart`: `generate` is replaced with today's `wall.dart:191-213`, and `_cut` (`:215-238`) is inserted after it, both unchanged. It also gains `import '../opening/opening_geometry.dart' show centrelinePieces, hostCutsInView, piecesOf;` (R13-4).
- The barrel now exports `src/opening/opening.dart` with `show HingeEnd, OpeningKind, OpeningParams, SwingSide;`.
- `test/support/catalog.dart` now registers `OpeningParams` after `WallParams` (R-P13).
- `test/support/opening_fixture.dart` is ported with A13-imports plus `export 'wall_fixture.dart' show installParametric, liveOf, testCatalog;`.
- `test/opening/opening_live_test.dart` (OG-live) is the brief's text verbatim; `dart format` rewrapped one `expect`. Its fixture is not degenerate:
  - two walls, A and X, each in its own rotated group at the far origin, with the plan turned 23 degrees;
  - two openings, O (a door) and P (a window);
  - three freezes: X, A and O.

## TDD evidence

RED (`flutter test test/opening/`, before any lib file existed): all 8 files failed to load. For example:
```
test/opening/opening_live_test.dart:10:8: Error: Error when reading 'lib/src/opening/opening.dart': No such file or directory
test/opening/opening_live_test.dart:11:8: Error: Error when reading 'lib/src/opening/opening_geometry.dart': No such file or directory
00:00 +0 -8: Some tests failed.
```
The same error appeared for params, geometry, cut, kink, obstacle, cost and symbol, and for `catalog.dart:10` and `opening_fixture.dart:15`.

GREEN: `dart format . && flutter test test/opening/` printed `00:07 +33: All tests passed!`.

RC3 printed these timings (it has no budget, so nothing is asserted on them):
```
RC3 n=100 line draw median 2.21 ms [2.31, 4.11, 2.21, 2.20, 2.20]; move median 3.21 ms [3.21, 3.08, 5.10, 3.68, 2.83]
RC3 n=300 line draw median 2.04 ms [2.04, 2.04, 2.04, 2.06, 2.92]; move median 2.36 ms [2.36, 2.31, 2.34, 2.40, 7.34]
RC3 n=600 line draw median 4.09 ms [4.09, 4.42, 4.21, 3.97, 4.00]; move median 4.36 ms [4.77, 4.50, 4.26, 4.36, 4.27]
```
`opening_cost_test.dart` has no timing or allocation budget: its only assertions are `hasLength(2)` and `driftOf(doc) isEmpty`. It was ported as written.

Other printed output:
- `KJ2: 1620 cases, 0 refused, 0 no-fit`
- OG9: `... 3235 openings (0 refused) ... 0 tiling violations ... 0 trials whose diagnostics differ from the oracle ... 0 off the oracle ...`

## Gates (kit; run before and again after the commit)

- `flutter test` printed `00:09 +113: All tests passed!`. That is 80 before this task plus 33 new. None of Task 11's or 12's wall tests changed outcome now that walls are cut.
- `flutter analyze` printed `No issues found!`.
- `dart format --output=none --set-exit-if-changed .` printed `Formatted 48 files (0 changed)` and exited 0.
- `dart pub publish --dry-run` printed `Package has 0 warnings.` after the commit. Before the commit, its only warning was the uncommitted-files one.
- `dart run tool/ci/check_kit_deps.dart` (repository root) printed `kit dependencies: 2 package(s) checked, none names the plan library or another kit` and exited 0.
- `git status --short` was empty after the commit and after every mutation revert. No `analysis_options.yaml` was touched.

## Mutation results

All were run on the committed files. Each was reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` then exited 0.

| Id | Mutation | Red output |
|---|---|---|
| M-OG-1 | `opening.dart`: `componentTypeId = 'floor_planner.opening'` | OP1 `[E]`: `Expected: 'architecture.opening'  Actual: 'floor_planner.opening'` |
| M-OG-2 | `hostFrameInDocument`: `wallsInDocument(doc, host, (h) => ArchitectureTypes.wall)` | OG-live `[E]`: `Expected: null  Actual: <Instance of 'HostFrame'>` (A frozen still has a frame) |
| M-OG-3 | `layoutInDocument`: `(h) => h == host ? live(h) : ArchitectureTypes.wall` | OG-live `[E]`: `Expected: empty  Actual: [` at `opening_live_test.dart 56:5` (`layout.obstacles`, X frozen is still an obstacle) |
| M-OG-4 | `openingsInDocument`: the `if (live(h) == ArchitectureTypes.opening)` line deleted | OG-live `[E]`: `Expected: [5100]  Actual: [5000, 5100]` at `:70:5` |
| M-OG-5 | `wall_geometry.dart` `wallsInDocument`: `&& live(h) == ArchitectureTypes.wall` deleted | OG-live `[E]`: `Expected: not contains <1200>  Actual: [1200]` at `:53:5`; HF9 `[E]`: `Expected: empty  Actual: [5100, 5200]` at `opening_geometry_test.dart 465:5` |
| M-OG-6 | `wall.dart`: the `if (_cut(view, self) case final pieces?) return pieces;` line deleted | `opening_cut_test.dart` is red in all six cases (OG1, OG2, OG8, OG9, OR3, OR6 `[E]`), which includes the named OG1 and OR3 |
| M-OG-7 | `placeCut`: `distance <= bestDistance` | HF6 `[E]` ("a tie goes to the lower a"): `Expected: <500.25>  Actual: <2000.75>` at `opening_geometry_test.dart 302:5` |
| M-OG-8 | `cutsOf`: `if (pieces.isEmpty)` | KJ1 (1e-6°) `[E]`: `Invalid argument(s): 3E8 generated a region whose boundary is not a closed polyline with a non-empty triangulation (spec 07 D8)` at `opening_kink_test.dart 129:18` |

## Ported-test accounting (32 ported plus 1 new, 33 cases)

| Old file (`jet_cad_floor_plan/test/`) | Cases | New file | Change classes |
|---|---|---|---|
| `opening_params_test.dart` | OP1 | `test/opening/opening_params_test.dart` | A13-imports; C7 class 1 (ids) at :28-29 |
| `opening_geometry_test.dart` | HF1, HF2, HF3, HF4, HF5, HF6, OG5, HF8, HF9 | `test/opening/opening_geometry_test.dart` | A13-imports; A13-live at :395, :409, :458-460, :462, :464, :471 (the :458 line was rewrapped by `dart format`) |
| `opening_cut_test.dart` | OG1, OG2, OG8, OG9, OR3, OR6 | `test/opening/opening_cut_test.dart` | A13-imports |
| `opening_obstacle_test.dart` | OG3, OG4, OG6, OG11 (a), (b), (c), OD1, OG11 (d) | `test/opening/opening_obstacle_test.dart` | A13-imports (`box.dart` from `src/box/`) |
| `opening_cost_test.dart` | RC3 | `test/opening/opening_cost_test.dart` | A13-imports |
| `opening_kink_test.dart` | KJ1, KJ1 (1e-6°), KJ2, KJ6 | `test/opening/opening_kink_test.dart` | A13-imports; the shell section (:75-160) is not copied, along with its imports (`planner_shell`, `planner_view`, `catalog`, the three flutter imports, `dart:math`, `jet_cad_2d_flutter`); A13-live at :182, :215 |
| `opening_symbol_test.dart` | OG7, OG10, OR7 | `test/opening/opening_symbol_test.dart` | A13-imports; lines :348-473 (OR8) and OR8's imports are not copied |
| `support/opening_fixture.dart` | — | `test/support/opening_fixture.dart` | A13-imports plus the `export 'wall_fixture.dart' show installParametric, liveOf, testCatalog;` line |
| (new) | OG-live | `test/opening/opening_live_test.dart` | — |

KJ3, KJ4, KJ5 and OR8 are not ported here (R13-3): Tasks 14 and 15 port them.

No assertion changed. Every ported file was diffed against its source. The only differences are:
- the header line;
- the mapped imports;
- the two id lines;
- the A13-live call sites;
- the removed shell and OR8 sections;
- `dart format` rewraps.

Because the files were copied byte for byte (a Python read and write of the source), the non-ASCII literals are identical to the source, and `diff` shows no other line.

## Files changed

- `packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart`
- `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_geometry.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart`
- `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart`
- `packages/jet_cad_2d_kit_architecture/test/support/opening_fixture.dart` (new)
- `packages/jet_cad_2d_kit_architecture/test/opening/` (8 new files): `opening_live_test`, `opening_params_test`, `opening_geometry_test`, `opening_cut_test`, `opening_kink_test`, `opening_obstacle_test`, `opening_cost_test`, `opening_symbol_test`

## Deviations

- The brief's line numbers for `opening_geometry.dart` differ by one: the `wallsInView` section runs to :617 (including its trailing blank line) and `wallsInDocument` to :728. The port copied 1-599 and 618-698. The content matches the brief's intent exactly.
- In `wall.dart`, `_cut` ends at today's :238, not :239 (:239 is the blank line). Its content is unchanged.
- `opening_fixture.dart` also got the "Ported from" header line, consistent with "every file below" in Step 4.

## Concerns

None. M-OG-6 turns all six cut cases red, not just OG1 and OR3: every one of them relies on the cut.

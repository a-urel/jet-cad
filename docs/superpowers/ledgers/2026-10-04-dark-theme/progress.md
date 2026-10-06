# Dark theme — progress ledger

**Plan:** docs/superpowers/plans/2026-10-04-dark-theme.md (at `91d88e4`).
**Spec:** docs/superpowers/specs/2026-10-04-dark-theme-design.md rev 2, approved 2026-10-04 ("Onaylıyorum").
**Branch:** `claude/dreamy-gates-2kgh4o`, main checkout /home/user/jet-cad (no worktree).
**Branch point gates** (`91d88e4`, this container, Flutter 3.47.6):
- render (`jet_cad_2d_flutter`): +1240 ~1 -7 (the 7 standing text-ladder golden failures, 1 skip)
- planner (`jet_cad_floor_plan`): +1167, all passed
- restaurant symbols: +94, all passed
- app `floor_planner`: +201, all passed
- demo `restaurant_demo`: +17, all passed
- engine: untouched by this plan (not run)

## Tasks

| Task | Implementer commits | Review | Status |
|---|---|---|---|
| 1 Palettes | `23314be` | Approved (no findings; named + 4 own mutants red; only the equivalent alpha-mask mutant survives) | done |
| 2 Painters | `2a439e0` | Approved (1 minor: M-DT-5 never crosses theme and paper — page breaks from chrome survives; carried into Task 3 as its first item; 2 notes) | done |
| 3 Tool paint methods | `31b5a43`, `eba82d0` (3b) | Needs fixes (2 minor: DimensionTool's `super.paintOverlay` paper unpinned; SelectTool's move guide colour unpinned) -> 3b test-only, verified by the controller (both mutants re-fired red, restored) | done |
| 4 Planner wiring | `37a1797` | Approved (no findings, 3 notes; 20 mutants re-fired red incl. 6 own; web builds ✓ both apps) | done |
| 5 Canvas UI fixes | `6e3fa02`, `1fab9a9` (5b) | Needs fixes (1 minor: `_onPage` updating `_paper` before its early return unpinned) -> 5b test-only by the controller: White→Ivory under `0x991E1E1E`; red under the mutant (`Expected 0xffffff Actual 0x202020`), restored; planner +1199 | done |
| 6 Widgets | `4f324f9`, `36902c0` (6b) | Needs fixes (1 minor: the dark sweep skipped `restaurant_demo`'s own UI) -> 6b test-only by the controller: demo under platform brightness dark through areas, service + statuses, discard dialog; `ThemeMode.light` mutant red (`Expected Brightness.dark Actual Brightness.light`), restored; demo +18 | done |
| 7 Exit | `3f28e41` (docs, screenshots, one test comment) | — (exit task) | done: gates re-run, both web builds ✓, Chromium smoke (10 shots), results note, spec amended, STATUS |

## Rulings (with cost-if-wrong)

- **R-C1-1 (accepted by the Task 1 review):** the old colour constants in `chrome_style.dart` / `selection_style.dart` stay as literals, not aliases (a Dart `const` cannot read a const object's field: `const_eval_property_access`); the transitional test `the old chrome and selection constants equal the .light fields` pins all 16 to `.light`. **Task 3 must delete both the constants and that test.** Cost if wrong: none at runtime.
- **R-C1-2 (accepted):** `forPaper`'s `& 0xFFFFFF` stays because the spec writes it; removing it is an equivalent mutant (`foregroundFor` reads only the RGB bytes). Cost if wrong: nil.
- **Note (review 1):** the palettes have no `toString`; Task 2 may add one for readable repaint-test failures.
- **R-C2-1 (accepted by the Task 2 review):** `RulerPainter` / `RulerCornerPainter` gain `@visibleForTesting TextSpan? get debugLastLabel` to read the label colour. Cost if wrong: two getters to remove.
- **R-C2-2 (accepted):** the M-DT-5 camera puts the sheet edge at x = 300.5 so the break covers column 300 exactly; a Paint-colour assertion backs it. Cost if wrong: a wider tolerance.
- **C-1 (controller):** review 2's minor finding (page breaks taken from chrome survives; M-DT-5 only runs dark chrome on Blueprint) is fixed as Task 3's first item: one crossed assertion (White paper under dark chrome → `0xFF3366CC`, Blueprint under light chrome → `0xFF8AB4F8`). Cost if wrong: none.
- **Note for Task 4 (review 2):** nothing in the planner suite pins which palettes `PlannerView` hands down (`.dark` survives); Task 4 adds a light-theme, light-paper planner assertion beside M-DT-1/-2.
- **R-C3-1 (accepted by the Task 3 review):** the extra `expectOnlySet` assertion (no colour of the other paper set in a frame); the two palettes share no colour value. Cost if wrong: none.
- **R-C3-2 (accepted):** Paint-identity tests for the tools' Paints, each owed a fresh-Paint-per-frame mutant. Cost if wrong: none.
- **Note (review 3):** `SelectTool.paintOverlay` allocates two `Paint`s and a `Color` per band frame, pre-existing at `2a439e0`; a later frame-path cleanup could make them fields. Not in this plan's scope.
- **R-C4-1 (accepted by the Task 4 review):** `_DraftCustomPainter.shouldRepaint` also answers `old.painter != painter` (outside spec "Files"). Without it a no-page theme flip replaces the resolver but nothing repaints the drawing. `painter` is assigned only in `_attach()` (initState, or didUpdateWidget on a real prop change), so an ordinary rebuild still answers false; frame accounting unedited and green. Cost if wrong: one line and one test. **Record in the spec's "Amended at execution".**
- **R-C4-2 (accepted):** spec M-DT-9's premise is wrong: `OutlineCache._onChange` (`outline_cache.dart:248-259`) repaints the overlay on any document change while something is selected, so a paper flip cannot witness the overlay's `shouldRepaint`. That mutant is killed by the no-page theme-switch tests (shell and ServiceView). **Record in the spec's "Amended at execution".**
- **R-C4-3 (accepted):** `bool _hasResolver` beside the `late` resolver. Cost if wrong: none.
- **R-C4-4 (accepted):** each app's seed hoisted to a file-private `const Color _seed` (one literal per file, fits Task 6's allow-list).
- **Notes (review 4):** stale "unconditionally false" comments about `_DraftCustomPainter.shouldRepaint` in three golden test files (leave unedited) and `test/support/tile_comparison.dart:555` (Task 7 may fix the support file's comment); the no-page theme-switch tests could assert the camera is unchanged.
- **R-C5-1 (accepted by the Task 5 review):** a status whose composite over the paper takes white ink gets a white caption in the light theme too (D6c's formula; `0xFF202020` on such a fill was unreadable). **Record in the spec's "Amended at execution":** D7's "captions unchanged" covers statuses whose composite takes black ink (the demo's three do).
- **R-C5-2 (accepted):** removing `fillColor:` with `filled: true` is equivalent under Material 3 defaults (no app sets an `inputDecorationTheme`). Optional extra variant under an explicit `InputDecorationTheme` not done.
- **R-C5-3, R-C5-4 (accepted):** the ServiceView caption fixture at 0.07 px/mm; `over` top-level in `table_status_painter.dart`, returning `0xRRGGBB`.
- **Note for Task 7 (review 5):** the caption overlapping the table number label is pre-existing at `37a1797` (likely the test font's full-em glyphs); check it in the service-view screenshot at ~0.25 px/mm.
- **R-C6-1 (accepted by the Task 6 review):** "centre leaf" sampled as the darkest/brightest pixel of the middle half of the thumbnail rect. Cost if wrong: a different sample region.
- **R-C6-2, R-C6-3 (accepted):** M-DT-17 a new test (the M-DT-9 shell has no symbol loader); shots wrap the navigator so popups are captured.
- **Debt (review 6, for the results note):** the D9a scan cannot tell two equal allowed literals apart in one file (N1; an expected count per pair would); a literal split across lines (`Color(\n 0x..)`), `Color.from(alpha:)` and `CupertinoColors` pass the spec's verbatim patterns (N2).

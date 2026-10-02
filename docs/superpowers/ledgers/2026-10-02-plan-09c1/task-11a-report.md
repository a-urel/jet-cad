# Task 11a report (implementer) — wall-aware placement end to end

Status: done, committed `8f5f601` (not pushed).

## Plan
- New `apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart` (steps 1-4 in one test, step 5 in a second).
- `test/support/pre_09c_library.dart`: `pre09cLibrary()` factored out of `furniture_library_test.dart`.
- Stale comment fixed at `symbol_placer_test.dart:~891`.

## Built (written so far)
- `apps/floor_planner/test/symbols/wall_attach_end_to_end_test.dart` (new):
  - **WE1** — L of 100 mm (A, right-justified, 4000 at 30°) and 240 mm (B, left-justified, 3000 at 120°) walls, each in its own `attachGroup` (turned, translated) near (1e5, −7e4), added through the session document's commands; camera `aimCamera` (rotated 0.3 rad, 0.1 px/mm). Step 1: `bed.double` armed from the Symbols tab (search, Enter, tap), hover 120 mm off A's outside face, press, move, release 40 mm along: hover ghost and committed transform byte-equal to `attachToWall` computed in the test from `faceRunsOf(doc, h, accept: isUsableHost)`; flush checked against the definition's drawn vertices (lines and polylines through the instance transform; nearest within 1e-9·|a|, the on-face vertices spanning the full 1600 width; local +y = −m, +x = t within 1e-12). Step 2: `kitchen.base.600` three times along A's inside face from the drawn corner (premises: the run starts on B's drawn inside face, not at the centrelines' meet; u grows away from the corner), pointer offsets 60/70/55 mm inside the 100 mm edge capture; each transform byte-equal to `attachToWall` with neighbours computed in the test from the placed instances; spans [0,600],[600,1200],[1200,1800] within 1e-9 absolute. Step 3: undo ×3 via Cmd+Z (bed only left, unit definition gone, tool still armed), redo ×3 via Cmd+Shift+Z: transforms and `bytesOf(doc)` equal. Step 4: Save As -> Open -> Save byte-identical (first write == bytes before the undo).
  - **WE2** — a "plan saved before 09c": `newDocument` + `installParametric`, a −112.5° wall (150, centre) in a turned group, the four pre-09c entries (`bed.double`, `bed.wardrobe`, `kitchen.base.600`, `office.desk`, untagged in the fixture) placed by `placeSymbol` with turns 1..4 and alternating mirror; encoded. Opened in the host through `openFlow`, saved through `saveStep`: written bytes == the plan's bytes. Then the same four keys from the CURRENT library (all tagged now) armed through the Symbols tab: three placed free 1500–2400 mm into the room (ghost not attached), the wardrobe mirrored with `M` and placed on the wall face (bytes == `attachToWall(mirrored: true)`, flush, +x = −t); every new instance's definition is the pre-09c definition of its key; the definitions' names stay exactly `key@1` (no `#2`).
- `apps/floor_planner/test/support/pre_09c_library.dart` (new): `pre09cLibraryPath`, `pre09cLibrary()` moved out of `furniture_library_test.dart` (which now imports it; no assertion changed).
- `apps/floor_planner/test/symbols/symbol_placer_test.dart:~891`: the stale comment rewritten (records and payloads have value `==`; the text snapshot is a value copy taken before the placements, since comparing the entry's own objects with themselves would hide an in-place change to a shared buffer).

First run: both tests passed before any mutant (`00:07 +2: All tests passed!`). No production code changed (none was needed).

## Commit
- `8f5f601` test(app): wall-aware placement end to end (4 files: +515 −9).

## Gates (this container, Flutter 3.47.2, CI=true, at 8f5f601's tree)
- App: `flutter test` -> `05:02 +1169: All tests passed!` (0 failures, 0 skips; the two new tests WE1, WE2 included); `flutter analyze` -> `No issues found!`; `dart format --output=none --set-exit-if-changed .` -> `Formatted 184 files (0 changed)`, exit 0.
- `flutter build web --release` -> `✓ Built build/web`, exit 0.
- Engine and render layer: unchanged by this task (`git diff --stat 2a1f8c2..HEAD -- packages/` empty); not re-run. Allocation invariant tests: `git diff --stat 904970d..HEAD` over both `test/invariants` dirs empty. `packages/jet_cad/analysis_options.yaml` modified by pub get, not staged.

## Mutants (each: cp backup, sed, run `test/symbols/wall_attach_end_to_end_test.dart`, cp back, diff exit 0 — every one printed `restored diff=0`)
| Mutant | file:line | change | red | real output excerpt |
|---|---|---|---|---|
| M-09c-c | lib/symbols/wall_attach.dart:338 | `rotation: (run.t.x, run.t.y),` -> `quarterTurns: 0,` | WE1, WE2 | `Expected: a value less than or equal to <0.00011967400990319506>  Actual: <399.99999999999886>` (line 194, expectFlush nearest); WE2 `Actual: <831.4915792601586>` |
| M-09c-b (at attach) | lib/symbols/wall_attach.dart:334 | base point `box.back` -> `box.front` | WE1, WE2 | `Actual: <2000.0000000000068>` (WE1, line 194); `Actual: <599.9999999999955>` (WE2) |
| M-09c-b (at the box) | lib/symbols/symbol_box.dart:111 | `back: maxY` -> `back: minY` | WE1, WE2 | `Actual: <2000.0000000000068>`; `Actual: <599.9999999999955>` |
| release ignores the attached transform | lib/symbols/symbol_place_tool.dart:445 | `transform: _attached?.transform` -> `transform: null` | WE1, WE2 | WE1 line 304 `Actual: [1.0, 0.0, 0.0, 1.0, 96775.0, -71450.0]`; WE2 line 477 `Actual: [-1.0, 0.0, 0.0, 1.0, 101675.0, -70850.0]` |
| leaf-equality always false | lib/symbols/symbol_placer.dart:195 | `{ if (definition.value > 0) return false;` at the top of `isLeafEqual` | WE1, WE2 | WE1 line 349 `Expected: empty Actual: ... Definition(25 "kitchen.base.600@1#2"), Definition(2A "kitchen.base.600@1#3")`; WE2 line 488 `Expected: <22> Actual: <47>` reason `bed.double reuses the pre-09c definition` |
| leaf-equality keeps geomIndex (D10's exemption dropped) | lib/symbols/symbol_placer.dart:218 | `geomIndex: want.record.geomIndex,` -> comment | WE1, WE2 | same as above: WE1 line 349, WE2 line 488 `Expected: <22> Actual: <47>` |
| M-09c-p (a style field ignored) | lib/symbols/symbol_placer.dart:218 | append `color: want.record.color,` | **survives** (`00:07 +2: All tests passed!`) | by construction: a more permissive equality cannot copy a definition that is equal; killed by Task 9's placer tests. The brief's replacement (always false) and the geomIndex variant are red above. |
| M-09c-h (extra) | lib/symbols/wall_attach.dart:307 | `neighbours[best]` -> `const <FaceNeighbour>[]` | WE1 | `Expected: a numeric value within <1e-9> of <600.000000000002>  Actual: <669.9999999999959>` |
| M-09c-j at the tool (extra) | lib/symbols/symbol_place_tool.dart:249 | `mirrored: _mirrored,` -> `mirrored: false,` | WE2 | line 477 `Expected: [ ... Actual: [` (the wardrobe's bytes) |
| M-09c-ap (extra) | lib/symbols/symbol_place_tool.dart:446 | `faces?.bands.invalidate();` removed | **survives** (`00:07 +2: All tests passed!`) | consistent with R-C7-3: in a pumped app the change stream delivers before the next pointer event; killed at the tool level only. |
| asset not regenerated | — | — | n/a | no catalog change in this task |

## Proposed rulings
- **R-C11a-1:** WE1's L is the 30° wall itself (A at 30°, B at 120°) rather than a separate 30° wall plus an L: the bed goes on A's outside face, the units on A's inside face from the drawn corner (both faces of one wall, one scene). Cost if wrong: a third wall in the fixture.
- **R-C11a-2:** "within 1e-9 relative" for flushness is `1e-9 · |run.a|` (~1.2e-4 mm at 1.2e5); the abutment (step 2) is 1e-9 absolute along t, as the brief states; it holds (no relative scale needed). Cost if wrong: a tolerance constant.
- **R-C11a-3:** step 5's plan is built with `newDocument` + `installParametric` + `placeSymbol` of the pre-09c entries and encoded by today's codec (no engine schema change since `4d6b78f` in 09c-1: Task 1 touched commands and the registry only). "The symbols' bytes unchanged" is asserted as the whole file byte-identical after open + save (stronger than per-symbol). The old plan has four instances, one per key (a duplicate placement made the leaf-equality mutant fail first in the set-up, muddying the red). Cost if wrong: a fixture file saved at `4d6b78f` would be needed; the test would read it instead of building it.

## Found, not fixed
- Nothing new. M-09c-ap's shell-level survival re-confirmed (already R-C7-3).

## For the reviewer
- The oracle independence: transforms are compared with `attachToWall` itself (the brief's ask), so a mutant inside `attachToWall` keeps the bytes equal; such mutants are killed by `expectFlush` (drawn vertices from the document's entities, not `SymbolBox`) and the abutment checks. Check that `drawnVertices` really reads only lines and polylines (the bed's and units' outlines are closed polylines; the units' knob circle is skipped).
- WE2's free placements assert `ghostAttachment == null` after release (the last recompute), not at hover.
- `furniture_library_test.dart`: only the helper moved; its group still uses `pre09cLibrary()` via the import.

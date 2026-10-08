# Task 3 review — groups follow the focus (Z14), `FloorPlanTable.visible` (Z24), the demo's zones (Z22), and the Task 2 review's tests

**Reviewer:** independent. **Target:** `3531e7d` (parent `fdc8918`), branch `claude/exciting-pasteur-9m22jv`.
**Clones:**
- `/tmp/zone-t3-review/repo` ran the gates and the web build.
- `/tmp/zone-t3-review/mut` ran the mutants.

Nothing was committed. Every mutated file was restored from a scratch copy and checked with `cmp`. Every restore printed `cmp=0` (24 in the main run, 7 in the two runs that checked the proposed tests), and `git status --short` in the mutant clone was empty at the end.

## Verdict

**Approve.** There is no blocking or important finding.
- Z14, Z24 and Z22 conform to spec rev 2 and to the plan's Task 3.
- The Task 2 review's tests landed:
  - RV1–RV3 verbatim;
  - TG-Z4 for O3;
  - FP7 for O13.
- I re-ran 15 assigned or review mutants, and all were red.
- Of my 9 mutants:
  - 5 were red;
  - 3 survive and point at test gaps (R-1 to R-3). I wrote and verified a killer for R-1 and R-3;
  - 1 is equivalent (N9).
- Every gate is green, and the standing comparison is exact everywhere. `flutter build web` succeeds after `rm -rf build`.

The report checks out against the code:
- its file:line references (spot-checked about 25);
- its test names and line numbers;
- its claim that one test line was removed: `git diff -U0 fdc8918 3531e7d -- '*/test/*'` shows exactly one removed line, the demo's `show` list.

One small inaccuracy: it says "Nothing is committed", but the work is now commit `3531e7d`. The report was written before the commit.

## 1. Spec conformance

### Z14 — groups follow the focus

All paths are under `packages/jet_cad_floor_plan/lib/src/`.

| Requirement | Where | Result |
|---|---|---|
| Both layers take `tableFocus` | `service/table_group_painter.dart:230,253`; `host/service_view.dart:216` | Conforms |
| The focus's identity joins the rebuild key | `table_group_painter.dart:409-420` (`!identical(_focusBuilt, focus)`) | Conforms |
| The focus joins `_groupRepaint` | `service_view.dart:202-203` | Conforms |
| No focused **visible** member → faded | `table_group_painter.dart:371`: `focus != null && !members.any(...)` | Conforms (see below) |
| One prebuilt faded `Paint`, alpha × 0.4 | `:262-266`, `:299-300` (`gripMove.a * (1 - kTableFocusVeilAlpha)`) | Conforms |
| The frame at the normal width | `:438` (both paints get the width) | Conforms |
| The chip as today, then its `RRect` again in the veil's paint | `:460-466`; the veil paint is `Color(paper).withValues(alpha: 0.6)` at `:302`, identical to `table_focus_painter.dart:150` | Conforms |
| Straddling groups and the lead rule unchanged | `table_status_painter.dart` untouched; a straddling group's `faded` is false | Conforms |
| Selection outlines above the veil | `service_view.dart` overlay order unchanged; pinned by RV3 | Conforms |

- **The `members` in the fade test** are `lookup.visibleMembers(id)`, built over `picker.candidates`. That is Z0's candidates: visible layer, invertible, finite. A hidden member therefore never counts as focused (TG-Z1: GA = {12, 20, 9} with 9 hidden, focus {3, 9}, is faded).
- **Locked tables** are candidates and so visible members, which is correct. Nothing pins this: R-1.

### Z24 — `FloorPlanTable.visible`

| Requirement | Where | Result |
|---|---|---|
| A named `bool visible = true` | `host/floor_plan_types.dart:22-25,39` | Conforms |
| In `==`, `hashCode` and `toString` | `:47`, `:50`, `:53-54` | Conforms |
| False on a hidden layer | `host/floor_plan_controller.dart:827-846` | Conforms |
| `tables` keeps hidden tables; `numberingWarnings` unchanged | `:830` iterates the whole survey; `numberingWarnings` (`:853`) untouched | Conforms (CV1, CV2) |

### Z22 — the demo

| Requirement | Where | Result |
|---|---|---|
| Salon A = 1–5, B = 6–7, C = 8–11, untranslated | `apps/restaurant_demo/lib/main.dart:109-115` | Conforms. The Salon's tables are 1–11 (`demo_test.dart:511-512`). |
| Only an area with zones; none for the Teras | `main.dart:732` (`if (a.zones.isNotEmpty)`); `kDemoZones` has no Teras entry | Conforms |
| `SegmentedButton` (All, A, B, C) and the switch | `main.dart:733-760` | Conforms |
| A zone calls `showZone`; All calls `showAllZones`; the bodies are Z21's | `main.dart:533-562` | Conforms. The bodies are verbatim on `a.controller`. |
| Kept per `Area` | `main.dart:129-134` (`zone` and `fadeOthers` are instance fields) | Conforms. Unpinned: R-3. |
| Three strings in en, de and tr | `demo_strings.dart:32-36,117-123,248-254,385-391` | Conforms, matching the spec's words exactly |

### The report's deviations

| Deviation | Judgement |
|---|---|
| **The demo panel placement** (after the numbering warnings, above the log) | **Accepted.** Neither Z22 nor the plan fixes a place. The first place pushed `groups` out of the lazily built `ListView` at the tests' 1000 px height and broke D16/17/18/23. Moving the section rather than editing those tests is what I-6 asks for. **For Task 4's web smoke check:** the controls sit below the fold and need a scroll. |
| **The `show` list line** (`demo_test.dart:19-25` gains `FloorPlanController`) | **Accepted.** It is one import line and widens a combinator. No assertion or fixture changed. DZ1's `boxOnScreen` needs the type. It is recorded in the report as I-6 requires. |
| **The group painter counts 3 allocations at construction** (`table_group_painter.dart:233`) | **Accepted.** Z14 itself asks for "one prebuilt faded `Paint`". Both paints are `late final` and so are actually created at the first `_rebuild`, which is accounting only. No test pins the absolute count. The per-frame bar holds: TG-Z2 pins identical objects and steady `debugAllocations` over 5 camera frames, and my N7 (a `Paint` per frame for the chip veil) is red there. |

## 2. `FloorPlanTable.visible`

- **Public API?** Yes. The barrel `lib/jet_cad_floor_plan.dart:13-24` shows `FloorPlanTable`, and B3 goes through the barrel.
- **A table on a hidden layer:**
  - `_onVisibleLayer` reads the instance's own layer, `d.tables.layers[node.layer]?.visible ?? true` (`floor_plan_controller.dart:842-846`). This is the same rule as `TablePicker.candidatesOf` (`table_picker.dart:241-242`) and the renderer's `QueryFilter._visibleLayer` (`jet_cad_2d/.../query_filter.dart:201-202`: a missing layer counts as visible).
  - It is read at the call, not cached with the survey. A layer toggle (a command) moves `stateId` and `revision`, and the next call reads it.
  - CV1 pins show, then undo. My N1 (a per-instance cache) is red ×3.
- **A table on a visible layer that is nested:** not a table. `TableSurvey.of` (`table_index.dart:83-86`) lists only root instances; nested servable instances go to `nested` (T1). So `tables` never lists one, and the question of its `visible` does not arise. The comment at `:839-841` says this.
- **`tables` is O(n) per call:**
  - The survey is cached by state id (`:811-821`).
  - Each table then costs one `DraftTree[]` and one `LayerTable[]` lookup, both hash-map reads (`tree.dart:67`, `tables.dart:97`).
- **Frame path:**
  - No painter calls `controller.tables`. Its only in-tree callers are the demo's `build` (`main.dart:716-719`) and `_randomStatuses` (`:390`), which run at widget-build or event rate.
  - Both allocation invariants are untouched (`git diff --stat` on `jet_cad_2d` and `jet_cad_2d_flutter` is empty).
- **Host-facing change:**
  - `==` and `hashCode` now differ between a hidden table and an otherwise equal shown one, and `toString` gains `, visible: …`.
  - In this repo nothing compares `tables` lists or parses `toString`. The demo uses `tables` for the text and the random statuses. The probe does not read `tables` yet; Task 4 adds `unplacedTables`. C1 (`controller_test.dart:85-90`) passes unedited, because all its tables are on visible layers.
  - A host that diffs successive `tables` lists will now see a change when a layer is hidden. That is the point of Z24.
  - **For Task 4's CHANGELOG:** state the `toString` format change too.
- **The doc wording overclaims slightly:** R-4.

## 3. Groups

- **A group with no focused visible member:**
  - Faded frame: TG-Z1 checks the paint identity, RGB, alpha 0.4 and width. TG-Z3 checks it through the real view.
  - Veiled chip: TG-Z1 checks the `RRect` order and colour, the veil after the label, and the pixel `veilOver(paper, gripMove)`. TG-Z3 checks it on screen.
- **A straddling group is unchanged:**
  - TG-Z1's GB has the normal paint and the chip pixel is exactly `gripMove`.
  - TG-Z4: G7's chip over the faded table 20 is unveiled, while 20 beside it is veiled. This kills O3 (115 > 1 per channel).
- **Repaint on a focus change:** TG-Z3 counts exactly one repaint per `setTableFocus` for both painters (M-Z38b red).
- **The rebuild key:** TG-Z2 shows that a focus set after the first paint rebuilds once and switches the paint (M-Z38a red).
- **Allocation:** TG-Z2 pins the same objects and steady `debugAllocations` and `debugRebuilds` over 5 pans (N7 red). The faded paint is reused: no per-frame `Paint`, `Path` or buffer.
- **Gap:** a group whose only focused member is on a locked layer (R-1).

## 4. Demo

- **Zones A/B/C on the Salon:**
  - zone B frames all four corners of 6 and 7 on the canvas, and none of table 1's;
  - the switch focuses {6, 7};
  - All clears the focus and equals a fresh `fitToView()` from a non-identity camera;
  - C with the switch on focuses {8, 9, 10, 11}.
- **State per area:** implemented. Only the Salon's own state is checked after a round trip, so a shared state survives (R-3).
- **Strings:** en, de and tr are pinned by DZ2. A de/tr swap (N5) is red.
- **Existing demo tests:** unedited apart from the one import line (verified above). The demo has 39 tests: the 37 existing ones plus DZ1 and DZ2.
- **`flutter build web` after `rm -rf build`:** exit 0, `✓ Built build/web` (output below).

## Findings

**R-1 — minor (test gap) — `packages/jet_cad_floor_plan/lib/src/service/table_group_painter.dart:371`: a focused member on a locked layer is not pinned as un-fading its group.**
- **Mutant N3:** the fade counts only selectable members (`m.selectable && focus.contains(m.number)`). It survives all 14 tests of `table_group_painter_test` and all 8 of `table_groups_look_test`. The group fixtures have no locked table.
- **The lookup offers the trap:** `TableGroupLookup` has `selectableMembers` right beside `visibleMembers`.
- **Scenario:**
  1. Table 7 is on a locked layer, which Z12 says is shown and fades like any other.
  2. A host focuses "My tables" = {7}.
  3. Group {7, 3} is wrongly drawn faded, its chip veiled, although its focused member shows unveiled.
- **Fix:** land this test in `table_group_painter_test.dart`, inside `main()` after TG-Z2. It is green at `3531e7d` and red under N3 (`Expected: <1>`, `Actual: <0.3999999761581421>`):

```dart
  test(
      'RX1 a group whose only focused member is on a locked layer draws as '
      'before (Z14: a locked table is a visible member)', () {
    final doc = groupedPlan();
    final locked = addLayer(doc, 'Locked', visible: true);
    doc.commands.execute(
        SetLayerCommand(doc.tables.layers[locked]!.copyWith(locked: true)));
    doc.commands.execute(SetInstanceLayerCommand(
        TableSurvey.of(doc).withNumber('7').single.instance, locked));
    final camera = ValueNotifier(cameraAt(0.06));
    final groups = ValueNotifier(zoneGroups());
    final focus = ValueNotifier<Set<String>?>({'7'});
    final paper = ValueNotifier<int>(0xFFFFFFFF);
    final frames = focusedPainter(
        TableGroupLayer.frames, doc, camera, groups, focus, paper);
    final chips = focusedPainter(
        TableGroupLayer.chips, doc, camera, groups, focus, paper);
    final spy = frame(frames);
    expect(spy.paths, hasLength(2), reason: 'premise: GA and GB framed');
    expect(spy.paints[0].color.a, closeTo(0.4, 1e-6), reason: 'GA faded');
    expect(spy.paints[1].color.a, 1, reason: 'GB: 7 is focused, locked');
    expect(frame(chips).rrects, hasLength(3), reason: 'GA veiled, GB not');
  });
```

**R-2 — nit (test gap) — `packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart:845`: "a layer missing from the table counts as shown" is unpinned.**
- **Mutant N2** (`?? true` changed to `?? false`) survives all 34 controller tests and the barrel tests.
- **The case is reachable:** `jet_cad_2d`'s `query_filter.dart:196-202` says a missing layer is `validate()`'s problem and draws it as visible. So a hand-edited file can reach this case. Under the mutant, the probe's `unplacedTables` would count a drawn table as unplaced.
- **Fix:** add a CV clause where an instance names an absent layer handle, and expect `visible` true. Or accept the gap, since it only matters for a corrupt file, and record it.

**R-3 — nit (test gap) — `apps/restaurant_demo/lib/main.dart:129-134`: "kept per `Area`" is unpinned.**
- **Mutant N4** (`zone` and `fadeOthers` backed by statics shared by every area) survives DZ1 and DZ2. DZ1 checks only that the Salon's own state survives a round trip through the Teras, which a shared state also passes.
- **Fix:** two lines in DZ1, after `expect(demo.area.fadeOthers, isTrue);`. They are green at `3531e7d` and red under N4 (`Expected: null`, `Actual: 'B'`):

```dart
    expect(demo.areas[1].zone, isNull, reason: 'the Teras keeps its own');
    expect(demo.areas[1].fadeOthers, isFalse);
```

**R-4 — nit (doc) — `packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart:36-38`: "Whether the plan draws it" claims more than is computed.**
- `visible` is the layer rule only, as Z24 specifies. A table that Z0 excludes for another reason reads `visible: true`, yet it is never framed, veiled or picked. Two examples: a singular transform, or a non-finite corner from a hand-edited file.
- **Fix:** word it as "Whether its layer is shown: false for a table on a hidden layer (Z24)…". Task 4's guide paragraph should say the same.

**R-5 — nit (demo UX) — `apps/restaurant_demo/lib/main.dart:547-562` and `:730-760`: the zone toggle does not follow the camera or the mode.**
- After *Fit*, or a pan, the toggle still reads "B" while the page shows everything.
- In the design mode the switch can be on with no visible effect, which is correct per Z11 but unexplained.
- **Fix:** optional; this is a demo. *Fit* could reset `a.zone` to null.

**R-6 — nit — test names.** The demo's `DZ1` and `DZ2` share their prefix with `packages/jet_cad_floor_plan/test/dimension_fuzz_test.dart:302` (`DZ1 300 seeded edits…`). They are in different packages, so nothing breaks. Only a `--name DZ` filter in a cross-package script would be ambiguous. No action needed.

## Mutants

**Method:**
1. `/tmp/zone-t3-review/scripts/{mut.py,defs.py,proposed.py}` apply each mutant by exact replacement, asserting that each anchor occurs exactly once.
2. They run the killers with `flutter test <file> --name <re> --file-reporter json:`.
3. They classify each result from the JSON. A load or compile failure would read `LOAD/COMPILE ERROR`; none did.
4. They restore each file from a snapshot and check it with `cmp`.

Every red below is an assertion failure with the expectation shown. Before any mutant, every killer file was green on the unmutated clone: TG 14/14, look 8/8, controller 34/34, barrel 3/3, view RV/VF 11/11, FP 7/7, demo DZ 2/2.

### Assigned and review mutants, re-run (15)

| Mutant | Applied | Killer | Result (first failing expectation) |
|---|---|---|---|
| M-Z24a | a faded frame stroked with the normal paint | TG-Z1; TG-Z3 | red (`:926` `identical(faded, normal)` true); red (alpha differs by 0.6) |
| M-Z24c | the chip not veiled | TG-Z1; TG-Z3 | red (rrects length 2, not 3); red (1, not 2) |
| M-Z24e | the fade read on the declared members (`group.members`, hidden 9 included) | TG-Z1 | red |
| M-Z24f | a straddling group faded (`every` for `any`) | TG-Z1 | red |
| M-Z38a | the focus out of the rebuild key | TG-Z2; TG-Z3 | red ("GA now faded", `:1026`); red |
| M-Z38b | `tableFocus` out of `_groupRepaint` | TG-Z3 | red (repaint map missing `table-group-layer`) |
| M-Z42a | `visible: true` hard-coded | CV1–CV3 | red ×3 (`['5']` expected, `[]`) |
| M-Z29a | a zone shows all zones | DZ1 | red ("table 1 is outside": its corners are on the canvas) |
| M-Z29c | "Fade the others" ignored | DZ1 | red (`{6, 7}` expected, null) |
| M-Z29d | All keeps the focus | DZ1 | red (null expected, `{6, 7}`) |
| O1 | `_changed` dropped from the veil's merge | RV1 | red |
| O2 | `_paper` dropped from the veil's merge | RV2 | red |
| O3 | the overlay `Stack` swapped (chips, then veil) | TG-Z4; VF + RV | red (`<115>`, ≤ 1 expected); VF and RV survive, as the Task 2 review found |
| O4 | the veil moved to a `foregroundPainter` over `PlannerView` | RV3 | red (`Expected: <0>`, `Actual: <709>`) |
| O13 | the focused quads added unreversed (`addPolygon` in the transform's own order) | FP1–FP7 | red: FP7 fails, FP1–FP6 pass, as the Task 2 review predicted |

### My own (9, plus 2 re-runs against the proposed tests)

| # | Aimed at | Applied | Run against | Result |
|---|---|---|---|---|
| N1 | `visible` not following a layer toggle | a per-instance cache of `_onVisibleLayer`, never invalidated | CV1–CV3 | red ×3 (CV1: `Expected: empty`, `Actual: ['5']` after the layer is shown) |
| N2 | a missing layer | `?? false` | all of `controller_test`, `barrel_test` | **survives** → R-2 |
| N3 | the group fade with a locked member | fade over selectable members only | all of `table_group_painter_test`, `table_groups_look_test` | **survives** → R-1; **red** under the proposed RX1 |
| N4 | demo zone state shared between areas | `zone`/`fadeOthers` backed by statics | DZ1, DZ2 | **survives** → R-3; **red** with the proposed two lines (`'B'` for the Teras) |
| N5 | the de/tr strings swapped | `fadeOthers` swapped between `_De` and `_Tr` | DZ2 | red (no "Andere abblenden" in German) |
| N6 | the faded frame's width | `_faded.strokeWidth` never set (hairline) | TG-Z1–Z4 | red in TG-Z1 (`[0.0, 33.33]`); TG-Z3/Z4 do not check width |
| N7 | per-frame allocation | a `Paint` per frame for the chip veil | TG-Z2 | red ("painter 1 item 4" not identical) |
| N8 | the switch not re-applied to the zone shown | `_setFadeOthers` stores but does not call `showZone` | DZ1 | red |
| N9 | `shouldRepaint` | `tableFocus` dropped from `shouldRepaint` | both group test files | survives. **Equivalent:** `ServiceView`'s painters are `late final`, so the old and new delegates are the same object. |

## Gates

Each run is from `/tmp/zone-t3-review/repo` at `3531e7d`:
1. `flutter pub get`.
2. `<runner> test --file-reporter json:<f>`; the engine uses `dart test`.
3. From the repo root, `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <f>`.
4. Analyze: `flutter analyze`, or `dart analyze --fatal-infos` for the engine.
5. `dart format --output=none --set-exit-if-changed .`

The planner gate ran concurrently with the mutant clone's tests, hence the longer time. These are the outputs as printed (last lines):

```
=== packages/jet_cad_floor_plan
test runner exit 0
05:27 +1435: All tests passed!
packages/jet_cad_floor_plan: 1435 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 9.6s)
analyze exit 0
Formatted 242 files (0 changed) in 1.02 seconds.
format exit 0
=== apps/restaurant_demo
test runner exit 0
00:25 +39: All tests passed!
apps/restaurant_demo: 39 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 5.3s)
analyze exit 0
Formatted 4 files (0 changed) in 0.05 seconds.
format exit 0
=== apps/floor_planner
test runner exit 0
02:39 +212: All tests passed!
apps/floor_planner: 212 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 4.5s)
analyze exit 0
Formatted 47 files (0 changed) in 0.16 seconds.
format exit 0
=== packages/jet_cad_2d
test runner exit 1
For example, 'dart test --chain-stack-traces'.
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found!
analyze exit 0
Formatted 169 files (0 changed) in 0.47 seconds.
format exit 0
=== packages/jet_cad_2d_flutter
test runner exit 1
  ... and 3 more
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 6.3s)
analyze exit 0
Formatted 221 files (0 changed) in 0.68 seconds.
format exit 0
```

The engine and the renderer exit 1 on their standing failures only (engine 2, render 7 plus 1 skip); the comparison is exact. My counts match the report's: 1435, 39, 212, 1255 and 1363.

**Web build** (`apps/restaurant_demo`, `rm -rf build && flutter build web`):

```
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 9876 bytes (99.4% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                            171.1s
✓ Built build/web
build exit 0
```

## For Task 4

- **CHANGELOG:** mention the `FloorPlanTable.toString` format change alongside `visible`.
- **Host guide:** word `visible` as the layer rule (R-4).
- **Web smoke check:** the demo's zone controls sit below the fold of the side panel. Scroll to them.

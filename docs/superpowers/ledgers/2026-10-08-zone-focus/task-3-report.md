# Task 3 report — groups, `FloorPlanTable.visible` and the demo (Z14, Z24, Z22)

This is the implementer's report. The work is on branch `claude/exciting-pasteur-9m22jv`, base `fdc8918` (Tasks 1 and 2). Nothing is committed: every change is in the working tree.

The report also covers the tests the coordinator forwarded from Task 2's review (R-1 to R-4, R-6 and O3); see "Task 2 review tests".

## What was built

### Z14: the group painter follows the focus

All paths are under `packages/jet_cad_floor_plan/`.

`lib/src/service/table_group_painter.dart`:
- `:14` imports `kTableFocusVeilAlpha` from the veil painter.
- `:161-169` `_Group.faded`: no visible member of the group is in a non-null focus.
- `:208-232` the class doc. The constructor takes an optional `tableFocus` (`ValueListenable<Set<String>?>?`) and counts 3 allocations: two paints and the matrix.
- `:253` the `tableFocus` field.
- `:260-266` `_faded`, the second prebuilt `Paint`:
  - in the frames layer it is a stroke;
  - in the chips layer it is the veil's fill.
- `:272` `_focusBuilt`, the focus identity in the rebuild key.
- `:296-302` `_rebuild(focus)` sets the faded paint's colour:
  - frames: `gripMove` at alpha × (1 − `kTableFocusVeilAlpha`), which is 0.4;
  - chips: the paper's RGB at `kTableFocusVeilAlpha`. The paper's own alpha is replaced, as in the veil.
- The `_Group` built in `_rebuild` has `faded = focus != null && !members.any((m) => focus.contains(m.number))`. `members` is the group's **visible** members.
- `:409-421` the focus's identity joins the rebuild key.
- `:438-444` the frames: both paints get the frame's stroke width, and a faded group is stroked with `_faded`.
- `:458-466` the chips: the chip as before (`RRect`, then the label), then, for a faded group, the same `RRect` again with the veil's paint.
- `:477` `shouldRepaint` compares `tableFocus`.

Straddling groups and the lead rule are unchanged. A null focus draws exactly as before.

`lib/src/host/service_view.dart`:
- `:198-203` `tableFocus` joins `_groupRepaint`.
- `:216` both group painters get `tableFocus: _c.tableFocus`.

### Z24: `FloorPlanTable.visible`

- `lib/src/host/floor_plan_types.dart:20-55`:
  - `{…, this.visible = true}` is a named parameter;
  - the field `:39` is documented;
  - it is part of `==` `:47`, `hashCode` `:50` and `toString` `:53-54`, which reads `FloorPlanTable(5, 4, k, visible: false)`.
- `lib/src/host/floor_plan_controller.dart:823-846`, the `tables` getter:
  - It sets `visible` from the table's own layer, read at the call, so a layer that is shown or hidden reads correctly at the next `revision`.
  - `_onVisibleLayer` follows the picker's rule: a layer missing from the table counts as shown.
  - Hidden tables stay listed, and `numberingWarnings` is unchanged.

### Z22: the demo's zones

`apps/restaurant_demo/lib/main.dart`:
- `:109` `kDemoZones`: the Salon's zones A = 1–5, B = 6–7, C = 8–11. They are host data, not translated.
- `:120-134` `Area` gains `zones`, `zone` (null means all) and `fadeOthers`. The zone and the switch are kept per area.
- `:174` the zones are wired into `Area`.
- `:533-544` `showZone` and `showAllZones`: the spec's Z21 bodies, on the area's controller.
- `:547-562` `_setZone` and `_setFadeOthers`:
  - a zone calls `showZone`, and All calls `showAllZones`;
  - flipping the switch while a zone is shown calls `showZone` again.
- `:644` the side panel's `ListView` is keyed `side-panel`, so tests can scroll it.
- `:730-760` the zone `SegmentedButton` (`zone-toggle`: `zone-all` for All, then `zone-A`, `zone-B`, `zone-C`) and the `fade-others` switch. They appear only for an area with zones, after the numbering warnings and above the log.

`apps/restaurant_demo/lib/demo_strings.dart`:
- `:32-36` the three abstract strings;
- en `:117-123`: Zones / All / Fade the others;
- de `:248-254`: Bereiche / Alle / Andere abblenden;
- tr `:385-391`: Bölgeler / Tümü / Diğerlerini soldur.

## Tests

| Test | File:line | What it checks |
|---|---|---|
| TG-Z1 | `test/service/table_group_painter_test.dart:902` | With focus {3, 9}, groups GA = {12, 20, 9} (9 hidden) and GB = {7, 3}. **GA:** stroked with the faded paint (gripMove's RGB, alpha 0.4, as wide as the normal frame). Its chips draw RRect, label, then the same RRect at `0x99FFFFFF`, the veil after the label. A pixel in its chip's padding is `veilOver(paper, gripMove)`. **GB:** normal paint, and its chip's pixel is gripMove exactly. **Focus `{}`:** both faded. **Null focus:** neither. **Paper `0x801F3A5F`:** the veil is `0x991F3A5F`, and the faded frame is that set's gripMove at 0.4. |
| TG-Z2 | same file `:1006` | A focus set after the first paint switches GA to the faded paint and veils its chip in one rebuild. Five camera frames then pass the same objects, with `debugAllocations` and `debugRebuilds` steady. |
| TG-Z3 | `test/host/table_groups_look_test.dart:414` | Through the real view, the frame and chip painters each repaint exactly once per `setTableFocus`. Focused on 20, G7's chip pixel on screen is the veil over gripMove and its frame paint has alpha 0.4. Focused on 3, the pixel is gripMove and the alpha is 1. |
| TG-Z4 | same file `:466` | Review O3; see below. |
| CV1 | `test/host/controller_test.dart:817` | The hidden 5 has `visible` false. Every other table, the locked L included, is true, in both modes. All 10 tables are listed. Showing its layer by command moves `revision` and flips it; Undo flips it back. |
| CV2 | same file `:864` | One 2 and the unnumbered table are moved to a layer `Back`, which is then hidden. `numberingWarnings` and the listed (number, seats) are unchanged. Only those two flip to not visible; the first 2 stays shown. |
| CV3 | same file `:899` | The spec's `unplacedTables` body, verbatim, gives `{5, 99}`; with the Hidden layer shown it gives `{99}`. |
| B3 | `test/host/barrel_test.dart:94` | Through the barrel: `visible` defaults to true and is part of `==`, `hashCode` and `toString`. |
| DZ1 | `apps/restaurant_demo/test/demo_test.dart:1273` | The sample plans, in Service. **Zone B:** the camera moves; 6's and 7's box corners are all inside the canvas and table 1's are all outside; the focus is null. **Fade on:** the focus is {6, 7}. **Teras:** with its panel scrolled to the end, there is no zone toggle and no switch. **Back in the Salon:** B and the switch are kept, and the focus is {6, 7}. **All:** the focus is null, and the camera equals a fresh `fitToView()` from another camera, with 1, 6 and 7 all on screen. **Zone C with fade on:** the focus is {8, 9, 10, 11}. |
| DZ2 | same file `:1359` | The three strings in en, de and tr. |

Existing tests that pin `FloorPlanTable`:
- `controller_test.dart:85-90` (C1) compares `c.tables` with `const FloorPlanTable(...)` without `visible`. Its tables are all on visible layers, so it passes **unedited**.
- `barrel_test.dart:81` compares with `const <FloorPlanTable>[]`. It passes unedited.
- No test pins `FloorPlanTable.toString`.

No existing test had to change.

## Mutants

The method: a scratch script applies each mutant by exact replacement, with each anchor occurring exactly once. It runs each killer with `--plain-name` and a JSON reporter, then restores each file from a snapshot taken before any mutation and checks it with `cmp`. Every restore printed `cmp=0`, and every source file was identical to its snapshot at the end. Every red was a `TestFailure`, never a compile error. The log is in the scratchpad (`t3/mutants.log`, `t3/mutants2.log`).

| Mutant | Applied | Killer | Result |
|---|---|---|---|
| M-Z24a | a faded group's frame stroked with the normal paint | TG-Z1, TG-Z3 | red, red |
| M-Z24b | the faded frame at alpha × 0.6 | TG-Z1 | red |
| M-Z24c | the chip not veiled | TG-Z1, TG-Z3 | red, red |
| M-Z24d | the veil drawn before the label | TG-Z1 | red |
| M-Z24e | the focus read on every declared member, hidden 9 included | TG-Z1 | red |
| M-Z24f | a straddling group faded (`every` instead of `any`) | TG-Z1 | red |
| M-Z24g | the chip's veil takes the paper's alpha | TG-Z1 | red |
| M-Z24h | a null focus read as the empty focus | TG-Z1 | red |
| M-Z38a | the focus out of the group painter's rebuild key | TG-Z2, TG-Z3 | red, red |
| M-Z38b | `tableFocus` out of `_groupRepaint` | TG-Z3 | red (`{}` repaints) |
| M-Z38c | `ServiceView` passes no `tableFocus` to the group painters | TG-Z3 | red |
| M-Z42a | `visible` hard-coded true | CV1, CV2, CV3 | red ×3 |
| M-Z42b | `visible` read from layer 0 | CV1, CV2, CV3 | red ×3 |
| M-Z42c | `visible` read from the label ATTRIB's layer | CV1, CV2, CV3 | red ×3 |
| M-Z42d | hidden tables dropped from `tables` | CV1, CV2 | red, red |
| M-Z42e | `numberingWarnings` skip hidden tables | CV2 | red |
| extra | `visible` dropped from `==` / `hashCode` / `toString` | B3 | red ×3 |
| M-Z29a | a zone shows all zones | DZ1 | red |
| M-Z29b | a zone frames the first zone | DZ1 | red |
| M-Z29c | "Fade the others" ignored | DZ1 | red |
| M-Z29d | All keeps the focus | DZ1 | red |
| M-Z29e | All does not fit the page | DZ1 | red |
| M-Z29f | the zones shown for an area without zones (the Teras) | DZ1 | red |
| M-Z29g | the zone and the switch kept app-wide, not per area | DZ1 | red |

All four of Task 3's mutants are red: M-Z24, M-Z29, M-Z38 and M-Z42. Each was run as several variants, every one red, and none survived.

M-Z29a–g were run twice: once on the first demo layout, and again after the zone section moved (see Deviations). They were red both times.

## Task 2 review tests

| Item | Test | Mutant | Result |
|---|---|---|---|
| R-1 | **RV1** `test/host/view_test.dart:1641`, landed as the review quotes it | O1, `_changed` dropped from the veil's merge | red |
| R-2 | **RV2** `:1668`, as quoted | O2, `_paper` dropped | red |
| R-3 | **RV3** `:1691`, as quoted | O4, the veil above the selection outlines (`foregroundPainter` over the canvas; the veil removed from the overlay `Stack`) | red, `Expected: <0>, Actual: <709>` |
| O3 | **TG-Z4** `test/host/table_groups_look_test.dart:466` | O3, the overlay `Stack` swapped (chips, then veil) | red (115 against ≤ 1 per channel) |
| R-4 | **FP7** `test/service/table_focus_painter_test.dart:368` | O13, the focused quads added unreversed | red |
| R-6 | none; equivalent | O10, the degenerate-camera guard removed | survives (FP1–FP7, VF1–VF7, RV1–RV3), as expected |

- **The names:** RV1–RV3 do not collide with any existing name, so they were landed under their own.
- **TG-Z4 (O3):**
  - A chip never covers a member of its own group (fixes X3). So the faded table under the straddling group's chip is the non-member 20, whose chair line runs through G7's chip in the look fixture.
  - Focused on 3, G7 straddles the focus and 20 is faded. A pixel 4 rows above 20's chair line is checked first: it lies inside the chip and inside 20's quad (premises).
  - That pixel is gripMove, unveiled.
  - A pixel of 20 beside the chip is the veil over the unfocused shot (premise).
- **FP7 (R-4):** F and G (mirrored) do not overlap H in the cluster, so a region F ∩ G ∩ H has no pixels. FP7 instead places a faded table J centred on the centroid of F ∩ G, sampled every 10 mm (more than 1,000 samples). It checks that F ∩ G ∩ J (over 200 px) is clear, and that J outside F and G (over 200 px) is veiled.
- **R-6, equivalent:**
  - `ViewportTransform`'s constructor calls `worldToScreenMatrix.invert()`. That throws `SingularTransformError` unless `a*d - b*c` is finite and non-zero (`transform2.dart:110-111`). The coefficients are final.
  - The guard computes `scale = sqrt(|a*d - b*c|)` from the same expression, so for any constructible camera `scale` is finite and positive, and the guard never fires.
  - A first FP8 tried a zero-scale camera, and constructing it threw `SingularTransformError`. That confirms the guard is unreachable, so FP8 was dropped.
  - The guard is harmless defensive code.

## Deviations and notes

- **The zone section's place in the demo.** At first it sat under the Fit button. That pushed the `groups` text out of the side `ListView`'s built range at the tests' 1000 px height, and the existing D16, D17, D18 and D23 failed (`find.byKey('groups')`: no element). Existing tests stay unedited, so the zone section now sits after the numbering warnings, above the log. Those four tests pass unedited. DZ1 scrolls the panel (keyed `side-panel`) to reach the controls. The M-Z29 mutants were re-run on this layout, all red.
- **`showZone(Area a, …)`.** The demo's `showZone` and `showAllZones` take the area: the demo has one controller per area, while the probe has a single `controller` field. The bodies are the spec's, on `final controller = a.controller`.
- **The parameter name `tableFocus`** (the plan's wording). The veil painter calls the same parameter `focus`.
- **The faded `Paint` is built in the constructor**, so construction counts 3 allocations, not 2. No test pins the absolute count. TG-L9 and TG-Z2 pin steadiness per frame.
- **Existing test files changed outside their own new tests:**
  - `demo_test.dart`: the `show` list of the `jet_cad_floor_plan.dart` import gains `FloorPlanController`. It is one rewritten import line; no assertion changed.
  - Otherwise there are new import lines only:
    - `table_group_painter_test.dart`: `kTableFocusVeilAlpha`, and `zone_fixture` `show rgbDistance, veilOver`;
    - `table_groups_look_test.dart`: `kTableFocusVeilAlpha`, and `zone_fixture` `show TestQuad, veilOver, zoneSymbolBoxes`.
  - `git diff -U0 -- '*/test/*'` shows exactly one removed line, that `show` list.
- **The paint's alpha is float32.** TG-Z1 and TG-Z2 compare it within 1e-6.
- **The demo's web build** leaves `apps/restaurant_demo/build/`, which is git-ignored.
- **A stray background wait loop of mine** (`pgrep -f mutants.py`, which matched its own command line) hit its time limit and was stopped. It did nothing else; every mutant run had completed before it.

## Gates

All gates ran after every restore, on the final tree. Each package ran `<runner> test --file-reporter json:<tmp>/<pkg>.json`, then from the repo root `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <json>`, then analyze and format. The engine ran `dart test`, then `dart analyze --fatal-infos`. These are the outputs as printed:

```
=== packages/jet_cad_floor_plan
test runner exit 0
03:35 +1435: All tests passed!
packages/jet_cad_floor_plan: 1435 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 242 files (0 changed) in 0.96 seconds.
format exit 0
=== apps/floor_planner
test runner exit 0
01:21 +212: All tests passed!
apps/floor_planner: 212 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.5s)
analyze exit 0
Formatted 47 files (0 changed) in 0.15 seconds.
format exit 0
=== apps/restaurant_demo
test runner exit 0
00:22 +39: All tests passed!
apps/restaurant_demo: 39 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.4s)
analyze exit 0
Formatted 4 files (0 changed) in 0.04 seconds.
format exit 0
=== packages/jet_cad_2d
test runner exit 1
For example, 'dart test --chain-stack-traces'.
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found!
analyze exit 0
Formatted 169 files (0 changed) in 0.54 seconds.
format exit 0
=== packages/jet_cad_2d_flutter
test runner exit 1
  ... and 3 more
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 221 files (0 changed) in 0.64 seconds.
format exit 0
=== web build apps/restaurant_demo
build exit 0
Compiling lib/main.dart for the Web...                             52.9s
✓ Built build/web
```

- **The planner** has 1435 tests: 1423 from Task 2 plus 12 new ones (TG-Z1, TG-Z2, TG-Z3, TG-Z4, CV1, CV2, CV3, B3, RV1, RV2, RV3, FP7).
- **The demo** has 39: 37 plus DZ1 and DZ2.
- **The engine and the renderer** exit 1 because of their standing failures (engine 2, render 7 plus 1 skip). The comparison is exact for both. Both are untouched.
- **The web build** was preceded by `rm -rf build`.
- **An earlier gate run, before the move,** had the demo red with D16, D17, D18 and D23. That run is the reason for the zone section's place.

## `git status --short`

```
 M apps/restaurant_demo/lib/demo_strings.dart
 M apps/restaurant_demo/lib/main.dart
 M apps/restaurant_demo/test/demo_test.dart
 M packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart
 M packages/jet_cad_floor_plan/lib/src/host/floor_plan_types.dart
 M packages/jet_cad_floor_plan/lib/src/host/service_view.dart
 M packages/jet_cad_floor_plan/lib/src/service/table_group_painter.dart
 M packages/jet_cad_floor_plan/test/host/barrel_test.dart
 M packages/jet_cad_floor_plan/test/host/controller_test.dart
 M packages/jet_cad_floor_plan/test/host/table_groups_look_test.dart
 M packages/jet_cad_floor_plan/test/host/view_test.dart
 M packages/jet_cad_floor_plan/test/service/table_focus_painter_test.dart
 M packages/jet_cad_floor_plan/test/service/table_group_painter_test.dart
```

No `analysis_options.yaml` appears. The engine, the renderer, the host guide, the probe, the CHANGELOG and STATUS are untouched; they are Task 4's.

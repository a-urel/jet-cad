# Task 15 report: painting, theme, the design canvas's colours and the export fills

Status: DONE_WITH_CONCERNS (concerns are the R-16 line drops listed under "Concerns"; everything else is as briefed)

Commit: `ed218143 feat(plan): unit painting, the service theme and export fills (2b S4)` (on d50976ed). 25 files, all under `packages/jet_cad_2d_plan`.

## What was implemented

- `lib/src/theme/plan_theme.dart`: `const double kUnitColourOpacity = 0.35` (R-22) before `PlanTheme`; the seventeen fields in today's order (`floor_plan_theme.dart:29-47`), `copyWith`, `merge` (with `_mergeStyle`), `lerp` (2a's covariant signature, `_lerpInsets`, `_lerpStyle` copied unchanged), `==`, `hashCode`, `_fields`; `validatePlanTheme` = today's `validateFloorPlanTheme` with `unitColourOpacity`. Doc comments are today's, renamed ("selection mode" -> "service", "table" -> "unit", "view refuses" -> "scope refuses"). Header's last sentence changed as briefed. `PlanTheme.of` kept.
- `lib/src/service/paint/unit_status_painter.dart`, `unit_group_painter.dart`, `unit_focus_painter.dart`: ports with the briefed adaptations (`units: UnitIndexCache`, `UnitIndex? _indexBuilt` as the rebuild key, `_Fill.toWorld` captured at rebuild, `UnitPicker.candidatesOf` in the focus and group painters, `c.transform` for a member's world transform, `shouldRepaint` gains `units`). Each starts with the briefed "Ported from ..." line.
- `lib/src/export/unit_colour_underlay.dart`: verbatim from the brief (`unitColourUnderlay`, `checkedUnitColourOpacity`, `unitFillsOf`).
- `registries.dart`: `PlanExportRequest.unitColourOpacity` (default `kUnitColourOpacity`). `builtin_exporters.dart`: both built-ins pass `underlay: unitFillsOf[request] ?? const []`; header changed. `page_flows.dart`: `units:` constructor argument, `unitColourOpacity` on `exportOnce`/`printOnce`/`export`/`print`, fills from the live index. `editor_page_flows.dart`: `unitColourOpacity` callback (default 0.35) passed to both flows.
- `plan_controller.dart`: `PlanPageFlows(units: () => unitIndex)`; `export`/`print` take `double? unitColourOpacity`, checked at the call by `checkedUnitColourOpacity`; docs gain the briefed paragraph; `@internal UnitIndexCache get documentUnits => _session.units`.
- `plan_canvas.dart`: the design colour underlay (key `unit-colour-layer`), `_fillPaper`/`_fillTheme`/`_Bump`/`_documentChanges`, the painter built per document in `_bind`; `_onPage`, `didChangeDependencies`, `dispose` as briefed. `plan_canvas_view.dart`: `tableOverlays` -> `unitOverlays`, the three docs. `plan_editor.dart`: `_unitColourOpacity` passed to `EditorPageFlows`.
- Test support: `test/support/service_paint.dart` (from the brief), `test/support/unit_zone_fixture.dart` (port of `zone_fixture.dart`; room dropped, TEXT `7` kept through `unitLabelRecord(...).copyWith(kind: text, tag: '')` + `unitLabelPayload`, `encodePlan(doc, validateKitSet([fxKit()]))`; `addZoneLayer` = fixture `addLayer`; `quadsOf` over `UnitInfo`).
- New tests: `test/service/paint/unit_paint_test.dart` (SP-seat-fill, SP-group-mixed, SP-locked-status, SP-dup-label), `test/export/unit_colour_opacity_test.dart` (SP-export-seat, SP-opacity-arg, SP-request), CV-alloc-colour and CV-alloc-service in `test/invariants/canvas_paint_allocation_test.dart`.
- Ported tests (assertions unchanged except the R-16 drops below): `unit_status_painter_test.dart` (SP1-SP12, 12 tests), `unit_group_painter_test.dart` (TG-L1..L11, TG-Z1, TG-Z2, RX1, premise; 15), `unit_focus_painter_test.dart` (FP1-FP7, FX1; 8), `unit_theme_painter_test.dart` (25), `unit_fill_test.dart` (fixture, TF1-TF5, TF7 head, TF8, TF8b, TF9, TF10; 11), `test/export/unit_colour_export_test.dart` (premises, EX1-EX5 incl. EX3b, EX3c; 8), `test/theme/plan_theme_test.dart` (22: 2a's 19 + TH19 T1-a, TH20 R-3, TH21 the 13-field validation through the scope).
- Carried 2a deferral (TH4's overshoot): ported into `plan_theme_test.dart` TH4. `edgeA`/`edgeB` are now the source's eleven-field themes (their `selectionWidth` 3 / 0.5 are 2a's, so 2a's assertions hold unchanged); TH4 keeps 2a's lines and gains the source's `expectWithinEnds(l, a, b, reason)` and its four overshoot lines (`statusFillOpacity` 1.0, `unitColourOpacity` 0.0, `groupChipPadding` zero, `statusCaptionStyle.fontSize` 1.0), renames only. Named mutation M-TH4b (below) turns it red. The premise is possible under the 2b spec (S4 "Theme" names the four fields), so nothing is left for a ruling.

## Deviations and findings (please rule where needed)

1. **unit_paint_test's `Spy` records `Color(paint.color.toARGB32())`, not `paint.color`.** As written in the brief, SP-group-mixed, SP-locked-status and SP-dup-label failed with identical-looking colours: a `Paint` stores its colour in float32, so `paint.color.r` reads `0.2235294133424759` against `const Color(0xFF3949AB).r == 0.2235294117647059`. Measured with a throwaway test: `Color Color 0.2235294117647059 0.2235294133424759 ColorSpace.sRGB ColorSpace.sRGB false`. The fixture (the spy) now normalises through ARGB with a comment; the assertions `[blue, blue, blue]`, `[blue, blue]`, `[red, red]` are unchanged.
2. **`exportOnce`/`printOnce` build the request inside the `try`** via a private helper `_requestOf(copy, live, choice, unitColourOpacity:)` (same body as the brief's block). The brief put the block between `_copyOf` and the `try`; there a throwing `unitColourUnderlay` (a direct `exportOnce(..., unitColourOpacity: 1.5)`) or `omittedOf` would leak the copy, which 2a's code disposed in the `finally`. M-SP-request was applied to `_requestOf`'s `unitColourOpacity: unitColourOpacity);` (the request's) and goes red.
3. **Step 7.8**: `PlanPageFlows._copyOf` already calls `registerUnitComponents(r)` (Task 6). No change.
4. `fillDoc` builds on `planDocument([fxKit()], measurer: measurer)` (what `unitPlan()` is, with the caller's measurer: `unitPlan()` takes none), then sets today's page (origin 37000, -36200, white, no grid) as the source does.
5. Brief code trimmed for the analyzer only: `unit_colour_opacity_test.dart` drops the unused `package:flutter/painting.dart show Color`; `service_paint.dart` drops `package:flutter/foundation.dart` (unnecessary under `widgets.dart`); the allocation test drops the `src/controller/plan_controller.dart`, `service_session.dart show PlanMode` and `service_state.dart show UnitGroup, UnitStatus` imports (the barrel provides them; `flutter analyze` flagged them as unnecessary). `unit_group_painter_test.dart`'s `var chipSpy` became `final` (prefer_final_locals). No test logic changed.
6. `plan_theme_test.dart`: 2a's TH11 is kept as is (its `expect(refused, hasLength(4))` untouched); the source's validation test is added as TH21 with its own `hasLength(4 * 3 + 4 * 5 + 3 * 6)`, through 2a's `scopeApp` harness (the source's `find.byType(ServiceView)` line is a view-level check, Task 16's). TH1's body is the source's 17-field version (2a's non-style assertions are a subset; it adds the S-3 style merge). TH10 gains the source's `groupFrameMargin`/`groupChipPadding` `toString` case. TH3/TH5/TH9 now run over the seventeen-field table (the insets' and styles' lerps included).
7. Names the brief assumed match the committed code (`UnitIndexCache.current`, `UnitInfo.toWorld/visible/locked/owner/text`, `UnitPicker.candidatesOf(..., boxes:, leaves:)`, `GroupUnit(label:)`, `UnitGroupLookup`, `editorSelectedUnits`, `unitDetails` with `.unit.label`/`.colour`, `PlanExport.name`). The source's `out!.fileName` (EX3c) is `out!.name` in 2a's `PlanExport` (rename).

## Concerns (R-16 drops: lines that name R, tintSample or tintAlpha)

Dropped, per ruling R-16; listed so the ledger can confirm each:
- TF1: the two `expectAt(... tintSample ...)` / `expectAt(... spec('R') ...)` lines.
- **TF3: `expect(spy.fills, hasLength(6), reason: 'A, B, C, U, K and R');`** It names R; with R gone the count is 5, so the test no longer pins the fill count. If the controller wants it kept, a ruling could port it as `hasLength(5)` (an assertion change) or keep R as a plain purple table without the room.
- TF7: `final (rx, ry) = pixelOf(tester, tintSample);`, the tint expect, the "room's tint taken back" block (names `tintAlpha`), **and `expect(channelDistance(fill, again), ...)`** which compares against the value that block computes (no R/tint name on the line itself, but its premise is gone); the light-mode `tintSample` expect. TF7's selection-mode tail moved to Task 16 as TF7b (R-15); TF6 likewise not here.
- Export premises: **`expect([for (final s in specs) s.key], ['A', 'B', 'C', 'N', 'U', 'K', 'H', 'M', 'R']);`** (names R). `filled` (a fixture list) drops `'R'`.
- EX2: the two tint/R lines. EX3: `expectRgb(img, page, tintSample, ...)` in the opacity-0 block.
- The `tintAlpha` const and `tintSample` declaration removed with the room.

Not done here (not in the brief's file list): the `jet_cad_2d_plan` CHANGELOG entry.

## TDD evidence

RED (the two new test files run against HEAD d50976ed in a temporary detached worktree, then removed):
`cd <worktree at d50976ed>/packages/jet_cad_2d_plan && flutter test test/service/paint/unit_paint_test.dart test/export/unit_colour_opacity_test.dart`
```
test/service/paint/unit_paint_test.dart:28:8: Error: Error when reading 'test/support/service_paint.dart': No such file or directory
import '../../support/service_paint.dart';
test/service/paint/unit_paint_test.dart:67:21: Error: Type 'ServicePaintLayers' not found.
...
test/export/unit_colour_opacity_test.dart:12:8: Error: Error when reading 'lib/src/export/unit_colour_underlay.dart': No such file or directory
import 'package:jet_cad_2d_plan/src/export/unit_colour_underlay.dart';
test/export/unit_colour_opacity_test.dart:33:19: Error: Method not found: 'unitColourUnderlay'.
test/export/unit_colour_opacity_test.dart:51:15: Error: No named parameter with the name 'unitColourOpacity'.
...
test/export/unit_colour_opacity_test.dart:61:32: Error: The getter 'unitColourOpacity' isn't defined for the type 'PlanExportRequest'.
00:00 +0 -2: Some tests failed.
```
Expected: the harness, the underlay file and the opacity API do not exist yet. (The painter import errors are masked by the first missing file in the paint test.)

First GREEN attempt failed on the float32 colour (finding 1): `Which: at location [0] is Color:<Color(alpha: 1.0000, red: 0.2235, ...)> instead of Color:<Color(alpha: 1.0000, red: 0.2235, ...)>`. After the spy fix:
`flutter test test/service/paint/unit_paint_test.dart test/export/unit_colour_opacity_test.dart`
```
00:00 +6: .../test/export/unit_colour_opacity_test.dart: SP-request a host's exporter receives the given opacity (M-SP-request)
00:00 +7: All tests passed!
```
Allocation scenes: `flutter test test/invariants/canvas_paint_allocation_test.dart` -> `00:01 +3: All tests passed!`.

Step 11:
- `flutter test test/service/paint` -> `00:06 +75: All tests passed!`
- `flutter test test/export test/theme test/canvas test/editor test/invariants/canvas_paint_allocation_test.dart` -> `00:20 +243: All tests passed!`

## Gates (jet_cad_2d_plan; the only package touched; no pubspec, tool/ci or kit change)

After `dart format .` (`Formatted 261 files (0 changed)`):
- `flutter test` -> `00:51 +1221 ~7: All tests passed!` (the 7 skips are the VM-service allocation meters)
- `flutter test --enable-vmservice` -> `01:05 +1228: All tests passed!`
- `flutter analyze` -> `No issues found! (ran in 4.2s)`
- `dart format --output=none --set-exit-if-changed .` -> `Formatted 261 files (0 changed) in 0.62 seconds.`, exit 0
- No failure at all, so nothing to compare with `tool/ci/standing_failures.txt`. `git status --short` after each pub run listed only this task's files; clean after the commit.

## Mutations (on the committed files; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` printed `DIFF_EXIT 0`)

| Mutation | Edit | Test | Failing line (quoted) |
|---|---|---|---|
| M-SP-seat | `unit_status_painter.dart` paint: `final t = f.toWorld;` -> `final t = (document.tree[f.instance]! as InstanceNode).transform;` | SP-seat-fill | `Expected: a numeric value within <1e-9> of <0.09393727128473789>` / `Actual: <0.1>` / `coefficient 0` |
| M-SP-frame | `unit_group_painter.dart` `if (members.length < 2) continue;` -> `< 4` | SP-group-mixed | `Expected: an object with length of <1>` / `Actual: []` / `one frame` |
| M-SP-locked | `unit_status_painter.dart` insert `if (u.locked) continue;` after `if (!u.visible) continue;` | SP-locked-status | `Actual: []` / `Which: at location [0] is [] which shorter than expected` |
| M-SP-dup | `unit_status_painter.dart` status line -> `label == null \|\| index.withLabel(label).first.instance != u.instance ? null : ...` | SP-dup-label | `Which: at location [1] is [ Color:Color(alpha: 1.0000, red: 0.8980, ...) ] which shorter than expected` (one fill, two expected) |
| M-SP-export | `unit_colour_underlay.dart` both `placement: u.toWorld,` -> `placement: (document.tree[u.instance]! as InstanceNode).transform,` | SP-export-seat | `Actual: [1.0, 0.0, 0.0, 1.0, 350.0, -265.0]` / `Which: at location [0] is <1.0> instead of <0.9393727128473789>` |
| M-SP-check | `unit_colour_underlay.dart` `checkedUnitColourOpacity`: the `if (!given.isFinite ...) throw` deleted | SP-opacity-arg | `Expected: throws <Instance of 'ArgumentError'> with `name`: 'unitColourOpacity'` / `Which: threw ArgumentError:<Invalid argument (opacity): must be in [0, 1]: -0.01>` |
| M-SP-request | `page_flows.dart` `_requestOf`: `unitColourOpacity: unitColourOpacity);` -> `unitColourOpacity: kUnitColourOpacity);` | SP-request | `Expected: <0.6>` / `Actual: <0.35>` |
| M-CV-colour-a | `plan_canvas.dart` build: `painter: _colourPainter,` -> `painter: UnitStatusPainter(document: document, units: c.documentUnits, camera: c.camera, statuses: _noStatuses, unitGroups: _noGroups, groupStatuses: _noStatuses, paper: _fillPaper, theme: _fillTheme, repaint: c.camera),` | CV-alloc-colour | `Expected: true` / `Actual: <false>` / `the painter is kept` |
| M-CV-colour-b | `unit_status_painter.dart` paint: `if (!identical(_indexBuilt, index) \|\|` -> `if (true \|\|` | CV-alloc-colour | `Expected: <2>` / `Actual: <12>` / `no rebuild per frame` |
| M-CV-service | `unit_group_painter.dart` paint: `!identical(_builtFor, map) \|\|` -> `true \|\|` | CV-alloc-service | `Expected: [6, 7, 8, 5]` / `Actual: [6, 17, 18, 5]` / `nothing per frame` |
| M-H31 | `unit_focus_painter.dart` recolour guard -> `if (true) {` | unit_theme_painter_test "FP3 themed" | `Expected: <3>` / `Actual: <14>` / `the colour is derived when the theme or paper changes only` |
| M-14c2-8 | `unit_status_painter.dart` `..drawPath(f.path, f.paint)` -> `..drawPath(f.path, Paint()..color = f.paint.color)` | unit_status_painter_test SP1 | `Expected: true` / `Actual: <false>` / `item 2` |
| M-TH-merge | `plan_theme.dart` merge: `unitColourOpacity: other.unitColourOpacity ?? unitColourOpacity,` -> `unitColourOpacity: unitColourOpacity,` | plan_theme_test TH1 | `Expected: <0.25>` / `Actual: <0.6>` / `unitColourOpacity set: unitColourOpacity` |
| M-TH-valid | `plan_theme.dart` delete `opacity(theme.unitColourOpacity, 'unitColourOpacity');` | plan_theme_test TH21 (validation) | `Expected: <Instance of 'ArgumentError'> with `name`: 'unitColourOpacity'` / `Actual: <null>` / `unitColourOpacity: PlanTheme(unitColourOpacity: -0.01)` |
| M-C8 | `builtin_exporters.dart` PNG: `underlay: unitFillsOf[request] ?? const [],` deleted | unit_colour_export_test EX2 | `Actual: <89>` / `A: 0xffffff, want 0xa6d6d1` |
| M-C23 | `plan_editor.dart` `_flowsFor`: `unitColourOpacity: _unitColourOpacity,` deleted | unit_colour_export_test EX4 | `Actual: <64>` / `0.6: A: 0xa6d6d1, want 0x66b8b0` |
| M-TH4b (carried TH4) | `plan_theme.dart` `_lerpInsets` -> `EdgeInsets.lerp(a, b, t)!` (unclamped) | plan_theme_test TH4 | `Expected: be in range from 0.0 (inclusive) to 7.0 (inclusive)` / `Actual: <-1.4000000000000001>` / `A to B at -0.2: groupChipPadding.left` |

Every run printed `Some tests failed.` and exit 1; every revert printed `DIFF_EXIT 0`; `git status --short` is empty after the last one.

## Self-review

- Completeness: every file of the brief's Files list is in the commit; every Produces name exists with the briefed signature (`UnitStatusPainter`, `UnitGroupPainter`/`UnitGroupLayer`, `UnitFocusPainter`, `kUnitFocusVeilAlpha`, `focusVeilColour`, `kStatusCaptionSize`, `kStatusCaptionGap`, `over`, `statusCaptionInk`, `paintedTextStyle`, `groupLabel`, `convexHull`, `offsetHull`, the `kGroup*` constants, `ServicePaintLayers`, `unitColourUnderlay`, `checkedUnitColourOpacity`, `unitFillsOf`, `documentUnits`, `PlanCanvasView.unitOverlays`, `EditorPageFlows.unitColourOpacity`).
- Frame path: the painters allocate nothing per frame (CV-alloc-colour, CV-alloc-service, SP1, TG-L9, FP3 and their themed siblings are green and each has a red mutation).
- Fixtures are not degenerate: the service fixture's table is turned and mirrored off the origin, row A turned, row B curved; the ported fixtures keep their 37-degree turns, mirrors and 40 m offsets.
- Old packages untouched; no `analysis_options.yaml`, pubspec or version change.
- Escape trap: the only non-ASCII literals in ported files are SP5's `'👍🏽'` captions; compared byte for byte against the oracle (`diff` of the non-ASCII lines, Table -> Unit renamed): identical. The new files' non-ASCII characters (`·`, `×` in comments) are the brief's.

## Fix round 1

Commit: `2daafc79 test(plan): pin TF3's fill count and the group caption's lead (2b Task 15)`.

What changed:
1. (Important, controller ruling) `test/service/paint/unit_fill_test.dart` TF3: `expect(spy.fills, hasLength(5), reason: 'A, B, C, U and K');` restored after the three `fillOf` lines (the source's `hasLength(6)` without R), with a comment naming the ruling.
2. `test/export/unit_colour_export_test.dart` premises: `expect([for (final s in specs) s.key], ['A', 'B', 'C', 'N', 'U', 'K', 'H', 'M']);` (the order of the port's `specs`, :105-185: A, B, C, N, U, K, H, M).
3. `unit_status_painter.dart`: "label label" -> "unit label" (three docs), `FloorPlanController`'s -> `PlanController`'s.
4. `unit_focus_painter.dart` and `unit_group_painter.dart`: the over-long doc lines reflowed by hand (no line over 80 but the briefed "Ported from" first lines); the group painter's split "(unit / groups fixes X3" restored to "(table / groups fixes X3" (a spec name the rename caught across the line break).
5. `unit_paint_test.dart` SP-group-mixed: the `Spy` records `translate` offsets; the test computes the table's label anchor (its definition-space point through the table's world transform and the camera) and asserts the one caption is centred on it (`closeTo(lx, 1e-6)`) and below it, with a premise that A2's anchor is more than 50 px away. Title gains M-SP-lead.

Covering tests: `flutter test test/service/paint/unit_paint_test.dart test/service/paint/unit_fill_test.dart test/export/unit_colour_export_test.dart` -> `00:02 +23: All tests passed!`

Gates (jet_cad_2d_plan, after `dart format .`, `Formatted 261 files (0 changed)`):
- `flutter test --enable-vmservice` -> `01:00 +1228: All tests passed!`
- `flutter test` -> `00:52 +1221 ~7: All tests passed!`
- `flutter analyze` -> `No issues found! (ran in 4.5s)`
- `dart format --output=none --set-exit-if-changed .` -> exit 0

Mutations (committed files; reverted with `git checkout --`, `git diff --quiet` -> `DIFF_EXIT 0`; tree clean after):
- M-TF3-dup, `unit_status_painter.dart` `_rebuild`: a second `_Fill(u.instance, u.toWorld, path, paint, null, 0, 0, 0, 0)` added before each unit's `fills.add(_Fill(` -> TF3 red: `Expected: an object with length of <5>` / `Which: has length of <10>` / `A, B, C, U and K`.
- M-SP-lead, `unit_status_painter.dart` `_rebuild`: `inLeadOrder(list).first.handle` -> `inLeadOrder(list).last.handle` (a non-lead member carries the caption) -> SP-group-mixed red: `Expected: a numeric value within <0.000001> of <-4140.05>` / `Actual: <-3323.5876372291573>` / `centred under the table's label`.

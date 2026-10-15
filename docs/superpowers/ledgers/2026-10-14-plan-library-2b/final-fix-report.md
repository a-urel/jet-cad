# Final fix wave: report

Branch `feat/plan-library-2b`, base `e7b7ceb6`. Commits:
- `318d2844` fix(plan): the design is read-only while a service copy exists (I-1)
- `93e92a74` test(plan): pin restore's notifications, the seat drag's spend, unitAt on a seat (I-3, I-4, M-2, M-3, T12, T14)
- `bb5b7c05` test(plan): port view_palette_test's mode views (M-DT-10, M-DT-11) (I-2)
- `ed27e2ca` docs: the 2b CHANGELOGs complete (I-2 engine blank line, M-7)
- `cd6c8957` docs: 2b's final fix wave of record; STATUS points at the merge (I-2)

Nothing pushed, tagged, merged or published. The ledger is not archived. No `analysis_options.yaml`
touched (`git status --short` clean after every pub run).

Every mutation below ran on a committed file through a small runner
(`scratchpad/mrun.py`: apply the exact-string edit, `flutter test <files>`, print the failure lines,
`git checkout -- <file>`, `git diff --quiet -- <file>`); each run printed
`REVERTED; git diff --quiet exit 0` (or, for the first two I-1 runs done by hand, `diff-quiet 0`).

## I-1. The design read-only in service

**Changed** (`lib/src/controller/plan_controller.dart`):
- new `DraftPermissions get _designDraft => _service != null ? DraftPermissions.readOnly : _permissions.draft;`
- `_open`: `document.commands.permissions = _designDraft;` (was `_permissions.draft`), so a load or
  newPlan in service (`_replace` opens the new design while the old copy still exists) is read-only.
- `setMode(service)`: after `_service = copy`, `design.document.commands.permissions = _designDraft;`
- `setMode(design)`: after `_service = null`, `document.commands.permissions = _designDraft;`
- `permissions` setter: `document.commands.permissions = _designDraft;` (was `value.draft`); doc
  comment says the design stays read-only in service and takes the profile on leaving.
- restore/reset do not replace the design and keep a copy, so the design stays read-only.
  `_unrestricted` saves and restores whatever is set, so the separator settle still works.

**No conflict found**: the full suite (1501 at that point, then 1512) stayed green; nothing in
service writes the design through its dispatcher except `_settleSeparator`, which already lifts
permissions. One consequence to note: in service `selectTool('<drawing tool>')` and a
design palette mounted in service now see the design's engine permissions as read-only
(`_allowsTool` reads them), so drawing tools are refused there. No test pinned the old behaviour.

**Tests** (new file `test/canvas/canvas_service_mode_test.dart`, `drawController()` fixture: a line
on a 1:20 page under the zoomed, rotated camera of `pumpDraw`):
- `SM-design-readonly`: PlanCanvas mounted, `setMode(service)`; a mouse drag on the selected line
  leaves `bytes(c)`, `dirty` and the design's `canUndo` alone; `c.permissions =
  full.copyWith(rotate: false)` in service keeps it read-only, a second drag also changes nothing;
  `setMode(design)` → `DraftPermissions.all`, the same drag changes the bytes and `dirty` is true.
- `SM-design-readonly-load`: load, newPlan and resetService in service keep `readOnly`; leaving
  gives `all`; with the profile `readOnly`, entering and leaving gives `readOnly` back.

**Mutations**:
- (a) M-SM-ro-enter, delete `design.document.commands.permissions = _designDraft;` in setMode:
  `Expected: same instance as <Instance of 'DraftPermissions'>` / `00:00 +1 -1: Some tests failed.`
  Re-run with the test's identity check after entering also removed (test reverted too), the
  drag itself goes red: `Expected: ... coords":[7137.3,3161 ...` / `Actual: ... coords":[7257.3,3221 ...`
  (the line moved by 120, 60). Reverted, `diff-quiet 0`.
- (b) M-SM-ro-setter, the setter writes `value.draft`: `Expected: same instance as <Instance of
  'DraftPermissions'>`; with the identity check after the setter removed, the second drag goes red
  with the same moved coords. Reverted, `diff-quiet 0`.
- M-SM-ro-leave, delete the restore in setMode(design): both tests red (`00:00 +0 -2: Some tests
  failed.`, `Expected: same instance as …`). Reverted, `diff-quiet 0`.
- M-SM-ro-open, `_open` writes `_permissions.draft`: `SM-design-readonly-load … [E]`. Reverted,
  `diff-quiet 0`.

## I-2. The ledger's fix-wave items

- **view_palette port**: `test/canvas/view_palette_test.dart`, header "Ported from
  jet_cad_floor_plan/test/host/view_palette_test.dart; assertions unchanged". 7 tests:
  `M-DT-11 (design mode)`, `M-DT-11 (service mode)`, `ServiceView, light theme, Blueprint paper`,
  `ServiceView, dark theme, White paper`, `ServiceView, dark theme, Blueprint paper`,
  `M-DT-10, ServiceView: no page …`, `ServiceView, a theme switch with no camera move …`.
  Mapping: FloorPlanView → the mode's view (PlanCanvas in design, PlanServiceView in service);
  PlannerView → PlanCanvasView; ServiceView → PlanServiceView; FloorPlanMode.selection →
  PlanMode.service; `cameraController` → `camera`; the oracle's palette_fixture →
  `support/canvas_fixture.dart` (`paletteController`). Every expect line is the oracle's.
  `flutter test test/canvas/view_palette_test.dart`: `00:01 +7: All tests passed!`.
  Mutations:
  - M-VP-paper (`plan_service_view.dart` `paper: PaperPalette.light`): 6 red (M-DT-11 service,
    the three crossings, M-DT-10, the theme switch); first line `Blueprint view: selection
    0x1e55a4, want 0x7fb2ff` (caught at `canvas_fixture.dart line 284`, `expectSelection`).
  - M-VP-chrome (`chrome: ChromePalette.light`): 3 red (the two dark crossings, the theme
    switch), `Expected: '0x8a8a8a'` (the sheet edge).
  - M-VP-surface (`_surfaceArgb = 0xFFFFFFFF;`): `M-DT-10 … [E]`, `Expected: <4294967295>` /
    `Actual: <4278190080>`.
  - M-VP-design-paper (`plan_canvas.dart` `paper: PaperPalette.light`): `M-DT-11 (design mode) …
    [E]`, `Blueprint view: selection 0x1e55a4, want 0x7fb2ff`.
  Each `TEST EXIT 1`, `REVERTED; git diff --quiet exit 0`.
- **Results note**: the view_palette finding (~:363) and the spec-gaps line (~:772) now say
  "ported in the final fix wave" with the tests named; the deferred-minors line records I-3/I-4
  pinned; an I-1 line added; a new `## Final fix wave` section at the end (changes, tests, the
  mutation table, premise checks, gates, dry runs).
- **STATUS.md**: the 2a paragraph's A14 sentence → settled by 2b spec decision 9; the 2b
  paragraph → review and fix wave done, 2b complete on its branch, not merged, not pushed;
  "Resume here" → 2b complete after the final review and fix wave, not merged, not pushed; next:
  the human's word on the merge; F-1 (`chrome_change_test.dart`, design-only, a 2a gap) open for
  the human; pointer to the results note's "Spec gaps" section (anchor link) and "Final fix wave".
- **Engine CHANGELOG**: the blank line before `ParametricType.instances…` in `## Unreleased`
  removed (the E1-E4 and E5 bullets now one list).

## I-3. restore's revision and notifications

**Tests**:
- `SR-restore-revision` (`test/controller/service_record_controller_test.dart`, after SR-C14,
  SR-C14 itself untouched): in service, unit 1 moved, `serviceJson()`; a counting listener;
  `restoreService(json)` → `revision` +1 and `notified == 1`; `resetService()` → `notified == 1`.
- `SV-restore` (`test/service/view/plan_service_view_test.dart`): rowsController in a
  PlanServiceView; the table moved by (-1500, -1500); `serviceJson`; `resetService` (premise: the
  table back; a tap at the moved place finds nothing); `restoreService(json)`, two pumps; the
  PlanCanvasView's `document` is `c.activeDocument`; a tap at the restored place gives
  `taps == [table]`.
**Mutations**:
- M-SR-restore-rev (delete `_revision.value++` in restoreService): `service_record_controller_test.dart line 182`
  `expect(c.revision.value - r, 1);` `Expected: <1>` / `Actual: <0>`.
- M-SR-restore-notify (delete restoreService's `notifyListeners()`): line 183 `expect(notified, 1);`
  `Expected: <1>` / `Actual: <0>`; and `plan_service_view_test.dart line 311`
  `expect(identical(canvas.document, c.activeDocument), isTrue);` `Expected: true` /
  `Actual: <false>` (`00:01 +28 -2: Some tests failed.`).
- M-SR-reset-notify (delete resetService's `notifyListeners()`): line 187 `expect(notified, 1);`
  `Actual: <0>`.
All `TEST EXIT 1`, `REVERTED; git diff --quiet exit 0`.

## I-4. The drag's `roots.isEmpty ||` spend

**Test** `ST-seat-drag` (`test/service/service_tool_units_test.dart`): the table tapped
(premise `{table}`), A3 a seat (premise); `r.drag(r.inside(a3), (600, -300))` → keys `{table}`,
table and seat transforms unchanged, the copy's `undoDepth` unchanged, `layouts == 0`,
`moved` empty.
**Mutation** M-ST-empty (`if (roots.isEmpty ||` → `if (`): `service_tool_units_test.dart line 266`
`expect(r.keys, {r.key(t)}, reason: 'the seat did not replace it');`
`Expected: Set:[SelectionKey:SelectionKey( 18)]` / `Actual: Set:[SelectionKey:SelectionKey( 22)]`
/ `Which: does not contain SelectionKey:<SelectionKey( 18)>`. `TEST EXIT 1`, reverted, exit 0.

## Folds

- **M-2** `UA-unitAt-seat` (`test/units/unit_api_test.dart`): design: `unitAt(centre of A3)` is
  `'A3'` (premise: A3 generated); service: B2 and A3 found. Mutation M-UA-at-seat
  (`UnitPicker(_activeDocument, units, placedOnly: true)`): `test/units/unit_api_test.dart 181:5`
  `expect(c.unitAt(at('A3')), 'A3');` `Expected: 'A3'` / `Actual: <null>`. Reverted, exit 0.
- **M-3** `UA-locked-label`: `controllerFor(kits: const [], json: serviceFixture().json)`; the
  placed table `locked` (premise); `setUnitLabel(label, '77')` false, `lockHint` false, undo depth
  unchanged, the label still held once. Mutation M-UA-lock-label (`if (u.generated) return false;`):
  `test/units/unit_api_test.dart 164:5` `expect(c.lockHint.value, isFalse, reason: 'a host call
  raises no hint');` `Expected: false` / `Actual: <true>`. Reverted, exit 0.
- **T8** (drop `old.selectUnitsOnly != value.selectUnitsOnly ||`) against
  `test/editor/units_only_select_test.dart`: killed by two R-1 cases (the body drag of the north
  wall, line 346, and the chair's rotation-grip turn, line 399), both `expect(encoded(c), before);`
  `Which: is different.` (`Expected: ... coords":[21400.0,168 ...` / `Actual: ... coords":[20750.0,170 ...`).
  Reverted, `diff-quiet 0`. No pin added.
- **T12** `SS-relabel` gains `expect(c.statusOf(c.unitIndex[h.table]!), bill, reason: 'premise:
  the status holds before the relabel');`. Check (test-only edit, reverted): without its
  `setUnitStatus` the premise is red, `Actual: <null>`.
- **T14** `RB16-hall` gains, before the band starts, the seats whose detail centre maps into
  `Rect.fromPoints(press, (1100, 300))`, `isNotEmpty` ("premise: the band covers a seat"); it
  allocates outside the measured epochs. Check (test-only, reverted): the rect shrunk to the press
  point → `Expected: non-empty` / `Actual: []`.
- **M-7** CHANGELOGs, Unreleased sections only, no version change: the plan library's
  `## 0.8.0 (unreleased)` gains the unit and service types the barrel exports (`PlanUnit`,
  `PlanUnitDetail`, the `PlanUnitChange` events, `UnitLabelProblem`, the label warnings,
  `UnitStatus`, `UnitGroup`, `ServiceRestore`, `PlanServiceAction`, `PlanLongPress`,
  `PlanFloorDrag`, `PlanOverlaySize`, `PlanUnitOverlayBuilder`), `cameraValue`/`PlanCamera`,
  `worldToGlobal`/`globalToWorld`, `unitColourOpacity` on export/print and
  `PlanExportRequest.unitColourOpacity` (`kUnitColourOpacity`), the unit section and
  `PlanEditor(unitInspectorBuilder:)`, `isUnitSymbol`, `PlanController.symbolsState` typed
  `SymbolsState` (2a's `PlanSymbolsState` removed), and the design read-only in service. The
  barrel was diffed against `651e3d09` to find them. The kit's 2b bullet (in its unreleased
  `## 0.1.0`, the only section) gains `kUnitLabelMaxHeight`, `kUnitLabelTopShare`,
  `kUnitLabelTextAttrs`.

## Gates

- `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice`: exit 0,
  `01:57 +1512: All tests passed!` (1498 before the wave + 14 new: 2 SM, 1 SR, 1 SV, 1 ST,
  2 UA, 7 view_palette). `flutter analyze`: `No issues found! (ran in 4.6s)`.
  `dart format --output=none --set-exit-if-changed .`: `Formatted 286 files (0 changed) in 0.81
  seconds.`, exit 0. (Run after `dart format .`, which formatted `view_palette_test.dart` once.)
  The focused runs: `band_allocation_test.dart` and `unit_groups_controller_test.dart` with
  `--enable-vmservice`: `00:07 +22: All tests passed!`; the four I-3/I-4/M files:
  `00:01 +51: All tests passed!`.
- `cd packages/jet_cad_2d_kit`: `flutter test` `00:03 +340: All tests passed!` (exit 0);
  `flutter analyze` `No issues found! (ran in 3.5s)`; format `Formatted 74 files (0 changed) in
  0.09 seconds.`, exit 0.
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 1 package(s) checked, none names the
  plan library or another kit`, exit 0.
- `cd packages/jet_cad_2d` (CHANGELOG only): `dart analyze` `No issues found!`; format
  `Formatted 187 files (0 changed) in 0.43 seconds.`, exit 0.
- No standing failure is in these packages' runs; nothing new failed.

## Dry runs (after `ed27e2ca`, tree clean)

- `packages/jet_cad_2d`: `dart pub publish --dry-run` exit 0, `Package has 0 warnings.`
- `packages/jet_cad_2d_kit`: `dart pub publish --dry-run` exit 0, `Package has 0 warnings.`
- `packages/jet_cad_2d_plan`: `dart pub publish --dry-run` exit 0, `├── CHANGELOG.md (4 KB)`,
  `Package has 0 warnings.`
(`flutter pub publish --dry-run` for the kit and the plan library also printed
`Package has 0 warnings.`, exit 0.)

## Self-review

- Escapes: `grep -nP '[^\x00-\x7F]|\\u|\\x'` over the two new test files and the oracle printed
  nothing (exit 1); no non-ASCII in any added test line.
- The I-1 test's red under (a) and (b) is first an identity check on the engine permissions; the
  behavioural drag assertion was shown red separately for both (above).
- Not done (ruled out of this wave): M-1, M-4, M-5, M-6, M-8, M-9.

## Concerns

- I-1's consequence beyond the ruling's wording: with the design read-only in service, any design
  widget still mounted in service (palette, gallery, panels) reads read-only engine permissions and
  greys out or refuses edits, and `selectTool` of a drawing tool answers false in service. This is
  the intended effect of S3 and no test pinned otherwise, but it is a visible change for a
  composable host; the CHANGELOG states it.

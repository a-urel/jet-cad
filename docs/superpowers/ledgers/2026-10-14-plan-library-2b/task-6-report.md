# Task 6 report: units core (UnitIndex, labels, numbering, per-unit data, locks)

Status: DONE (base 395ec35f).

Commits:
- `9ce5096a feat(plan): units: the index, labels, numbering, data, locks (2b S2)` — the task.
- `85065219 test(plan): reflow registerPlanComponents' doc comment` — comment only: the Step 10.4 doc sentence left one line at 98 columns (`dart format` does not reflow comments); reflowed to 80.

## What I implemented

All under `packages/jet_cad_2d_plan/`.

- `lib/src/units/unit_label.dart` (Step 4, verbatim from the brief): `kUnitLabelMaxLength`, `UnitLabelProblem`, `isControlCodeUnit`, `unitLabelProblem`, `unitLabelError`, `unitLabelRecord`, `firstLeafOf` (with the optional `leavesByOwner`, R-20), `unitTopOfLeaves`, `placedLabelTop`, `placedLabelTopOf` (R-21), `addUnitLabelCommand`, `unitLabelOf`.
- `lib/src/units/unit_problems.dart` (Step 5, verbatim): `UnitProblem` (seven codes), `UnitLabelWarning`, `DuplicateLabel`, `Unlabelled`, `BadLabel`.
- `lib/src/units/unit_numbers.dart` (Step 6, verbatim): `countedUnitNumber`, `nextUnitNumberOf`, `nextUnitNumber`.
- `lib/src/units/unit_components.dart` (Step 7): `UnitData` (`jetcad.unit_data`), `UnitColour` (`jetcad.unit_colour`, `name`, `swatch`), `kUnitDataMax*`, `unitDataProblem`, `registerUnitComponents`. Ported line by line from `table_data_component.dart` and `table_color_component.dart` with exactly the renames the brief lists; the two `static register` methods dropped for `registerUnitComponents`.
- `lib/src/units/unit_locks.dart` (Step 8, verbatim): `isLockedUnit`, `heldTypeOf`.
- `lib/src/units/unit_index.dart` (Step 9, verbatim): `UnitInfo`, `UnitIndex` (`of`, `units`, `[]`, `withLabel`, `nested`, `diagnostics()` returning the engine's `List<Diagnostic>` per R-8, `warnings()`), `UnitIndexCache`.
- Wiring (Step 10): `DocumentSession.units` (`UnitIndexCache`, built after the lock scan, disposed before the lock expander); `PlanController._register` registers the unit components (doc comment updated to say so); `@internal UnitIndex get unitIndex => _session.units.current` after `isLocked` (declared once, R-10); the export copy (`page_flows.dart` `_copyOf`) registers them; the test harness's `registerPlanComponents` registers them.
- `test/support/unit_fixtures.dart` (Step 1, verbatim from the brief, R-19): `fxKitId`, `fxKit()`, `tableUnit`, `tableSymbol`, `stoolSymbol`, `planterSymbol`, `oneChairTable`, `trapezoidTable`, `entryOf` (by hand), `plan()`, `kDeg37`, `placementAt`, `unitIndexOf`, `labelUnit`, `labelsOf`.
- Tests: `test/units/units_test.dart` (the brief's eleven + Step 11b's `UI-def-missing`), and the ports `unit_index_test.dart` (TI1-TI6, TI4b), `unit_numbers_test.dart` (TN1-TN8), `unit_components_test.dart` (TD1-TD6, TC1), `unit_label_test.dart` (TL5-TL7).

Code from earlier tasks was used as committed (`unitKit`, `RowComponent`, `placeRowCommand`, `entryTop`, `rowSeatKey`, `tableSymbolId`, `boothSymbolId`, `serviceFixture`, `testEntry`, `addRow`, `seatsOf`, `unitLabelsOf`, `labelPlacedUnit`, `symbolKit`, `planText`, `controllerFor`, `catalogOf`); no name the brief assumed differed from the committed code.

## Ported tests: adaptations (assertions unchanged)

- TI1-TI6, TI4b: exactly the brief's renames (`place` without `numbered:`, `labelUnit`, `addUnitLabelCommand(..., text:)`, `unitIndexOf(doc).units`, `labelsOf`, `withLabel`, `.text`, `.capacity`, the `UnitProblem` constants, `SetComponentCommand<UnitComponent>` in TI4b).
- **Finding P-1 (for the ledger, accepted by R-10/R-19):** TI1's `symbolKey` list reads `['fx.stool.round', 'fx.table.two', 'fx.stool.round', 'fx.table.two']` instead of `['test.stool', 'test.table', ...]` — the fixture's keys, which K2's key rule requires under a kit with two segments (fixture data, 2a precedent). A comment at the assertion names the ruling.
- TL5: `expect(r.tag, 'UNIT')` (the tag renamed, spec S2), as the brief directs.
- TD6: `registerAppComponents` → `(r) => registerPlanComponents(r, ParametricCatalog())`; `tableDiagnostics(back)` → `unitIndexOf(back).diagnostics()`; the code constant and its value `'unit.invalid_data'`.
- TC1: `UnitColour`, `PlanSwatch.teal/purple`, `swatch`.
- Not ported here (as the brief says): TL1-TL4 (Task 3), TD7-TD10 (Task 7).

## TDD evidence

RED (Step 3), before `unit_components.dart` and the wiring existed:
`cd packages/jet_cad_2d_plan && flutter test test/units/units_test.dart`
```
test/units/units_test.dart:13:8: Error: Error when reading 'lib/src/units/unit_components.dart': No such file or directory
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
...
test/units/units_test.dart:170:21: Error: The getter 'unitIndex' isn't defined for the type 'PlanController'.
```
Expected: compilation errors (the brief's two, the URI and the getter). (The other `lib/src/units` files had been written from the brief already, so the URI error names `unit_components.dart` rather than `unit_index.dart`.)

GREEN (Step 11): same command → `00:00 +11: All tests passed!` (eleven tests).

Step 11b: `flutter test test/units/units_test.dart --plain-name UI-def-missing` → `00:00 +1: All tests passed!`.

Step 13: `flutter test test/units` → `00:00 +37: All tests passed!` (7 TI + 8 TN + 7 TD/TC + 3 TL + 12 UI). Output pristine: no line other than the test progress lines.

## UI-def-missing (Step 11b, R-24)

The fixture text is decoded with `jsonDecode`; `components['test.row']['<rowA>']['seat']` (asserted first to be the seat definition's handle) is set to `handleSeed.next()` of a scratch decode (asserted to name no definition). Loaded into `controllerFor(kits: [unitKit()])`. Asserted: `c.frozen == {rowA}`; `c.isLocked(rowA)`; `seatsOf(d, rowA) == f.seatsA` (no regeneration ran); each seat of A is a unit with `(owner, ownerType, locked, text) == (rowA, 'test.row', true, 'A<i+1>')` and its UNIT ATTRIBs equal the original plan's; row B's seat not locked; `c.diagnostics.value` has exactly one entry, subject `test.row`, code `hookFailed`, message containing the row's hex, error a `GeneratedDefinitionError`.

## Gates (packages/jet_cad_2d_plan, at HEAD 85065219)

- `dart format .` → `Formatted 195 files (5 changed)` (before the commit; my new files), then `dart format --output=none --set-exit-if-changed .` → `Formatted 195 files (0 changed) in 0.39 seconds.`, exit 0.
- `flutter test` → `00:39 +788: All tests passed!` (Task 5's report: +751; +37 here).
- `flutter analyze` → `No issues found! (ran in 3.2s)`.
- `git status --short` → empty after the commits (no `analysis_options.yaml` change). No pubspec, `jet_cad_2d_kit`, `tool/ci` or `.github` change, so no kit-deps / tool-ci gate.

## Mutations (on the committed files; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` printed exit 0)

| Id | Edit | Test | Failing output (verbatim) | Revert |
|---|---|---|---|---|
| M-UI-generated | `unit_index.dart`: `final typeId = catalog.typeIdOf(document, parent.handle);` → `final String? typeId = null;` | UI-generated | `Expected: [24, 30, 32, 34, 36, 38, 40, 43, 45, 47, 49, 51]` / `Actual: [24]` / `test/units/units_test.dart 173:5` | exit 0 |
| M-UI-held | `if (typeId == null && !locks.isLockedObject(parent.handle)) {` → `if (typeId == null) {` | UI-missing-kit | `Expected: [24, 30, 32, 34, 36, 38, 40, 43, 45, 47, 49, 51]` / `Actual: [24]` / `test/units/units_test.dart 230:5` | exit 0 |
| M-UI-held | (same edit, same run) | UI-flip | `Null check operator used on a null value` / `test/units/units_test.dart 286:63` (the held seat `[held.seat]!` is no unit) | exit 0 |
| M-UI-object | same line → `if (false) {` | UI-flip | `Expected: null` / `Actual: UnitInfo:<UnitInfo(16, null, table)>` / `test/units/units_test.dart 304:5` (`expect(c[plain.seat], isNull);`) | exit 0 |
| M-UI-locked-key | delete `_locked.addListener(_lockedChanged);` | UI-frozen-no-edit | `Expected: true` / `Actual: <false>` / `test/units/units_test.dart 269:7` (`expect(after[s]!.locked, isTrue, ...)`) | exit 0 |
| M-UI-covers | `unit_locks.dart`: `return locks.covers(document, instance);` → `return false;` | UI-def-kit-missing | `Expected: (int, String, bool):<(20, test.row, true)>` / `Actual: (int, String, bool):<(20, test.row, false)>` / `test/units/units_test.dart 319:7` | exit 0 |
| M-UI-scan | `kits/locks.dart` `LockSet.scan`: `(node is InstanceNode && definitions.contains(node.definition))) {` → `false) {` | UI-held-seat-row-locked | `Expected: false` / `Actual: <true>` / `test/units/units_test.dart 336:5` (the execute succeeded) | exit 0 |
| M-UI-dup | `if (handles.length < 2) continue;` → `< 3` | UI-dup | `Bad state: No element` / `test/units/units_test.dart 364:10` (the `.single` duplicate diagnostic is missing) | exit 0 |
| M-UI-unlabelled | `null \|\| '' => null,` → `null => null,` | UI-unlabelled | `Expected: null` / `Actual: ''` / `test/units/units_test.dart 392:5` | exit 0 |
| M-UI-bad | delete the `else if (unitLabelError(text) case final error?) { … }` branch | UI-bad | `Expected: [[24], [54], [56]]` / `Actual: []` / `test/units/units_test.dart 435:5` | exit 0 |
| M-UI-next-skip | `unit_numbers.dart`: `while (candidate <= _kLargestCounted && labels.contains('$candidate')) {` → `while (false) {` | UI-next | `Expected: '15'` / `Actual: '13'` / `test/units/units_test.dart 452:5` | exit 0 |
| M-UI-next-fallback | `while (used.contains(candidate) \|\| labels.contains('$candidate')) {` → `while (used.contains(candidate)) {` | UI-next | `Expected: '15'` / `Actual: '1'` / `test/units/units_test.dart 456:5` | exit 0 |
| M-UI-registered | `plan_controller.dart`: delete `registerUnitComponents(r);` from `_register` | UI-registered | `UnregisteredComponentError(UnitData): call registry.register first` / `test/units/units_test.dart 467:11` | exit 0 |
| M-TN-max | `unit_numbers.dart`: `if (v > max) max = v;` → `max++;` | TN2 | `Expected: '4'` / `Actual: '3'` / `test/units/unit_numbers_test.dart 18:7` | exit 0 |
| M-TI-label | `unit_index.dart`: `?..sort((a, b) => a.$1.value.compareTo(b.$1.value));` → `;` | TI4 | `Expected: <18>` / `Actual: <36>` / `test/units/unit_index_test.dart 138:5` (`expect(survey.units.last.label, earlyLabel);`) | exit 0 |
| M-UI-def | `jet_cad_2d/lib/src/parametric/regeneration.dart` `_planInstances`: `if (t.tree.definition(g.definition) == null) {` → `if (false) {` | UI-def-missing | `Expected: Set:[29]` / `Actual: Set:[]` / `Which: does not contain <29>` / `test/units/units_test.dart 502:5` (`expect(c.frozen, {f.rowA});`) | exit 0 |

Each test was run as `cd packages/jet_cad_2d_plan && flutter test test/units/<file> --plain-name <id>`; each run ended `Some tests failed.`

## Self-review

- Every Produces name of the brief exists with the brief's signature; no barrel export (Task 9's).
- `unitIndex` is declared once (R-10). `placeSymbol` is unchanged: the dispatch's R-10 note says it gains `UnitIndex? units`, but the Shared interfaces and the brief put that in Task 7 (`symbol_placer.dart ... (Task 7)`, "placer: placeSymbol(…, {UnitIndex? units})" under "// Task 7"), and this brief's tests call it without one. Left for Task 7.
- `placeUnit` is not in this task's fixture: R-19 lists it among Task 8's appends, and the brief's Step 1 file does not hold it.
- Fixtures are not degenerate: the service fixture (mirrored, turned table; a turned row and a curved one off the origin), the held group turned 0.4 rad at (3100.5, -1700.25) with a 37° seat, the gone-kit row turned 0.5 rad off the origin.
- Every new test has a named mutation that turns it red (table above).

## Concerns / notes for the ledger

1. Finding P-1 (TI1's fixture keys `fx.*`), accepted by R-10/R-19; to be recorded in the ledger.
2. The brief's Step 4 note stands: `unitLabelHeight` of a definition whose first leaf is no top reads the leaves' box for `UnitInfo.top`, while a placed label's height (`placedLabelTop`, R-21) keeps today's 200 for a non-circle, non-polyline first leaf. No library unit takes that branch (K3 rule 11).
3. A comment-only follow-up commit (85065219) reflowed the harness doc comment the brief's Step 10.4 sentence produced.

---

# Fix round 1

Commit: `abbc9612 fix(plan): units review round 1: NBSP inputs, one unknown-kit rule`.

## What changed

1. **Important, NBSP inputs.** The file-writing tool I used had turned the ` ` escapes in my port into literal characters: TD1's U+00A0 became a plain space, and TN7's became a literal NBSP. Both are restored as escapes:
   - `unit_components_test.dart:77`: `expect(unitDataProblem({'a': ' ¡ é'}), isNull,` (the oracle's bytes `C2 A0 C2 A1 20 C3 A9`: NBSP, ¡, space, é).
   - `unit_numbers_test.dart:63`: `'a b',` (the oracle, `table_numbers_test.dart:59`, writes exactly this escape).
   - What I checked: every quoted literal in the five oracle files (`table_data_test.dart`, `host/table_color_test.dart`, `table_numbers_test.dart`, `table_index_test.dart`, `table_label_test.dart`) that holds non-ASCII text or a `\u` escape, checked byte for byte against its port with a script. Before the fix only these two did not match. Every other one matched: `'7f3c-ä'`, `'Masa 4.ğ'`, the two JSON payloads, `'ı'`, `'ş'`, `'\u0000'`, `'\u001f'`, `'\u007f'`, `'\u009f'`, `'x\u0085'`, `'x\u0085y'`, `'\u{1F37D}'`, `'1234567😀'`, `'Bahçe 3'`, `'\u007F'`, `'a\u0085b'`, `'a\u009Fb'`, `'ÇİĞ'`, `'٣'`. The other non-matches are TL1's and TL2's titles, which are not ported here (Task 3/7). I also grepped every file this task added for literal C0, DEL or C1 characters or a literal U+0080-U+00A0: none.
2. **Important, one unknown-kit rule.** `lib/src/kits/locks.dart` gains `@internal String? unknownKitTypeIdOf(CommandTarget document, Handle h)`: the old `_unknownKit` loop (typeId, dot, `isKitId`, not `jetcad`, not `plan`), returning the type id. `@internal` comes from `flutter/foundation.dart`, which the file already imports; analyze flagged a separate `package:meta` import as unnecessary. `LockSet._unknownKit` is now `typeId?.substring(0, typeId.indexOf('.'))` of the helper. `heldTypeOf` (`unit_locks.dart`) is `=> unknownKitTypeIdOf(document, group)`, and the duplicate loop and its `isKitId` import are gone. No behaviour change: the kit is the same prefix before the first dot.
3. **Minor.** The ported headers of `unit_components_test.dart` and `unit_index_test.dart` are reflowed to 80 columns.
4. **Minor.** `DocumentSession`'s constructor builds `units = UnitIndexCache(...)` last, after `lockExpander.install()`. It is a pure reorder: nothing in the constructor reads `units`, and the cache's constructor only adds its listener. A comment says why it comes last.

## Covering tests and gates (packages/jet_cad_2d_plan)

- `flutter test test/units test/kits` → `00:02 +117: All tests passed!`
- `flutter test` → `00:41 +788: All tests passed!`
- `flutter analyze` → `No issues found! (ran in 2.8s)`
- `dart format --output=none --set-exit-if-changed .` → `Formatted 195 files (0 changed) in 0.42 seconds.`, exit 0
- `git status --short` was empty after the commit.

## Mutations (on abbc9612; each reverted with `git checkout -- <file>`, then `git diff --quiet -- <file>` printed exit 0)

| Id | Edit | Test | Failing output (verbatim) |
|---|---|---|---|
| M-TD1-nbsp | `unit_label.dart` `isControlCodeUnit`: `(u >= 0x7F && u <= 0x9F)` → `(u >= 0x7F && u <= 0xA0)` | TD1 | `Expected: null` / `Actual: 'the value of "a" has a control character'` / `U+00A0 is past the C1 range` / `test/units/unit_components_test.dart 78:7` |
| M-TD1-nbsp | (same edit, same run) | TN7 | `Expected: null` / `Actual: 'No line breaks or control characters'` / `test/units/unit_numbers_test.dart 65:9` |
| M-UI-held | `unit_index.dart`: `if (typeId == null && !locks.isLockedObject(parent.handle)) {` → `if (typeId == null) {` | UI-missing-kit | `Expected: [24, 30, 32, 34, 36, 38, 40, 43, 45, 47, 49, 51]` / `Actual: [24]` / `test/units/units_test.dart 230:5` |
| M-UI-held | (same edit) | UI-flip | `Null check operator used on a null value` / `test/units/units_test.dart 286:63` |
| M-UI-object | the same line → `if (false) {` | UI-flip | `Expected: null` / `Actual: UnitInfo:<UnitInfo(16, null, table)>` / `test/units/units_test.dart 304:5` |
| M-UI-covers | `unit_locks.dart`: `return locks.covers(document, instance);` → `return false;` | UI-def-kit-missing | `Expected: (int, String, bool):<(20, test.row, true)>` / `Actual: (int, String, bool):<(20, test.row, false)>` / `test/units/units_test.dart 319:7` |
| M-UI-scan | `kits/locks.dart` `LockSet.scan`: `(node is InstanceNode && definitions.contains(node.definition))) {` → `false) {` | UI-held-seat-row-locked | `Expected: false` / `Actual: <true>` / `test/units/units_test.dart 336:5` |
| M-UI-heldtype (new) | `kits/locks.dart` `unknownKitTypeIdOf`: `... kit != 'plan') return typeId;` → `return kit;` (shows `LockSet` reads the shared helper) | UI-flip | `RangeError (end): Invalid value: Not in inclusive range 0..4: -1` / `package:jet_cad_2d_plan/src/kits/locks.dart 86:20  LockSet._unknownKit` / `test/units/units_test.dart 283:27` |
| M-UI-heldtype-b (new) | `unit_locks.dart` `heldTypeOf`: `unknownKitTypeIdOf(document, group);` → `null;` | UI-flip | `Expected: (int, String, bool):<(18, test.slab, true)>` / `Actual: (int, Null, bool):<(18, null, true)>` / `test/units/units_test.dart 287:5` |

Each test was run as `cd packages/jet_cad_2d_plan && flutter test test/units/<file> --plain-name <id>`. Every run ended `Some tests failed.`

## Notes

- M-UI-heldtype crashes `LockSet.scan` instead of failing on an `ownerType` value: with `return kit`, `_unknownKit` takes the substring of a string that has no dot. It still goes red, and it shows that the lock set and `heldTypeOf` read one helper. M-UI-heldtype-b pins `heldTypeOf`'s use of the helper through `ownerType`.

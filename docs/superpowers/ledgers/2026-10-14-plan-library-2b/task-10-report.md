# Task 10 report: words, the unit section, the colour row over units, the unit inspector

Commit: 106a8780 feat(plan): unit words, the unit section and the unit inspector (2b S4)
(trailer is the implementer-instructions' `Co-Authored-By: Claude Opus 5.5`.)

## Implemented
Steps 4-9 of the brief as written (PlanStrings words in en/de/tr, `unitKindWord`, `planStrings`, `unit_section.dart`,
the panel's `_UnitTarget`/`_unitSection`, `unitColourTargets`/`pickedColours`/`recolourCommand` over units,
`UnitInspector`, `PlanEditor.unitInspectorBuilder`), plus the recording strings and all the tests of Steps 1-2.

## Deviations from the brief (all small, all reported)
1. `_turnableAt` (property panel): the brief's SW9 keeps `expect(editable, isFalse, 'premise: a table does not')` under
   runtime permissions, but the committed 2a panel made a symbol's Rotation depend on `transform` alone. I ported
   today's `_turnableAt` (selection_panel.dart:486-491): a placed unit's Symbol rotation and Mirror need `transform` AND
   `geometry`; the `_SymbolTarget` `_editable` case asks it of the pinned handle. Named mutation M-UW13; new test UW-runtime-unit.
2. CP11: the brief says `c.selectTool('plan.line')`, but `plan.line` has no settings, so the colour row (hidden only while
   a tool's settings show) stays. I used `disc.draw` (the tool CP1 already uses; the disc kit is loaded). Assertion (row absent under the tool) unchanged.
3. SW6/SW9 use the library's own unit symbols (`test.corner.seat`, `test.table.a`, both units) instead of adding a `tableSymbol(seats: 4)`; SW6 labels the corner with `addUnitLabel` (the file's `place` uses `placeSymbol` without `units:`).
4. `UnitIndex.debugBuilds` (`@visibleForTesting static`, incremented in `UnitIndex.of`) added for CP12: Task 6 had no counter.
5. Unused imports named in the brief (`unit_index.dart` in the panel and colour_row) dropped (analyzer).
6. Inspector test: only the first half of "none without a builder ...; none in the selection mode" is ported (the mode half is Task 16's, per the brief).
7. Extra tests beyond the brief: UW-order (Symbol section above unit section), UW-runtime-unit.
8. T5-b landed inside units_only_select_test's `move (T5-a ...)` group (it follows T5-a).

## Carried item: unitLabelCommand's new-ATTRIB branch
Reachable from the UI: an unlabelled placed unit gaining a label from the unit section (UW-section-assigned types `S1` on an unlabelled seat; TS5 types `7` on an unnumbered, quarter-turned table and checks the label payload `[200, rotation, widthFactor]`). Named mutation M-UW12 below turns TS5 red.

## TDD evidence
Tests were written against an already-implemented tree for this task (the brief's Step 3 compile-failure red was not captured separately: lib work preceded the test files). The mutation step below is the red evidence; every new test went red under a named mutation.

## Gates (packages/jet_cad_2d_plan)
- `dart format .`: 0 changed. `flutter analyze`: `No issues found!`. `dart format --output=none --set-exit-if-changed .`: exit 0.
- `flutter test`: `00:45 +967: All tests passed!` (no standing failures hit).
- `git status --short` clean after the commit; no analysis_options.yaml staged.

## Mutations (each: run, red, `git checkout -- <file>`, `git diff --quiet -- <file>` exit 0)
- M-UW1 unit_words.dart: the `if (key != null) {...}` block deleted -> UW-kind-lookup red: `Expected: 'Loca'  Actual: 'booth'` (also UW-host-word-first red).
- M-UW2 unit_words.dart: `return unit.kind;` -> UW-kind-lookup red: `Expected: 'Masa'  Actual: 'table'`.
- M-UW3 plan_controller.dart:389 `kit.names.merge(_hostWords)` -> UW-host-word-first red: `Expected: 'Bölme'  Actual: 'Loca'`.
- M-UW4 strings_en.dart `unitKind` `_ => kind` -> UW-words red: `Expected: null  Actual: 'booth'` (line `expect(s.unitKind('booth'), isNull, reason: s.languageCode);`).
- M-UW5 panel field title always `_strings.number` -> UW-section-assigned red at unit_section_test.dart:106 `expect(fieldTitle(tester), 'Label');`: `Expected: 'Label'  Actual: 'Number'`.
- M-UW6 `_editable` unit case without `relabel` -> UW-relabel-gate red at :126 `expect(tester.widget<TextField>(label).readOnly, isTrue);`: `Expected: true  Actual: <false>`.
- M-UW7 `_unitTarget` without `isLocked` -> UW-locked-none red at :144 `expect(section, findsNothing);`: `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'unit-section'>]`.
- M-UW8 `_parse` unit case `return text;` -> TS3 red at :222 `expect(c.document.commands.undoDepth, depth);`: `Expected: <4>  Actual: <5>`.
- M-UW9 inspector `_detail` shared-label loop deleted -> M-H45 red at unit_inspector_test.dart:146 `expect(byKey('host-inspector'), findsNothing, reason: name);`: `Expected: no matching candidates  Actual: _KeyWidgetFinder:<Found 1 widget with key [<'host-inspector'>]`.
- M-UW10 inspector `_onSelection` without `if (next == _shown) return;` -> T6-d red (and T6-f) at :220 `expect(h.calls.length, 1, reason: 'a hover builds nothing');`: `Expected: <1>  Actual: <4>`.
- M-UW11 colour_row `final u => u.name` -> CP8 red at colour_row_test.dart:547 `expect(marked(tester), isNull, reason: 'a kept payload marks no swatch');`: `Expected: null  Actual: 'none'`.
- M-UW12 (new, carried) unit_writes.dart new-ATTRIB `placement: Transform2.identity()` (was `node.transform`) -> TS5 red at unit_section_test.dart:308 `expect(payload.scalars, [200, st.rotation, st.widthFactor]);`: `Expected: [200, -1.5707963267948966, 1.0]  Actual: [200.0, 0.0, 1.0]`.
- M-UW13 (new) `_turnableAt` body `return true;` after the transform check removed (unit needs no geometry) -> SW9 red at symbol_section_test.dart:633 `expect(editable(tester), isFalse, reason: 'premise: a table does not');` and UW-runtime-unit red at unit_section_test.dart:432 `expect(rotationEditable(), isFalse);`: `Expected: false  Actual: <true>`.

## Concerns
- SW1's and SW4's table halves in symbol_section_test remain unported (not in this brief); UW-order / UW-runtime-unit cover their unit-specific assertions.
- LK1 (Turkish leak sweep) does not select a placed unit; the unit words are pinned by unit_words_test / VW2 / VW3 instead.

# Fix round 1

Commit: 7ebae14d test(plan): unit colour-target exclusions and 2a's deferred unit cases (2b Task 10 fix 1). Tests only; no lib change.

## 1. Review gap (unitColourTargets exclusions)
- CP13 (colour_row_test.dart): `PlanController(kits: const [], json: serviceFixture().json)`: the placed table is locked and `generated == false`; selected in the panel, no picker, `unitColourTargets` empty, `recolourCommand` null; the same unit under `[unitKit()]` is a target (control).
- CP14: a generated seat (`serviceFixture().seatsA.first`, not locked, `generated == true`) is not a target through `unitColourTargets`, the placed table beside it is; `recolourCommand` null.
- M-UW14 (`&& !c.isLocked(h)` deleted) -> CP13 red at colour_row_test.dart:745 `expect(unitColourTargets(locked, [k(f.table)]), isEmpty);`: `Expected: empty  Actual: [24]`.
- M-UW15 (`index[h]?.generated == false` -> `index[h] != null`) -> CP14 red at :760 `expect(unitColourTargets(c, [k(seat)]), isEmpty);`: `Expected: empty  Actual: [30]`.

## 2. 2a deferrals ported (assertions unchanged; names follow the rename)
- SW1 table half and SW4 table half: in place in symbol_section_test.dart (`test.table.a` is a unit; `table-section` -> `unit-section`). Mutations: SW1 red on swapping the Symbol and unit sections in the panel's `sections` list: symbol_section_test.dart:478 `expect(tester.getTopLeft(byKey('symbol-section')).dy,` -> `Expected: a value less than <12.0>  Actual: <200.0>`. SW4 red on M-UW13 (`_turnableAt` returns true): :546 `expect(editable(tester), isFalse, reason: 'a table: the design mode');` -> `Expected: false  Actual: <true>`.
- T6-c, RP1 (unitsOnly), RP12: plan_shortcuts_test.dart (the 2a keyboard file, KB-*). New helpers `mountUnitKeys` (PlanEditor over the unit fixture, intent-based or CallbackShortcuts host), `kIntentKeys`, `HostIntent`, `canvasFocused`; `sendActivator` is design_harness's. `tablesOnly` -> `PlanPermissions.unitsOnly`; RP12 arms `PlanSymbol(kitId: 'fx', entry: entryOf(tableSymbol()))` with `c.armSymbol`. RP1's full variant is 2a's KB-3 and was not repeated.
  - RP1 and the whole file under `if (!widget.shortcuts) return const {};` deleted from `_bindings` (plan_shortcuts.dart): RP1 red at plan_shortcuts_test.dart:480 `expect(reached[e.key], 1, reason: e.key);` -> `Expected: <1>  Actual: <0>`.
  - T6-c under `selectGates.idleKeys = widget.shortcuts;` -> `= true;`: red at :456 `expect(encodedPlan(c), before);` (Delete removed unit 1 with shortcuts false; `Expected: ... children":[22,24,26,28 ...  Actual: ... children":[24,26,28,30 ...`).
  - RP12 under `(key == LogicalKeyboardKey.keyM && (canMirror?.call() ?? true))` -> `(key == LogicalKeyboardKey.keyM)` (plan_symbol_tool.dart): red at :516 `expect(reached['M'], 1, reason: 'unitsOnly refuses mirror: M bubbles');` -> `Expected: <1>  Actual: <0>`.
- readOnly (V-5) table part: editor_options_test.dart (2a's editor panels file), three tests in the `readOnly (V-5)` group over `mountUnitEditor(permissions: readOnly)`: the table's section read-only (no ±90, Mirror, layer picker); no command reaches the design from a pointer path or key on a table, the free line and the column; host calls (`setUnitData`, `undo`, `load`) still work. The oracle's wall/room/dimension parts are sub-project 3's and were not ported.
  - Test 1: `_editable` unit case `return true;` -> red at :391 `expect(fieldOf(tester, 'unit-label').readOnly, isTrue);` -> `Expected: true  Actual: <false>`.
  - Test 2: `PlanPermissions.readOnly` with `delete: true` -> red at :447 `expect(encoded(c), before);` (`Expected: ... hildren":[18,21],"ex ...`).
  - Test 3: `_requireDesign` throwing when `!_permissions.relabel` -> red at :457 `expect(c.setUnitData('2', const {'pos': 'b2'}), isTrue);` -> `Bad state: setUnitData`.
  - Finding: deleting `relabel &&` from `_editable` (M-UW6 on the readOnly mount) and the `move`/`rotate`/`delete` select-gate `_permissions()` terms do NOT turn these tests red: the engine permissions that readOnly derives already block the same edits (those terms are redundant on this path). The mutations above are the ones that do.
- Premises impossible under the 2b spec: none.

## Gates
`dart format .`: 0 changed; `flutter analyze`: No issues found!; format gate exit 0; `flutter test`: `+975: All tests passed!`. Every mutation reverted with `git checkout --` and `git diff --quiet` exit 0.

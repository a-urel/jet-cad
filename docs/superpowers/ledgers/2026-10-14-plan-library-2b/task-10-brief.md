### Task 10: Words, the unit section, the colour row over units and the unit inspector (spec S4 "Words", "The unit inspector" and the unit section; S5 the words and capabilities rows)

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/l10n/strings.dart`, `strings_en.dart`, `strings_de.dart`, `strings_tr.dart` (the unit and service words)
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_words.dart` (`unitKindWord`)
- Create: `packages/jet_cad_2d_plan/lib/src/panels/unit_section.dart` (the unit section's model: the placed unit shown, the label's refusal)
- Modify: `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart` (the unit section, after the symbol section)
- Modify: `packages/jet_cad_2d_plan/lib/src/panels/colour_row.dart` (placed units are colour targets: today's tables)
- Create: `packages/jet_cad_2d_plan/lib/src/editor/unit_inspector.dart` (`UnitInspector`, internal)
- Modify: `packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart` (`unitInspectorBuilder`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`@internal PlanStrings get planStrings`)
- Test (support): `packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart` (the new members recorded)
- Test (new): `packages/jet_cad_2d_plan/test/l10n/unit_words_test.dart` (UW-*), `packages/jet_cad_2d_plan/test/panels/unit_section_test.dart` (UW-* and the ported TS cases)
- Test (ported): `packages/jet_cad_2d_plan/test/editor/unit_inspector_test.dart`; cases appended to `test/l10n/value_words_test.dart`, `test/panels/colour_row_test.dart`, `test/panels/symbol_section_test.dart`, `test/panels/hover_removal_test.dart`, `test/editor/units_only_select_test.dart`, `test/editor/editor_words_test.dart`; new `test/l10n/stale_error_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/` unless they say otherwise.)

**Interfaces:**
- Consumes:
  - Task 6: `UnitInfo` (`instance`, `definition`, `text`, `kind`, `capacity`, `labelling`, `symbolKey`, `generated`), `UnitIndex` (`operator []`, `withLabel`), `UnitLabelProblem`, `unitLabelProblem`, `kUnitLabelMaxLength`, `UnitLabelWarning`, `DuplicateLabel`, `Unlabelled`, `BadLabel`, `UnitColour` (`UnitColour(PlanSwatch)`, `name`: null for a payload of another shape).
  - Task 7: `rotateUnitCommand(DraftDocument doc, Handle instance, int quarterTurns)` (`units/unit_rotate.dart`), the label system re-stamping a turned unit's label.
  - Task 9: `PlanController.unitIndex`, `unitDetails`, `unitDetailInstances`, `revision`, `editorSelectedUnits`, `setUnitData`; `unitLabelCommand` (`units/unit_writes.dart`); the test support `unit_embedding_fixture.dart`.
  - Task 8: the test support `unit_fixtures.dart` (`fxKit`, `placeAt`, `placeUnit`, `addUnitLabel`, `tableSymbol`, `planterSymbol`, `unitPlan`) and `unit_editor_fixture.dart` (`mountUnitEditor`, `unitEditorPlanJson`, `editorCamera`, `screenOf`, `centreOf`, `tableOf`, `unitsIn`, `click`, `press`, `kEditorSurface`, `editorTextAt`, `editorNorthWall`).
  - Task 4: `PlanController(words: KitNames)`, each kit's `KitNamesWords` over `words.merge(kit.names)` (`KitServices.words`); `PlanController.servicesOf(kitId)` (2a, `@internal`).
  - Task 3: the `unit:<kit>/<kind>` word namespace accepted by `PlanKit.validate`.
  - 2a: `PlanStrings` and its three languages; `PlanPropertyPanel`'s field cycle (`_Field`, `_Scope`, `_Target`, `_targetOf`, `_shown`, `_parse`, `_editable`, `_write`, `_guarded`, `_commit`, `_onChanged`, `_sync`, `_textField`, `plan_property_panel.dart:55-600`); `ColourRow`, `colourTargets`, `pickedColours`, `recolourCommand`, `colourRowBlocked` (`colour_row.dart:18-97`); `FrameSafeRelay`; `PlanEditor`'s right column (`plan_editor.dart:632-655`).
- Produces (the Shared interfaces' Task 10 row, exactly):
  - `PlanStrings` gains `merge`, `split`, `number`, `label`, `capacity`, `rotateLeft`, `rotateRight` (getters), `String labelProblem(UnitLabelProblem problem)`, `String labelUsed(String label)`, `String labelWarning(UnitLabelWarning warning)`, `String? unitKind(String kind)` (`table`, `seat`; null otherwise), in `PlanStringsEn`, `PlanStringsDe`, `PlanStringsTr`.
  - `String unitKindWord(PlanController c, UnitInfo unit)` (`lib/src/units/unit_words.dart`, internal): the kit's word, else `PlanStrings.unitKind`, else the kind as stored.
  - `PlanEditor(unitInspectorBuilder: Widget? Function(BuildContext, PlanUnitDetail)?)`.
  - Internal: `UnitInspector` (`editor/unit_inspector.dart`); `UnitInfo? placedUnitOf(UnitIndex index, Handle handle)` and `String Function(PlanStrings)? labelRefusal(UnitIndex index, UnitInfo unit, String text)` (`panels/unit_section.dart`); `List<Handle> unitColourTargets(PlanController c, Iterable<SelectionKey> keys)` (`panels/colour_row.dart`); `@internal PlanStrings get planStrings` on `PlanController`.

Plan decision (the words): the unit words are today's table words where today has one, with today's texts in the three languages (`jet_cad_floor_plan/lib/src/l10n/strings_{en,de,tr}.dart`): `merge`, `split`, `number`, `rotateLeft`, `rotateRight`; `capacity` is today's `seats` ("Seats", "Plätze", "Kişilik"); `labelProblem`, `labelUsed` and `labelWarning`'s `DuplicateLabel` are today's `tableNumberProblem`, `tableNumberUsed` and `numberingWarning`'s `DuplicateNumber` texts, so the ported VW2, VW3 and SE1 keep their assertions; `Unlabelled` says today's text for a table and names the kind for any other; `BadLabel` is new. `label` ("Label", "Bezeichnung", "Etiket"), `unitKind` ("Table"/"Tisch"/"Masa", "Seat"/"Sitzplatz"/"Koltuk") are new. The table-flavoured texts (a seat's duplicate label "used by 2 tables") stay as today's for 0.8.0; a later rewording is sub-project 4's.

Plan decision (the kind's word, spec S4 "Words"): the kit id is the unit's `symbolKey`'s first segment (`kitOfKey`); a unit with no symbol key (a definition without `SymbolComponent`) skips the kit's word. The kit's word is read through its services' `KitWords.maybe('unit:<kit>/<kind>')`, so a host's word (Task 4's merge) comes first. A kit that is not loaded has no services: its step is skipped. The language class for the second step is the one the widgets last reported (`reportLocale`'s `strings`), else the built-in language of the controller's locale: `PlanController.planStrings`.

Plan decision (the unit section, spec S4): it shows for one selected **placed** unit the lock does not cover (2a's rule: a locked object shows no section), after the symbol section (today's order, `selection_panel.dart:1396-1414`): the kind's word as its title (key `unit-section`), the label field (key `unit-label`, titled `number` for a `numbered` unit, `label` for an `assigned` one), the refusal line (`unit-label-error`), the shared-label warning (`unit-label-duplicate`), the capacity (`unit-capacity`), and the ±90 buttons (`unit-rotate-left`, `unit-rotate-right`). The field follows the panel's field cycle (pinned target, commit on focus loss and Enter, revert on refusal); it edits while `permissions.relabel` is on and the document's permissions allow `geometry` (a label is entity text, today's `_editable`, `selection_panel.dart:362-366`). The buttons show while `permissions.rotate` is on and the document allows `transform` and `geometry` (today's `_rotatable`, `:743-748`). The refusal line lasts until the next keystroke in the field or a change of the shown unit (today's `:1003-1006`, `:1097-1099`).

Plan decision (the colour row): today's colour row covers rooms **and tables** (`colors/color_picker.dart:18-67`). 2a ported the rooms' half as the kit types' colour targets; the tables' half is the placed units of the selection that the lock does not cover (a generated seat is never in the design's selection: Task 8 maps it to its row). Their colour is `jetcad.unit_colour`; the row lists the kit targets first, then the units, each in key order (today's rooms, then tables); a unit with a colour of another shape lists a marker that marks nothing (today's `_keptMarker`). `colourRowBlocked` is unchanged in kind: `components` refused → read-only, `recolor` off → refused.

Plan decision (the inspector, spec S4 "The unit inspector"): today's `_TableInspector` (`planner_shell.dart:1626-1700`) and `FloorPlanView._inspect` (`host/floor_plan_view.dart:622-643`), as one internal widget under the property panel: it shows for exactly one selected key, a root key whose target is a placed unit with a label no other unit has; it is built at a selection change that changes the unit shown (frame-safe), at each change of the plan while one is shown (`revision`), and at each host rebuild; never on pan, zoom or hover. It goes with the property panel (`propertyPanel: false` shows none). The design mode only: Task 16 shows `PlanServiceView` in service.

- [ ] **Step 1: The failing tests (new).** Create `test/l10n/unit_words_test.dart`:

```dart
// 2b Task 10, spec S4 "Words": a unit kind's word -- the kit's (through its
// KitWords, a host's word first), else PlanStrings' for the contract's
// kinds, else the kind as stored -- and the new words in each language.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_words.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

/// A booth (a kit's own kind), a table and a kiosk (no word anywhere) of
/// kit `bt`, each a closed outline off its base point.
CatalogSymbol unit(String key, String kind, int capacity) => CatalogSymbol(
      key: key,
      name: key,
      category: 'Tests',
      tags: const ['test'],
      unit: CatalogUnit(kind: kind, capacity: capacity),
      base: (410.5, 220.25),
      shapes: const [
        CatalogPolyline([(100, 50), (900, 50), (900, 650), (100, 650)],
            closed: true),
      ],
    );

final CatalogSymbol booth = unit('bt.booth.corner', 'booth', 6);
final CatalogSymbol table = unit('bt.table.round', UnitKinds.table, 4);
final CatalogSymbol kiosk = unit('bt.kiosk.small', 'kiosk', 2);

/// Kit `bt`: an English and a Turkish word for its booth; no type, no
/// library (the units are placed by hand).
PlanKit btKit() => PlanKit(
    id: 'bt',
    version: '1.0.0',
    names: const KitNames({
      'en': {'unit:bt/booth': 'Booth'},
      'tr': {'unit:bt/booth': 'Loca'},
    }));

String boothPlan() => planText([btKit()], (d) {
      placeAt(d, booth, Vector2(-2600.5, 1400.25), quarterTurns: 1);
      placeAt(d, table, Vector2(2300.75, 1400.5), mirrored: true);
      placeAt(d, kiosk, Vector2(900.25, -1700.75), quarterTurns: 3);
    });

/// The kind's word of the unit of kind [kind] in [c], at [locale].
String wordOf(PlanController c, String kind, String locale) {
  c.reportLocale(Locale(locale));
  return unitKindWord(
      c, c.unitIndex.units.singleWhere((u) => u.kind == kind));
}

void main() {
  test(
      'UW-kind-lookup the kit\'s word in Turkish, its English in German; '
      'PlanStrings\' word for a table; the stored kind with no word', () {
    final c = controllerFor(kits: [btKit()], json: boothPlan());
    // M-UW1: the kit's step skipped.
    expect(wordOf(c, 'booth', 'tr'), 'Loca');
    expect(wordOf(c, 'booth', 'de'), 'Booth', reason: 'the English fallback');
    // M-UW2: the PlanStrings step skipped.
    expect(wordOf(c, UnitKinds.table, 'tr'), 'Masa');
    expect(wordOf(c, UnitKinds.table, 'de'), 'Tisch');
    expect(wordOf(c, 'kiosk', 'tr'), 'kiosk');
  });

  test(
      'UW-host-word-first a host\'s word comes before the kit\'s, per '
      'locale; the kit\'s still answers where the host has none', () {
    final c = PlanController(
        kits: [btKit()],
        json: boothPlan(),
        words: const KitNames({
          'tr': {'unit:bt/booth': 'Bölme'},
        }));
    addTearDown(c.dispose);
    // M-UW3 (Task 4's merge, cross-check): `kit.names.merge(words)`.
    expect(wordOf(c, 'booth', 'tr'), 'Bölme');
    expect(wordOf(c, 'booth', 'en'), 'Booth');
  });

  test(
      'UW-words the unit words in each language: never empty, each '
      'language its own; unitKind for table and seat only', () {
    const languages = <PlanStrings>[
      PlanStringsEn(),
      PlanStringsDe(),
      PlanStringsTr(),
    ];
    for (final word in <String Function(PlanStrings)>[
      (s) => s.merge,
      (s) => s.split,
      (s) => s.number,
      (s) => s.label,
      (s) => s.capacity,
      (s) => s.rotateLeft,
      (s) => s.rotateRight,
      (s) => s.unitKind(UnitKinds.table)!,
      (s) => s.unitKind(UnitKinds.seat)!,
      (s) => s.labelWarning(const BadLabel(
          label: 'A\u0007', problem: UnitLabelProblem.control)),
    ]) {
      final words = [for (final s in languages) word(s)];
      expect(words, everyElement(isNotEmpty));
      expect(words.toSet(), hasLength(3), reason: '$words');
    }
    for (final s in languages) {
      // M-UW4: unitKind answering a word for any kind.
      expect(s.unitKind('booth'), isNull, reason: s.languageCode);
    }
    expect(const PlanStringsEn().unitKind(UnitKinds.seat), 'Seat');
  });
}
```

  Create `test/panels/unit_section_test.dart` with the new cases (the ported TS cases join it in Step 2):

```dart
// 2b Task 10, spec S4 "The unit inspector" (the unit section): one selected
// placed unit shows its kind, its label field (Number for a numbered unit,
// Label for an assigned one; gated by relabel), its capacity and the ±90
// buttons (gated by rotate). Ported from jet_cad_floor_plan's
// tables/table_section_test.dart (TS1-TS8, assertions unchanged) and new
// cases (UW-*). Units are placed off the origin, turned and mirrored.
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/authoring.dart' show CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

Finder get section => find.byKey(const Key('unit-section'));
Finder get label => find.byKey(const Key('unit-label'));
Finder get capacity => find.byKey(const Key('unit-capacity'));
Finder get error => find.byKey(const Key('unit-label-error'));
Finder get duplicate => find.byKey(const Key('unit-label-duplicate'));
Finder get left => find.byKey(const Key('unit-rotate-left'));
Finder get right => find.byKey(const Key('unit-rotate-right'));

String fieldText(WidgetTester tester) =>
    tester.widget<TextField>(label).controller!.text;

/// The label field's title.
String fieldTitle(WidgetTester tester) =>
    tester.widget<TextField>(label).decoration!.labelText!;

Future<void> pumpPanel(WidgetTester tester, PlanController c) =>
    pumpApp(tester, SingleChildScrollView(child: PlanPropertyPanel(controller: c)));

Future<void> select(WidgetTester tester, PlanController c, Handle h) async {
  c.selection.replace([SelectionKey.root(h)]);
  await tester.pump();
}

Future<void> enterAndSubmit(WidgetTester tester, String text) async {
  await tester.pump(kDoubleTapTimeout * 2);
  await tester.tap(label);
  await tester.pump();
  await tester.enterText(label, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  await tester.pump();
}

/// A seat (an assigned unit): [tableSymbol]'s shapes and base point.
const CatalogSymbol seatSymbol = CatalogSymbol(
  key: 'fx.seat.single',
  name: 'Test seat',
  category: 'Tests',
  tags: ['seat', 'test'],
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
        closed: true),
  ],
);

/// A seat placed by hand (no label) and a table labelled 1, both off the
/// origin, turned or mirrored.
({String json, String seatKey}) seatAndTable() {
  final json = planText([fxKit()], (d) {
    placeAt(d, seatSymbol, Vector2(-2400.5, 1300.25), quarterTurns: 1);
    addUnitLabel(
        d,
        placeAt(d, tableSymbol(seats: 4), Vector2(2400.75, 1300.5),
            mirrored: true),
        '1');
  });
  return (json: json, seatKey: seatSymbol.key);
}

void main() {
  testWidgets(
      'UW-section-assigned an assigned unit: the kind\'s word as the title, '
      'the field titled Label, empty; typing gives it a label', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: [fxKit()], json: f.json);
    await pumpPanel(tester, c);
    final seat = c.unitIndex.units.singleWhere((u) => u.text == null);
    await select(tester, c, seat.instance);
    expect(tester.widget<Text>(section).data, 'Seat');
    // M-UW5: the field always titled by `number`.
    expect(fieldTitle(tester), 'Label');
    expect(fieldText(tester), '');
    await enterAndSubmit(tester, 'S1');
    expect(c.unitIndex.withLabel('S1').single.instance, seat.instance);
    final table = c.unitIndex.withLabel('1').single;
    await select(tester, c, table.instance);
    expect(fieldTitle(tester), 'Number');
    expect(tester.widget<Text>(capacity).data, '4');
  });

  testWidgets(
      'UW-relabel-gate relabel off: the field is read-only and a typed '
      'label commits nothing; the buttons still show', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: [fxKit()], json: f.json);
    c.permissions = PlanPermissions.full.copyWith(relabel: false);
    await pumpPanel(tester, c);
    final table = c.unitIndex.withLabel('1').single;
    await select(tester, c, table.instance);
    // M-UW6: `_editable` of the unit target ignoring `relabel`.
    expect(tester.widget<TextField>(label).readOnly, isTrue);
    final depth = c.document.commands.undoDepth;
    await enterAndSubmit(tester, '5');
    expect(c.document.commands.undoDepth, depth);
    expect(c.unitIndex.withLabel('1'), hasLength(1));
    expect(left, findsOneWidget);
  });

  testWidgets(
      'UW-locked-none a placed unit under the lock (its kit missing) shows '
      'no unit section', (tester) async {
    final f = seatAndTable();
    final c = controllerFor(kits: const [], json: f.json);
    await pumpPanel(tester, c);
    final table = c.unitIndex.withLabel('1').single;
    expect(c.isLocked(table.instance), isTrue, reason: 'premise');
    await select(tester, c, table.instance);
    // M-UW7: the unit target ignoring `isLocked`.
    expect(section, findsNothing);
  });
}
```

  (The file's imports gain `CatalogPolyline` and `CatalogSymbol` from `package:jet_cad_2d_kit/authoring.dart`.)

- [ ] **Step 2: The ported tests.** Each file below is its source with the listed adaptations; **assertions unchanged**. Common adaptations as Task 9's Step 3 (the controller over a plan file, the barrel, `c.document`, `c.selection`), plus: `SelectionPanel(document: doc, selection: s)` → `PlanPropertyPanel(controller: c)`; the old keys `table-section`, `table-number`, `table-seats`, `table-number-error`, `table-number-duplicate`, `table-rotate-left`, `table-rotate-right`, `table-inspector` → `unit-section`, `unit-label`, `unit-capacity`, `unit-label-error`, `unit-label-duplicate`, `unit-rotate-left`, `unit-rotate-right`, `unit-inspector`; `selection-panel` → `property-panel`; `layers-panel` → `find.byType(PlanLayerPanel)`; `tableInspectorBuilder` → `unitInspectorBuilder`; `FloorPlanEditorCapabilities.full.copyWith(selectionPanel: false)` → `PlanEditor(propertyPanel: false)`; `FloorPlanTool.select` → `'plan.select'`; the letter `W` → `L` (2a's generic letters).
  1. `test/panels/unit_section_test.dart` (above) gains `tables/table_section_test.dart`'s TS1, TS2, TS3, TS3b, TS4, TS5, TS6, TS7, TS8. `rig()` → a controller over `planText([fxKit()], …)` (the controller installs the parametric system, the label system and the lock); `placeOne(doc, s, at, quarterTurns:, mirrored:)` → `placeAt(c.document, s, at, …)` followed by `addUnitLabel(c.document, h, n)` with `n` the number today's placer gave (`'1'`, `'2'`, … in placement order), except TS4, whose second placement is the placer's own (Task 7's `placeSymbol` through `c.execute`) because its premise is the placer's next number (101 → 102); `planterSymbol` and `tableSymbol` are the fixture's; `numbers(doc)` → `[for (final u in c.unitIndex.units) u.text]`; `tablesOf(doc)` → `c.unitIndex.units`; TS8's runtime permissions are set as `c.document.commands.permissions = DraftPermissions.runtime`. TS9 and TS10 (`rotateTableCommand` alone; the label on a hidden layer) are Task 7's (its Step 8 item 4 ports them).
  2. `test/editor/unit_inspector_test.dart` from `host/inspector_test.dart`: M-H45, T6-d, T6-f, "the inspector reaches the host's state …". `mountInspector` → `PlanEditor(controller: c, propertyPanel: h.panel.value, unitInspectorBuilder: …)` in `kEditorSurface` over `unitEditorPlanJson()` under `editorCamera()`, the host's `caps` notifier becoming a `ValueNotifier<bool> panel` (T6-f); `liveObjectsOf<WallParams>(c.activeDocument).first` → the north wall's line (the root line between `editorNorthWall`'s points); `c.selectedTables` → `c.editorSelectedUnits`; `d.table.number` → `d.unit.label`; `setTableData` → `setUnitData`; `t.centreOf`, `t.screenOf` → the editor fixture's; `editorTextAt` the fixture's. "none without a builder …; none in the selection mode" and T6-e need the mode (Task 16 ports them whole, its Step B2b item 10).
  3. `test/l10n/value_words_test.dart` (2a's) gains VW2 and VW3's unit halves: `FloorPlanStrings` → `PlanStrings`; `TableNumberProblem` → `UnitLabelProblem`; `s.tableNumberProblem(p)` → `s.labelProblem(p)`; `tableNumberError('')` → `const PlanStringsEn().labelProblem(UnitLabelProblem.length)` (the English text today's `tableNumberError` returned, so the line keeps its assertion); `s.tableNumberUsed('12')` → `s.labelUsed('12')`; `s.numberingWarning(const DuplicateNumber(number: '7', count: 3))` → `s.labelWarning(const DuplicateLabel(label: '7', count: 3))`; `Unnumbered(seats: 4, symbolKey: 'k')` → `Unlabelled(kind: 'table', capacity: 4, symbolKey: 'k')`; `Unnumbered(seats: 1, symbolKey: null)` → `Unlabelled(kind: 'table', capacity: 1, symbolKey: null)`. VW3's `roomOccupied` line is sub-project 3's.
  4. `test/l10n/stale_error_test.dart` from `l10n/stale_error_test.dart`: SE1, ported as **SE1L** (the label error re-worded on a language switch; Task 14 ports `service_events_test.dart`'s SE1 … SE16 under their source ids, and 2a named this file's SE2 `SE2L` for the same reason). `twoTables()` → two `tableSymbol()` units placed with `placeAt` (`quarterTurns: 1` for the first) and labelled `1` and `2`, and the layer `Bar`, in a plan file over `fxKit()`; `FloorPlanView` → `PlanEditor` with `planSupportedLocales` and `planLocalizationsDelegates`; `'table-number'` → `'unit-label'`, `'table-number-error'` → `'unit-label-error'`. SE2 (the layer name) is 2a's ground.
  5. `test/panels/colour_row_test.dart` (2a's) gains CP7, CP8, CP9, CP10, CP11, CP12. The file's fixture gains two placed units of `tableSymbol(seats: 4)` labelled `1` and `2` and a third labelled `7` (placed with `placeAt`, off the origin, one turned, one mirrored) and loads `fxKit()` beside its kits; "a room" is the file's box `A`; `c.tableDetails` → `c.unitDetails`; `FloorPlanColor.teal` → `PlanSwatch.teal`; `Caps.tablesOnly` → `c.permissions = PlanPermissions.unitsOnly`; CP10's "without components" sets the document's permissions as CP4 does; CP11's "the active Wall tool" → `c.selectTool('plan.line')`; CP12's survey counter → Task 6's `UnitIndex` build counter (its `@visibleForTesting` name; if Task 6 has none, add `@visibleForTesting static int debugBuilds = 0;` to `UnitIndex`, incremented in `UnitIndex.of`, in this task), `pickedColors(doc, keys)` → `pickedColours(c, keys)`, `recolorCommand(doc, keys, …)` → `recolourCommand(c, keys, …)`, and `isTable(doc, h)` → `c.unitIndex[h]?.generated == false` (the unit test of the placed-unit rule).
  6. `test/panels/symbol_section_test.dart` (2a's) gains SW6 (`symbols/symbol_section_test.dart:519-597`: a corner unit turned to 37 then mirrored, its label upright, its footprint kept, one undo each; the label read with `c.unitIndex[h]!.label`) and SW9 (`:598-626`: a rotation typed under runtime for a box, the selection moved to a unit before the edit ends: the pinned target decides), over the file's fixture with one `tableSymbol(seats: 4)` unit added.
  7. `test/panels/hover_removal_test.dart` (2a's) gains HR2 (`hover_removal_test.dart:58-…`: a hovered unit of the embedding fixture in `PlanEditor`, then the editor removed in one pump; `embeddingController()` of Task 9's support).
  8. `test/editor/units_only_select_test.dart` (Task 8's) gains T5-b (`editor_select_test.dart:294-330`: readOnly, 1 selected, no rotation grip, no ±90, a read-only Rotation field; unitsOnly: the grip turns it and `unit-rotate-left` shows).
  9. `test/editor/editor_words_test.dart` (2a's) gains OV-H's unit half (`l10n/overflow_test.dart:84-112`): for `en`, `de`, `tr`, at 656 x 700, `unitEditorPlanJson()`'s table `1` selected, then the unlabelled one, then `7`: no exception (no overflow) from the right panel.
  - Not ported here: LK2's and the determinism test's table halves (`l10n/leak_test.dart:186-258`, `l10n/determinism_test.dart`) place a table from the restaurant library (`dining.table.square.two@2`): sub-project 4's.

- [ ] **Step 3: Run the tests, see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/l10n/unit_words_test.dart test/panels/unit_section_test.dart`. Expected: compile errors — `unitKindWord`, `PlanStrings.label`, `unitKind`, `labelWarning` and the rest are not defined.

- [ ] **Step 4: The words.** In `lib/src/l10n/strings.dart` import `'../units/unit_label.dart' show UnitLabelProblem;` and `'../units/unit_problems.dart' show UnitLabelWarning;` and add before the closing brace:

```dart
  // The units and the service mode (sub-project 2b).

  /// The service bar's Merge.
  String get merge;

  /// The service bar's Split.
  String get split;

  /// The label field's title for a numbered unit ("Number").
  String get number;

  /// The label field's title for an assigned unit ("Label").
  String get label;

  /// The capacity read-out's title (today's "Seats").
  String get capacity;

  /// "Rotate 90° left".
  String get rotateLeft;

  /// "Rotate 90° right".
  String get rotateRight;

  /// Why a text cannot be a unit's label (the text rule).
  String labelProblem(UnitLabelProblem problem);

  /// A label another unit already holds.
  String labelUsed(String label);

  /// One of the plan's labelling problems.
  String labelWarning(UnitLabelWarning warning);

  /// The contract's unit kinds' words: `table` and `seat`; null for any
  /// other kind (a kit words its own, `unit:<kit>/<kind>`).
  String? unitKind(String kind);
```

  In `strings_en.dart` (imports: `UnitKinds` from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `'../units/unit_label.dart' show UnitLabelProblem, kUnitLabelMaxLength;` and `'../units/unit_problems.dart' show BadLabel, DuplicateLabel, Unlabelled, UnitLabelWarning;`), before the closing brace:

```dart
  @override
  String get merge => 'Merge';

  @override
  String get split => 'Split';

  @override
  String get number => 'Number';

  @override
  String get label => 'Label';

  @override
  String get capacity => 'Seats';

  @override
  String get rotateLeft => 'Rotate 90° left';

  @override
  String get rotateRight => 'Rotate 90° right';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length => '1 to $kUnitLabelMaxLength characters',
        UnitLabelProblem.control => 'No line breaks or control characters',
      };

  @override
  String labelUsed(String label) => 'Number $label is already used';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          'Number $label is used by $count tables',
        Unlabelled(:final kind, :final capacity) => capacity == 1
            ? 'A ${_kindLower(kind)} with 1 seat has no number'
            : 'A ${_kindLower(kind)} with $capacity seats has no number',
        BadLabel(:final label, :final problem) =>
          '"$label" is no label: ${labelProblem(problem)}',
      };

  String _kindLower(String kind) => (unitKind(kind) ?? kind).toLowerCase();

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Table',
        UnitKinds.seat => 'Seat',
        _ => null,
      };
```

  In `strings_de.dart` (the same imports):

```dart
  @override
  String get merge => 'Zusammenlegen';

  @override
  String get split => 'Trennen';

  @override
  String get number => 'Nummer';

  @override
  String get label => 'Bezeichnung';

  @override
  String get capacity => 'Plätze';

  @override
  String get rotateLeft => '90° nach links drehen';

  @override
  String get rotateRight => '90° nach rechts drehen';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length => '1 bis $kUnitLabelMaxLength Zeichen',
        UnitLabelProblem.control => 'Keine Zeilenumbrüche oder Steuerzeichen',
      };

  @override
  String labelUsed(String label) => 'Die Nummer $label ist bereits vergeben';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          'Die Nummer $label wird von $count Tischen verwendet',
        Unlabelled(:final kind, :final capacity) => kind == UnitKinds.table
            ? (capacity == 1
                ? 'Ein Tisch mit 1 Platz hat keine Nummer'
                : 'Ein Tisch mit $capacity Plätzen hat keine Nummer')
            : '${unitKind(kind) ?? kind} mit $capacity '
                '${capacity == 1 ? 'Platz' : 'Plätzen'} hat keine Nummer',
        BadLabel(:final label, :final problem) =>
          '„$label" ist keine Bezeichnung: ${labelProblem(problem)}',
      };

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Tisch',
        UnitKinds.seat => 'Sitzplatz',
        _ => null,
      };
```

  In `strings_tr.dart` (the same imports):

```dart
  @override
  String get merge => 'Birleştir';

  @override
  String get split => 'Ayır';

  @override
  String get number => 'Numara';

  @override
  String get label => 'Etiket';

  @override
  String get capacity => 'Kişilik';

  @override
  String get rotateLeft => '90° sola döndür';

  @override
  String get rotateRight => '90° sağa döndür';

  @override
  String labelProblem(UnitLabelProblem problem) => switch (problem) {
        UnitLabelProblem.length =>
          '1 ile $kUnitLabelMaxLength karakter arasında olmalı',
        UnitLabelProblem.control => 'Satır sonu veya kontrol karakteri olamaz',
      };

  @override
  String labelUsed(String label) => '$label numarası zaten kullanılıyor';

  @override
  String labelWarning(UnitLabelWarning warning) => switch (warning) {
        DuplicateLabel(:final label, :final count) =>
          '$label numarası $count masada kullanılıyor',
        Unlabelled(:final kind, :final capacity) => kind == UnitKinds.table
            ? '$capacity kişilik bir masanın numarası yok'
            : '$capacity kişilik ${unitKind(kind) ?? kind}: numara yok',
        BadLabel(:final label, :final problem) =>
          '"$label" bir etiket değil: ${labelProblem(problem)}',
      };

  @override
  String? unitKind(String kind) => switch (kind) {
        UnitKinds.table => 'Masa',
        UnitKinds.seat => 'Koltuk',
        _ => null,
      };
```

  In `test/support/recording_plan_strings.dart`, add (the class implements `PlanStrings`, so the compiler names every missing member):

```dart
  @override
  String get merge => record(inner.merge);
  @override
  String get split => record(inner.split);
  @override
  String get number => record(inner.number);
  @override
  String get label => record(inner.label);
  @override
  String get capacity => record(inner.capacity);
  @override
  String get rotateLeft => record(inner.rotateLeft);
  @override
  String get rotateRight => record(inner.rotateRight);
  @override
  String labelProblem(UnitLabelProblem problem) =>
      record(inner.labelProblem(problem));
  @override
  String labelUsed(String label) => record(inner.labelUsed(label));
  @override
  String labelWarning(UnitLabelWarning warning) =>
      record(inner.labelWarning(warning));
  @override
  String? unitKind(String kind) => switch (inner.unitKind(kind)) {
        null => null,
        final w => record(w),
      };
```

  with `import 'package:jet_cad_2d_plan/src/units/unit_label.dart' show UnitLabelProblem;` and `import 'package:jet_cad_2d_plan/src/units/unit_problems.dart' show UnitLabelWarning;`.

- [ ] **Step 5: The kind's word.** In `lib/src/controller/plan_controller.dart`, beside `reportLocale`:

```dart
  /// The language class the widgets last reported (a host's own included),
  /// else the built-in language of [locale]: the plan library's words
  /// outside a widget (the unit kinds', `unitKindWord`).
  @internal
  PlanStrings get planStrings =>
      _reportedStrings ?? PlanStrings.forLocale(_locale.value);
```

  Create `lib/src/units/unit_words.dart`:

```dart
// A unit kind's word (spec 2b S4 "Words"): the kit's own, as
// `unit:<kit id>/<kind>` in its KitNames (a host's word first, through the
// kit's KitWords, Task 4); else the contract's word in PlanStrings (table,
// seat); else the kind as stored. The kit id is the unit's symbol key's
// first segment; a unit with no symbol key skips the kit's word.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kitOfKey;

import '../controller/plan_controller.dart';
import 'unit_index.dart';

/// [unit]'s kind in the controller's language.
String unitKindWord(PlanController c, UnitInfo unit) {
  final key = unit.symbolKey;
  if (key != null) {
    final kit = kitOfKey(key);
    if (c.kits.kitOf(kit) != null) {
      final word = c.servicesOf(kit).words.maybe('unit:$kit/${unit.kind}');
      if (word != null) return word;
    }
  }
  return c.planStrings.unitKind(unit.kind) ?? unit.kind;
}
```

- [ ] **Step 6: The unit section's model.** Create `lib/src/panels/unit_section.dart`:

```dart
// The unit section's model (spec 2b S4, the unit section; today's Table
// section, jet_cad_floor_plan/lib/src/selection_panel.dart:437-456,
// :1193-1248): which placed unit it shows and why a text cannot be its
// label. The widgets are the property panel's.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../l10n/strings.dart';
import '../units/unit_index.dart';
import '../units/unit_label.dart' show unitLabelProblem;

/// The placed unit [handle] names in [index], or null (no unit, or a
/// generated one: its object stands for it in design).
UnitInfo? placedUnitOf(UnitIndex index, Handle handle) {
  final u = index[handle];
  return u == null || u.generated ? null : u;
}

/// Why [text] (trimmed) cannot be [unit]'s label, worded on demand: the
/// text rule's problem, or a label another unit holds (today's
/// `_parseNumber`, :437-456). Null when it can, or when it is the unit's
/// own label (an unlabelled unit's empty field included: no error).
String Function(PlanStrings)? labelRefusal(
    UnitIndex index, UnitInfo unit, String text) {
  final t = text.trim();
  if (t == (unit.text ?? '')) return null;
  final problem = unitLabelProblem(t);
  if (problem != null) return (s) => s.labelProblem(problem);
  if (index.withLabel(t).any((o) => o.instance != unit.instance)) {
    return (s) => s.labelUsed(t);
  }
  return null;
}
```

- [ ] **Step 7: The panel.** In `lib/src/panels/plan_property_panel.dart` (imports: `'../units/unit_index.dart'`, `'../units/unit_problems.dart' show DuplicateLabel`, `'../units/unit_rotate.dart' show rotateUnitCommand`, `'../units/unit_words.dart'`, `'../units/unit_writes.dart' show unitLabelCommand`, `'unit_section.dart'`):
  1. A target and a scope:

```dart
final class _UnitTarget extends _Target {
  const _UnitTarget(this.handle);

  final Handle handle;

  @override
  bool operator ==(Object other) =>
      other is _UnitTarget && other.handle == handle;

  @override
  int get hashCode => Object.hash(_UnitTarget, handle);
}
```

     `enum _Scope { object, tool, symbol }` → `enum _Scope { object, tool, symbol, unit }`.
  2. The state gains the refusal line and the target:

```dart
  /// The label field's last refusal and the unit it was for (today's
  /// `_numberError`, selection_panel.dart:244-249).
  String Function(PlanStrings)? _labelError;
  Handle? _labelErrorFor;

  _UnitTarget? get _unitTarget {
    final h = _single;
    if (h == null || _c.isLocked(h)) return null;
    return placedUnitOf(_c.unitIndex, h) == null ? null : _UnitTarget(h);
  }
```

  3. `_targetOf` gains `_Scope.unit => _unitTarget,`; `_fieldsOrNull` gains `case _UnitTarget(): return const [];`; `_kitOf` gains `_UnitTarget() => 'plan',`; `_guarded`'s subject switch gains `_UnitTarget() => 'plan.unit',`.
  4. `_shown`, before its symbol case:

```dart
    if (t case _UnitTarget(:final handle)) {
      final u = placedUnitOf(_c.unitIndex, handle);
      return u == null ? null : (u.text ?? '');
    }
```

  5. `_parse`, before its symbol line:

```dart
    if (t case _UnitTarget(:final handle)) {
      final u = placedUnitOf(_c.unitIndex, handle);
      if (u == null) return null;
      final refusal = labelRefusal(_c.unitIndex, u, text);
      if (refusal == null) return text;
      // The line is not cleared here: Enter's focus-loss commit re-reads
      // the reverted text, which must not end it (today's T14).
      _labelError = refusal;
      _labelErrorFor = handle;
      return null;
    }
```

  6. `_editable` gains:

```dart
      case _UnitTarget():
        // A label is entity text (today's _editable, :362-366).
        return c.permissions.relabel && engine.allows(Capability.geometry);
```

  7. `_write` gains:

```dart
        case _UnitTarget(:final handle):
          final u = placedUnitOf(c.unitIndex, handle);
          if (u == null) return;
          final command = unitLabelCommand(c.document, u, input! as String);
          if (command != null) c.execute(command);
```

  8. `_onChanged` gains as its first line `if (f.scope == _Scope.unit && _labelError != null) setState(() => _labelError = null);`; `_sync` gains as its first lines (today's `:1002-1006`):

```dart
    // A selection change ends the label field's refusal line.
    if (_labelError != null && _labelErrorFor != _unitTarget?.handle) {
      _labelError = null;
    }
```

  9. The section, after `_symbolSection`:

```dart
  /// The unit section (spec S4; today's Table section,
  /// selection_panel.dart:1193-1248).
  List<Widget> _unitSection(_UnitTarget t, TextStyle? title) {
    final c = _c;
    final u = placedUnitOf(c.unitIndex, t.handle)!;
    final error =
        _labelErrorFor == t.handle ? _labelError?.call(_strings) : null;
    final shared =
        u.text == null ? 0 : c.unitIndex.withLabel(u.text!).length;
    final theme = Theme.of(context);
    final engine = c.document.commands.permissions;
    final turnable = engine.allows(Capability.transform) &&
        engine.allows(Capability.geometry);
    return [
      Text(unitKindWord(c, u), key: const Key('unit-section'), style: title),
      _textField(
          const Key('unit-label'),
          u.labelling == UnitLabelling.assigned
              ? _strings.label
              : _strings.number,
          _fieldFor(_Scope.unit, 'label'),
          _editable(t, 'label'),
          isText: true),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(error,
              key: const Key('unit-label-error'),
              style: TextStyle(color: theme.colorScheme.error)),
        ),
      if (shared > 1)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              _strings.labelWarning(
                  DuplicateLabel(label: u.text!, count: shared)),
              key: const Key('unit-label-duplicate'),
              style: TextStyle(color: theme.colorScheme.tertiary)),
        ),
      InputDecorator(
        decoration: InputDecoration(
            labelText: _strings.capacity, border: InputBorder.none),
        child: Text('${u.capacity}', key: const Key('unit-capacity')),
      ),
      // A button the permissions refuse is not shown (S-11).
      if (turnable && c.permissions.rotate)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('unit-rotate-left'),
                onPressed: () => _rotateUnit(t, 1),
                icon: const Icon(Icons.rotate_left),
                label: Text(_strings.rotateLeft),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('unit-rotate-right'),
                onPressed: () => _rotateUnit(t, -1),
                icon: const Icon(Icons.rotate_right),
                label: Text(_strings.rotateRight),
              ),
            ),
          ],
        ),
    ];
  }

  /// Today's `_rotateTable` (:685-701): one Rotate step about the base
  /// point; a refusal is caught inside `execute`.
  void _rotateUnit(_UnitTarget t, int quarterTurns) =>
      _guarded(t, 'Rotate', () {
        final command = rotateUnitCommand(_c.document, t.handle, quarterTurns);
        if (command != null) _c.execute(command);
      });
```

     `UnitLabelling` comes from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (already imported). In `build`, after `final symbol = …;` add `final unit = tool == null && object == null ? _unitTarget : null;`, and in `sections`, after `if (symbol != null) _symbolSection(symbol, title),` add `if (unit != null) _unitSection(unit, title),`. The colour condition becomes `tool == null && (colourTargets(c, c.selection.keys).isNotEmpty || unitColourTargets(c, c.selection.keys).isNotEmpty)`.

- [ ] **Step 8: The colour row over units.** In `lib/src/panels/colour_row.dart` (imports: `'../units/unit_components.dart' show UnitColour`, `'../units/unit_index.dart'`):

```dart
/// The placed units among [keys], each once, in key order, that the lock
/// does not cover (today's `_tables`, colors/color_picker.dart:24-35: a
/// key's target is a placed unit's instance). Per key, read from the
/// controller's cached index: the panel asks on every build, hovers
/// included.
List<Handle> unitColourTargets(PlanController c, Iterable<SelectionKey> keys) {
  if (keys.isEmpty) return const [];
  final index = c.unitIndex;
  return [
    for (final h in {for (final k in keys) k.target})
      if (index[h]?.generated == false && !c.isLocked(h)) h,
  ];
}
```

     `pickedColours` lists the units after the kit targets:

```dart
List<String?> pickedColours(PlanController c, Iterable<SelectionKey> keys) => [
      for (final t in colourTargets(c, keys)) _colourOf(c, t),
      for (final h in unitColourTargets(c, keys))
        switch (c.document.components.get<UnitColour>(h)) {
          null => null,
          // A payload of another shape marks nothing (today's _keptMarker).
          final u => u.name ?? _unreadable,
        },
    ];
```

     `recolourCommand`, after the kit targets' loop and before its `return`:

```dart
  final wanted = swatch == null ? null : UnitColour(swatch);
  for (final h in unitColourTargets(c, keys)) {
    if (doc.components.get<UnitColour>(h) != wanted) {
      edits.add(SetComponentCommand<UnitColour>(h, wanted));
    }
  }
```

     `colourRowBlocked` is unchanged (a unit's colour needs `components` alone, which its first test reads). The file's header comment gains: "Placed units are today's tables (2b Task 10): `jetcad.unit_colour` on the instance."

- [ ] **Step 9: The inspector.** Create `lib/src/editor/unit_inspector.dart`:

```dart
// The host's unit inspector (spec 2b S4 "The unit inspector"; today's
// _TableInspector, jet_cad_floor_plan/lib/src/planner_shell.dart:1626-1700,
// and FloorPlanView._inspect, host/floor_plan_view.dart:622-643): built under
// the property panel for exactly one selected placed unit whose label no
// other unit has; again when the unit shown changes (a selection change,
// frame-safe), at each change of the plan while one is shown (the detail is
// read fresh), and at each host rebuild. A hover, the camera and a selection
// change that keeps the unit build nothing.
import 'package:flutter/widgets.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionController;

import '../controller/plan_controller.dart';
import '../panels/frame_safe_relay.dart';
import '../units/unit_detail.dart';

class UnitInspector extends StatefulWidget {
  const UnitInspector(
      {super.key, required this.controller, required this.builder});

  final PlanController controller;
  final Widget? Function(BuildContext context, PlanUnitDetail unit) builder;

  @override
  State<UnitInspector> createState() => _UnitInspectorState();
}

class _UnitInspectorState extends State<UnitInspector> {
  /// The unit shown; null for none.
  Handle? _shown;
  SelectionController? _selection;
  FrameSafeRelay? _relay;

  @override
  void initState() {
    super.initState();
    _bind();
    widget.controller.revision.addListener(_onDocument);
    _shown = _inspected();
  }

  @override
  void didUpdateWidget(UnitInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.revision.removeListener(_onDocument);
      widget.controller.revision.addListener(_onDocument);
    }
    _bind();
    _shown = _inspected();
  }

  @override
  void dispose() {
    widget.controller.revision.removeListener(_onDocument);
    _unbind();
    super.dispose();
  }

  /// The relay over the controller's current selection (a new one per
  /// document).
  void _bind() {
    final selection = widget.controller.selection;
    if (identical(selection, _selection)) return;
    _unbind();
    _selection = selection;
    _relay = FrameSafeRelay(selection)..addListener(_onSelection);
  }

  void _unbind() {
    _relay
      ?..removeListener(_onSelection)
      ..dispose();
    _relay = null;
    _selection = null;
  }

  /// The selection's one key when it is a root key on a placed unit.
  Handle? _inspected() {
    final c = widget.controller;
    final keys = c.selection.keys;
    if (keys.length != 1) return null;
    final key = keys.single;
    if (key.chain.isNotEmpty) return null;
    return c.unitIndex[key.target]?.generated == false ? key.target : null;
  }

  void _onSelection() {
    final next = _inspected();
    if (next == _shown) return;
    setState(() => _shown = next);
  }

  void _onDocument() {
    _bind();
    final next = _inspected();
    if (next == null && _shown == null) return;
    setState(() => _shown = next);
  }

  /// [instance]'s fresh detail, or null for an unlabelled unit or a label
  /// another unit shares (today's _inspect: the label names no one unit,
  /// and setUnitData refuses it).
  PlanUnitDetail? _detail(Handle instance) {
    final c = widget.controller;
    final details = c.unitDetails;
    final i = c.unitDetailInstances.indexOf(instance);
    if (i < 0) return null;
    final detail = details[i];
    final label = detail.unit.label;
    if (label == null) return null;
    for (var j = 0; j < details.length; j++) {
      if (j != i && details[j].unit.label == label) return null;
    }
    return detail;
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final detail = shown == null ? null : _detail(shown);
    if (detail == null) return const SizedBox.shrink();
    return widget.builder(context, detail) ?? const SizedBox.shrink();
  }
}
```

  In `lib/src/editor/plan_editor.dart`: import `'../units/unit_detail.dart'` and `'unit_inspector.dart'`; the constructor gains `this.unitInspectorBuilder,` and the widget the field:

```dart
  /// The host's unit inspector (spec S4; today's `tableInspectorBuilder`):
  /// built under the property panel for exactly one selected placed unit
  /// whose label no other unit has, with nothing else selected, with that
  /// unit's detail as `unitDetails` reads it; null from it shows nothing.
  /// Built when the selection becomes such a unit, at each change of the
  /// plan, and at each host rebuild; never on pan, zoom or hover. Hidden
  /// with the property panel. A host links a drawn unit to its own record
  /// here, with `PlanController.setUnitData`.
  final Widget? Function(BuildContext context, PlanUnitDetail unit)?
      unitInspectorBuilder;
```

  In the right column's `Column` (`:644-652`), right after `_kept(widget.propertyPanel, PlanPropertyPanel(controller: c)),`:

```dart
                                // Spec S4: the host's inspector under the
                                // panel's fields, with the panel. Keyed, so
                                // adding or removing it keeps the panels
                                // below.
                                if (widget.unitInspectorBuilder
                                    case final inspect?
                                    when widget.propertyPanel)
                                  UnitInspector(
                                      key: const Key('unit-inspector'),
                                      controller: c,
                                      builder: inspect),
```

- [ ] **Step 10: Run the tests, see them pass.** Run: `cd packages/jet_cad_2d_plan && flutter test test/l10n/ test/panels/ test/editor/`. Expected: `All tests passed!`. Then the whole package: `flutter test`, `All tests passed!`.

- [ ] **Step 11: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. From the root, `git status --short`: only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/l10n/strings.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_en.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_de.dart packages/jet_cad_2d_plan/lib/src/l10n/strings_tr.dart packages/jet_cad_2d_plan/lib/src/units/unit_words.dart packages/jet_cad_2d_plan/lib/src/panels/unit_section.dart packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/lib/src/panels/colour_row.dart packages/jet_cad_2d_plan/lib/src/editor/unit_inspector.dart packages/jet_cad_2d_plan/lib/src/editor/plan_editor.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/test/support/recording_plan_strings.dart packages/jet_cad_2d_plan/test/l10n/unit_words_test.dart packages/jet_cad_2d_plan/test/l10n/value_words_test.dart packages/jet_cad_2d_plan/test/l10n/stale_error_test.dart packages/jet_cad_2d_plan/test/panels/unit_section_test.dart packages/jet_cad_2d_plan/test/panels/colour_row_test.dart packages/jet_cad_2d_plan/test/panels/symbol_section_test.dart packages/jet_cad_2d_plan/test/panels/hover_removal_test.dart packages/jet_cad_2d_plan/test/editor/unit_inspector_test.dart packages/jet_cad_2d_plan/test/editor/units_only_select_test.dart packages/jet_cad_2d_plan/test/editor/editor_words_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): unit words, the unit section and the unit inspector (2b S4)

PlanStrings gains the unit and service words in English, German and
Turkish, today's table texts kept. A unit kind is worded by its kit
(a host's word first), else by the contract's word, else as stored.
The property panel shows one placed unit's kind, its label field
(Number or Label, gated by relabel), its capacity and the ±90 buttons;
the colour row covers placed units; PlanEditor takes a host's unit
inspector with today's eligibility.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-UW1 `lib/src/units/unit_words.dart`: delete the `if (key != null) { … }` block → UW-kind-lookup red (`test/l10n/unit_words_test.dart`).
  - M-UW2 same file: `return c.planStrings.unitKind(unit.kind) ?? unit.kind;` → `return unit.kind;` → UW-kind-lookup red.
  - M-UW3 (cross-check, Task 4's committed `lib/src/controller/plan_controller.dart`): each kit's `KitNamesWords` over `kit.names.merge(words)` in place of `words.merge(kit.names)` → UW-host-word-first red.
  - M-UW4 `lib/src/l10n/strings_en.dart`: in `unitKind`, `_ => null` → `_ => kind` → UW-words red.
  - M-UW5 `lib/src/panels/plan_property_panel.dart`: `u.labelling == UnitLabelling.assigned ? _strings.label : _strings.number` → `_strings.number` → UW-section-assigned red (`test/panels/unit_section_test.dart`).
  - M-UW6 same file: in `_editable`'s unit case, `c.permissions.relabel &&` deleted → UW-relabel-gate red.
  - M-UW7 same file: in `_unitTarget`, `|| _c.isLocked(h)` deleted → UW-locked-none red.
  - M-UW8 same file: in `_parse`'s unit case, `if (refusal == null) return text;` → `return text;` (every refusal ignored) → the ported TS3 red.
  - M-UW9 `lib/src/editor/unit_inspector.dart`: in `_detail`, delete the shared-label loop → the ported M-H45 red (`test/editor/unit_inspector_test.dart`, `7 alone`).
  - M-UW10 same file: in `_onSelection`, delete `if (next == _shown) return;` → the ported T6-d red (a call per selection notification that keeps the unit).
  - M-UW11 `lib/src/panels/colour_row.dart`: in `pickedColours`, `final u => u.name ?? _unreadable` → `final u => u.name` → the ported CP8 red (`test/panels/colour_row_test.dart`).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 6 (`lib/src/units/unit_label.dart`): `enum UnitLabelProblem { length, control }`, `const int kUnitLabelMaxLength = 8`, `UnitLabelProblem? unitLabelProblem(String raw)`; (`lib/src/units/unit_problems.dart`) `UnitLabelWarning` with `const DuplicateLabel({required String label, required int count})`, `const Unlabelled({required String kind, required int capacity, required String? symbolKey})`, `const BadLabel({required String label, required UnitLabelProblem problem})`; `UnitInfo.labelling` (a `UnitLabelling`); `lib/src/units/unit_components.dart`'s `UnitColour(PlanSwatch)` with `name` null for a payload of another shape and `==` by value.
- Task 7 (`lib/src/units/unit_rotate.dart`): `DraftCommand? rotateUnitCommand(DraftDocument doc, Handle instance, int quarterTurns)`; the controller installs `UnitLabelSystem` (a turn re-stamps the label in the same step, TS7).
- Task 9: `PlanController.unitIndex`, `unitDetails`, `unitDetailInstances`, `revision`, `editorSelectedUnits`, `setUnitData`; `unitLabelCommand`.
- Task 4: `PlanController(words:)`; `KitServices.words` is each kit's `KitNamesWords` over `words.merge(kit.names)`.
- 2a: `PlanController.servicesOf(kitId)` (`@internal`), `kits.kitOf`, `isLocked`, `reportLocale(Locale, {PlanStrings? strings})` and its private `_reportedStrings`, `_locale`.

---


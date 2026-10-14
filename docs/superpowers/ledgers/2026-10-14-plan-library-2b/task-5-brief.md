### Task 5: The test kit's units (spec "Tests" "The test kit", S2 "The label" uniqueness, S2 "The contract gains")

**Files:**
- Modify: `packages/jet_cad_2d_plan/test/support/test_kit.dart` (the unit symbols, `test.row`'s component, type and tool, the unit words, `unitKit()`; `testKit()` unchanged unless asked with `units: true`)
- Create: `packages/jet_cad_2d_plan/test/support/service_fixture.dart` (`serviceFixture()` and the row helpers later tasks reuse)
- Test: `packages/jet_cad_2d_plan/test/kits/test_kit_units_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/`.)

**Interfaces:**
- Consumes:
  - Task 1 (engine, Shared interfaces): `GeneratedInstance(Handle definition, Transform2 transform, {List<GeneratedAttrib> attributes})`, `GeneratedAttrib`, `ParametricType.instances(ParametricView view, Handle self)`; the planner's matching by position (a shrink keeps the first seats' handles).
  - Task 3 (contract, Shared interfaces): `SymbolsState`, `SymbolDefinitionRef` (`handle`, `add`, `basePoint`, `top`), `PlanServices.symbolDefinition(String key)`, `kUnitLabelTag`, `kUnitLabelMaxHeight`, `kUnitLabelTextAttrs`, `unitLabelHeight(Aabb2 top)`, `unitLabelStamp(Transform2)`, `unitLabelPayload({anchor, height, instanceToWorld})`, `unitLabelAttrib(String text, {instanceToWorld, anchor, top})`; `PlanKit.validate` accepting `unit:<kit>/<kind>`; `conformance()` reporting `KitProblemCode.unitKindWord`.
  - Task 4: `KitServices.symbolDefinition` (one ref per key until executed), `PlanController.symbolsState` as `ValueListenable<SymbolsState>`. Task 1: `GuardedType.instances` (controller ruling R-1).
  - 2a, unchanged: `placeSymbol`, `definitionForEntry` (`lib/src/symbols/symbol_placer.dart:84-181`), `PlacementTool` (`jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:35-249`), `planText`, `controllerFor` (`test/support/harness.dart:112-134`), `settle`, `symbolKit` (`test/support/symbol_fixtures.dart:229-252`), `useTestCamera`, `tapAt` (`test/support/tool_events.dart:25-52`), `encodeLibrary`, `encodeSnapshot`, `geometrySnapshot`, `conformance` (`package:jet_cad_2d_kit/authoring.dart`).
- Produces (test support only; later tasks use these names):
  - In `test/support/test_kit.dart`:
    - `const String rowTypeId = 'test.row'`, `const String rowToolId = 'test.row'`, `const String rowSeatKey = 'test.seat.basic.one@1'`, `const String tableSymbolId = 'test.table.square.four@1'`, `const String boothSymbolId = 'test.booth.corner.six@1'`, `const int kRowToolSeats = 6`, `const double kRowToolSpacing = 600`.
    - `final Catalog testUnitCatalog`, `Uint8List testUnitLibraryBytes()`, `const KitNames testUnitWords`.
    - `final class RowComponent implements Component` (`prefix`, `count`, `spacing`, `curve`, `seat`, `base`, `top`; `copyWith`, `fromJson`, `==`).
    - `Transform2 rowSeatTransform(RowComponent row, int i)` (seat `i`, 0-based, in the row's group space).
    - `final class RowType extends ParametricType<RowComponent>` (seats only: `generate` returns no entity; `instances` returns `count` seats labelled `<prefix>1`…`<prefix>N`).
    - `final class RowTool extends PlacementTool`; `PlanType<RowComponent> rowType()`; `PlanTool rowTool()`.
    - `String freeRowPrefix(DraftDocument d, int count)`; `CompoundCommand placeRowCommand(DraftDocument d, RowComponent row, {required Vector2 at, double angle = 0, Handle? handle})`; `Aabb2 entryTop(SymbolEntry entry)`.
    - `PlanKit testKit({String version = '1.2.0', KitLog? log, bool units = false})` (unchanged with `units: false`); `PlanKit unitKit({KitLog? log})` (= `testKit(units: true)`).
  - In `test/support/service_fixture.dart`:
    - `typedef ServiceFixture = ({String json, Handle table, Handle tableLabel, Handle tableDefinition, Handle seatDefinition, Handle rowA, List<Handle> seatsA, Handle rowB, List<Handle> seatsB})`; `ServiceFixture serviceFixture()`.
    - `SymbolEntry testEntry(String id)`, `Handle addRow(DraftDocument d, RowComponent row, {required Vector2 at, double angle = 0})`, `List<Handle> rowsOf(DraftDocument d)`, `List<Handle> seatsOf(DraftDocument d, Handle row)`, `List<(Handle, String)> unitLabelsOf(DraftDocument d, Handle instance)`, `Handle labelPlacedUnit(DraftDocument d, Handle instance, SymbolEntry entry, String text)`, `void expectUprightLabel(DraftDocument d, Handle label, Transform2 instanceToWorld)`.

Plan decision (`testKit()` stays as 2a left it): `testKit()` is called 74 times in 11 test files outside `test/support` (`grep -rn "testKit(" test | grep -v support`), among them `TK1`, which pins the words to English and Turkish with one key set (`test/kits/test_kits_test.dart:14-23`), and symbol, tool and lifetime tests that a new library, type or tool would shift. The units come only with `testKit(units: true)`, spelled `unitKit()`. It is the same kit id, `test`, so `unit:test/booth` is the test kit's word.

Plan decision (`test.row` is seats only): its `generate` returns no entity. A seats-only row is the case spec S2's selection rules discuss: the design's click maps a seat to the row, a crossing band takes the row through the seats' ATTRIBs, and a window band over a seats-only row takes nothing (decision 9). A thin row line would hide the last of these.

Plan decision (the row's geometry): seat `i` (0-based) sits on a chord walk of `spacing`, turning by `curve` radians per seat (`curve = 0`: a straight row along the group's +x). With `R = spacing / (2 sin(curve / 2))`, seat `i` is at `(R sin(i·curve), R (1 − cos(i·curve)))`, turned by `i·curve`; its transform is `translate(position) · rotate(i·curve) · translate(−base)`, so the seat's base point lands on the position, as `placementTransform` does (`symbol_placer.dart:48-67`). The component holds the seat definition's handle, base point and top, from `symbolDefinition` (spec S1 "The definition"), so `instances` reads only its own parameters (spec S1).

Plan decision (the free prefix, spec S2 "Uniqueness across objects is the placing tool's"): a prefix `P` is free for a row of `N` seats when none of `P1`…`PN` is the trimmed text of a live `UNIT` ATTRIB in `PlanServices.document`. The prefixes are tried in the order `A`, `B`, …, `Z`, `AA`, `AB`, …. A second check on the rows' own prefixes would be redundant: a live row of prefix `P` always holds `P1`. `UnitIndex` is Task 6's, so the tool reads the ATTRIBs directly.

Plan decision (the row tool): two presses, as the slab tool (`test/support/test_kit.dart:296-344`). The first anchors the row and the second turns it towards the press. On the second press the tool checks the permissions, then calls `symbolDefinition(rowSeatKey)` once (spec S2: "a tool calls it once per placement, never per preview"). Null (libraries loading or failed) places nothing. Otherwise it executes one `CompoundCommand`: the ref's `add` when present, then the row. It has no preview and no letter.

- [ ] **Step 1: The failing tests.** Create `test/kits/test_kit_units_test.dart`:

```dart
// The test kit's units (2b Task 5; spec "Tests", "The test kit"): the
// table, the seat and the booth symbols, the row type generating labelled
// seats through E5, its tool placing rows through symbolDefinition with the
// first free prefix, and the service fixture later tasks stand on. Rows are
// turned and placed off the origin; the camera is turned and flipped.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show conformance, encodeLibrary, encodeSnapshot, geometrySnapshot;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        KitNames,
        KitProblemCode,
        SymbolComponent,
        SymbolsState,
        UnitComponent,
        UnitKinds,
        UnitLabelling;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placeSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart';
import '../support/symbol_fixtures.dart' show settle;
import '../support/test_kit.dart';
import '../support/tool_events.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

/// Every live UNIT ATTRIB's trimmed text in [d], ascending by handle.
List<String> allLabels(DraftDocument d) {
  final e = d.entities;
  final found = <(Handle, String)>[
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.attrib && e.tagAt(s) == 'UNIT')
        (e.handleAt(s), e.textAt(s).trim()),
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
  return [for (final f in found) f.$2];
}

/// One row placed with the row tool: a press at [from], one at [to].
Handle placeRowWithTool(PlanController c, Vector2 from, Vector2 to) {
  final before = rowsOf(c.document).toSet();
  expect(c.selectTool(rowToolId), isTrue);
  tapAt(c, from);
  tapAt(c, to);
  return rowsOf(c.document).singleWhere((r) => !before.contains(r));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'TK-units the unit kit validates; its library holds the table, the '
      'seat and the booth with their units (fixture sanity)', () {
    final kit = unitKit();
    expect(kit.validate(), isEmpty);
    expect(testKit().validate(), isEmpty);
    expect(testKit().symbols, isEmpty, reason: 'testKit() is 2a\'s');
    expect([for (final t in kit.types) t.id], ['test.slab', rowTypeId]);
    expect([for (final t in kit.tools) t.id], ['test.slab', rowToolId]);
    final units = {
      for (final s in testUnitCatalog.symbols) s.id: s.unit,
    };
    expect(units.keys, [tableSymbolId, rowSeatKey, boothSymbolId]);
    expect((units[tableSymbolId]!.kind, units[tableSymbolId]!.capacity),
        (UnitKinds.table, 4));
    expect(units[tableSymbolId]!.labelling, UnitLabelling.numbered);
    expect((units[rowSeatKey]!.kind, units[rowSeatKey]!.capacity),
        (UnitKinds.seat, 1));
    expect(units[rowSeatKey]!.labelling, UnitLabelling.assigned);
    expect((units[boothSymbolId]!.kind, units[boothSymbolId]!.capacity),
        ('booth', 6));
    expect(kit.names.words['en']!['unit:test/booth'], 'Booth');
    expect(kit.names.words['tr']!.containsKey('unit:test/booth'), isFalse,
        reason: 'the booth has an English word only (Task 10\'s fallback)');
  });

  test(
      'TK-row the row tool places one row through symbolDefinition: six '
      'seats of the seat definition, labelled A1 to A6, upright in the '
      'world; a shrink keeps the first seats under their handles '
      '(M-TK-row)', () async {
    final c = controllerFor(kits: [unitKit()]);
    await settle();
    expect(c.symbolsState.value, SymbolsState.ready);
    useTestCamera(c);
    final row = placeRowWithTool(
        c, Vector2(-3100.5, 2200.25), Vector2(-1200.75, 3300.5));
    final d = c.document;
    final params = d.components.get<RowComponent>(row)!;
    expect(params.prefix, 'A');
    expect(params.count, kRowToolSeats);
    expect(params.spacing, kRowToolSpacing);
    final group = d.tree[row]! as GroupNode;
    expect(group.transform.b, isNot(0), reason: 'premise: the row is turned');
    expect(d.tree.definition(params.seat), isNotNull);
    expect(d.components.get<SymbolComponent>(params.seat)!.id, rowSeatKey);
    expect(d.components.get<UnitComponent>(params.seat)!.kind, UnitKinds.seat);
    final seats = seatsOf(d, row);
    expect(seats, hasLength(kRowToolSeats));
    for (final (i, s) in seats.indexed) {
      final node = d.tree[s]! as InstanceNode;
      expect(node.definition, params.seat);
      expect(node.transform.equals(rowSeatTransform(params, i), exact), isTrue,
          reason: 'seat $i');
      final labels = unitLabelsOf(d, s);
      expect([for (final l in labels) l.$2], ['A${i + 1}']);
      expectUprightLabel(
          d, labels.single.$1, group.transform.multiply(node.transform));
    }

    // E5's matching through the guarded type: 6 -> 4 keeps seats 1-4.
    expect(
        c.execute(SetComponentCommand<RowComponent>(
            row, params.copyWith(count: 4))),
        isTrue);
    expect(seatsOf(d, row), seats.sublist(0, 4));
    expect([for (final s in seatsOf(d, row)) unitLabelsOf(d, s).single.$2],
        ['A1', 'A2', 'A3', 'A4']);
    c.undo();
    expect(seatsOf(d, row), seats);
  });

  test(
      'TK-two-rows Review Focus 3: rows placed one after the other take A '
      'and B; a prefix a placed label holds is skipped; no label twice, '
      'every seat labelled once (M-TK-prefix)', () async {
    final c = controllerFor(kits: [unitKit()]);
    await settle();
    useTestCamera(c);
    final a = placeRowWithTool(
        c, Vector2(-3100.5, 2200.25), Vector2(-1200.75, 3300.5));
    final b = placeRowWithTool(
        c, Vector2(1900.25, -2600.5), Vector2(3700.5, -3900.75));
    final d = c.document;
    expect(d.components.get<RowComponent>(a)!.prefix, 'A');
    expect(d.components.get<RowComponent>(b)!.prefix, 'B');

    // A table labelled C2: C is not free for a row of six.
    final table = testEntry(tableSymbolId);
    final before = {for (final n in d.tree.nodes) n.handle};
    expect(
        c.execute(placeSymbol(d, table,
            at: Vector2(6100.5, 4200.25), quarterTurns: 1, mirrored: true)),
        isTrue);
    final placed = d.tree.nodes
        .whereType<InstanceNode>()
        .singleWhere((n) => !before.contains(n.handle));
    labelPlacedUnit(d, placed.handle, table, 'C2');
    final third = placeRowWithTool(
        c, Vector2(-5200.75, -4100.5), Vector2(-3900.25, -5600.75));
    expect(d.components.get<RowComponent>(third)!.prefix, 'D');

    final labels = allLabels(d);
    expect(labels, hasLength(3 * kRowToolSeats + 1));
    expect(labels.toSet(), hasLength(labels.length), reason: 'no label twice');
    for (final row in [a, b, third]) {
      for (final s in seatsOf(d, row)) {
        expect(unitLabelsOf(d, s), hasLength(1), reason: 'seat ${s.toHex()}');
      }
    }
  });

  test(
      'TK-conformance the unit kit passes conformance with the booth\'s '
      'English word; without it, unitKindWord (M-TK-conf)', () {
    final kit = unitKit();
    List<Object> problemsWith(KitNames names) => [
          for (final p in conformance(
            catalog: testUnitCatalog,
            committedLibrary: encodeLibrary(testUnitCatalog),
            committedSnapshot: encodeSnapshot(geometrySnapshot(testUnitCatalog)),
            names: names,
            locales: const ['tr'],
            typeIds: [for (final t in kit.types) t.id],
            toolIds: [for (final t in kit.tools) t.id],
            propertyIds: kit.propertyIds,
          ))
            p.code,
        ];
    expect(problemsWith(kit.names), isEmpty);
    final english = {...kit.names.words['en']!}..remove('unit:test/booth');
    expect(
        problemsWith(KitNames({'en': english, 'tr': kit.names.words['tr']!})),
        [KitProblemCode.unitKindWord]);
  });

  test(
      'TK-fixture the service fixture: a table turned a quarter and '
      'mirrored, labelled 12; row A turned with six seats, row B curved '
      'with five; all off the origin (fixture sanity)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final table = d.tree[f.table]! as InstanceNode;
    expect(table.parent, d.rootHandle);
    expect(table.transform.determinant, lessThan(0), reason: 'mirrored');
    expect(table.transform.a, closeTo(0, 1e-12), reason: 'a quarter turn');
    expect(unitLabelsOf(d, f.table), [(f.tableLabel, '12')]);
    expect(table.definition, f.tableDefinition);
    expect(rowsOf(d), [f.rowA, f.rowB]);
    final a = d.components.get<RowComponent>(f.rowA)!;
    final b = d.components.get<RowComponent>(f.rowB)!;
    expect((a.prefix, a.count, a.curve), ('A', 6, 0.0));
    expect((b.prefix, b.count), ('B', 5));
    expect(b.curve, isNot(0));
    expect((d.tree[f.rowA]! as GroupNode).transform.b, isNot(0));
    expect(seatsOf(d, f.rowA), f.seatsA);
    expect(seatsOf(d, f.rowB), f.seatsB);
    expect(
        [for (final s in f.seatsA) unitLabelsOf(d, s).single.$2],
        ['A1', 'A2', 'A3', 'A4', 'A5', 'A6']);
    expect([for (final s in f.seatsB) unitLabelsOf(d, s).single.$2],
        ['B1', 'B2', 'B3', 'B4', 'B5']);
    for (final s in [...f.seatsA, ...f.seatsB]) {
      expect((d.tree[s]! as InstanceNode).definition, f.seatDefinition);
    }
  });
}
```

- [ ] **Step 2: Run the tests to see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits/test_kit_units_test.dart`. Expected: compilation errors, `Undefined name 'unitKit'`, `'RowComponent' isn't a type`, `Target of URI doesn't exist: '../support/service_fixture.dart'`.

- [ ] **Step 3: The test kit's units.** In `test/support/test_kit.dart`:
  1. Header comment: after `// no German (the fallback).` add the lines:
     ```dart
     // With `units: true` (`unitKit()`, 2b Task 5) it also carries a symbol
     // library (a numbered table of four, an assigned seat, a booth of six
     // whose kind only the kit names), the parametric row `test.row` that
     // generates labelled seats through E5, its tool, and the words they need.
     ```
  2. Imports: add `import 'dart:typed_data';`, `import 'package:jet_cad_2d_kit/authoring.dart' show Catalog, CatalogLine, CatalogPolyline, CatalogSymbol, CatalogUnit, encodeLibrary;` and keep `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` (it exports `kUnitLabelTag`, `unitLabelAttrib`, `SymbolEntry`, `UnitKinds`, `UnitLabelling`, `SymbolLibrarySource` after Task 3).
  3. Replace `testKit` (`:537-546`) with:

```dart
/// The test kit: one type, one tool, one provider; a fresh descriptor per
/// call. [log] records its factories' products. With [units], also the
/// unit library, the row type and its tool, and their words (2b).
PlanKit testKit({String version = '1.2.0', KitLog? log, bool units = false}) =>
    PlanKit(
      id: 'test',
      version: version,
      symbols: [
        if (units)
          SymbolLibrarySource(
              label: 'test units', read: () async => testUnitLibraryBytes()),
      ],
      types: [slabType(log: log), if (units) rowType()],
      tools: [slabTool(log: log), if (units) rowTool()],
      attachments: [(services) => TestEdge(log: log)],
      names: units ? testWords.merge(testUnitWords) : testWords,
    );

/// The test kit with its units (2b): `testKit(units: true)`.
PlanKit unitKit({KitLog? log}) => testKit(log: log, units: true);
```

  4. Append, before `// Placing objects.` (`:714`), a new section:

```dart
// ---------------------------------------------------------------------------
// The units (2b): the symbols, the row, its tool, its words.

const String rowTypeId = 'test.row';
const String rowToolId = 'test.row';

/// The seat a row generates.
const String rowSeatKey = 'test.seat.basic.one@1';

/// The placed, numbered table of four.
const String tableSymbolId = 'test.table.square.four@1';

/// The booth of six: a kind the contract does not name.
const String boothSymbolId = 'test.booth.corner.six@1';

/// The row tool's row: six seats, 600 mm apart, straight.
const int kRowToolSeats = 6;
const double kRowToolSpacing = 600;

/// The unit library, kit `test`. Each unit draws its top first (K3 rule
/// 11); every base point is off the frame's origin.
final Catalog testUnitCatalog = Catalog(kit: 'test', symbols: [
  CatalogSymbol(
    key: 'test.table.square.four',
    name: 'Square table',
    category: 'Tests',
    tags: const ['table', 'square'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4),
    base: (600, 600),
    shapes: const [
      CatalogPolyline([(150, 150), (1050, 150), (1050, 1050), (150, 1050)],
          closed: true),
      CatalogPolyline([(375, -150), (825, -150), (825, 100), (375, 100)],
          closed: true),
      CatalogPolyline([(375, 1100), (825, 1100), (825, 1350), (375, 1350)],
          closed: true),
      CatalogPolyline([(-150, 375), (100, 375), (100, 825), (-150, 825)],
          closed: true),
      CatalogPolyline([(1100, 375), (1350, 375), (1350, 825), (1100, 825)],
          closed: true),
    ],
  ),
  CatalogSymbol(
    key: 'test.seat.basic.one',
    name: 'Seat',
    category: 'Tests',
    tags: const ['seat'],
    unit: const CatalogUnit(
        kind: UnitKinds.seat,
        capacity: 1,
        labelling: UnitLabelling.assigned),
    base: (250, 265),
    shapes: const [
      CatalogPolyline([(25, 40), (475, 40), (475, 490), (25, 490)],
          closed: true),
      CatalogLine((25, 440), (475, 440)),
    ],
  ),
  CatalogSymbol(
    key: 'test.booth.corner.six',
    name: 'Corner booth',
    category: 'Tests',
    tags: const ['booth'],
    unit: const CatalogUnit(kind: 'booth', capacity: 6),
    base: (400, 400),
    shapes: const [
      CatalogPolyline([
        (100, 100),
        (1700, 100),
        (1700, 700),
        (700, 700),
        (700, 1500),
        (100, 1500)
      ], closed: true),
      CatalogLine((300, 300), (1500, 300)),
    ],
  ),
]);

Uint8List testUnitLibraryBytes() => encodeLibrary(testUnitCatalog);

/// The units' words: the row in English and Turkish, the symbols and their
/// category in Turkish (their English is the catalog's), the booth's kind in
/// English only (spec S4 "Words": the English fallback).
const KitNames testUnitWords = KitNames({
  'en': {
    'type:test.row': 'Row',
    'tool:test.row': 'Row',
    'unit:test/booth': 'Booth',
  },
  'tr': {
    'type:test.row': 'Sıra',
    'tool:test.row': 'Sıra',
    'symbol:test.table.square.four': 'Kare masa',
    'symbol:test.seat.basic.one': 'Koltuk',
    'symbol:test.booth.corner.six': 'Köşe loca',
    'category:test/Tests': 'Testler',
  },
});

/// A row of [count] seats of the definition [seat] (its [base] point and
/// [top] box, from `PlanServices.symbolDefinition`), [spacing] mm apart,
/// turning [curve] radians a seat, labelled `<prefix>1` to `<prefix>N`.
@immutable
final class RowComponent implements Component {
  /// Throws [ArgumentError] for a prefix over 8 code units or with a
  /// control character, a count outside 1 to 999, a spacing that is not
  /// finite and above 0, a curve that is not finite or reaches ±π, and a
  /// base point that is not finite.
  RowComponent({
    required this.prefix,
    required this.count,
    required this.spacing,
    this.curve = 0,
    required this.seat,
    required Vector2 base,
    required this.top,
  }) : base = Vector2.copy(base) {
    if (prefix.length > 8 ||
        prefix.codeUnits.any((u) => u < 0x20 || (u >= 0x7F && u <= 0x9F))) {
      throw ArgumentError.value(prefix, 'prefix',
          'must be at most 8 code units, no control character');
    }
    if (count < 1 || count > 999) {
      throw ArgumentError.value(count, 'count', 'must be 1 to 999');
    }
    if (!spacing.isFinite || spacing <= 0) {
      throw ArgumentError.value(
          spacing, 'spacing', 'must be finite and above 0');
    }
    if (!curve.isFinite || curve.abs() >= math.pi) {
      throw ArgumentError.value(curve, 'curve', 'must be finite, below π');
    }
    if (!this.base.x.isFinite || !this.base.y.isFinite) {
      throw ArgumentError.value(base, 'base', 'must be finite');
    }
  }

  static const String componentTypeId = rowTypeId;

  final String prefix;
  final int count;
  final double spacing;
  final double curve;
  final Handle seat;
  final Vector2 base;
  final Aabb2 top;

  @override
  String get typeId => componentTypeId;

  @override
  Map<String, Object?> toJson() => {
        'base': [base.x, base.y],
        'count': count,
        'curve': curve,
        'prefix': prefix,
        'seat': seat.toJson(),
        'spacing': spacing,
        'top': [top.minX, top.minY, top.maxX, top.maxY],
      };

  static RowComponent fromJson(Map<String, Object?> json) {
    final base = (json['base']! as List).cast<num>();
    final top = (json['top']! as List).cast<num>();
    return RowComponent(
      prefix: json['prefix']! as String,
      count: json['count']! as int,
      spacing: (json['spacing']! as num).toDouble(),
      curve: (json['curve']! as num).toDouble(),
      seat: Handle.fromJson(json['seat']),
      base: Vector2(base[0].toDouble(), base[1].toDouble()),
      top: Aabb2.raw(top[0].toDouble(), top[1].toDouble(), top[2].toDouble(),
          top[3].toDouble()),
    );
  }

  RowComponent copyWith(
          {String? prefix, int? count, double? spacing, double? curve}) =>
      RowComponent(
        prefix: prefix ?? this.prefix,
        count: count ?? this.count,
        spacing: spacing ?? this.spacing,
        curve: curve ?? this.curve,
        seat: seat,
        base: base,
        top: top,
      );

  @override
  bool operator ==(Object other) =>
      other is RowComponent &&
      other.prefix == prefix &&
      other.count == count &&
      other.spacing == spacing &&
      other.curve == curve &&
      other.seat == seat &&
      other.base.x == base.x &&
      other.base.y == base.y &&
      other.top.minX == top.minX &&
      other.top.minY == top.minY &&
      other.top.maxX == top.maxX &&
      other.top.maxY == top.maxY;

  @override
  int get hashCode => Object.hash(prefix, count, spacing, curve, seat, base.x,
      base.y, top.minX, top.minY, top.maxX, top.maxY);

  @override
  String toString() => 'RowComponent($prefix × $count @ $spacing, $curve)';
}

/// Seat [i] (0-based) of [row] in the row's group space: a chord walk of
/// `spacing`, turning `curve` a seat; the seat's base point on its place.
Transform2 rowSeatTransform(RowComponent row, int i) {
  final theta = i * row.curve;
  final double x, y;
  if (row.curve == 0) {
    x = i * row.spacing;
    y = 0;
  } else {
    final r = row.spacing / (2 * math.sin(row.curve / 2));
    x = r * math.sin(theta);
    y = r * (1 - math.cos(theta));
  }
  final c = math.cos(theta), s = math.sin(theta);
  return Transform2.translation(x, y)
      .multiply(Transform2(c, s, -s, c, 0, 0))
      .multiply(Transform2.translation(-row.base.x, -row.base.y));
}

/// The row's engine type: seats only (spec 2b "The test kit"; the
/// selection rules of S2 discuss a seats-only row), each labelled through
/// the kit's `unitLabelAttrib`.
final class RowType extends ParametricType<RowComponent> {
  const RowType();

  @override
  Capability get editCapability => Capability.geometry;

  /// The seats' tops, in the world.
  @override
  Aabb2 reach(RowComponent params, Transform2 toWorld) {
    final t = params.top;
    return Aabb2.fromPoints([
      for (var i = 0; i < params.count; i++)
        for (final (x, y) in [
          (t.minX, t.minY),
          (t.maxX, t.minY),
          (t.maxX, t.maxY),
          (t.minX, t.maxY),
        ])
          toWorld
              .multiply(rowSeatTransform(params, i))
              .transformPoint(Vector2(x, y)),
    ]);
  }

  @override
  List<Generated> generate(ParametricView view, Handle self) => const [];

  @override
  List<GeneratedInstance> instances(ParametricView view, Handle self) {
    final row = view.paramsOf<RowComponent>(self)!;
    final toWorld = view.toWorld(self);
    final out = <GeneratedInstance>[];
    for (var i = 0; i < row.count; i++) {
      final seat = rowSeatTransform(row, i);
      out.add(GeneratedInstance(row.seat, seat, attributes: [
        unitLabelAttrib('${row.prefix}${i + 1}',
            instanceToWorld: toWorld.multiply(seat),
            anchor: row.base,
            top: row.top),
      ]));
    }
    return out;
  }
}

/// The first free prefix for a row of [count] seats in [d] (spec S2: the
/// placing tool's job): `A`, `B`, …, `Z`, `AA`, `AB`, …, the first `P` for
/// which none of `P1` to `P<count>` is the trimmed text of a live UNIT
/// ATTRIB. O(entities), once per placement.
String freeRowPrefix(DraftDocument d, int count) {
  final e = d.entities;
  final labels = <String>{
    for (final s in e.liveSlots)
      if (e.kindAt(s) == EntityKind.attrib && e.tagAt(s) == kUnitLabelTag)
        e.textAt(s).trim(),
  };
  for (var n = 0;; n++) {
    final prefix = _letters(n);
    var free = true;
    for (var i = 1; i <= count && free; i++) {
      if (labels.contains('$prefix$i')) free = false;
    }
    if (free) return prefix;
  }
}

/// 0 → A, 25 → Z, 26 → AA: bijective base 26.
String _letters(int n) {
  var k = n + 1;
  final codes = <int>[];
  while (k > 0) {
    k--;
    codes.add(0x41 + k % 26);
    k ~/= 26;
  }
  return String.fromCharCodes(codes.reversed);
}

/// A root-level group at [at] turned by [angle], carrying [row] and the
/// drawing layer: one step (the seats come from the row's regeneration).
CompoundCommand placeRowCommand(DraftDocument d, RowComponent row,
    {required Vector2 at, double angle = 0, Handle? handle}) {
  final h = handle ?? d.handleSeed.next();
  return CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: d.rootHandle,
        transform: Transform2.translation(at.x, at.y)
            .multiply(Transform2.rotation(angle)),
        children: const [])),
    SetComponentCommand<RowComponent>(h, row),
    SetComponentCommand<ObjectLayer>(h, ObjectLayer(drawingLayer(d))),
  ], label: 'Add row');
}

/// The definition's top, as `SymbolDefinitionRef.top` gives it (spec S2):
/// the first leaf's box when it is a closed polyline or a circle, else the
/// leaves' vertex box. The unit library's entries all take the first
/// branch.
Aabb2 entryTop(SymbolEntry entry) {
  if (entry.leaves.isEmpty) return Aabb2.empty();
  final first = entry.leaves.first;
  final p = first.payload;
  if (first.record.kind == EntityKind.circle) {
    final r = p.scalars[0];
    return Aabb2.raw(
        p.coords[0] - r, p.coords[1] - r, p.coords[0] + r, p.coords[1] + r);
  }
  if (first.record.kind == EntityKind.polyline && isClosedPolyline(p)) {
    return Aabb2.fromPoints([for (var i = 0; i < p.pointCount; i++) p.pointAt(i)]);
  }
  return Aabb2.fromPoints([
    for (final l in entry.leaves)
      for (var i = 0; i < l.payload.pointCount; i++) l.payload.pointAt(i),
  ]);
}

/// What a row placement needs.
const Set<Capability> rowNeeds = {
  Capability.structure,
  Capability.components,
  Capability.geometry,
};

/// Two presses: the first anchors the row, the second turns it towards the
/// press and places a row of [kRowToolSeats] seats with the first free
/// prefix, through `symbolDefinition` once.
final class RowTool extends PlacementTool {
  RowTool(this.services);

  final PlanServices services;

  @override
  String get name => 'Row';

  @override
  void accept(Vector2 point, ToolContext ctx) {
    if (points.isEmpty) {
      points.add(point);
      return;
    }
    final start = points.first;
    final d = point - start;
    if (d.length <= Tolerance.standard.linear) return;
    clearShape();
    // The permissions first: a refused row allocates no handle (Ruling
    // 05-3), then the definition, once per placement (spec S2).
    if (!rowNeeds.every(ctx.document.commands.permissions.allows)) return;
    final ref = services.symbolDefinition(rowSeatKey);
    if (ref == null) return;
    final document = services.document;
    ctx.execute(CompoundCommand([
      if (ref.add case final add?) add,
      placeRowCommand(
          document,
          RowComponent(
              prefix: freeRowPrefix(document, kRowToolSeats),
              count: kRowToolSeats,
              spacing: kRowToolSpacing,
              seat: ref.handle,
              base: ref.basePoint,
              top: ref.top),
          at: start,
          angle: math.atan2(d.y, d.x)),
    ], label: 'Add row'));
  }

  @override
  void paintRubberBand(Canvas canvas, Vector2 origin, double scale) {}
}

PlanType<RowComponent> rowType() => PlanType<RowComponent>(
      id: rowTypeId,
      fromJson: RowComponent.fromJson,
      parametric: const RowType(),
    );

PlanTool rowTool() => PlanTool(
      id: rowToolId,
      icon: Icons.event_seat,
      needs: rowNeeds,
      create: RowTool.new,
    );
```

  `_letters` uses `StringBuffer.writeCharCodes`; `math`, `Vector2`, `Icons`, `Canvas` are already imported (`:12-18`).

- [ ] **Step 4: The service fixture.** Create `test/support/service_fixture.dart`:

```dart
// The service fixture (2b Task 5; spec "Tests": not degenerate): a plan over
// unitKit() holding one placed table of four, a quarter turn and mirrored,
// at (-2400.5, 3100.25), labelled 12; and two rows of the test seat, sharing
// one definition: A (six seats, 600 apart, straight) turned 0.35 rad at
// (5200.5, -3100.25), and B (five seats, 650 apart, curved 0.18 rad a seat)
// at (-4800.75, -2600.5). Later tasks load `json` into a controller over
// [unitKit()] (or another kit set, for a missing kit) and address the parts
// by the handles below, which the plan text keeps.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placeSymbol;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart';
import 'test_kit.dart';

typedef ServiceFixture = ({
  String json,
  Handle table,
  Handle tableLabel,
  Handle tableDefinition,
  Handle seatDefinition,
  Handle rowA,
  List<Handle> seatsA,
  Handle rowB,
  List<Handle> seatsB,
});

final SymbolLibrary _library = SymbolLibrary.decode(testUnitLibraryBytes());

/// The unit library's entry [id] (`key@version`).
SymbolEntry testEntry(String id) =>
    _library.entries.firstWhere((e) => e.id == id);

/// [placeRowCommand], executed; the row's handle.
Handle addRow(DraftDocument d, RowComponent row,
    {required Vector2 at, double angle = 0}) {
  final h = d.handleSeed.next();
  d.commands.execute(placeRowCommand(d, row, at: at, angle: angle, handle: h));
  return h;
}

/// The live rows of [d], ascending.
List<Handle> rowsOf(DraftDocument d) => [
      for (final h in d.components.withComponent<RowComponent>())
        if (d.tree[h] is GroupNode) h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [row]'s instance children, ascending: its seats.
List<Handle> seatsOf(DraftDocument d, Handle row) => [
      for (final h in (d.tree[row]! as GroupNode).children)
        if (d.tree[h] is InstanceNode) h,
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [instance]'s UNIT ATTRIBs, (handle, text), ascending by handle.
List<(Handle, String)> unitLabelsOf(DraftDocument d, Handle instance) {
  final e = d.entities;
  return [
    for (final s in e.liveSlots)
      if (e.ownerAt(s) == instance &&
          e.kindAt(s) == EntityKind.attrib &&
          e.tagAt(s) == kUnitLabelTag)
        (e.handleAt(s), e.textAt(s)),
  ]..sort((a, b) => a.$1.value.compareTo(b.$1.value));
}

/// Adds [text] as the UNIT label of the placed [instance] of [entry], as
/// today's placement shapes it (layer 0, BYBLOCK, centred, the stamp for
/// the instance's transform, the height of the entry's top): executed; the
/// label's handle.
Handle labelPlacedUnit(
    DraftDocument d, Handle instance, SymbolEntry entry, String text) {
  final node = d.tree[instance]! as InstanceNode;
  final h = d.handleSeed.next();
  d.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: instance,
      kind: EntityKind.attrib,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byBlockLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByBlockColor(),
      lineweight: kByBlock,
      transparency: kByBlock,
      flags: 0,
      text: text,
      tag: kUnitLabelTag,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: kUnitLabelTextAttrs,
    ),
    payload: unitLabelPayload(
        anchor: entry.definition.basePoint,
        height: unitLabelHeight(entryTop(entry)),
        instanceToWorld: node.transform),
  ));
  return h;
}

/// The label [label]'s world linear map under [instanceToWorld] is the
/// identity: it reads upright and unmirrored, whatever the instance's turn.
void expectUprightLabel(
    DraftDocument d, Handle label, Transform2 instanceToWorld) {
  final p =
      d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(label)!));
  final t = instanceToWorld;
  final w = Transform2(t.a, t.b, t.c, t.d, 0, 0)
      .multiply(Transform2.rotation(p.scalars[1]))
      .multiply(Transform2.scale(p.scalars[2], 1));
  expect([w.a, w.b, w.c, w.d], [
    closeTo(1, 1e-12),
    closeTo(0, 1e-12),
    closeTo(0, 1e-12),
    closeTo(1, 1e-12),
  ]);
}

ServiceFixture serviceFixture() {
  late Handle table, tableLabel, tableDefinition, seatDefinition, rowA, rowB;
  late List<Handle> seatsA, seatsB;
  final json = planText([unitKit()], (d) {
    final tableEntry = testEntry(tableSymbolId);
    final before = {for (final n in d.tree.nodes) n.handle};
    d.commands.execute(placeSymbol(d, tableEntry,
        at: Vector2(-2400.5, 3100.25), quarterTurns: 1, mirrored: true));
    final placed = d.tree.nodes
        .whereType<InstanceNode>()
        .singleWhere((n) => !before.contains(n.handle));
    table = placed.handle;
    tableDefinition = placed.definition;
    tableLabel = labelPlacedUnit(d, table, tableEntry, '12');

    final seatEntry = testEntry(rowSeatKey);
    final made = definitionForEntry(d, seatEntry);
    d.commands.execute(CompoundCommand(made.commands, label: 'Seat'));
    seatDefinition = made.definition;
    RowComponent row(String prefix, int count, double spacing, double curve) =>
        RowComponent(
            prefix: prefix,
            count: count,
            spacing: spacing,
            curve: curve,
            seat: seatDefinition,
            base: seatEntry.definition.basePoint,
            top: entryTop(seatEntry));
    rowA = addRow(d, row('A', 6, 600, 0),
        at: Vector2(5200.5, -3100.25), angle: 0.35);
    rowB = addRow(d, row('B', 5, 650, 0.18), at: Vector2(-4800.75, -2600.5));
    seatsA = seatsOf(d, rowA);
    seatsB = seatsOf(d, rowB);
  });
  return (
    json: json,
    table: table,
    tableLabel: tableLabel,
    tableDefinition: tableDefinition,
    seatDefinition: seatDefinition,
    rowA: rowA,
    seatsA: seatsA,
    rowB: rowB,
    seatsB: seatsB,
  );
}
```

  `planText` builds with the kits' parametric system installed (`test/support/harness.dart:112-122`), so the rows' seats exist in the text; their handles are the plan's (the codec keeps handles).

- [ ] **Step 5: Run the tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/kits/test_kit_units_test.dart test/kits/test_kits_test.dart`. Expected: `All tests passed!` (five new tests, and `TK1`-`TK5` unchanged).

- [ ] **Step 6: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`. Each exits 0. `git status --short` lists only this task's three files.

- [ ] **Step 7: Commit.**

```bash
git add packages/jet_cad_2d_plan/test/support/test_kit.dart packages/jet_cad_2d_plan/test/support/service_fixture.dart packages/jet_cad_2d_plan/test/kits/test_kit_units_test.dart
git commit -m "$(cat <<'EOF'
test(plan): the test kit's units and the service fixture (2b)

unitKit() is the test kit with a unit library (a numbered table of
four, an assigned seat, a booth of six named only in English), the
seats-only parametric row test.row generating labelled seats through
E5, and its tool, which places a row through symbolDefinition once
and picks the first prefix no label holds. testKit() is unchanged.
serviceFixture() gives later tasks a mirrored, turned table and two
rows, one turned, one curved, all off the origin.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, `git diff --quiet -- <file>` exits 0):
  - M-TK-row `test/support/test_kit.dart`: in `RowType.instances`, `'${row.prefix}${i + 1}'` → `'${row.prefix}$i'`. Run `flutter test test/kits/test_kit_units_test.dart --plain-name TK-row`: red (`['A0']` for `['A1']`).
  - M-TK-prefix `test/support/test_kit.dart`: in `freeRowPrefix`, `if (labels.contains('$prefix$i')) free = false;` → `{}`. Run `--plain-name TK-two-rows`: red (the second row's prefix is `A`).
  - M-TK-conf `test/support/test_kit.dart`: delete `'unit:test/booth': 'Booth',` from `testUnitWords`. Run `--plain-name TK-conformance`: red (`[KitProblemCode.unitKindWord]` for `[]`).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 1: `GeneratedInstance`, `GeneratedAttrib`, `ParametricType.instances` exported from `package:jet_cad_2d/jet_cad_2d.dart`; a matched instance keeps its handle.
- Task 3: `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` exports `SymbolsState`, `SymbolDefinitionRef`, `kUnitLabelTag`, `kUnitLabelMaxHeight`, `kUnitLabelTextAttrs`, `unitLabelHeight`, `unitLabelPayload`, `unitLabelAttrib`; `PlanKit.validate` accepts `unit:test/booth`; `conformance()` requires an **English** `unit:<kit>/<kind>` word for a kind outside `UnitKinds` and does not hold it to the declared locales (spec S4: "requires an English word"). Task 3 does not hold it to the declared locales (its plan decision "`unit:` words need English only in conformance"); do not add a Turkish booth word.
- Task 4: `KitServices.symbolDefinition` returns the pending ref until the document holds the definition or the next `execute`; `PlanController.symbolsState` is `ValueListenable<SymbolsState>`. Task 1: `GuardedType` forwards `instances` (controller ruling R-1).

---


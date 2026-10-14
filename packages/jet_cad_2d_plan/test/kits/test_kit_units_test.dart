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
        c.execute(
            SetComponentCommand<RowComponent>(row, params.copyWith(count: 4))),
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
            committedSnapshot:
                encodeSnapshot(geometrySnapshot(testUnitCatalog)),
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
    expect([for (final s in f.seatsA) unitLabelsOf(d, s).single.$2],
        ['A1', 'A2', 'A3', 'A4', 'A5', 'A6']);
    expect([for (final s in f.seatsB) unitLabelsOf(d, s).single.$2],
        ['B1', 'B2', 'B3', 'B4', 'B5']);
    for (final s in [...f.seatsA, ...f.seatsB]) {
      expect((d.tree[s]! as InstanceNode).definition, f.seatDefinition);
    }
  });
}

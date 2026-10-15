// Spec 2b S2: placed and generated units in one index, locks (a frozen
// row, a missing kit's rows, a seat of a missing kit's definition), a held
// object's units, duplicate, unlabelled and bad labels, the next number,
// and the unit components' registration. On the service fixture: a
// mirrored, turned table; a turned row and a curved one, off the origin.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:jet_cad_2d_plan/src/kits/locks.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placeSymbol;
import 'package:jet_cad_2d_plan/src/units/unit_components.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:jet_cad_2d_plan/src/units/unit_label.dart';
import 'package:jet_cad_2d_plan/src/units/unit_numbers.dart';
import 'package:jet_cad_2d_plan/src/units/unit_problems.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart';
import '../support/symbol_fixtures.dart' show symbolKit;
import '../support/test_kit.dart';
import '../support/unit_fixtures.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

List<double> boxOf(Aabb2 b) => [b.minX, b.minY, b.maxX, b.maxY];

List<Handle> ascending(Iterable<Handle> hs) =>
    hs.toList()..sort((a, b) => a.value.compareTo(b.value));

/// A row of the fixture's seat: [prefix], [count] seats, at [at] turned
/// [angle]; executed through [c]; its handle.
Handle addSeatRow(PlanController c, ServiceFixture f, String prefix, int count,
    {required Vector2 at, double angle = 0, double curve = 0}) {
  final seat = testEntry(rowSeatKey);
  final h = c.document.handleSeed.next();
  expect(
      c.execute(placeRowCommand(
          c.document,
          RowComponent(
              prefix: prefix,
              count: count,
              spacing: 500,
              curve: curve,
              seat: f.seatDefinition,
              base: seat.definition.basePoint,
              top: entryTop(seat)),
          at: at,
          angle: angle,
          handle: h)),
      isTrue);
  return h;
}

/// A plan text whose root holds a group G turned 0.4 rad at (3100.5,
/// -1700.25), carrying a slab (the test kit's type) unless [plain], with
/// one stool (a unit) under it, turned 37°.
({String text, Handle group, Handle seat}) heldPlan({bool plain = false}) {
  final d = plan(catalog: catalogOf([testKit()]));
  final group = d.handleSeed.next();
  d.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: group,
        parent: d.rootHandle,
        transform: Transform2.translation(3100.5, -1700.25)
            .multiply(Transform2.rotation(0.4)),
        children: const [])),
    if (!plain)
      SetComponentCommand<SlabComponent>(
          group, SlabComponent(width: 1800, height: 900, angle: 0.4)),
  ], label: 'Holder'));
  final made = definitionForEntry(d, entryOf(stoolSymbol));
  d.commands.execute(CompoundCommand(made.commands, label: 'Stool'));
  final seat = d.handleSeed.next();
  d.commands.execute(AddNodeCommand(InstanceNode(
      handle: seat,
      parent: group,
      transform: placementAt(120, -80, kDeg37, baseX: 400, baseY: 300),
      definition: made.definition,
      layer: ReservedHandles.layerZero)));
  final text = DraftDocumentCodec.encodeToString(d);
  d.dispose();
  return (text: text, group: group, seat: seat);
}

DraftDocument decodeWith(String text, ParametricCatalog catalog) {
  final d = DraftDocumentCodec.decodeString(text,
      registerComponents: (r) => registerPlanComponents(r, catalog));
  addTearDown(d.dispose);
  return d;
}

/// A plan over unitKit() whose row A (four seats, turned 0.5 rad, off the
/// origin) seats a definition keyed under the kit `gone`.
({String json, Handle row, List<Handle> seats}) goneSeatPlan() {
  late Handle row;
  late List<Handle> seats;
  final json = planText([unitKit(), symbolKit('gone', const [])], (d) {
    final def = d.handleSeed.next();
    final leaf = d.handleSeed.next();
    d.commands.execute(CompoundCommand([
      AddDefinitionCommand(Definition(
          handle: def,
          name: 'gone.seat.basic.one@1',
          basePoint: Vector2(250, 265),
          children: const [])),
      SetComponentCommand<SymbolComponent>(
          def,
          SymbolComponent(
              key: 'gone.seat.basic.one',
              version: 1,
              name: 'Gone seat',
              category: 'Gone',
              tags: const ['seat'])),
      SetComponentCommand<UnitComponent>(
          def,
          UnitComponent(
              kind: UnitKinds.seat,
              capacity: 1,
              labelling: UnitLabelling.assigned)),
      AddEntityCommand(
          record: EntityRecord(
            handle: leaf,
            owner: def,
            kind: EntityKind.polyline,
            layer: ReservedHandles.layerZero,
            linetype: ReservedHandles.byBlockLinetype,
            linetypeScale: 1.0,
            geomIndex: 0,
            color: const ByBlockColor(),
            lineweight: kByBlock,
            transparency: kByBlock,
            flags: 0,
          ),
          payload: polylinePayload([
            Vector2(25, 40),
            Vector2(475, 40),
            Vector2(475, 490),
            Vector2(25, 490),
          ], closed: true)),
    ], label: 'Gone seat'));
    row = addRow(
        d,
        RowComponent(
            prefix: 'A',
            count: 4,
            spacing: 600,
            seat: def,
            base: Vector2(250, 265),
            top: const Aabb2.raw(25, 40, 475, 490)),
        at: Vector2(-3900.25, 2700.5),
        angle: 0.5);
    seats = seatsOf(d, row);
  });
  return (json: json, row: row, seats: seats);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'UI-generated placed and generated units in one index, ascending: the '
      'table placed; each seat generated by its row, labelled, with its '
      'world transform, its top and its box (M-UI-generated)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final index = c.unitIndex;
    expect([for (final u in index.units) u.instance],
        ascending([f.table, ...f.seatsA, ...f.seatsB]));
    final table = index[f.table]!;
    expect(
        (table.owner, table.ownerType, table.generated), (null, null, false));
    expect((
      table.label,
      table.text,
      table.kind,
      table.capacity,
      table.labelling,
      table.symbolKey
    ), (
      f.tableLabel,
      '12',
      UnitKinds.table,
      4,
      UnitLabelling.numbered,
      'test.table.square.four'
    ));
    expect(
        table.toWorld
            .equals((d.tree[f.table]! as InstanceNode).transform, exact),
        isTrue);
    expect(boxOf(table.top), [150, 150, 1050, 1050]);
    expect(boxOf(table.box), [-150, -150, 1350, 1350]);
    final groupA = (d.tree[f.rowA]! as GroupNode).transform;
    for (final (i, s) in f.seatsA.indexed) {
      final u = index[s]!;
      expect((u.owner, u.ownerType, u.generated, u.text, u.kind, u.capacity),
          (f.rowA, rowTypeId, true, 'A${i + 1}', UnitKinds.seat, 1));
      expect(u.labelling, UnitLabelling.assigned);
      expect(
          u.toWorld.equals(
              groupA.multiply((d.tree[s]! as InstanceNode).transform), exact),
          isTrue,
          reason: 'seat $i: group × instance');
      expect((u.locked, u.visible), (false, true));
      expect(boxOf(u.top), [25, 40, 475, 490]);
    }
    expect([for (final s in f.seatsB) index[s]!.text],
        ['B1', 'B2', 'B3', 'B4', 'B5']);
    expect(
        [for (final u in index.withLabel(' A3 ')) u.instance], [f.seatsA[2]]);
    expect(index.nested, isEmpty);
    expect(index.diagnostics(), isEmpty);
    expect(index.warnings(), isEmpty);
  });

  test(
      'UI-missing-kit Review Focus 4: rows whose kit is missing: each seat a '
      'unit of its row, served and locked; the table of the missing kit\'s '
      'symbol locked; none nested (M-UI-held)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [discKit()], json: f.json);
    expect(c.missingKits, {'test'});
    final index = c.unitIndex;
    expect([for (final u in index.units) u.instance],
        ascending([f.table, ...f.seatsA, ...f.seatsB]));
    for (final (row, seats) in [(f.rowA, f.seatsA), (f.rowB, f.seatsB)]) {
      for (final s in seats) {
        final u = index[s]!;
        expect((
          u.owner,
          u.ownerType,
          u.locked,
          u.visible
        ), (
          row,
          rowTypeId,
          true,
          true
        ), reason: 'seat ${s.toHex()}');
      }
    }
    expect(index[f.seatsA.first]!.text, 'A1');
    expect(index[f.table]!.locked, isTrue);
    expect(index.nested, isEmpty);
  });

  test(
      'UI-frozen-no-edit a row frozen with no edit after it: its seats read '
      'locked at once, the state id unmoved; the other row\'s and the table '
      'do not (M-UI-locked-key)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final first = c.unitIndex;
    expect(identical(c.unitIndex, first), isTrue,
        reason: 'no change, no rebuild');
    expect(first[f.seatsA.first]!.locked, isFalse);
    final state = c.document.commands.stateId;
    c.lockBroken({f.rowA});
    expect(c.document.commands.stateId, state,
        reason: 'premise: a freeze moves no state id');
    final after = c.unitIndex;
    for (final s in f.seatsA) {
      expect(after[s]!.locked, isTrue, reason: 'seat ${s.toHex()}');
    }
    for (final s in f.seatsB) {
      expect(after[s]!.locked, isFalse);
    }
    expect(after[f.table]!.locked, isFalse);
  });

  test(
      'UI-flip a group the lock set holds for an unknown component stays '
      'held: its unit served and locked, its kit missing or loaded; a plain '
      'group: unit.nested (M-UI-held, M-UI-object)', () {
    final held = heldPlan();
    final missing = decodeWith(held.text, ParametricCatalog());
    final locks = LockSet.scan(missing, (kit) => kit != 'test');
    expect(locks.isLockedObject(held.group), isTrue, reason: 'premise');
    final a = UnitIndex.of(missing,
        catalog: ParametricCatalog(), locks: locks)[held.seat]!;
    expect((a.owner, a.ownerType, a.locked), (held.group, 'test.slab', true));

    // Spec S2 "A held object stays held" (controller ruling R-9): with its
    // kit loaded, a group holding a component no loaded code knows keeps
    // its lock (2a's rule, locks.dart:33-44).
    final catalog = catalogOf([testKit()]);
    final ghost = held.text.replaceAll('"$slabTypeId"', '"test.ghost"');
    expect(ghost, isNot(held.text), reason: 'premise');
    final loaded = decodeWith(ghost, catalog);
    final loadedLocks = LockSet.scan(loaded, (_) => true);
    expect(loadedLocks.isLockedObject(held.group), isTrue, reason: 'premise');
    final b =
        UnitIndex.of(loaded, catalog: catalog, locks: loadedLocks)[held.seat]!;
    expect((b.owner, b.ownerType, b.locked), (held.group, 'test.ghost', true));

    final plain = heldPlan(plain: true);
    final c = unitIndexOf(decodeWith(plain.text, catalog), catalog: catalog);
    expect(c[plain.seat], isNull);
    expect(c.nested, [plain.seat]);
    expect([for (final x in c.diagnostics()) x.code], [UnitProblem.nested]);
  });

  test(
      'UI-def-kit-missing a seat whose definition\'s kit is missing, in a '
      'loaded kit\'s row: covered and locked; the row is no locked object '
      '(M-UI-covers)', () {
    final g = goneSeatPlan();
    final c = controllerFor(kits: [unitKit()], json: g.json);
    expect(c.missingKits, {'gone'});
    final index = c.unitIndex;
    for (final s in g.seats) {
      final u = index[s]!;
      expect((u.owner, u.ownerType, u.locked), (g.row, rowTypeId, true));
    }
    expect(c.locked.value.contains(g.row), isFalse);
    expect(c.isLocked(g.row), isFalse);
  });

  test(
      'UI-held-seat-row-locked the row of such a seat is effectively locked: '
      'an edit regenerating it is refused with PlanLocked, nothing changed '
      '(M-UI-scan)', () {
    final g = goneSeatPlan();
    final c = controllerFor(kits: [unitKit()], json: g.json);
    final d = c.document;
    final params = d.components.get<RowComponent>(g.row)!;
    final before = [
      for (final s in g.seats) (d.tree[s]! as InstanceNode).transform,
    ];
    expect(
        c.execute(SetComponentCommand<RowComponent>(
            g.row, params.copyWith(spacing: 700))),
        isFalse);
    expect(c.lockHint.value, isTrue);
    expect(d.components.get<RowComponent>(g.row), params);
    for (final (i, s) in g.seats.indexed) {
      expect((d.tree[s]! as InstanceNode).transform.equals(before[i], exact),
          isTrue);
    }
  });

  test(
      'UI-dup a label a table and a seat share stays label-keyed: both carry '
      'it, one DuplicateLabel, one duplicate diagnostic naming both '
      '(M-UI-dup)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final row = addSeatRow(c, f, '', 13,
        at: Vector2(1200.5, 5600.25), angle: -0.2, curve: -0.05);
    final twelfth = seatsOf(c.document, row)[11];
    final index = c.unitIndex;
    expect([for (final u in index.withLabel('12')) u.instance],
        [f.table, twelfth]);
    expect(index.warnings(), [const DuplicateLabel(label: '12', count: 2)]);
    final dup = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.duplicateLabel)
        .single;
    expect(dup.handles, [f.table, twelfth]);
    expect(dup.severity, DiagnosticSeverity.warning);
  });

  test(
      'UI-unlabelled a placed unit with no label, or an empty one, is '
      'unlabelled: Unlabelled with its kind, capacity and symbol, and '
      'unit.unlabelled (M-UI-unlabelled)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    InstanceNode place(String id, Vector2 at, int turns) {
      final before = {for (final n in d.tree.nodes) n.handle};
      expect(
          c.execute(placeSymbol(d, testEntry(id), at: at, quarterTurns: turns)),
          isTrue);
      return d.tree.nodes
          .whereType<InstanceNode>()
          .singleWhere((n) => !before.contains(n.handle));
    }

    final table = place(tableSymbolId, Vector2(7100.25, 2300.5), 3);
    labelPlacedUnit(d, table.handle, testEntry(tableSymbolId), '  ');
    final booth = place(boothSymbolId, Vector2(-6400.5, 5100.75), 2);
    final index = c.unitIndex;
    expect(index[table.handle]!.label, isNotNull,
        reason: 'premise: the table carries an empty label');
    expect(index[table.handle]!.text, isNull);
    expect(index.warnings(), const [
      Unlabelled(
          kind: 'table', capacity: 4, symbolKey: 'test.table.square.four'),
      Unlabelled(
          kind: 'booth', capacity: 6, symbolKey: 'test.booth.corner.six'),
    ]);
    final unlabelled = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.unlabelled)
        .toList();
    expect([
      for (final x in unlabelled) x.handles
    ], [
      [table.handle],
      [booth.handle]
    ]);
  });

  test(
      'UI-bad a label outside the text rule is still a label, served by its '
      'text: BadLabel and unit.bad_label, a generated one included '
      '(M-UI-bad)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final row = addSeatRow(c, f, 'ABCDEFGH', 2,
        at: Vector2(-1500.75, -6200.5), angle: 1.1);
    expect(c.execute(SetEntityTextCommand(f.tableLabel, 'a\u0085b', 'UNIT')),
        isTrue);
    final seats = seatsOf(c.document, row);
    final index = c.unitIndex;
    expect(index[seats.first]!.text, 'ABCDEFGH1');
    expect([for (final u in index.withLabel('ABCDEFGH2')) u.instance],
        [seats.last]);
    expect(index.warnings(), const [
      BadLabel(label: 'a\u0085b', problem: UnitLabelProblem.control),
      BadLabel(label: 'ABCDEFGH1', problem: UnitLabelProblem.length),
      BadLabel(label: 'ABCDEFGH2', problem: UnitLabelProblem.length),
    ]);
    final bad = index
        .diagnostics()
        .where((x) => x.code == UnitProblem.badLabel)
        .toList();
    expect([
      for (final x in bad) x.handles
    ], [
      [f.table],
      [seats.first],
      [seats.last],
    ]);
  });

  test(
      'UI-next the next number skips any unit\'s label, a seat\'s included; '
      'past 99999999 it is the smallest number no unit holds '
      '(M-UI-next-skip, M-UI-next-fallback)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    expect(nextUnitNumber(c.unitIndex), '13');
    addSeatRow(c, f, '', 14, at: Vector2(2100.25, 6300.5), angle: 0.25);
    expect(nextUnitNumber(c.unitIndex), '15',
        reason: '13 and 14 are seats\' labels');
    expect(c.execute(SetEntityTextCommand(f.tableLabel, '99999999', 'UNIT')),
        isTrue);
    expect(nextUnitNumber(c.unitIndex), '15',
        reason: '1 to 14 are seats\' labels, 99999999 the table\'s');
  });

  test(
      'UI-registered the plan registers the unit components: data on the '
      'table and a colour on a seat survive a save and a load, typed '
      '(M-UI-registered)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    expect(
        c.execute(SetComponentCommand<UnitData>(
            f.table, UnitData({'id': 'T-12', 'zone': 'Bahçe'}))),
        isTrue);
    expect(
        c.execute(SetComponentCommand<UnitColour>(
            f.seatsB[2], UnitColour(PlanSwatch.teal))),
        isTrue);
    final back = controllerFor(kits: [unitKit()], json: c.save());
    expect(back.document.components.get<UnitData>(f.table)!.data,
        {'id': 'T-12', 'zone': 'Bahçe'});
    expect(back.document.components.get<UnitColour>(f.seatsB[2])!.swatch,
        PlanSwatch.teal);
    expect(back.unitIndex.diagnostics(), isEmpty);
  });

  test(
      'UI-def-missing a row naming a definition that is gone is frozen on '
      'load by the boundary: its seats stay units of their row, locked, '
      'with their handles and labels; one diagnostic names the row '
      '(controller ruling R-24, M-UI-def)', () {
    final f = serviceFixture();
    final catalog = catalogOf([unitKit()]);
    final scratch = decodeWith(f.json, catalog);
    final gone = scratch.handleSeed.next();
    expect(scratch.tree.definition(gone), isNull, reason: 'premise');
    final labels = {
      for (final s in f.seatsA) s: unitLabelsOf(scratch, s),
    };
    final json = (jsonDecode(f.json) as Map).cast<String, Object?>();
    final rows = (json['components']! as Map)[rowTypeId]! as Map;
    final rowA = rows['${f.rowA.value}']! as Map;
    expect(rowA['seat'], f.seatDefinition.value, reason: 'premise');
    rowA['seat'] = gone.value;
    final c = controllerFor(kits: [unitKit()], json: jsonEncode(json));
    final d = c.document;
    expect(c.frozen, {f.rowA});
    expect(c.isLocked(f.rowA), isTrue);
    expect(seatsOf(d, f.rowA), f.seatsA, reason: 'no regeneration ran');
    final index = c.unitIndex;
    for (final (i, s) in f.seatsA.indexed) {
      final u = index[s]!;
      expect((
        u.owner,
        u.ownerType,
        u.locked,
        u.text
      ), (
        f.rowA,
        rowTypeId,
        true,
        'A${i + 1}'
      ), reason: 'seat ${s.toHex()}');
      expect(unitLabelsOf(d, s), labels[s]);
    }
    expect(index[f.seatsB.first]!.locked, isFalse);
    final diagnostics = c.diagnostics.value;
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.subject, rowTypeId);
    expect(diagnostics.single.code, KitDiagnosticCode.hookFailed);
    expect(diagnostics.single.message, contains(f.rowA.toHex()));
    expect(diagnostics.single.error, isA<GeneratedDefinitionError>());
  });
}

// Spec 2b S2 "The label system", "The label" (placed rules): the label
// system stacks between the parametric system and the lock, so the lock
// sees its stamps; a placed numbered unit gets the next number, upright, in
// the placement's one step, from the controller's index and through its
// symbol tool; an assigned one gets none; a seat's label stays its type's.
// On the service fixture: a mirrored, turned table, a turned row and a
// curved one, off the origin.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show unitLabelAttrib;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart' show PlanController;
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show placeSymbol;
import 'package:jet_cad_2d_plan/src/units/unit_rotate.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart' show kDeg37, plan, unitIndexOf;
import '../support/service_fixture.dart';
import '../support/symbol_fixtures.dart' show settle;
import '../support/test_kit.dart';
import '../support/tool_events.dart';

const Tolerance exact = Tolerance(linear: 0, angular: 0);

GeometryPayload payloadOf(DraftDocument d, Handle entity) =>
    d.geometry.read(d.entities.geomIndexAt(d.entities.slotOf(entity)!));

/// The one new root-level instance [action] adds to [c]'s document.
Handle placedBy(PlanController c, void Function() action) {
  final d = c.document;
  final before = {for (final n in d.tree.nodes) n.handle};
  action();
  return d.tree.nodes
      .whereType<InstanceNode>()
      .singleWhere((n) => !before.contains(n.handle))
      .handle;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'UL-stack the lock sees the label system\'s stamps: a turn whose stamp '
      'writes a locked handle is refused, nothing changed; unlocked, the '
      'same turn passes and stamps (M-UL-stack)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final start = (d.tree[f.table]! as InstanceNode).transform;
    final label0 = payloadOf(d, f.tableLabel);
    // Positive control: the turn applies and stamps the label.
    expect(c.execute(rotateUnitCommand(d, f.table, 1)!), isTrue);
    expect(payloadOf(d, f.tableLabel), isNot(label0));
    c.undo();
    expect(payloadOf(d, f.tableLabel), label0);
    // The label alone locked: it stands for any handle only a stamp
    // touches. The turn itself touches the table, which is not locked.
    c.lockBroken({f.tableLabel});
    expect(c.isLocked(f.table), isFalse, reason: 'premise');
    expect(c.execute(rotateUnitCommand(d, f.table, 1)!), isFalse);
    expect(c.lockHint.value, isTrue);
    expect((d.tree[f.table]! as InstanceNode).transform.equals(start, exact),
        isTrue);
    expect(payloadOf(d, f.tableLabel), label0);
  });

  test(
      'UL-place-number a placed numbered unit gets the next number as its '
      'UNIT label in the placement\'s one step, upright though turned and '
      'mirrored; the symbol tool numbers through the controller\'s index '
      '(M-UL-number, M-UL-tool)', () async {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    await settle();
    final d = c.document;
    final entry = c.symbolById(tableSymbolId)!.entry;
    final depth = d.commands.undoDepth;
    final first = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, entry,
                at: Vector2(-6100.25, 4300.5),
                quarterTurns: 3,
                mirrored: true,
                units: c.unitIndex)),
            isTrue));
    expect(d.commands.undoDepth, depth + 1, reason: 'one step');
    final [(label, text)] = unitLabelsOf(d, first);
    expect(text, '13', reason: 'the table is 12; seats do not count');
    final node = d.tree[first]! as InstanceNode;
    expect(node.transform.determinant, lessThan(0), reason: 'premise');
    expectUprightLabel(d, label, node.transform);
    expect(payloadOf(d, label).coords,
        [entry.definition.basePoint.x, entry.definition.basePoint.y]);

    // The placer's own stamp, without the label system to mask it: on a
    // bare document the placement alone leaves the label upright.
    final bare = plan();
    bare.commands.execute(placeSymbol(bare, entry,
        at: Vector2(-6100.25, 4300.5),
        quarterTurns: 3,
        mirrored: true,
        units: unitIndexOf(bare)));
    final bareUnit = bare.tree.nodes.whereType<InstanceNode>().single;
    final [(bareLabel, _)] = unitLabelsOf(bare, bareUnit.handle);
    expectUprightLabel(bare, bareLabel, bareUnit.transform);

    useTestCamera(c);
    expect(c.armSymbol(c.symbolById(tableSymbolId)!), isTrue);
    final second = placedBy(c, () => tapAt(c, Vector2(7300.75, -5200.5)));
    expect([for (final l in unitLabelsOf(d, second)) l.$2], ['14']);
  });

  test(
      'UL-assigned an assigned unit placed gets no label; a numbered one '
      'placed after it takes the next number (M-UL-assigned)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final seat = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, testEntry(rowSeatKey),
                at: Vector2(3300.5, 6100.25),
                quarterTurns: 2,
                units: c.unitIndex)),
            isTrue));
    expect(unitLabelsOf(d, seat), isEmpty);
    final booth = placedBy(
        c,
        () => expect(
            c.execute(placeSymbol(d, testEntry(boothSymbolId),
                at: Vector2(-7200.75, -1100.5),
                quarterTurns: 1,
                mirrored: true,
                units: c.unitIndex)),
            isTrue));
    expect([for (final l in unitLabelsOf(d, booth)) l.$2], ['13']);
  });

  test(
      'UL-seat a seat a row\'s regeneration adds keeps its type\'s label, '
      'stamped for the world: the label system stamps placed units only '
      '(M-UL-root)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final p = d.components.get<RowComponent>(f.rowA)!;
    final grown = p.copyWith(count: 7);
    expect(c.execute(SetComponentCommand<RowComponent>(f.rowA, grown)), isTrue);
    final seven = seatsOf(d, f.rowA);
    expect(seven.sublist(0, 6), f.seatsA);
    final added = seven.last;
    final [(label, text)] = unitLabelsOf(d, added);
    expect(text, 'A7');
    final group = (d.tree[f.rowA]! as GroupNode).transform;
    final toWorld = group.multiply((d.tree[added]! as InstanceNode).transform);
    final want = unitLabelAttrib('A7',
            instanceToWorld: toWorld, anchor: grown.base, top: grown.top)
        .payload;
    final got = payloadOf(d, label);
    expect(got.coords, want.coords);
    expect(got.scalars[0], want.scalars[0]);
    expect(got.scalars[1], closeTo(want.scalars[1], 1e-12));
    expect(got.scalars[2], want.scalars[2]);
    expectUprightLabel(d, label, toWorld);
  });

  test(
      'UL-turn-row a row group turned about a point off it keeps every seat '
      'label upright for the world: the label system stamps nothing here, '
      'the row\'s regeneration restamps (M-UL-turn)', () {
    final f = serviceFixture();
    final c = controllerFor(kits: [unitKit()], json: f.json);
    final d = c.document;
    final group = d.tree[f.rowA]! as GroupNode;
    Transform2 toWorld(Handle seat) => (d.tree[f.rowA]! as GroupNode)
        .transform
        .multiply((d.tree[seat]! as InstanceNode).transform);
    final seats = seatsOf(d, f.rowA);
    final before = {
      for (final s in seats) s: payloadOf(d, unitLabelsOf(d, s).single.$1),
    };
    final pivot = Vector2(-1750.5, 3300.25);
    final turned = Transform2.translation(pivot.x, pivot.y)
        .multiply(Transform2.rotation(kDeg37))
        .multiply(Transform2.translation(-pivot.x, -pivot.y))
        .multiply(group.transform);
    expect(c.execute(TransformNodeCommand(f.rowA, turned)), isTrue);
    expect(
        (d.tree[f.rowA]! as GroupNode).transform.equals(group.transform, exact),
        isFalse,
        reason: 'premise: the row turned');
    for (final s in seats) {
      final [(label, _)] = unitLabelsOf(d, s);
      expectUprightLabel(d, label, toWorld(s));
      expect(payloadOf(d, label).scalars[1], isNot(before[s]!.scalars[1]),
          reason: 'restamped for the new group transform');
    }
    c.undo();
    for (final s in seats) {
      final [(label, _)] = unitLabelsOf(d, s);
      expectUprightLabel(d, label, toWorld(s));
      expect(payloadOf(d, label), before[s]);
    }
  });
}

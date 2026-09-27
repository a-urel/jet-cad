// Spec 10 D3, D17: the room separator's parameters (SR1), what it generates
// (SR2), its empty reach (SR4) and the DASHED record (SR5).
import 'dart:convert';

import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// A group near the corpus's far origin, turned by a non-right angle.
final Transform2 farGroup =
    Transform2.translation(4500000 + 311.5, 1200000 - 173.25)
        .multiply(Transform2.rotation(0.3 + 0.7 * 4));

List<double> coordsOf(DraftDocument doc, Handle h) =>
    payloadOf(doc, h).coords.toList();

void main() {
  test(
      'SR1 SeparatorParams round-trip with key order start, end; == '
      'differs on each field', () {
    const p = SeparatorParams(1234.5, -678.25, 4321.75, 876.125);
    final json = p.toJson();
    expect(json.keys.toList(), ['start', 'end']);
    expect(json, {
      'start': [1234.5, -678.25],
      'end': [4321.75, 876.125],
    });
    final back = SeparatorParams.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, Object?>);
    expect(back, p);
    expect(back.hashCode, p.hashCode);
    expect(p.typeId, 'floor_planner.separator');
    // Each field alone breaks ==.
    for (final other in const [
      SeparatorParams(1234.25, -678.25, 4321.75, 876.125),
      SeparatorParams(1234.5, -678.5, 4321.75, 876.125),
      SeparatorParams(1234.5, -678.25, 4321.5, 876.125),
      SeparatorParams(1234.5, -678.25, 4321.75, 876.25),
    ]) {
      expect(other == p, isFalse, reason: '$other');
    }
    // copyWith replaces one end and keeps the other.
    expect(p.copyWith(start: Vector2(1.5, 2.25)),
        const SeparatorParams(1.5, 2.25, 4321.75, 876.125));
    expect(p.copyWith(end: Vector2(-3.75, 4.5)),
        const SeparatorParams(1234.5, -678.25, -3.75, 4.5));
    // Anything well-typed: integers read as doubles.
    expect(
        SeparatorParams.fromJson(const {
          'start': [1, 2],
          'end': [3, 4],
        }),
        const SeparatorParams(1, 2, 3, 4));
  });

  test(
      'SR2 a separator generates one open polyline, ByLayer, linetype '
      'dashedLinetype, lineweight 35, written once on add', () {
    final doc = DraftDocument.empty();
    installParametric(doc);
    ensureDashedLinetype(doc);
    final s = Vector2(4501234.5, 1201876.25),
        e = Vector2(4503456.75, 1204321.5);
    final depth = doc.commands.undoDepth;
    final h = addSeparator(doc, s, e, at: farGroup);
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    final p = doc.components.get<SeparatorParams>(h)!;
    // Premise: fractional stored ends, off the identity.
    expect(p.sx == p.sx.roundToDouble(), isFalse);

    final children = kids(doc, h);
    expect(children, hasLength(1));
    final child = children.single;
    expect(kindOf(doc, child), EntityKind.polyline);
    final r = recordOf(doc, child);
    expect(r.color, isA<ByLayerColor>());
    expect(r.layer, ReservedHandles.layerZero);
    expect(r.linetype, ReservedHandles.dashedLinetype);
    expect(r.lineweight, 35);
    expect(r.transparency, kByLayer);
    expect(r.flags, 0);
    // Open, two points: the stored ends themselves, in local space.
    expect(coordsOf(doc, child), [p.sx, p.sy, p.ex, p.ey]);
    final world = worldPoints(doc, child);
    expect(world[0].distanceTo(s), lessThan(1e-6));
    expect(world[1].distanceTo(e), lessThan(1e-6));
    expect(driftOf(doc), isEmpty);

    // Moving the end rewrites the payload in place and keeps the record.
    final moved = p.copyWith(end: Vector2(p.ex + 250.25, p.ey - 125.5));
    doc.commands.execute(SetComponentCommand<SeparatorParams>(h, moved));
    expect(kids(doc, h), [child]);
    expect(coordsOf(doc, child), [moved.sx, moved.sy, moved.ex, moved.ey]);
    final r2 = recordOf(doc, child);
    expect(r2.color, isA<ByLayerColor>());
    expect(r2.linetype, ReservedHandles.dashedLinetype);
    expect(r2.lineweight, 35);
    expect(driftOf(doc), isEmpty);

    // A degenerate separator (its ends one point) generates nothing: a
    // childless group.
    final d = addSeparator(doc, s, s, at: farGroup);
    expect(kids(doc, d), isEmpty);
    expect(driftOf(doc), isEmpty);
  });

  test('SR4 a separator\'s reach is empty: no wall lists it as a neighbour',
      () {
    for (final place in [origin, corpusGroups]) {
      // A separator lying diagonally across the box's bottom wall.
      final plan = buildPlan(boxWalls,
          seps: const [(3500.25, -600.5, 4200.75, 700.25)], place: place);
      final bottom = plan.walls[0], sep = plan.seps.single;
      // Premise: the segment's box overlaps the wall's reach by far more
      // than the engine's tolerance on both axes, so any reach built from
      // the segment would make them neighbours.
      final reach = const WallType().reach(
          plan.doc.components.get<WallParams>(bottom)!,
          plan.doc.tree.accumulatedTransform(bottom));
      final segment = Aabb2.fromPoints(
          [plan.at(3500.25, -600.5), plan.at(4200.75, 700.25)]);
      for (final (lo, hi) in [
        (reach.minX, segment.maxX),
        (segment.minX, reach.maxX),
        (reach.minY, segment.maxY),
        (segment.minY, reach.maxY),
      ]) {
        expect(hi - lo, greaterThan(1), reason: '$place: overlap');
      }

      final seen = probeView(plan.doc);
      expect(seen.neighbours[bottom], isNot(contains(sep)), reason: '$place');
      expect(seen.neighbours[sep], isEmpty, reason: '$place');
      for (final w in plan.walls) {
        expect(seen.neighbours[w], isNot(contains(sep)), reason: '$place');
      }
      // It is still placed: an input to rooms by place, not by reach.
      expect(seen.inputs[sep], isNotNull);
      expect(seen.placedAll, contains(sep));
      final inputs = RoomInputs(plan.doc);
      addTearDown(inputs.dispose);
      expect(inputs.wallNeighboursOf(sep), isEmpty);
      expect(inputs.inputOf(sep), seen.inputs[sep]);
    }
  });

  test(
      'SR5 ensureDashedLinetype adds the DASHED record once, and adds '
      'nothing when handle 6 or the name DASHED is taken', () {
    // Twice on one document: one record, outside the history.
    final doc = DraftDocument.empty();
    final lt = doc.tables.linetypes;
    expect(lt.contains(ReservedHandles.dashedLinetype), isFalse,
        reason: 'premise: not in the default tables');
    ensureDashedLinetype(doc);
    ensureDashedLinetype(doc);
    final r = lt[ReservedHandles.dashedLinetype]!;
    expect(r.name, 'DASHED');
    expect(r.description, 'Dashed __ __ __');
    expect(r.pattern.dashes, [200, -100]);
    expect(r.pattern.totalLength, 300);
    expect([
      for (final x in lt.records)
        if (x.name == 'DASHED') x
    ], hasLength(1));
    expect(doc.commands.undoDepth, 0, reason: 'outside the history');

    // Handle 6 already holds another record: it is kept.
    final six = DraftDocument.empty();
    six.tables.linetypes.add(const LinetypeRecord(
        handle: ReservedHandles.dashedLinetype,
        name: 'OTHER',
        description: 'another',
        pattern: DashPattern(dashes: [50, -50], totalLength: 100)));
    ensureDashedLinetype(six);
    expect(six.tables.linetypes[ReservedHandles.dashedLinetype]!.name, 'OTHER');
    expect(six.tables.linetypes.byName('DASHED'), isNull);

    // `dashed` on handle 20: nothing is added, and a separator still names
    // handle 6 (it draws continuous there).
    final named = DraftDocument.empty();
    named.tables.linetypes.add(const LinetypeRecord(
        handle: Handle(20),
        name: 'dashed',
        description: 'theirs',
        pattern: DashPattern(dashes: [10, -10], totalLength: 20)));
    ensureDashedLinetype(named);
    expect(named.tables.linetypes.contains(ReservedHandles.dashedLinetype),
        isFalse);
    expect(named.tables.linetypes.byName('DASHED')!.handle, const Handle(20));
    installParametric(named);
    final h =
        addSeparator(named, Vector2(1000.5, 2000.25), Vector2(4000.75, 2500.5));
    expect(recordOf(named, kids(named, h).single).linetype,
        ReservedHandles.dashedLinetype);
  });
}

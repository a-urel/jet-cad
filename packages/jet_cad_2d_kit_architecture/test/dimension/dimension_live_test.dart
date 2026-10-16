// 3a Task 20, spec C1.5: the dimension's attach search asks the plan's live
// types, never a catalog of its own. A frozen wall (the plan's
// liveTypeIdOf answers null) is no candidate, by its own children or as an
// opening's host, and no part of T; a frozen opening brings no host in.
// Today's rule (`live_objects.dart`) asked the global catalog, which
// answers a frozen object's id too (spec C1.5's Facts:
// `ParametricCatalog.typeIdOf`, parametric_system.dart:672-675).
//
// The fixture is AM6's flush T (spike C5) at the corpus far origin with
// every wall in its own turned group: C (0, 0) -> (6000, 0), 200; S (2500,
// 0) -> (2500, 3000), 100; a 900 mm door on S centred 450 along it, so S's
// butt-end points are reached only through the door's host query (AM6's
// premise, re-asserted below).
import 'dart:convert' show jsonDecode;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_attach.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left, c = WallSide.centre;

void main() {
  test(
      'DG-frozen a frozen wall is no candidate and no part of T; a frozen '
      'host is not brought in by its door; a frozen door brings no host '
      '(M-DG1, M-DG2, M-DG3, M-DG4)', () {
    final plan = flushT(corpusGroups);
    final doc = plan.doc;
    final [cw, s] = plan.walls;
    final door = plan.openings.single;
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final all = liveOf(doc);
    LiveTypeOf frozen(Handle h) => (x) => x == h ? null : all(x);

    // Premises: the catalog names all three; the plan's view of a frozen
    // object answers null for it alone.
    expect(all(cw), ArchitectureTypes.wall);
    expect(all(s), ArchitectureTypes.wall);
    expect(all(door), ArchitectureTypes.opening);
    expect(frozen(cw)(cw), isNull);
    expect(frozen(cw)(s), ArchitectureTypes.wall);

    // -- T: the thickest live wall. C is 200, S 100.
    expect(thickestWall(doc, all), 200, reason: 'control');
    expect(thickestWall(doc, frozen(cw)), 100, reason: 'C frozen: S only');

    // -- C's free start, left face (0, 100): a point of C's own children.
    final c0 = plan.at(0, 100);
    List<AttachedEnd> at(Vector2 q, LiveTypeOf live,
            [Map<Handle, WallPoints>? points]) =>
        attachCandidates(doc, index, q,
            live: live,
            objectSnap: true,
            thickest: thickestWall(doc, live),
            points: points);
    expect(at(c0, all), contains(AttachedEnd(cw, 0, l)), reason: 'control');
    // The candidate set itself, before any wall is laid out: a memo that
    // still holds every wall's live points answers a candidate without
    // laying it out, so a frozen wall in the set would come back from the
    // memo (M-DG2 red here, not at a null check).
    final held = <Handle, WallPoints>{};
    at(c0, all, held);
    at(plan.at(2500, 0), all, held);
    expect(held.keys, containsAll([cw, s]), reason: 'premise: memo filled');
    expect([
      for (final e in at(c0, frozen(cw), {...held})) e.wall
    ], isNot(contains(cw)),
        reason: 'C frozen: no candidate, its points memoised');
    expect([for (final e in at(c0, frozen(cw))) e.wall], isNot(contains(cw)),
        reason: 'C frozen: none of its points');

    // -- S's butt end on C's face, its centre (2500, 0): not stored on S
    // (AM6), so only the door's host query reaches it.
    final s0 = plan.at(2500, 0);
    expect(at(s0, all), contains(AttachedEnd(s, 0, c)), reason: 'control');
    expect(bruteCandidates(doc, s0), contains(AttachedEnd(s, 0, c)),
        reason: 'premise: a point of S');
    // The candidate set first, as above (M-DG3 red here).
    expect([
      for (final e in at(s0, frozen(s), {...held})) e.wall
    ], isNot(contains(s)),
        reason: 'S frozen: no candidate through its door, its points '
            'memoised');
    expect([for (final e in at(s0, frozen(s))) e.wall], isNot(contains(s)),
        reason: 'S frozen: its door does not bring it in');
    expect([for (final e in at(s0, frozen(door))) e.wall], isNot(contains(s)),
        reason: 'the door frozen: no host query through it');
  });

  test('DG-id a dimension is stored under architecture.dimension (M-DG5)', () {
    expect(DimensionParams.componentTypeId, ArchitectureTypes.dimension);
    expect(ArchitectureTypes.dimension, 'architecture.dimension');
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: corpusGroups);
    addDimension(
        plan.doc, const FixedEnd(10.5, -20.25), const FixedEnd(3010.75, 1180.5),
        kind: DimKind.horizontal, offset: 300.25, at: corpusGroups.m);
    final json = jsonDecode(enc(plan.doc)) as Map<String, Object?>;
    final components = json['components']! as Map<String, Object?>;
    expect(components.keys, contains('architecture.dimension'));
    expect(components.keys, isNot(contains('floor_planner.dimension')));
  });
}

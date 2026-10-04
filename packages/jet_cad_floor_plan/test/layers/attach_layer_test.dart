// Spec 12b D6 (R-7): a dimension attaches only to what is drawn, and a
// wall's layer is its `ObjectLayer`. A wall moved to a hidden layer, whose
// door stays on a visible one, attaches through neither of
// `attachCandidates`' queries: not through its own children (now on the
// hidden layer), and not as the host of the drawn door (the host's object
// layer is tested).
//
// Spike C5's T with a 900 mm door flush with the stem's butt end
// (`flushT`'s geometry): the through wall T (0, 0) → (6000, 0), 200, and
// the stem S (2500, 0) → (2500, 3000), 100, both on `A`; the door on `B`
// (visible, locked: locking is not hiding). S/0's three points are stored
// on neither wall, so only the opening-host query reaches them (AM6). At
// the corpus far origin turned 23°, every wall in its own rotated group.
import 'package:jet_cad_floor_plan/src/parametric/dimension_attach.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension_geometry.dart';
import 'package:jet_cad_floor_plan/src/parametric/opening.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/layer_fixture.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

void main() {
  for (final swing in SwingSide.values) {
    test(
        'a wall on a hidden layer whose door is on a visible one attaches '
        'through neither query; undo brings both back (M-LP-20), swing '
        '${swing.name}', () {
      final fx = layerDoc();
      final doc = fx.doc;
      final [_, s] = addWallsOn(fx, c5Walls, fx.a);
      final door = addObjectOn(doc,
          OpeningParams(s, 450, 900, OpeningKind.door, swing: swing), fx.b);
      doc.commands.clearHistory();
      expect(driftOf(doc), isEmpty, reason: 'premise: generated');
      final index = SpatialIndex(doc);
      addTearDown(index.dispose);
      List<AttachedEnd> got(Vector2 q) => attachCandidates(doc, index, q,
          objectSnap: true, thickest: thickestWall(doc));

      // S/0's three points, reached through the door only; S/1's centre,
      // reached through S's own children only.
      final flush = {
        l: fx.at(2450, 100),
        c: fx.at(2500, 0),
        r: fx.at(2550, 100),
      };
      final farEnd = fx.at(2500, 3000);

      void expectDrawn(String why) {
        for (final MapEntry(key: side, value: q) in flush.entries) {
          expect(bruteCandidates(doc, q), [AttachedEnd(s, 0, side)],
              reason: 'premise: S/0/${side.name} is a point');
          expect(got(q), [AttachedEnd(s, 0, side)],
              reason: '$why: S/0/${side.name} attaches through the door');
        }
        expect(got(farEnd), [AttachedEnd(s, 1, c)],
            reason: '$why: S/1/centre attaches through S\'s children');
      }

      expectDrawn('S on A');

      // S to the hidden C, by the picker's command.
      moveObject(doc, s, fx.c);
      expect(objectLayerOf(doc, s), fx.c);
      for (final k in kids(doc, s)) {
        expect(layerOf(doc, k), fx.c, reason: 'premise: S\'s children on C');
      }
      for (final k in kids(doc, door)) {
        expect(layerOf(doc, k), fx.b, reason: 'premise: the door stays on B');
      }
      for (final MapEntry(key: side, value: q) in flush.entries) {
        // The door is still drawn there, so the host query does run: the
        // rendering query near the point returns the door's children.
        final owners = <Handle>{};
        index.forEachInRect(
            Aabb2.raw(q.x - 300, q.y - 300, q.x + 300, q.y + 300),
            const QueryFilter.rendering(),
            (slot) => owners.add(doc.entities.ownerAt(slot)));
        expect(owners, contains(door),
            reason: 'premise: the door is drawn near S/0/${side.name}');
        expect(owners, isNot(contains(s)), reason: 'premise: S is not drawn');
        expect(bruteCandidates(doc, q), [AttachedEnd(s, 0, side)],
            reason: 'premise: S/0/${side.name} is still a point');
        expect(got(q), isEmpty,
            reason: 'S hidden: S/0/${side.name} does not attach through '
                'its drawn door');
      }
      expect(got(farEnd), isEmpty,
          reason: 'S hidden: S/1/centre does not attach through its own '
              'children');

      doc.commands.undo();
      expect(objectLayerOf(doc, s), fx.a);
      expectDrawn('undone: S on A again');
    });
  }

  test(
      'a wall whose ObjectLayer names a missing layer is on layer 0: with '
      'layer 0 hidden it attaches through neither query (8b; reads '
      'objectLayer, not the stored component)', () {
    final fx = layerDoc();
    final doc = fx.doc;
    final [_, s] = addWallsOn(fx, c5Walls, fx.a);
    addObjectOn(
        doc,
        OpeningParams(s, 450, 900, OpeningKind.door, swing: SwingSide.left),
        fx.b);
    // A dangling component: the object is on layer 0 (D2).
    doc.commands.execute(
        SetComponentCommand<ObjectLayer>(s, const ObjectLayer(Handle(0x7A7A))));
    expect(objectLayer(doc, s), ReservedHandles.layerZero);
    expect(doc.tables.layers[const Handle(0x7A7A)], isNull,
        reason: 'premise: the stored layer is missing');
    for (final k in kids(doc, s)) {
      expect(layerOf(doc, k), ReservedHandles.layerZero,
          reason: 'premise: S regenerated on layer 0');
    }
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    List<AttachedEnd> got(Vector2 q) => attachCandidates(doc, index, q,
        objectSnap: true, thickest: thickestWall(doc));
    final flush = {
      l: fx.at(2450, 100),
      c: fx.at(2500, 0),
      r: fx.at(2550, 100),
    };
    final farEnd = fx.at(2500, 3000);
    for (final MapEntry(key: side, value: q) in flush.entries) {
      expect(got(q), [AttachedEnd(s, 0, side)],
          reason: 'premise: layer 0 visible, S/0/${side.name} attaches');
    }
    expect(got(farEnd), [AttachedEnd(s, 1, c)]);

    // Hide layer 0: A current first, so layer 0 is not the effective
    // current layer (decision 7).
    doc.commands.execute(SetCurrentLayerCommand(fx.a));
    final zero = doc.tables.layers[ReservedHandles.layerZero]!;
    doc.commands.execute(SetLayerCommand(zero.copyWith(visible: false)));
    for (final MapEntry(key: side, value: q) in flush.entries) {
      expect(bruteCandidates(doc, q), [AttachedEnd(s, 0, side)],
          reason: 'premise: S/0/${side.name} is still a point');
      expect(got(q), isEmpty,
          reason: 'S on hidden layer 0: S/0/${side.name} does not attach '
              'through its drawn door');
    }
    expect(got(farEnd), isEmpty);
  });
}

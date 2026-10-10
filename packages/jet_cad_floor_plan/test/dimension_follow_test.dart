// Spec 11 D3 (the cascade), D5 (what a dimension reads, and why today's
// closure is enough) and D16 (undo of a cascade): a dimension follows its
// walls and its walls' neighbours, and is rebuilt by exactly the edits that
// reach its walls. After every edit, `drift()` is empty and every dimension
// agrees with the all-walls oracle (`oracleFailures`). Every expected value
// is hand arithmetic beside the assertion; each dimension's own group sits
// at the placement, so a hand value in the plan's frame holds at every
// placement. Ported from the spike's `drift_test.dart` (`Q2a`, `Q2b`,
// `Q2c`).
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/opening.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// `drift()` and the all-walls oracle, both empty, after [what].
void expectFollows(DraftDocument doc, String what) {
  expect(driftOf(doc), isEmpty, reason: 'drift after $what');
  expect(oracleFailures(doc), isEmpty, reason: 'oracle after $what');
}

/// Wall [w]'s thickness to [t], one command, as the Wall section makes it.
DraftCommand thickness(DraftDocument doc, Handle w, double t) =>
    SetComponentCommand<WallParams>(
        w, doc.components.get<WallParams>(w)!.copyWith(thickness: t));

/// A wall from plan point ([sx], [sy]) to ([ex], [ey]), [t] thick, centred,
/// added to [plan] as the Wall tool commits it (a root-level group and its
/// parameters, one compound), in [plan]'s own group for object number [k]
/// when the placement has own groups. Returns its handle.
Handle addWallAt(
    Plan plan, int k, double sx, double sy, double ex, double ey, double t) {
  final doc = plan.doc;
  final h = doc.handleSeed.next();
  final g = plan.place.groups ? groupFor(plan.place, k) : Transform2.identity();
  final s = g.invert().transformPoint(plan.at(sx, sy));
  final e = g.invert().transformPoint(plan.at(ex, ey));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<WallParams>(
        h, WallParams(s.x, s.y, e.x, e.y, t, Justification.centre)),
  ], label: 'Add wall'));
  return h;
}

/// The L at [place], a millimetres page: A (0, 0) → (4000, 0) and B (4000,
/// 0) → (4000, 3000), 200 centred, mitred at (4000, 0); and [dim], on A's
/// left face, A/0/left → A/1/left, aligned, offset 800.5, in a group at the
/// placement: it references A only. A's left face is y = 100: from A's free
/// start (0, 100) to the inner corner (4000 − 100, 100): 3900.
({Plan plan, Handle a, Handle b, Handle dim}) lPlan(Placement place) {
  final plan = buildPlan(
      const [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)],
      place: place);
  attachPage(plan.doc, mmPage);
  final [a, b] = plan.walls;
  final dim = addDimension(plan.doc, AttachedEnd(a, 0, l), AttachedEnd(a, 1, l),
      offset: 800.5, at: place.m);
  return (plan: plan, a: a, b: b, dim: dim);
}

/// Every live entity of [doc] as (handle, owner), ascending by handle.
List<(int, int)> handlesAndOwners(DraftDocument doc) => [
      for (final s in doc.entities.liveSlots)
        (doc.entities.handleAt(s).value, doc.entities.ownerAt(s).value),
    ]..sort((x, y) => x.$1.compareTo(y.$1));

void main() {
  for (final place in [origin, corpusGroups, km1000Groups]) {
    test(
        'DN1 a neighbour\'s edit moves a referenced wall\'s corner and '
        'rebuilds the dimension once, at $place', () {
      final (:plan, :a, :b, :dim) = lPlan(place);
      final doc = plan.doc;
      expect(dimText(doc, dim), '3900');
      expectFollows(doc, 'the L');

      // B 200 → 300: B's left face (west, B runs north) is x = 4000 − 150,
      // so A's inner corner moves to (3850, 100): 3850. A is not edited: its
      // parameters are == unchanged, and the dimension, which references A
      // only, is rebuilt once, through A being B's neighbour.
      final aBefore = doc.components.get<WallParams>(a);
      final gens = debugDimensionGenerates;
      doc.commands.execute(thickness(doc, b, 300));
      expect(doc.components.get<WallParams>(a), aBefore);
      expect(dimText(doc, dim), '3850');
      expect(debugDimensionGenerates - gens, 1);
      expectFollows(doc, 'B 200 → 300');

      // A second dimension on A's right face, A/0/right → A/1/right,
      // horizontal (the group's local x, A's direction), offset −600.25: A's
      // right face is y = −100, from A's free start (0, −100) to the outer
      // corner on B's right face (east), x = 4000 + 150: 4150.
      final right = addDimension(
          doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
          kind: DimKind.horizontal, offset: -600.25, at: place.m);
      expect(dimText(doc, right), '4150');
      expectFollows(doc, 'the right-face dimension');

      // C joined at A's start, north from (0, 0), 200 centred: A's start is
      // an L now. Its inner corner is on C's east face, (100, 100): 3850 −
      // 100 = 3750; its outer corner on C's west face, (−100, −100): 4150 +
      // 100 = 4250. Neither dimension references C.
      final c = addWallAt(plan, 7, 0, 0, 0, 3000, 200);
      expect(dimText(doc, dim), '3750');
      expect(dimText(doc, right), '4250');
      expectFollows(doc, 'C added');

      // C deleted, one step: back to 3850 and 4150.
      doc.commands.execute(deleteObject(doc, c));
      expect(dimText(doc, dim), '3850');
      expect(dimText(doc, right), '4150');
      expectFollows(doc, 'C deleted');
    });
  }

  for (final place in [origin, corpusGroups]) {
    test(
        'DN2 the T: the through wall thickened moves the stem\'s corner; the '
        'through wall moved off the stem squares it, at $place', () {
      // The through wall C (0, 0) → (6000, 0), 200; the stem S (2500, 0) →
      // (2500, 3000), 100, butting C: S's faces start on C's near face.
      final plan = buildPlan(
          const [W(0, 0, 6000, 0, 200), W(2500, 0, 2500, 3000, 100)],
          place: place);
      final doc = plan.doc;
      attachPage(doc, mmPage);
      final [cw, s] = plan.walls;
      // S's left face (west, S runs north) is x = 2450, from C's near face
      // (2450, 100) to S's free end (2450, 3000): 2900, aligned. Its right
      // face, x = 2550, the same length along the group's local y: 2900,
      // vertical. Both reference S only.
      final left = addDimension(doc, AttachedEnd(s, 0, l), AttachedEnd(s, 1, l),
          offset: 500.5, at: place.m);
      final right = addDimension(
          doc, AttachedEnd(s, 0, r), AttachedEnd(s, 1, r),
          kind: DimKind.vertical, offset: -450.25, at: place.m);
      expect(dimText(doc, left), '2900');
      expect(dimText(doc, right), '2900');
      expectFollows(doc, 'the T');

      // C 200 → 400: its near face is y = 200; 3000 − 200 = 2800. S is not
      // edited.
      final sBefore = doc.components.get<WallParams>(s);
      doc.commands.execute(thickness(doc, cw, 400));
      expect(doc.components.get<WallParams>(s), sBefore);
      expect(dimText(doc, left), '2800');
      expect(dimText(doc, right), '2800');
      expectFollows(doc, 'C 200 → 400');

      // C's group moved 50 mm along the plan's y (a select-tool move of the
      // through wall): S's start is no longer on C's centreline, so the T is
      // gone (07 D4.1) and S's start squares at its own end, (2450, 0) and
      // (2550, 0): 3000. S is still not edited.
      final m = doc.tree[cw]!.transform;
      final up = plan.at(0, 50) - plan.at(0, 0);
      doc.commands.execute(TransformNodeCommand(
          cw, Transform2.translation(up.x, up.y).multiply(m)));
      expect(doc.components.get<WallParams>(s), sBefore);
      expect(dimText(doc, left), '3000');
      expect(dimText(doc, right), '3000');
      expectFollows(doc, 'C moved off the stem');
    });

    test(
        'DN3 deleting a wall carrying three dimensions deletes all three in '
        'the same step; the other wall\'s dimensions rebuild or stay; undo '
        'restores every handle, owner and text, at $place', () {
      final (:plan, :a, :b, :dim) = lPlan(place);
      final doc = plan.doc;
      // A second dimension on B only: B/0/right → B/1/right, B's outer face
      // (east, B runs north), x = 4100, from the outer corner (4100, −100)
      // to (4100, 3000): 3100.
      final other = addDimension(
          doc, AttachedEnd(b, 0, r), AttachedEnd(b, 1, r),
          offset: -600.75, at: place.m);
      // Two more on A, of the other kinds (Review Focus #4: three on the
      // wall deleted), each in a group at the placement, so the hand values
      // are in the plan's frame:
      // - horizontal, A/0/right → A/1/right: A's outer face y = −100 from
      //   its free start (0, −100) to the outer corner (4100, −100): 4100;
      // - vertical, A/0/centre (0, 0) → a fixed point (500.25, 2300.75):
      //   |2300.75 − 0| = 2300.75, which reads 2301.
      final outer = addDimension(
          doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
          kind: DimKind.horizontal, offset: -450.25, at: place.m);
      final toFixed = addDimension(doc, AttachedEnd(a, 0, WallSide.centre),
          fixedAt(plan.at(500.25, 2300.75), place.m),
          kind: DimKind.vertical, offset: 350.5, at: place.m);
      // And one on B that A's deletion leaves as it is: B's free end across
      // its thickness, B/1/left (3900, 3000) → B/1/right (4100, 3000): 200.
      final survivor = addDimension(
          doc, AttachedEnd(b, 1, l), AttachedEnd(b, 1, r),
          offset: 250.75, at: place.m);
      final onA = [dim, outer, toFixed];
      const textsOnA = ['3900', '4100', '2301'];
      expect([for (final d in onA) dimText(doc, d)], textsOnA);
      expect(dimText(doc, other), '3100');
      expect(dimText(doc, survivor), '200');
      expectFollows(doc, 'the L');
      final dimKids = kids(doc, dim), otherKids = kids(doc, other);
      final onAKids = [for (final d in onA) kids(doc, d)];
      final survivorKids = kids(doc, survivor);
      final survivorLines = dimLines(doc, survivor);
      final survivorText = dimTextGeometry(doc, survivor);
      void expectSurvivorUnchanged(String when) {
        expect(kids(doc, survivor), survivorKids, reason: when);
        expect(dimText(doc, survivor), '200', reason: when);
        expect(dimLines(doc, survivor), survivorLines, reason: when);
        expect(dimTextGeometry(doc, survivor), survivorText, reason: when);
      }

      final before = canon(doc);
      final entities = handlesAndOwners(doc);
      final depth = doc.commands.undoDepth;

      // A deleted, as the select tool deletes a group: the dimension on A
      // goes in the same step (cascade, D3), its parameters and children
      // with it.
      doc.commands.execute(deleteObject(doc, a));
      expect(doc.commands.undoDepth, depth + 1);
      expect(doc.tree[a], isNull);
      for (final (i, d) in onA.indexed) {
        expect(doc.tree[d], isNull, reason: d.toHex());
        expect(doc.components.get<DimensionParams>(d), isNull,
            reason: d.toHex());
        for (final k in onAKids[i]) {
          expect(doc.entities.slotOf(k), isNull, reason: k.toHex());
        }
      }
      expectSurvivorUnchanged('A deleted');
      // B's start is free now: its outer face from (4100, 0) to (4100,
      // 3000): 3000, the same six children.
      expect(dimText(doc, other), '3000');
      expect(kids(doc, other), otherKids);
      expectFollows(doc, 'A deleted');

      // Undo, one step: the canonical bytes (a restored node back at its
      // index among the root's children, spec O-10), and every entity's
      // handle and owner.
      doc.commands.undo();
      expect(doc.commands.undoDepth, depth);
      expect(canon(doc), before);
      expect(handlesAndOwners(doc), entities);
      expect(kids(doc, dim), dimKids);
      for (final (i, d) in onA.indexed) {
        expect(kids(doc, d), onAKids[i], reason: d.toHex());
        expect(dimText(doc, d), textsOnA[i], reason: d.toHex());
      }
      expect(dimText(doc, other), '3100');
      expectSurvivorUnchanged('undo');
      expectFollows(doc, 'undo');
      // ignore: avoid_print
      print('DN3 at $place: ${entities.length} entities restored with their '
          'handles and owners; undo depth ${depth + 1} -> $depth');
    });

    test(
        'DN4 an edit away from a dimension\'s walls generates nothing for it; '
        'an offset change regenerates exactly the dimensions on its walls; '
        'the door-slide and partition counts are printed, at $place', () {
      final (:plan, :a, :b, dim: d1) = lPlan(place);
      final doc = plan.doc;
      // D: a free wall (10000, 6000) → (14000, 6000), 200, far from A and B
      // (B's free end is at y 3000; the gap is 2800 mm between faces), so
      // it is neither a referenced wall nor a neighbour of one.
      final d = addWallAt(plan, 8, 10000, 6000, 14000, 6000, 200);
      // d1 on A only (3900); d2 on A only, A/0/right → A/1/right, the outer
      // face (4100); d3 from A to B, A/0/left (0, 100) → B/1/left (3900,
      // 3000), aligned: √(3900² + 2900²) = √(15,210,000 + 8,410,000) =
      // √23,620,000 = 4,860.04; d4 on B only, B/0/right → B/1/right
      // (3100).
      final d2 = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
          kind: DimKind.horizontal, offset: -500.25, at: place.m);
      final d3 = addDimension(doc, AttachedEnd(a, 0, l), AttachedEnd(b, 1, l),
          offset: 350.5, at: place.m);
      final d4 = addDimension(doc, AttachedEnd(b, 0, r), AttachedEnd(b, 1, r),
          kind: DimKind.vertical, offset: -700.75, at: place.m);
      expect(dimText(doc, d1), '3900');
      expect(dimText(doc, d2), '4100');
      expect(dimText(doc, d3), '4860');
      expect(dimText(doc, d4), '3100');
      expectFollows(doc, 'four dimensions');

      // Away: D 200 → 250.5. No dimension generates.
      var gens = debugDimensionGenerates;
      doc.commands.execute(thickness(doc, d, 250.5));
      expect(debugDimensionGenerates - gens, 0);
      expectFollows(doc, 'D thickened');

      // d1's offset 800.5 → 1200.25: d1's reference A is in the closure's
      // core, so every live dimension referencing A regenerates, d1
      // included: d1, d2, d3 (3). d4 references B only, which is not in the
      // core (a dimension has no neighbours): it does not.
      final texts = [
        for (final h in [d1, d2, d3, d4]) dimText(doc, h)
      ];
      gens = debugDimensionGenerates;
      doc.commands.execute(SetComponentCommand<DimensionParams>(d1,
          doc.components.get<DimensionParams>(d1)!.copyWith(offset: 1200.25)));
      expect(debugDimensionGenerates - gens, 3);
      expect([
        for (final h in [d1, d2, d3, d4]) dimText(doc, h)
      ], texts);
      expectFollows(doc, 'd1\'s offset');

      // Printed, not asserted (S-6): a through wall C (0, 0) → (12000, 0),
      // 200, carrying N dimensions and a 900 mm door at 3000, with a
      // partition P T-joined at (6000, 0) north, 100. A door slid along C
      // regenerates every dimension on C (C is the door's reference); a
      // thickness change of P reaches C as P's neighbour.
      for (final n in [1, 10, 50]) {
        final t = buildPlan(
            const [W(0, 0, 12000, 0, 200), W(6000, 0, 6000, 3000, 100)],
            openings: const [(0, 3000, 900, OpeningKind.door, SwingSide.left)],
            place: place);
        final tdoc = t.doc;
        attachPage(tdoc, mmPage);
        final [cw, p] = t.walls;
        final door = t.openings.single;
        for (var i = 0; i < n; i++) {
          addDimension(tdoc, AttachedEnd(cw, 0, i.isEven ? l : r),
              AttachedEnd(cw, 1, i.isEven ? l : r),
              kind: DimKind.values[i % 3],
              offset: (i.isEven ? 1 : -1) * (400.5 + 150 * i),
              at: place.m);
        }
        expectFollows(tdoc, 'N = $n');
        var g0 = debugDimensionGenerates;
        tdoc.commands.execute(SetComponentCommand<OpeningParams>(
            door,
            tdoc.components
                .get<OpeningParams>(door)!
                .copyWith(position: 3400.5)));
        final slide = debugDimensionGenerates - g0;
        expectFollows(tdoc, 'the door slid, N = $n');
        g0 = debugDimensionGenerates;
        tdoc.commands.execute(thickness(tdoc, p, 150));
        final partition = debugDimensionGenerates - g0;
        expectFollows(tdoc, 'the partition thickened, N = $n');
        // ignore: avoid_print
        print('DN4 at $place, N = $n: a door slid along the wall: $slide '
            'dimension generates; the partition thickened: $partition');
      }
    });
  }
}

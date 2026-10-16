// ignore_for_file: invalid_use_of_internal_member
// Spec 10 D21: a room's label grip, a separator's end grips, and no
// select-tool move or rotate for a room (R-22). The label grip sits at the
// labels' anchor, `toWorld(q) − (0, 0.7 · h_name_w)` from the name TEXT's
// stored insertion point `q`; a drag stores `label = toLocal(p) − pole_l`,
// the pole `pole_l = toLocal(anchor_w) − label`; a drop within the snap
// aperture of the pole stores null (auto, R-26), whatever F3 says (Ruling
// 10-17). A separator's end grip moves one end through `trimSeparator`.
//
// The plan is the two-room rectangle (`twoRoomWalls`) with a separator
// face to face at x = 6,250.5, at the origin and at the corpus far origin
// with every wall and the separator in its own rotated, translated group.
// The Kitchen has a fractional, non-null label offset and a name that is
// not `Room N`; `GR6` puts it in a group turned 23°, at the far origin,
// scaled 1.5. Anchors come from the stored TEXTs by D21's formula
// (`anchorOf`), never from the grip code; expected areas are hand
// arithmetic, each label at least 0.0005 m² from a rounding tie.
// Ported from jet_cad_floor_plan/test/room_grips_test.dart (GR1 (shell),
// GR2, GR3, GR4, GR5 (shell); GR1, GR5 and GR6 run in the kit) (spec 3a
// C6, C7); assertions unchanged. PlannerShell becomes PlanEditor over a
// PlanController whose plan a PlanBuild makes (fixture changes); the view's
// selection, camera and grips are the controller's (C7 class 3: widgets
// that changed form; the grip cache is @internal, ruling R-P9). GR4's last
// face is read from the Kitchen's drawn tint, the kit's tracer being
// internal (ruling R-P1).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_plans.dart';

SelectionKey k(Handle h) => SelectionKey.root(h);

/// The Kitchen's stored label offset, local: fractional, non-null.
const (double, double) kitchenLabel = (-310.37, 145.61);

/// The plan's separator, face to face between the partition and the east
/// wall.
const S sep = (6250.5, 100, 6250.5, 3900);

/// Today's gripPlan (room_grips_test.dart:59-93) with `shell: true`:
/// [twoRoomWalls] and [sep] at [place], a 1:50 page in metres with no grid
/// snap, the Kitchen (its label offset [kitchenLabel]) and B ('Room 2',
/// auto), built and clean.
({RoomPlan p, Handle kitchen, Handle b, Handle sep, Handle part}) gripPlan(
    Placement place) {
  final p = roomPlan(twoRoomWalls,
      seps: const [sep],
      place: place,
      page: PageComponent(snapToGrid: false),
      rooms: const [
        (x: 1500.25, y: 2000.5, name: 'Kitchen', label: kitchenLabel, at: null),
        (x: 4700.75, y: 1900.25, name: 'Room 2', label: null, at: null),
      ]);
  expect(labelStrings(p.doc, p.rooms[0]), ['Kitchen', '10.83 m²'],
      reason: 'premise, $place');
  expect(labelStrings(p.doc, p.rooms[1]), ['Room 2', '12.16 m²'],
      reason: 'premise, $place');
  return (
    p: p,
    kitchen: p.rooms[0],
    b: p.rooms[1],
    sep: p.seps.single,
    part: p.walls[4],
  );
}

RoomParams roomOf(DraftDocument doc, Handle h) =>
    doc.components.get<RoomParams>(h)!;

SeparatorParams sepOf(DraftDocument doc, Handle h) =>
    doc.components.get<SeparatorParams>(h)!;

/// D21's pole, local, from a grip at [anchorW] and the stored offset.
Vector2 poleLocal(DraftDocument doc, Handle room, Vector2 anchorW) {
  final toLocal = doc.tree.accumulatedTransform(room).invert();
  final l = roomOf(doc, room).label;
  return toLocal.transformPoint(anchorW) -
      (l == null ? Vector2.zero() : Vector2(l.$1, l.$2));
}

/// D21's stored offset for a drop at [p]: `toLocal(p) − pole_l`.
(double, double) labelFor(
    DraftDocument doc, Handle room, Vector2 anchorW, Vector2 p) {
  final toLocal = doc.tree.accumulatedTransform(room).invert();
  final l = toLocal.transformPoint(p) - poleLocal(doc, room, anchorW);
  return (l.x, l.y);
}

/// The distance from [p] to the line through [a] and [b], relative to [a].
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a, q = p - a;
  return (q.x * d.y - q.y * d.x).abs() / d.length;
}

/// The shown object grips of [h] (the canvas's grip cache).
List<Grip> objectGripsOf(PlanController c, Handle h) => [
      for (final r in c.grips.grips)
        if (r.object && r.key == SelectionKey.root(h)) r.grip,
    ];

Vector2 at(Grip g) => Vector2(g.x, g.y);

void main() {
  for (final place in [origin, corpusGroups]) {
    testWidgets(
        'GR1 (shell) the label grip is shown at the anchor and a drag stores '
        'the offset in one undo step, $place', (tester) async {
      final f = gripPlan(place);
      final doc = f.p.doc;
      final c = f.p.c;
      await pumpAt(tester, c, f.p.at(1500, 2000));
      c.activeSelection.replace([k(f.kitchen)]);
      await tester.pump();
      final g = objectGripsOf(c, f.kitchen).single;
      expect((at(g) - anchorOf(doc, f.kitchen)).length, lessThan(1e-6));
      final before = roomOf(doc, f.kitchen);
      final p = f.p.at(1900.37, 2600.81);
      final want = labelFor(doc, f.kitchen, at(g), p);
      await dragWorld(tester, c, at(g), p, pumps: 2);
      expect(doc.commands.undoDepth, 1, reason: 'one undo step');
      final got = roomOf(doc, f.kitchen).label!;
      expect(got.$1, closeTo(want.$1, 1e-6));
      expect(got.$2, closeTo(want.$2, 1e-6));
      expect((anchorOf(doc, f.kitchen) - p).length, lessThan(1e-6));
      await undoKey(tester);
      expect(roomOf(doc, f.kitchen), before, reason: 'undone, exactly');
    });

    testWidgets(
        'GR2 a drop within the aperture of the pole returns the label to '
        'auto, with object snap on and off, $place', (tester) async {
      final f = gripPlan(place);
      final doc = f.p.doc;
      final c = f.p.c;
      await pumpAt(tester, c, f.p.at(1500, 2000));
      c.activeSelection.replace([k(f.kitchen)]);
      await tester.pump();
      final before = roomOf(doc, f.kitchen);
      final ap = kSnapAperturePixels / c.camera.value.scale;
      expect(ap, closeTo(66.67, 0.01), reason: 'premise');
      final g0 = objectGripsOf(c, f.kitchen).single;
      final pole = doc.tree
          .accumulatedTransform(f.kitchen)
          .transformPoint(poleLocal(doc, f.kitchen, at(g0)));
      expect((pole - at(g0)).length, greaterThan(3 * ap),
          reason: 'premise: the stored offset is well outside the aperture');

      for (final snap in [true, false]) {
        expect(osnap(tester), snap ? 'OSNAP' : 'osnap off');
        final g = objectGripsOf(c, f.kitchen).single;
        await dragWorld(tester, c, at(g), pole + Vector2(0.4 * ap, -0.3 * ap),
            pumps: 2);
        expect(doc.commands.undoDepth, 1, reason: 'F3 $snap: one step');
        expect(roomOf(doc, f.kitchen).label, isNull,
            reason: 'F3 $snap: auto (Ruling 10-17)');
        expect(roomOf(doc, f.kitchen).name, 'Kitchen');
        expect((anchorOf(doc, f.kitchen) - pole).length, lessThan(1e-6),
            reason: 'F3 $snap: the labels at the pole');
        expect(driftOf(doc), isEmpty);
        await undoKey(tester);
        expect(roomOf(doc, f.kitchen), before, reason: 'F3 $snap: undone');
        if (snap) await toggleF3(tester);
      }

      // The control: 1.5 apertures from the pole stores an offset.
      final g = objectGripsOf(c, f.kitchen).single;
      final out = pole + Vector2(1.5 * ap, 0);
      final want = labelFor(doc, f.kitchen, at(g), out);
      await dragWorld(tester, c, at(g), out, pumps: 2);
      expect(doc.commands.undoDepth, 1);
      final got = roomOf(doc, f.kitchen).label!;
      expect(got.$1, closeTo(want.$1, 1e-6));
      expect(got.$2, closeTo(want.$2, 1e-6));
    });
  }

  testWidgets('GR3 the label grip is not hit under runtime permissions',
      (tester) async {
    final f = gripPlan(corpusGroups);
    final doc = f.p.doc;
    final c = f.p.c;
    await pumpAt(tester, c, f.p.at(1500, 2000));
    c.activeSelection.replace([k(f.kitchen)]);
    await tester.pump();
    final g = objectGripsOf(c, f.kitchen).single;
    final m = c.camera.value.worldToScreenMatrix;
    final s = c.camera.value.worldToScreen(at(g));
    expect(c.grips.hitTest(Offset(s.x, s.y), m), isNot(-1),
        reason: 'the control: hit under full permissions');
    doc.commands.permissions = DraftPermissions.runtime;
    expect(c.grips.hitTest(Offset(s.x, s.y), m), -1);
    final before = enc(doc);
    await dragWorld(tester, c, at(g), f.p.at(1900.37, 2600.81), pumps: 2);
    expect(enc(doc), before, reason: 'nothing moved');
  });

  for (final place in [origin, corpusGroups]) {
    testWidgets(
        'GR4 a body drag on a selected room moves nothing; rooms alone have '
        'no rotation grip; a wall selected with a room moves and the room '
        're-traces, $place', (tester) async {
      final f = gripPlan(place);
      final doc = f.p.doc;
      final c = f.p.c;
      await pumpAt(tester, c, f.p.at(3000, 2000));

      // The Kitchen alone, selected by a click on its name label.
      final name = anchorOf(doc, f.kitchen) + Vector2(0, 0.7 * 125);
      await clickAt(tester, c, name);
      expect(c.activeSelection.keys, [k(f.kitchen)]);
      expect(c.grips.box, isNotNull);
      expect(c.grips.rotatable, isFalse, reason: 'no rotation grip');
      final before = enc(doc);
      await dragWorld(tester, c, name, name + (f.p.at(700, 300) - f.p.at(0, 0)),
          pumps: 2);
      expect(doc.commands.undoDepth, 0, reason: 'nothing in the history');
      expect(enc(doc), before, reason: 'nothing moved');
      expect(c.activeSelection.keys, [k(f.kitchen)], reason: 'still a click');

      // The Kitchen, B and the partition: a drag on the partition's west
      // face, x 2,950, 250 mm along the plan's x axis, with object snap
      // off, moves the partition alone.
      await toggleF3(tester);
      c.activeSelection.replace([k(f.kitchen), k(f.b), k(f.part)]);
      await tester.pump();
      expect(c.grips.rotatable, isTrue, reason: 'the partition');
      final t0 = doc.tree.accumulatedTransform(f.part);
      final rooms = {
        f.kitchen: (roomOf(doc, f.kitchen), doc.tree[f.kitchen]),
        f.b: (roomOf(doc, f.b), doc.tree[f.b]),
      };
      await dragWorld(tester, c, f.p.at(2950, 1200.5), f.p.at(3200, 1200.5),
          pumps: 2);
      expect(doc.commands.undoDepth, 1, reason: 'one step');
      final t1 = doc.tree.accumulatedTransform(f.part);
      final v = Vector2(t1.e - t0.e, t1.f - t0.f);
      final x = Vector2(math.cos(place.deg * math.pi / 180),
          math.sin(place.deg * math.pi / 180));
      final delta = v.dot(x);
      expect(delta, closeTo(250, 1), reason: 'premise: the partition moved');
      expect((v - x * delta).length, lessThan(1e-6), reason: 'along x only');
      for (final MapEntry(key: h, value: (p, node)) in rooms.entries) {
        expect(roomOf(doc, h), p, reason: 'the room stays: $h');
        expect(doc.tree[h], node, reason: 'its group untouched: $h');
      }
      // Re-traced: the Kitchen x 100..2,950 + Δ, (2,850 + Δ) × 3,800 with
      // Δ = 250 ± 1: 11.776..11.784 m², "11.78 m²"; B x 3,050 + Δ..6,250.5,
      // (3,200.5 − Δ) × 3,800: 11.2081..11.2157 m², "11.21 m²".
      expect(labelStrings(doc, f.kitchen), ['Kitchen', '11.78 m²']);
      expect(labelStrings(doc, f.b), ['Room 2', '11.21 m²']);
      // The Kitchen's face, from its tint (D9 step 1: the face's ring; no
      // hole here): its shoelace area.
      final tint = worldTintOf(doc, f.kitchen);
      var twice = 0.0;
      for (var i = 0; i < tint.length; i++) {
        final a = tint[i] - tint[0], b = tint[(i + 1) % tint.length] - tint[0];
        twice += a.x * b.y - a.y * b.x;
      }
      expect(twice.abs() / 2, closeTo((2850 + delta) * 3800, 1e-2));
      expect(driftOf(doc), isEmpty);
    });
  }

  for (final place in [origin, corpusGroups]) {
    testWidgets(
        'GR5 (shell) a separator end dragged into a band is trimmed with F3 '
        'on and kept as placed with it off; a separator alone gets a '
        'rotation grip, $place', (tester) async {
      final f = gripPlan(place);
      final doc = f.p.doc;
      final c = f.p.c;
      await pumpAt(tester, c, f.p.at(6000, 3000));
      c.activeSelection.replace([k(f.sep)]);
      await tester.pump();
      expect(c.grips.rotatable, isTrue, reason: 'a separator is movable');
      final stored = sepOf(doc, f.sep);
      final toWorld = doc.tree.accumulatedTransform(f.sep);
      final p = f.p.at(5800.37, 3960.21);
      for (final on in [true, false]) {
        expect(osnap(tester), on ? 'OSNAP' : 'osnap off');
        final g = objectGripsOf(c, f.sep)[1];
        await dragWorld(tester, c, at(g), p, pumps: 2);
        expect(doc.commands.undoDepth, 1, reason: 'F3 $on: one step');
        final now = sepOf(doc, f.sep);
        expect((now.sx, now.sy), (stored.sx, stored.sy),
            reason: 'F3 $on: the start stays');
        final w = toWorld.transformPoint(now.end);
        if (on) {
          expect(distToLine(w, f.p.at(0, 3900), f.p.at(8000, 3900)),
              lessThan(1e-6),
              reason: 'trimmed to the north wall\'s inner face');
        } else {
          expect((w - p).length, lessThan(1e-6), reason: 'as placed');
        }
        await undoKey(tester);
        expect(sepOf(doc, f.sep), stored);
        if (on) await toggleF3(tester);
      }
    });
  }
}

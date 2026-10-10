// Spec 10 D6, D8, D9's fallback chain and D15 at the app level: a room keeps
// its holes in its tint through a slit keyhole, falls back to its outer ring
// or to an invisible outline so that no edit is refused because of a tint,
// and dissolves in the same undo step when its seed ends up in a wall or in
// an unbounded face. Nothing else dissolves it: two rooms in one face both
// survive and are reported.
//
// A page is attached (1:50, metres). Expected areas are hand arithmetic,
// next to the assertion; every expected label string is at least 0.0005 m²
// from a rounding tie, checked in the comment. `drift()` is empty after
// every edit. RG2 runs at all six placements, the relational edits at the
// origin and at the corpus far origin in own groups.
import 'dart:math' as math;

import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_inputs.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_label.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_trace.dart';
import 'package:jet_cad_floor_plan/src/parametric/separator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The two-room fixture's left and right seeds, plan mm (fractional).
const (double, double) leftSeed = (1512.5, 1987.25);
const (double, double) rightSeed = (5487.75, 2012.5);

/// The two-room fixture at [place] with the app's opening page attached.
Plan twoRooms(Placement place) {
  final plan = buildPlan(twoRoomWalls, place: place);
  attachPage(plan.doc, PageComponent());
  return plan;
}

Vector2 seedAt(Plan plan, (double, double) s) => plan.at(s.$1, s.$2);

/// The shoelace area of [r], relative to its first point.
double areaOf(List<Vector2> r) {
  final o = r.first;
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i] - o, q = r[(i + 1) % r.length] - o;
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

/// The distance from [q] to [pts]' nearest point.
double nearestTo(Vector2 q, Iterable<Vector2> pts) =>
    pts.map((p) => (p - q).length).reduce(math.min);

/// [room]'s tint is the rectangle with plan corners [corners]: as many
/// points, each within 1e-5 mm of one corner in world.
void expectTintRect(
    Plan plan, Handle room, List<(double, double)> corners, String why) {
  final tint = worldTintOf(plan.doc, room);
  expect(tint, hasLength(corners.length), reason: why);
  for (final (x, y) in corners) {
    expect(nearestTo(plan.at(x, y), tint), lessThan(1e-5),
        reason: '$why: corner ($x, $y)');
  }
}

/// [room]'s tint is D9's step 1, a region whose ring is the face's outer
/// ring [outer] keyholed to each hole of [holes] (plan corners): every
/// corner is within 1e-5 mm of a stored point; each hole adds exactly two
/// more, `H + s` and `V + s`, consecutive, each the slit's 0.5 mm from a
/// corner; with them snapped back onto their corners the ring encloses the
/// face's net area [net], and without, a little less.
void expectKeyhole(Plan plan, Handle room, List<(double, double)> outer,
    List<List<(double, double)>> holes, double net, String why) {
  final doc = plan.doc;
  expect(
      kindsOf(doc, room),
      [
        EntityKind.fill,
        EntityKind.polyline,
        EntityKind.text,
        EntityKind.text,
      ],
      reason: '$why: a region (it triangulated), then the labels');
  final tint = worldTintOf(doc, room);
  final corners = [
    for (final (x, y) in [...outer, for (final h in holes) ...h]) plan.at(x, y),
  ];
  expect(tint, hasLength(corners.length + 2 * holes.length), reason: why);
  for (final c in corners) {
    expect(nearestTo(c, tint), lessThan(1e-5), reason: '$why: corner $c');
  }
  final slit = [
    for (var i = 0; i < tint.length; i++)
      if (nearestTo(tint[i], corners) > 1e-5) i,
  ];
  expect(slit, hasLength(2 * holes.length), reason: why);
  for (final i in slit) {
    expect(nearestTo(tint[i], corners), closeTo(kSlit, 1e-6),
        reason: '$why: the slit\'s 0.5 mm');
  }
  var bridges = 0;
  for (final i in slit) {
    if (slit.contains((i + 1) % tint.length)) bridges++;
  }
  expect(bridges, holes.length, reason: '$why: one bridge per hole');
  // Each slit point snapped back onto its corner gives the exact keyhole,
  // whose two coincident bridge edges enclose nothing: the face's net area.
  final snapped = [
    for (final q in tint)
      slit.contains(tint.indexOf(q))
          ? corners.reduce((a, b) => (a - q).length <= (b - q).length ? a : b)
          : q,
  ];
  expect(areaOf(snapped), closeTo(net, 1e-2), reason: '$why: the keyhole');
  // Moving H and V 0.5 mm aside changes the area by thin strips and
  // triangles along the bridge and the edges at H and V, of either sign
  // (the triangle at V can lie in the band beyond it): far less than a
  // 0.5 mm strip 10 m long per hole.
  expect((net - areaOf(tint)).abs(), lessThan(kSlit * 10000 * holes.length),
      reason: '$why: the slit');
}

/// The room diagnostics of [doc].
List<Diagnostic> roomDiagnostics(DraftDocument doc) =>
    codedAs(diagnosticsOf(doc), 'room.');

/// The room diagnostics of [doc] that name [room]. While
/// `debugTintFailedSteps` is set, every room's diagnose applies it, so a
/// room without holes reports its step 1 failed too.
List<Diagnostic> diagnosticsNaming(DraftDocument doc, Handle room) => [
      for (final d in roomDiagnostics(doc))
        if (d.handles.contains(room)) d,
    ];

/// `room.shared` for [a] (the lower handle) and [b], named [na] and [nb].
Diagnostic shared(Handle a, String na, Handle b, String nb) => Diagnostic(
      severity: DiagnosticSeverity.warning,
      code: 'room.shared',
      message: '$na and $nb share a space',
      handles: [a, b],
    );

/// Separator [i] of [plan] moved to [s], plan millimetres: one
/// `SetComponentCommand`, its ends taken back through its own group.
DraftCommand moveSeparator(Plan plan, int i, S s) {
  final h = plan.seps[i];
  final inv = plan.doc.tree.accumulatedTransform(h).invert();
  final a = inv.transformPoint(plan.at(s.$1, s.$2));
  final b = inv.transformPoint(plan.at(s.$3, s.$4));
  return SetComponentCommand<SeparatorParams>(
      h, SeparatorParams(a.x, a.y, b.x, b.y));
}

/// Whether [h] is gone: no component, no node, no child left.
void expectDissolved(
    DraftDocument doc, Handle h, List<Handle> children, String why) {
  expect(doc.components.get<RoomParams>(h), isNull, reason: why);
  expect(doc.tree[h], isNull, reason: why);
  for (final k in children) {
    expect(doc.entities.slotOf(k), isNull, reason: '$why: child $k');
  }
}

/// D23's Living: its outer ring and its column, plan corners.
const livingRing = [
  (21500.0, 11560.0),
  (25750.0, 11560.0),
  (25750.0, 16750.0),
  (21500.0, 16750.0),
];
const livingColumn = [
  (23500.0, 13800.0),
  (23900.0, 13800.0),
  (23900.0, 14200.0),
  (23500.0, 14200.0),
];

void main() {
  tearDown(() => debugTintFailedSteps = null);

  test(
      'RG2 a room\'s holes and the tint\'s fallback chain: one column, two '
      'columns, and step 2 with room.tint, at six placements', () {
    for (final place in placements) {
      // --- One column: D23's Living, step 1.
      final plan = samplePlan(place);
      final doc = plan.doc;
      final rooms = addSampleRooms(plan);
      final living = rooms['Living']!;
      // (25,750 − 21,500) × (16,750 − 11,560) − 400 × 400 = 4,250 × 5,190 −
      // 160,000 = 22,057,500 − 160,000 = 21,897,500 (21.90, 0.0025 from
      // 21.895 and 21.905).
      expect(labelStrings(doc, living), ['Living', '21.90 m²'],
          reason: '$place');
      expectKeyhole(plan, living, livingRing, [livingColumn], 21897500,
          'Living at $place');
      // The anchor is the pole of the face with its hole (D10): it clears
      // the column. The pole of the ring alone, the rectangle's centre line
      // through (23,625, 14,155), lies inside the column.
      final seed = plan.at(24500, 16000);
      final face = faceAt(doc, seed) as Traced;
      expect(face.holes, hasLength(1), reason: '$place');
      final pole = poleOfInaccessibility(face.ring, face.holes);
      expect((anchorOf(doc, living) - pole.point).length, lessThan(1e-6),
          reason: 'the anchor is the pole with holes at $place');
      final a = place.m.invert().transformPoint(anchorOf(doc, living));
      final dx = math.max(math.max(23500 - a.x, a.x - 23900), 0.0);
      final dy = math.max(math.max(13800 - a.y, a.y - 14200), 0.0);
      expect(math.sqrt(dx * dx + dy * dy), greaterThan(1000),
          reason: 'the anchor $a clears the column at $place');
      expect(roomDiagnostics(doc), isEmpty, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');

      // --- Step 2 (Ruling 10-16): the keyholed ring treated as failing.
      final labels = labelsOf(doc, living);
      debugTintFailedSteps = {1};
      doc.commands.execute(renameRoom(doc, living, 'Living room'));
      expect(
          kindsOf(doc, living),
          [
            EntityKind.fill,
            EntityKind.polyline,
            EntityKind.text,
            EntityKind.text,
          ],
          reason: 'step 2 is a region at $place');
      // The outer ring alone, the column tinted over: 4,250 × 5,190 =
      // 22,057,500 stored; the area label is the trace's, unchanged.
      expectTintRect(plan, living, livingRing, 'step 2 at $place');
      expect(areaOf(worldTintOf(doc, living)), closeTo(22057500, 1e-2),
          reason: '$place');
      expect(labelStrings(doc, living), ['Living room', '21.90 m²'],
          reason: '$place');
      expect(labelsOf(doc, living), labels, reason: '$place');
      expect(doc.components.get<RoomParams>(living), isNotNull,
          reason: 'the room alive at $place');
      expect(
          diagnosticsNaming(doc, living),
          [
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'room.tint',
              message:
                  'room ${living.toHex()} ("Living room"): its tint covers '
                  'its holes: the keyholed ring does not triangulate',
              handles: [living],
            ),
          ],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'step 2 at $place');

      // --- Step 3: neither ring treated as triangulating: an invisible,
      // unfilled closed POLYLINE of the outer ring, ACI 7 (D9). The kind
      // changes, so it comes with a fresh handle, above the labels' (D9's
      // accepted cost): no fill at all.
      debugTintFailedSteps = {1, 2};
      doc.commands.execute(renameRoom(doc, living, 'Living'));
      expect(kindsOf(doc, living),
          [EntityKind.text, EntityKind.text, EntityKind.polyline],
          reason: 'step 3 is a polyline at $place');
      final outline = kids(doc, living).last;
      final c = payloadOf(doc, outline).coords;
      expect(c.length, 10, reason: 'four points, closed, at $place');
      expect((c[8], c[9]), (c[0], c[1]), reason: 'closed at $place');
      final r = recordOf(doc, outline);
      expect(r.color, const IndexedColor(7), reason: '$place');
      expect(r.flags, EntityFlags.invisible, reason: '$place');
      expect(r.transparency, isNot(kRoomTintTransparency), reason: '$place');
      expect(r.layer, ReservedHandles.layerZero, reason: '$place');
      expectTintRect(plan, living, livingRing, 'step 3 at $place');
      expect(labelStrings(doc, living), ['Living', '21.90 m²'],
          reason: '$place');
      expect(labelsOf(doc, living), labels, reason: '$place');
      expect(
          diagnosticsNaming(doc, living),
          [
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'room.tint',
              message: 'room ${living.toHex()} ("Living"): its tint is an '
                  'unfilled outline: its face does not triangulate',
              handles: [living],
            ),
          ],
          reason: '$place');
      // Living's stored outline is what generate makes under the seam; the
      // other rooms, generated before it was set, still store step 1's
      // region, which the seam now fails for every room.
      expect(
          driftOf(doc),
          [
            for (final MapEntry(key: n, value: h) in rooms.entries)
              if (n != 'Living') h,
          ]..sort((a, b) => a.value.compareTo(b.value)),
          reason: 'step 3 at $place');

      // Without the seam the stored outline is not what generate makes; an
      // edit brings step 1 back, the region with fresh handles above the
      // labels' (D9: step 3 changes the child's kind).
      debugTintFailedSteps = null;
      expect(driftOf(doc), [living], reason: '$place');
      doc.commands.execute(renameRoom(doc, living, 'Living'));
      expect(
          kindsOf(doc, living),
          [
            EntityKind.text,
            EntityKind.text,
            EntityKind.fill,
            EntityKind.polyline,
          ],
          reason: 'step 1 again at $place');
      expect(worldTintOf(doc, living), hasLength(10), reason: '$place');
      expect(roomDiagnostics(doc), isEmpty, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');

      // --- Two columns in one room: two bridges, step 1.
      final two = buildPlan([
        ...boxWalls,
        const W(2000, 1500, 2400, 1500, 400), // x 2,000..2,400, y 1,300..1,700
        const W(5500.5, 2500.25, 5800.5, 2500.25, 300), // 5,500.5..5,800.5
      ], place: place);
      attachPage(two.doc, PageComponent());
      final room = addRoom(two.doc, two.at(1000.25, 3000.5), 'Room 1');
      // 7,800 × 3,800 − 400 × 400 − 300 × 300 = 29,640,000 − 160,000 −
      // 90,000 = 29,390,000 (29.39, 0.005 from 29.385 and 29.395).
      expect(labelStrings(two.doc, room), ['Room 1', '29.39 m²'],
          reason: '$place');
      expectKeyhole(
          two,
          room,
          const [(100, 100), (7900, 100), (7900, 3900), (100, 3900)],
          const [
            [(2000, 1300), (2400, 1300), (2400, 1700), (2000, 1700)],
            [
              (5500.5, 2350.25),
              (5800.5, 2350.25),
              (5800.5, 2650.25),
              (5500.5, 2650.25)
            ],
          ],
          29390000,
          'two columns at $place');
      expect(roomDiagnostics(two.doc), isEmpty, reason: '$place');
      expect(driftOf(two.doc), isEmpty, reason: '$place');

      // --- Honest fallbacks, no seam (Ruling 10-16's candidate). Two
      // 400 × 400 columns 0.2 mm off the faces, x 100.2..500.2, y
      // 3,499.8..3,899.8 by the north-west corner, and x 7,499.8..7,899.8,
      // y 1,800.5..2,200.5 by the east wall. 29,640,000 − 2 × 160,000 =
      // 29,320,000 (29.32, 0.005 from the ties).
      //
      // Before Task 14c this was step 2: a bridge from the north-west
      // column was clear but its slit, 0.5 mm to the bridge's right,
      // pierced the column or the face 0.2 mm away, so the keyholed ring
      // was not simple. Now the slit is checked too (D9, decision 29's
      // note) and the next vertex is tried. Turned 23°, the column's
      // rightmost vertex is its south-east corner and a clear keyhole is
      // found: step 1, exact. Unturned, it is the north-east corner, from
      // which every clear bridge's slit pierces the north face or the
      // column: that hole is left out (the tint covers it), the east
      // column is still cut out, and room.tint says so (D22).
      final near = buildPlan([
        ...boxWalls,
        const W(100.2, 3699.8, 500.2, 3699.8, 400),
        const W(7499.8, 2000.5, 7899.8, 2000.5, 400),
      ], place: place);
      attachPage(near.doc, PageComponent());
      final nearRoom = addRoom(near.doc, near.at(1000.25, 2500.5), 'Room 1');
      expect(labelStrings(near.doc, nearRoom), ['Room 1', '29.32 m²'],
          reason: '$place');
      expect(
          kindsOf(near.doc, nearRoom),
          [
            EntityKind.fill,
            EntityKind.polyline,
            EntityKind.text,
            EntityKind.text,
          ],
          reason: 'a region at $place');
      final nearTint = worldTintOf(near.doc, nearRoom);
      bool stored(double x, double y) =>
          nearestTo(near.at(x, y), nearTint) < 1e-5;
      const northWest = [
        (100.2, 3499.8),
        (500.2, 3499.8),
        (500.2, 3899.8),
        (100.2, 3899.8),
      ];
      const east = [
        (7499.8, 1800.5),
        (7899.8, 1800.5),
        (7899.8, 2200.5),
        (7499.8, 2200.5),
      ];
      for (final (x, y) in east) {
        expect(stored(x, y), isTrue, reason: 'east column cut out at $place');
      }
      if (place.deg == 0) {
        expect(nearTint, hasLength(4 + 4 + 2), reason: '$place');
        for (final (x, y) in northWest) {
          expect(stored(x, y), isFalse, reason: 'north-west left out, $place');
        }
        expect(
            roomDiagnostics(near.doc),
            [
              Diagnostic(
                severity: DiagnosticSeverity.warning,
                code: 'room.tint',
                message: 'room ${nearRoom.toHex()} ("Room 1"): its tint covers '
                    '1 of its holes: no clear keyhole reaches them',
                handles: [nearRoom],
              ),
            ],
            reason: 'a hole left out at $place');
      } else {
        expect(nearTint, hasLength(4 + 2 * (4 + 2)), reason: '$place');
        for (final (x, y) in northWest) {
          expect(stored(x, y), isTrue, reason: 'north-west cut out, $place');
        }
        expect(roomDiagnostics(near.doc), isEmpty, reason: 'exact at $place');
      }
      expect(driftOf(near.doc), isEmpty, reason: '$place');

      // Step 2: an island pinched at a vertex, two 400 × 400 columns x
      // 5,000..5,400, y 1,800..2,200 and x 5,400..5,800, y 2,200..2,600,
      // touching at (5,400, 2,200) only. One hole that passes that vertex
      // twice: the keyholed ring through it is not simple and does not
      // triangulate; the outer ring alone does. 29,320,000 again.
      final pinchedHole = buildPlan([
        ...boxWalls,
        const W(5000, 2000, 5400, 2000, 400),
        const W(5400, 2400, 5800, 2400, 400),
      ], place: place);
      attachPage(pinchedHole.doc, PageComponent());
      final holeRoom =
          addRoom(pinchedHole.doc, pinchedHole.at(1000.25, 2500.5), 'Room 1');
      final hole =
          (faceAt(pinchedHole.doc, pinchedHole.at(1000.25, 2500.5)) as Traced)
              .holes;
      expect(hole, hasLength(1), reason: 'the premise: one hole at $place');
      expect(
          hole.single
              .where((q) => (q - pinchedHole.at(5400, 2200)).length < 1e-6),
          hasLength(2),
          reason: 'the premise: pinched at $place');
      expect(labelStrings(pinchedHole.doc, holeRoom), ['Room 1', '29.32 m²'],
          reason: '$place');
      expect(
          kindsOf(pinchedHole.doc, holeRoom),
          [
            EntityKind.fill,
            EntityKind.polyline,
            EntityKind.text,
            EntityKind.text,
          ],
          reason: 'honest step 2 at $place');
      expectTintRect(
          pinchedHole,
          holeRoom,
          const [(100, 100), (7900, 100), (7900, 3900), (100, 3900)],
          'honest step 2 at $place');
      expect(
          roomDiagnostics(pinchedHole.doc),
          [
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'room.tint',
              message: 'room ${holeRoom.toHex()} ("Room 1"): its tint covers '
                  'its holes: the keyholed ring does not triangulate',
              handles: [holeRoom],
            ),
          ],
          reason: 'honest step 2 at $place');
      expect(driftOf(pinchedHole.doc), isEmpty, reason: '$place');

      // Step 3: a 400 × 400 column turned 45°, its top vertex on the north
      // face (y 3,900). It touches the ring, so the ring walks round it
      // (D6) and passes that vertex twice: pinched, neither ring
      // triangulates.
      final half = 200 * math.sqrt2, d = 100 * math.sqrt2;
      final pinched = buildPlan([
        ...boxWalls,
        W(4000 - d, 3900 - half - d, 4000 + d, 3900 - half + d, 400),
      ], place: place);
      attachPage(pinched.doc, PageComponent());
      final seed3 = pinched.at(1000.25, 2500.5);
      final face3 = faceAt(pinched.doc, seed3) as Traced;
      expect(
          face3.ring.where((q) => (q - pinched.at(4000, 3900)).length < 1e-6),
          hasLength(2),
          reason: 'the premise: pinched at $place');
      final pinchedRoom = addRoom(pinched.doc, seed3, 'Room 1');
      // 29,640,000 − 400 × 400 = 29,480,000 (29.48, 0.005 from the ties).
      expect(labelStrings(pinched.doc, pinchedRoom), ['Room 1', '29.48 m²'],
          reason: '$place');
      expect(kindsOf(pinched.doc, pinchedRoom),
          [EntityKind.polyline, EntityKind.text, EntityKind.text],
          reason: 'honest step 3 at $place');
      expect(
          roomDiagnostics(pinched.doc),
          [
            Diagnostic(
              severity: DiagnosticSeverity.warning,
              code: 'room.tint',
              message: 'room ${pinchedRoom.toHex()} ("Room 1"): its tint is '
                  'an unfilled outline: its face does not triangulate',
              handles: [pinchedRoom],
            ),
          ],
          reason: 'honest step 3 at $place');
      expect(driftOf(pinched.doc), isEmpty, reason: '$place');
    }
  });

  test(
      'RD1 a wall moved onto a room\'s seed dissolves it in the same undo '
      'step', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      final leftKids = kids(doc, left), rightKids = kids(doc, right);
      final before = canon(doc);
      final depth = doc.commands.undoDepth;

      doc.commands
          .execute(moveWall(plan, 4, const W(1500, 0, 1500, 4000, 100)));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      // Premise: the left seed lies in the partition's band (x 1,450..1,550).
      expect(faceAt(doc, seedAt(plan, leftSeed)), isA<SeedInWall>(),
          reason: '$place');
      expectDissolved(doc, left, leftKids, 'left at $place');
      // Right: x 1,550..7,900, (7,900 − 1,550) × 3,800 = 6,350 × 3,800 =
      // 24,130,000 (24.13, 0.005 from 24.125 and 24.135).
      expect(labelStrings(doc, right), ['Room 2', '24.13 m²'],
          reason: '$place');
      expect(kids(doc, right), rightKids, reason: '$place');
      expect(roomDiagnostics(doc), isEmpty, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'moved at $place');

      doc.commands.undo();
      expect(canon(doc), before, reason: 'undo at $place');
      expect(kids(doc, left), leftKids, reason: '$place');
      expect(kids(doc, right), rightKids, reason: '$place');
      expect(labelStrings(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test('RD2 a face opened to the outside dissolves its room', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      final leftKids = kids(doc, left), rightKids = kids(doc, right);
      final depth = doc.commands.undoDepth;

      // The west wall shortened 1,000 at its south end: a 900 mm gap from
      // the south wall's face (y 100) to y 1,000.
      doc.commands.execute(moveWall(plan, 3, const W(0, 4000, 0, 1000, 200)));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      // Premise: no bounded face holds the left seed.
      expect(faceAt(doc, seedAt(plan, leftSeed)), isA<Unbounded>(),
          reason: '$place');
      expectDissolved(doc, left, leftKids, 'left at $place');
      // Right unchanged: 4,850 × 3,800 = 18,430,000 (18.43, 0.005 from the
      // ties).
      expect(labelStrings(doc, right), ['Room 2', '18.43 m²'],
          reason: '$place');
      expect(kids(doc, right), rightKids, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
      doc.commands.undo();
      expect(kids(doc, left), leftKids, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test('RD3 deleting E4 dissolves the Hall and Bedroom 1 in one step', () {
    for (final place in [origin, corpusGroups]) {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final rooms = addSampleRooms(plan);
      final children = {
        for (final MapEntry(key: n, value: h) in rooms.entries) n: kids(doc, h),
      };
      final strings = {
        for (final MapEntry(key: n, value: h) in rooms.entries)
          n: labelStrings(doc, h),
      };
      final before = canon(doc);
      final depth = doc.commands.undoDepth;

      doc.commands.execute(deleteObject(doc, plan.walls[3]));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      for (final n in ['Hall', 'Bedroom 1']) {
        // Premise: both faces open to the outside.
        final (x, y) = sampleSeeds[n]!;
        expect(faceAt(doc, plan.at(x, y)), isA<Unbounded>(),
            reason: '$n at $place');
        expectDissolved(doc, rooms[n]!, children[n]!, '$n at $place');
      }
      for (final n in ['Bedroom 2', 'Kitchen', 'Bath', 'Living', 'Dining']) {
        expect(kids(doc, rooms[n]!), children[n], reason: '$n at $place');
        expect(labelStrings(doc, rooms[n]!), strings[n],
            reason: '$n at $place');
      }
      expect(driftOf(doc), isEmpty, reason: '$place');

      doc.commands.undo();
      expect(canon(doc), before, reason: 'undo at $place');
      for (final MapEntry(key: n, value: h) in rooms.entries) {
        expect(kids(doc, h), children[n], reason: '$n undone at $place');
      }
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'RD4 deleting the column keeps Living, closes its hole, and reports '
      'nothing', () {
    for (final place in [origin, corpusGroups]) {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final living = addSampleRooms(plan)['Living']!;
      final handles = kids(doc, living);
      expect(worldTintOf(doc, living), hasLength(10),
          reason: 'the premise: a keyholed tint at $place');

      doc.commands.execute(deleteObject(doc, plan.walls[9]));
      // 4,250 × 5,190 = 22,057,500 (22.06, 0.0025 from 22.055 and 22.065).
      expect(labelStrings(doc, living), ['Living', '22.06 m²'],
          reason: '$place');
      final face = faceAt(doc, plan.at(24500, 16000)) as Traced;
      expect(face.holes, isEmpty, reason: '$place');
      expectTintRect(plan, living, livingRing, 'no hole at $place');
      expect(areaOf(worldTintOf(doc, living)), closeTo(22057500, 1e-2),
          reason: '$place');
      expect(kids(doc, living), handles, reason: '$place');
      expect(diagnosticsOf(doc), isEmpty, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');

      doc.commands.undo();
      expect(labelStrings(doc, living), ['Living', '21.90 m²'],
          reason: '$place');
      expectKeyhole(plan, living, livingRing, [livingColumn], 21897500,
          'undone at $place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
    }
  });

  test(
      'RD5 a partition pulled back 160 mm leaves both rooms in one face, '
      'reported once', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');

      // The partition's south end pulled back 160 mm: a 60 mm gap above
      // the south wall's face (y 100 to 160); its north T and its band stay.
      doc.commands
          .execute(moveWall(plan, 4, const W(3000, 160, 3000, 4000, 100)));
      // One face: 7,800 × 3,800 − 100 × (3,900 − 160) = 29,640,000 −
      // 374,000 = 29,266,000 (29.27, 0.001 from 29.265).
      for (final (h, n) in [(left, 'Room 1'), (right, 'Room 2')]) {
        expect(labelStrings(doc, h), [n, '29.27 m²'], reason: '$place');
        expect(areaOf(worldTintOf(doc, h)), closeTo(29266000, 1e-2),
            reason: '$n at $place');
      }
      expect(roomDiagnostics(doc), [shared(left, 'Room 1', right, 'Room 2')],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });

  test(
      'RD6 the Living | Dining separator pulled 50 mm short leaves both '
      'rooms in one face', () {
    for (final place in [origin, corpusGroups]) {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final rooms = addSampleRooms(plan);
      final living = rooms['Living']!, dining = rooms['Dining']!;
      doc.commands
          .execute(moveSeparator(plan, 0, (21500, 11560, 21500, 16700)));
      // One face, D23's two joined: (25,750 − 17,060) × (16,750 − 11,560)
      // − 400 × 400 = 8,690 × 5,190 − 160,000 = 45,101,100 − 160,000 =
      // 44,941,100 (44.94, 0.0039 from 44.945).
      expect(labelStrings(doc, living), ['Living', '44.94 m²'],
          reason: '$place');
      expect(labelStrings(doc, dining), ['Dining', '44.94 m²'],
          reason: '$place');
      expect(roomDiagnostics(doc), [shared(living, 'Living', dining, 'Dining')],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });

  test(
      'RD7 undoing a dissolve restores the room, its component and every '
      'child handle', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Kitchen area',
          label: (123.25, -47.5));
      final params = doc.components.get<RoomParams>(left);
      final children = kids(doc, left);
      final strings = labelStrings(doc, left);
      final before = canon(doc);

      doc.commands
          .execute(moveWall(plan, 4, const W(1500, 0, 1500, 4000, 100)));
      expectDissolved(doc, left, children, '$place');
      final after = canon(doc);
      expect(driftOf(doc), isEmpty, reason: '$place');

      doc.commands.undo();
      expect(canon(doc), before, reason: 'undo at $place');
      expect(doc.components.get<RoomParams>(left), params, reason: '$place');
      expect(doc.tree[left]!.parent, doc.rootHandle, reason: '$place');
      expect(kids(doc, left), children, reason: '$place');
      expect(labelStrings(doc, left), strings, reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');

      doc.commands.redo();
      expect(canon(doc), after, reason: 'redo at $place');
      expectDissolved(doc, left, children, 'redone at $place');
      expect(driftOf(doc), isEmpty, reason: 'redone at $place');
    }
  });

  test('RD8 a separator moved 60 m away merges the two rooms it split', () {
    for (final place in [origin, corpusGroups]) {
      final plan = boxAndSeparatorPlan(place);
      final doc = plan.doc;
      attachPage(doc, PageComponent());
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, plan.at(6512.25, 3012.75), 'Room 2');
      // 2,900 × 3,800 = 11,020,000; 4,900 × 3,800 − 700 × 700 = 18,130,000.
      expect(labelStrings(doc, left), ['Room 1', '11.02 m²']);
      expect(labelStrings(doc, right), ['Room 2', '18.13 m²']);

      doc.commands.execute(moveSeparator(plan, 0, (63000, 100, 63000, 3900)));
      // Premise: only the separator's before box reaches the rooms; its
      // after box lies 50 m beyond the box's east wall.
      final inputs = RoomInputs(doc);
      final box = inputs.placeBoxOf(plan.seps.single)!;
      inputs.dispose();
      final east = plan.at(8100, 0);
      expect(
          [
            for (final (x, y) in [(63000.0, 100.0), (63000.0, 3900.0)])
              (plan.at(x, y) - east).length,
          ].reduce(math.min),
          greaterThan(50000),
          reason: '$place');
      expect(box.containsPoint(seedAt(plan, leftSeed)), isFalse);
      // One face: 7,800 × 3,800 − 700 × 700 = 29,640,000 − 490,000 =
      // 29,150,000 (29.15, 0.005 from the ties).
      expect(labelStrings(doc, left), ['Room 1', '29.15 m²'], reason: '$place');
      expect(labelStrings(doc, right), ['Room 2', '29.15 m²'],
          reason: '$place');
      expect(roomDiagnostics(doc), [shared(left, 'Room 1', right, 'Room 2')],
          reason: '$place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });
}

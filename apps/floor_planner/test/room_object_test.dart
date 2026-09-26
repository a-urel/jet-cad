// Spec 10 D2, D9-D11, D14-D16 and D18 at the app level: a room is its own
// parametric object. It stores a seed, a name and a label offset; it
// generates a translucent tint and two labels, in that order, with their
// attributes; its labels sit at the pole of its face, horizontal and sized
// on paper; a page change regenerates them in one undo step; its children
// keep their handles; it saves and loads byte-identically.
//
// A page is attached (1:50, metres) unless a case says otherwise. Expected
// areas are hand arithmetic, next to the assertion; every expected label
// string is at least 0.0005 m² (or ft²) from a rounding tie, checked in the
// comment. Seeds and offsets are fractional. The relational tests run at
// the origin and at the corpus far origin in own groups; RG1 at all six
// placements.
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;

import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_label.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

/// The two-room fixture's left and right seeds, plan mm (fractional).
const (double, double) leftSeed = (1512.5, 1987.25);
const (double, double) rightSeed = (5487.75, 2012.5);

/// The two-room fixture's partition (wall 4) moved 250.5 mm east: x 3,250.5.
const W movedPartition = W(3250.5, 0, 3250.5, 4000, 100);

/// The two-room fixture at [place] with the app's opening page attached.
Plan twoRooms(Placement place) {
  final plan = buildPlan(twoRoomWalls, place: place);
  attachPage(plan.doc, PageComponent());
  return plan;
}

Vector2 seedAt(Plan plan, (double, double) s) => plan.at(s.$1, s.$2);

/// World point [w] in [plan]'s plan millimetres.
Vector2 toPlan(Plan plan, Vector2 w) => plan.place.m.invert().transformPoint(w);

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

/// [room]'s tint is the rectangle with plan corners [corners]: as many
/// points, each within 1e-5 mm of one corner in world.
void expectTintRect(
    Plan plan, Handle room, List<(double, double)> corners, String why) {
  final tint = worldTintOf(plan.doc, room);
  expect(tint, hasLength(corners.length), reason: why);
  for (final (x, y) in corners) {
    final w = plan.at(x, y);
    final d = tint.map((q) => (q - w).length).reduce(math.min);
    expect(d, lessThan(1e-5), reason: '$why: corner ($x, $y) off by $d');
  }
}

/// The stored height and rotation of TEXT [h]: its payload's first two
/// scalars.
(double, double) heightAndRotation(DraftDocument doc, Handle h) {
  final s = payloadOf(doc, h).scalars;
  return (s[0], s[1]);
}

/// TEXT [h]'s insertion point in world.
Vector2 worldInsertion(DraftDocument doc, Handle h) =>
    worldPoints(doc, h).single;

/// [room]'s name and area strings.
List<String> stringsOf(DraftDocument doc, Handle room) =>
    [for (final h in labelsOf(doc, room)) textOf(doc, h)];

/// The pole of the face around world [seed], through the document adapter:
/// the point [RoomType.generate] anchors at when the label is auto.
Vector2 poleAt(DraftDocument doc, Vector2 seed) {
  final inputs = RoomInputs(doc);
  try {
    final t = traceRoomAmong(seed, inputs) as Traced;
    return poleOfInaccessibility(t.ring, t.holes).point;
  } finally {
    inputs.dispose();
  }
}

void main() {
  test(
      'RP1 RoomParams round-trips with key order seed, name, label; label '
      'null is written; == differs on each field', () {
    const auto = RoomParams(1234.5, -987.25, 'Room 1');
    const offset = RoomParams(1234.5, -987.25, 'Room 1', label: (12.75, -3.5));
    expect(auto.typeId, 'floor_planner.room');
    expect(RoomParams.componentTypeId, 'floor_planner.room');
    expect(auto.toJson().keys, ['seed', 'name', 'label']);
    expect(jsonEncode(auto.toJson()),
        '{"seed":[1234.5,-987.25],"name":"Room 1","label":null}');
    expect(jsonEncode(offset.toJson()),
        '{"seed":[1234.5,-987.25],"name":"Room 1","label":[12.75,-3.5]}');
    for (final p in [auto, offset]) {
      final back = RoomParams.fromJson(
          jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>);
      expect(back, p);
      expect(back.hashCode, p.hashCode);
    }

    // Exact == on every field, each one alone.
    for (final other in [
      const RoomParams(1234.5000000000002, -987.25, 'Room 1',
          label: (12.75, -3.5)),
      const RoomParams(1234.5, -987.2500000000001, 'Room 1',
          label: (12.75, -3.5)),
      const RoomParams(1234.5, -987.25, 'Room 2', label: (12.75, -3.5)),
      const RoomParams(1234.5, -987.25, 'Room 1',
          label: (12.750000000000002, -3.5)),
      const RoomParams(1234.5, -987.25, 'Room 1',
          label: (12.75, -3.5000000000000004)),
      auto,
    ]) {
      expect(other == offset, isFalse, reason: '$other');
    }
    expect(const RoomParams(1234.5, -987.25, 'Room 1', label: (12.75, -3.5)),
        offset);

    // copyWith keeps what it is not given, and clears the label on null.
    expect(offset.copyWith(), offset);
    expect(offset.copyWith(label: null), auto);
    expect(auto.copyWith(label: (12.75, -3.5)), offset);
    expect(offset.copyWith(name: 'Kitchen'),
        const RoomParams(1234.5, -987.25, 'Kitchen', label: (12.75, -3.5)));
    expect(offset.copyWith(seedX: 1.25, seedY: 2.5),
        const RoomParams(1.25, 2.5, 'Room 1', label: (12.75, -3.5)));

    // Anything well-typed loads: integers, a non-finite label.
    expect(
        RoomParams.fromJson(const {
          'seed': [3, -4],
          'name': 'N',
          'label': [1, 2],
        }),
        const RoomParams(3, -4, 'N', label: (1, 2)));
    final wild = RoomParams.fromJson(const {
      'seed': [3.5, -4.25],
      'name': '',
      'label': [double.infinity, 2.5],
    });
    expect(wild.label!.$1, double.infinity);
    expect(wild.label!.$2, 2.5);
    expect(wild.name, '');
    expect(() => RoomParams.fromJson(const {'name': 'N', 'label': null}),
        throwsA(isA<TypeError>()));
  });

  test(
      'RG1 a room generates its tint, its name and its area, in that order, '
      'with their attributes, at six placements', () {
    for (final place in placements) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final room = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final k = kids(doc, room);
      expect([
        for (final h in k) kindOf(doc, h)
      ], [
        EntityKind.fill,
        EntityKind.polyline,
        EntityKind.text,
        EntityKind.text,
      ], reason: 'fill < boundary < name < area at $place');
      final [fill, boundary, name, area] = k;
      expect(payloadOf(doc, fill).scalars[0].toInt(), boundary.value,
          reason: 'the fill names the boundary at $place');

      // The tint (D9, R-8, R-10): ACI 7 on both records, transparency 229
      // on both, the boundary invisible, the fill drawn.
      for (final (h, flags) in [(fill, 0), (boundary, EntityFlags.invisible)]) {
        final r = recordOf(doc, h);
        expect(r.color, const IndexedColor(7), reason: '$h at $place');
        expect(r.transparency, 229, reason: '$h at $place');
        expect(r.flags, flags, reason: '$h at $place');
        expect(r.layer, ReservedHandles.layerZero, reason: '$h at $place');
      }

      // The labels (D9, D11, Ruling 10-14): ByLayer, STANDARD, centre-middle
      // (0x21: h = 1, v = 2), flags 0.
      for (final h in [name, area]) {
        final r = recordOf(doc, h);
        expect(r.color, const ByLayerColor(), reason: '$h at $place');
        expect(r.layer, ReservedHandles.layerZero, reason: '$h at $place');
        expect(r.textStyle, ReservedHandles.standardTextStyle,
            reason: '$h at $place');
        expect(r.textAttrs, 0x21, reason: '$h at $place');
        expect(r.flags, 0, reason: '$h at $place');
      }
      // Left room: inner faces x 100..2,950 (the partition's west face,
      // 3,000 − 50), y 100..3,900: 2,850 × 3,800 = 10,830,000 mm², 10.83 m²
      // (0.005 from the ties 10.825 and 10.835).
      expect(textOf(doc, name), 'Room 1', reason: '$place');
      expect(textOf(doc, area), '10.83 m²', reason: '$place');
      // 1:50: 2.5 × 50 = 125 and 2.0 × 50 = 100; the group is the identity,
      // so rotation 0 (and not -0.0).
      final (hName, rName) = heightAndRotation(doc, name);
      final (hArea, rArea) = heightAndRotation(doc, area);
      expect((hName, hArea), (125.0, 100.0), reason: '$place');
      expect((rName, rArea), (0.0, 0.0), reason: '$place');
      expect(rName.isNegative || rArea.isNegative, isFalse, reason: '$place');

      // The tint is the face: its four corners, its area.
      const corners = [
        (100.0, 100.0),
        (2950.0, 100.0),
        (2950.0, 3900.0),
        (100.0, 3900.0)
      ];
      expectTintRect(plan, room, corners, 'the tint at $place');
      expect(areaOf(worldTintOf(doc, room)), closeTo(10830000, 1e-2),
          reason: '$place');

      // The labels at the pole, in world directions: the name 0.7 × 125
      // above the anchor, the area 0.7 × 100 below it.
      final gap = worldInsertion(doc, name) - worldInsertion(doc, area);
      expect(gap.x, closeTo(0, 1e-6), reason: '$place');
      expect(gap.y, closeTo(87.5 + 70, 1e-6), reason: '$place');
      // The pole of a 2,850 × 3,800 rectangle is 1,425 from its boundary
      // (half its width), within the 10 mm precision.
      final a = toPlan(plan, anchorOf(doc, room));
      final clearance =
          [a.x - 100, 2950 - a.x, a.y - 100, 3900 - a.y].reduce(math.min);
      expect(clearance, greaterThanOrEqualTo(1425 - 10),
          reason: 'the anchor $a at $place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });

  test(
      'RG4 a room\'s children keep their handles across a wall move, undo, '
      'redo and purge', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final right = addRoom(doc, seedAt(plan, rightSeed), 'Room 2');
      // Left 2,850 × 3,800 = 10,830,000 (10.83); right: x 3,050..7,900,
      // 4,850 × 3,800 = 18,430,000 (18.43, 0.005 from 18.425 and 18.435).
      expect(stringsOf(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(stringsOf(doc, right), ['Room 2', '18.43 m²'], reason: '$place');
      final handles = {
        for (final r in [left, right]) r: kids(doc, r),
      };
      for (final r in [left, right]) {
        expect(handles[r], hasLength(4), reason: '$r at $place');
      }
      // Premise (X5-noStored): the partition's band box, before and after,
      // misses both seeds, so only the rooms' stored tints reach it.
      final inputs = RoomInputs(doc);
      final bandBefore = inputs.placeBoxOf(plan.walls[4])!;
      inputs.dispose();
      for (final s in [leftSeed, rightSeed]) {
        expect(bandBefore.containsPoint(seedAt(plan, s)), isFalse);
      }
      final before = canon(doc, sortNodes: true);
      final depth = doc.commands.undoDepth;

      doc.commands.execute(moveWall(plan, 4, movedPartition));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      final moved = RoomInputs(doc);
      final bandAfter = moved.placeBoxOf(plan.walls[4])!;
      moved.dispose();
      for (final s in [leftSeed, rightSeed]) {
        expect(bandAfter.containsPoint(seedAt(plan, s)), isFalse);
      }
      expect({
        for (final r in [left, right]) r: kids(doc, r)
      }, handles, reason: 'moved at $place');
      // Left: x 100..3,200.5, 3,100.5 × 3,800 = 11,781,900 (11.78, 0.0031
      // from 11.785); right: x 3,300.5..7,900, 4,599.5 × 3,800 =
      // 17,478,100 (17.48, 0.0031 from 17.475).
      expect(stringsOf(doc, left), ['Room 1', '11.78 m²'], reason: '$place');
      expect(stringsOf(doc, right), ['Room 2', '17.48 m²'], reason: '$place');
      expectTintRect(
          plan,
          left,
          const [(100, 100), (3200.5, 100), (3200.5, 3900), (100, 3900)],
          'left moved at $place');
      expect(driftOf(doc), isEmpty, reason: 'moved at $place');
      final after = canon(doc, sortNodes: true);

      doc.commands.undo();
      expect(canon(doc, sortNodes: true), before, reason: 'undo at $place');
      expect({
        for (final r in [left, right]) r: kids(doc, r)
      }, handles);
      expect(stringsOf(doc, left), ['Room 1', '10.83 m²'], reason: '$place');
      expect(driftOf(doc), isEmpty, reason: 'undone at $place');
      doc.commands.redo();
      expect(canon(doc, sortNodes: true), after, reason: 'redo at $place');
      expect({
        for (final r in [left, right]) r: kids(doc, r)
      }, handles);
      expect(driftOf(doc), isEmpty, reason: 'redone at $place');
      doc.commands.undo();
      doc.purge();
      expect(canon(doc, sortNodes: true), before, reason: 'purge at $place');
      expect({
        for (final r in [left, right]) r: kids(doc, r)
      }, handles);
      expect(driftOf(doc), isEmpty, reason: 'purged at $place');
    }
  });

  test(
      'RG5 save, load and save are byte-identical; RoomParams come back '
      'equal; labels keep their strings; the DASHED record persists; '
      'drift() is empty after the load', () {
    for (final place in [origin, corpusGroups]) {
      final plan = boxAndSeparatorPlan(place);
      final doc = plan.doc;
      attachPage(doc, PageComponent());
      final left = addRoom(doc, seedAt(plan, leftSeed), 'Room 1',
          label: (123.25, -47.5));
      final right = addRoom(doc, plan.at(6512.25, 3012.75), 'Room 2');
      doc.commands.execute(SetComponentCommand<RoomParams>(
          left,
          doc.components
              .get<RoomParams>(left)!
              .copyWith(name: 'Kitchen area')));
      // Left: face to face at x 3,000, 2,900 × 3,800 = 11,020,000 (11.02,
      // 0.005 from 11.015 and 11.025). Right: 4,900 × 3,800 = 18,620,000
      // less the hollow column's 700 × 700 = 490,000: 18,130,000 (18.13,
      // 0.005 from 18.125 and 18.135).
      expect(stringsOf(doc, left), ['Kitchen area', '11.02 m²']);
      expect(stringsOf(doc, right), ['Room 2', '18.13 m²']);
      final params = {
        for (final r in [left, right]) r: doc.components.get<RoomParams>(r),
      };
      final strings = {
        for (final r in [left, right])
          for (final h in labelsOf(doc, r)) h: textOf(doc, h),
      };
      final saved = enc(doc);
      final loaded = reloadWithPage(saved);
      expect(enc(loaded), saved, reason: 'save, load, save at $place');
      expect({
        for (final r in [left, right]) r: loaded.components.get<RoomParams>(r),
      }, params);
      expect(loaded.components.get<RoomParams>(left)!.label, (123.25, -47.5));
      expect({
        for (final r in [left, right])
          for (final h in labelsOf(loaded, r)) h: textOf(loaded, h),
      }, strings);
      expect(loaded.tables.linetypes[ReservedHandles.dashedLinetype],
          kDashedLinetypeRecord);
      expect(loaded.components.get<PageComponent>(loaded.rootHandle),
          PageComponent());
      expect(driftOf(loaded), isEmpty, reason: 'loaded at $place');
    }
  });

  test('RG6 the same state and the same edit give the same bytes', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final a = plan.doc;
      addRoom(a, seedAt(plan, leftSeed), 'Room 1', label: (40.5, 12.25));
      addRoom(a, seedAt(plan, rightSeed), 'Room 2');
      final b = reloadWithPage(enc(a));
      expect(enc(b), enc(a), reason: 'the premise at $place');
      a.commands.execute(moveWall(plan, 4, movedPartition));
      b.commands.execute(moveWall(plan, 4, movedPartition, doc: b));
      expect(enc(b), enc(a), reason: 'the same move at $place');
      expect(driftOf(a), isEmpty);
      expect(driftOf(b), isEmpty);
    }
  });

  test('RL3 a label offset rides with the pole across a wall move', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      // The seed far from the pole: (700.5, 3,400.25) in a face whose pole
      // lies on x 1,525 between y 1,525 and 2,475 (> 800 mm away).
      final seed = plan.at(700.5, 3400.25);
      const label = (310.25, -145.5);
      final room = addRoom(doc, seed, 'Kitchen area', label: label);
      // A non-finite offset reads as auto (D2): the right room anchors at
      // its pole.
      final store = addRoom(doc, seedAt(plan, rightSeed), 'Store',
          label: (double.infinity, 5.5));
      final offset = Vector2(label.$1, label.$2);

      void expectRides(String when) {
        final pole = poleAt(doc, seed);
        final anchor = anchorOf(doc, room);
        // The room group is the identity: local is world.
        final d = anchor - pole - offset;
        expect(d.length, lessThan(1e-6),
            reason: 'anchor − pole == label $when at $place');
        expect((anchor - (seed + offset)).length, greaterThan(100),
            reason: 'the anchor is not seed + label $when at $place');
        expect(stringsOf(doc, room).first, 'Kitchen area');
        final storePole = poleAt(doc, seedAt(plan, rightSeed));
        expect((anchorOf(doc, store) - storePole).length, lessThan(1e-6),
            reason: 'a non-finite offset is auto $when at $place');
      }

      expectRides('placed');
      final pole0 = poleAt(doc, seed);
      final anchor0 = anchorOf(doc, room);
      doc.commands.execute(moveWall(plan, 4, movedPartition));
      final pole1 = poleAt(doc, seed);
      // Premise: the move shifts the pole (the face's centre line moves
      // from x 1,525 to 1,650.25).
      expect((pole1 - pole0).length, greaterThan(100), reason: '$place');
      expectRides('moved');
      expect(((anchorOf(doc, room) - anchor0) - (pole1 - pole0)).length,
          lessThan(1e-6),
          reason: 'the anchor moves by the pole\'s move at $place');
      expect(driftOf(doc), isEmpty, reason: '$place');
    }
  });

  test(
      'RL4 under a rotated, translated, scaled room group the labels are '
      'horizontal in world and sized on paper', () {
    final plan = twoRooms(corpus);
    final doc = plan.doc;
    final seed = seedAt(plan, leftSeed);
    final room = addRoom(doc, seed, 'Room 1');
    // A hand-built similarity about the seed (only a file makes one, D21):
    // 23°, scale 1.5, and a far-origin translation, so the seed stays put.
    final m = Transform2.translation(seed.x, seed.y)
        .multiply(Transform2.rotation(23 * math.pi / 180))
        .multiply(Transform2.scale(1.5, 1.5))
        .multiply(Transform2.translation(-seed.x, -seed.y));
    doc.commands.execute(TransformNodeCommand(room, m));
    final toWorld = doc.tree.accumulatedTransform(room);
    // Premises: the group is that similarity, far from the origin, and the
    // stored seed still lands on the world seed.
    expect(toWorld.scaleMagnitude, closeTo(1.5, 1e-12));
    expect(
        math.atan2(toWorld.b, toWorld.a), closeTo(23 * math.pi / 180, 1e-12));
    expect(toWorld.e.abs() + toWorld.f.abs(), greaterThan(1e6));
    final p = doc.components.get<RoomParams>(room)!;
    expect((toWorld.transformPoint(p.seed) - seed).length, lessThan(1e-6));

    final [name, area] = labelsOf(doc, room);
    for (final (h, height) in [(name, 125.0), (area, 100.0)]) {
      final (hStored, rStored) = heightAndRotation(doc, h);
      final dir = toWorld
          .transformDirection(Vector2(math.cos(rStored), math.sin(rStored)));
      expect(math.atan2(dir.y, dir.x), closeTo(0, 1e-12),
          reason: 'horizontal in world: $h');
      expect(hStored * toWorld.scaleMagnitude, closeTo(height, 1e-9),
          reason: 'on paper: $h');
    }
    final gap = worldInsertion(doc, name) - worldInsertion(doc, area);
    expect(gap.x, closeTo(0, 1e-6));
    expect(gap.y, closeTo(87.5 + 70, 1e-6));
    expect(stringsOf(doc, room), ['Room 1', '10.83 m²']);
    // The tint is still the face, through the scaled, turned group.
    expectTintRect(plan, room,
        const [(100, 100), (2950, 100), (2950, 3900), (100, 3900)], 'RL4');
    final a = toPlan(plan, anchorOf(doc, room));
    expect([a.x - 100, 2950 - a.x, a.y - 100, 3900 - a.y].reduce(math.min),
        greaterThanOrEqualTo(1425 - 10));
    expect(driftOf(doc), isEmpty);
  });

  test(
      'RA2 a page change from metres at 1:50 to ft-in at 1:100 regenerates '
      'the labels in one undo step', () {
    for (final place in [origin, corpusGroups]) {
      final plan = twoRooms(place);
      final doc = plan.doc;
      final room = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final handles = kids(doc, room);
      final [name, area] = labelsOf(doc, room);
      final m50 = doc.components.get<PageComponent>(doc.rootHandle)!;

      void expectLabels(String want, double hName, double hArea, String why) {
        expect(stringsOf(doc, room), ['Room 1', want], reason: why);
        expect(heightAndRotation(doc, name).$1, hName, reason: why);
        expect(heightAndRotation(doc, area).$1, hArea, reason: why);
        final gap = worldInsertion(doc, name) - worldInsertion(doc, area);
        expect(gap.y, closeTo(0.7 * (hName + hArea), 1e-6), reason: why);
        expect(kids(doc, room), handles, reason: why);
        expect(driftOf(doc), isEmpty, reason: why);
      }

      expectLabels('10.83 m²', 125, 100, 'metres at 1:50 at $place');
      final depth = doc.commands.undoDepth;
      var generates = debugRoomGenerates;
      // 10,830,000 / (304.8 × 304.8) = 10,830,000 / 92,903.04 = 116.5737…
      // (116.57, 0.0013 from 116.575); 2.5 and 2.0 mm × 100.
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle,
          m50.copyWith(
              displayUnit: DisplayUnit.feetInches, scaleDenominator: 100)));
      expect(doc.commands.undoDepth, depth + 1, reason: '$place');
      expect(debugRoomGenerates - generates, 1, reason: '$place');
      expectLabels('116.57 ft²', 250, 200, 'ft-in at 1:100 at $place');
      doc.commands.undo();
      expectLabels('10.83 m²', 125, 100, 'undone at $place');

      // A paper colour or a grid change is outside the key: no generate.
      generates = debugRoomGenerates;
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle,
          m50.copyWith(
              background: 0xFF1F3B5C, gridVisible: false, gridStepMm: 125.0)));
      expect(debugRoomGenerates - generates, 0,
          reason: 'paper and grid at $place');
      expectLabels('10.83 m²', 125, 100, 'paper and grid at $place');
      doc.commands.undo();

      // Each half of the key alone regenerates: the unit (inches, 1:50),
      // then the scale (metres, 1:100).
      generates = debugRoomGenerates;
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, m50.copyWith(displayUnit: DisplayUnit.inches)));
      expect(debugRoomGenerates - generates, 1, reason: '$place');
      expectLabels('116.57 ft²', 125, 100, 'inches at 1:50 at $place');
      doc.commands.undo();
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, m50.copyWith(scaleDenominator: 100)));
      expectLabels('10.83 m²', 250, 200, 'metres at 1:100 at $place');
    }
  });

  test('RX1 a room with no page reads 1:50 and metres', () {
    for (final registered in [false, true]) {
      final plan = buildPlan(twoRoomWalls, place: corpusGroups);
      final doc = plan.doc;
      if (registered) PageComponent.register(doc.components);
      expect(pageOf(doc), PageComponent(),
          reason: 'the premise: no page on the root');
      final room = addRoom(doc, seedAt(plan, leftSeed), 'Room 1');
      final [name, area] = labelsOf(doc, room);
      expect(stringsOf(doc, room), ['Room 1', '10.83 m²'],
          reason: 'registered: $registered');
      expect(heightAndRotation(doc, name).$1, 125,
          reason: 'registered: $registered');
      expect(heightAndRotation(doc, area).$1, 100,
          reason: 'registered: $registered');
      expect(driftOf(doc), isEmpty);
    }
  });
}

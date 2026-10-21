// The room's area through the kit contract (PlanType.area): the traced outer
// ring in world millimetres, anticlockwise, from the document.
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/room_fixture.dart';

final KitWords words =
    KitNamesWords(architectureKit.names, () => const Locale('en'));

/// A 6000 x 4000 room (centrelines) of 200 mm walls at (12000, 7000).
const List<W> offsetWalls = [
  W(12000, 7000, 18000, 7000, 200),
  W(18000, 7000, 18000, 11000, 200),
  W(18000, 11000, 12000, 11000, 200),
  W(12000, 11000, 12000, 7000, 200),
];

List<Vector2>? areaOf(DraftDocument doc, Handle room) =>
    roomPlanType.areaOf(doc, room, words);

void expectRing(List<Vector2>? got, List<Vector2> want) {
  expect(got, isNotNull);
  expect(got!.length, want.length);
  // Same cycle, any starting vertex: find the rotation that lines them up.
  final k = got.indexWhere((p) => (p - want.first).length < 1e-6);
  expect(k, isNonNegative, reason: '$got vs $want');
  for (var i = 0; i < want.length; i++) {
    final p = got[(k + i) % got.length];
    expect(p.x, closeTo(want[i].x, 1e-6));
    expect(p.y, closeTo(want[i].y, 1e-6));
  }
}

double signedArea(List<Vector2> r) {
  var a = 0.0;
  for (var i = 0; i < r.length; i++) {
    final p = r[i], q = r[(i + 1) % r.length];
    a += p.x * q.y - q.x * p.y;
  }
  return a / 2;
}

void main() {
  test('RA1 four walls 6000 x 4000 at (12000, 7000): the inner ring', () {
    final plan = buildPlan(offsetWalls);
    addTearDown(plan.doc.dispose);
    final room = addRoom(plan.doc, Vector2(14500.5, 9000.25), 'Hall');
    expect(roomPlanType.hasArea, isTrue);
    final ring = areaOf(plan.doc, room);
    expectRing(ring, [
      Vector2(12100, 7100),
      Vector2(17900, 7100),
      Vector2(17900, 10900),
      Vector2(12100, 10900),
    ]);
    expect(signedArea(ring!), closeTo(5800 * 3800, 1e-3));
    final traced = faceAt(plan.doc, Vector2(14500.5, 9000.25));
    expectRing(ring, (traced as Traced).ring);
  });

  test('RA2 two walls and two separators (an open garden): an area', () {
    final plan = buildPlan(const [
      W(0, 0, 6000, 0, 200),
      W(6000, 4000, 0, 4000, 200),
    ], seps: const [
      (6000, 0, 6000, 4000),
      (0, 4000, 0, 0),
    ], place: corpus);
    addTearDown(plan.doc.dispose);
    final room = addRoom(plan.doc, plan.at(3000.5, 2000.25), 'Garden');
    final ring = areaOf(plan.doc, room);
    expect(ring, isNotNull);
    // Between the wall faces (y 100..3900) and the separators' lines.
    expect(signedArea(ring!), closeTo(6000 * 3800, 1e-2));
  });

  test('RA3 the room group rotated 90 degrees and mirrored: world placement',
      () {
    final plan = buildPlan(offsetWalls);
    addTearDown(plan.doc.dispose);
    // The seed is stored local: (200, 300) mirrored in x, turned 90 degrees
    // and moved to (15000, 9000) is the world point (14700, 8800).
    final g = Transform2.translation(15000, 9000)
        .multiply(Transform2.rotation(math.pi / 2))
        .multiply(Transform2.scale(-1, 1));
    final h = plan.doc.handleSeed.next();
    plan.doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h,
          parent: plan.doc.rootHandle,
          transform: g,
          children: const [])),
      SetComponentCommand<RoomParams>(h, RoomParams(200, 300, 'Mirrored')),
    ], label: 'Add room'));
    expect(g.transformPoint(Vector2(200, 300)).x, closeTo(14700, 1e-9));
    expectRing(areaOf(plan.doc, h), [
      Vector2(12100, 7100),
      Vector2(17900, 7100),
      Vector2(17900, 10900),
      Vector2(12100, 10900),
    ]);
  });

  test('RA4 a seed in a wall, and a room with a wall deleted: null', () {
    final plan = buildPlan(offsetWalls);
    addTearDown(plan.doc.dispose);
    final inWall = addRoom(plan.doc, Vector2(12000, 9000), 'Wall');
    expect(areaOf(plan.doc, inWall), isNull);
    final room = addRoom(plan.doc, Vector2(14500.5, 9000.25), 'Hall');
    expect(areaOf(plan.doc, room), isNotNull);
    plan.doc.commands.execute(RemoveNodeCommand(plan.walls[2]));
    expect(areaOf(plan.doc, room), isNull);
  });

  test('RA5 the ring follows an edit (memo per document state)', () {
    final plan = buildPlan(offsetWalls);
    addTearDown(plan.doc.dispose);
    final room = addRoom(plan.doc, Vector2(14500.5, 9000.25), 'Hall');
    final before = areaOf(plan.doc, room)!;
    final traces = debugRoomAreaTraces;
    expect(areaOf(plan.doc, room), same(before));
    expect(debugRoomAreaTraces, traces, reason: 'memoised');
    plan.doc.commands.execute(TransformNodeCommand(
        plan.walls[1], Transform2.translation(-1000.5, 0)));
    final after = areaOf(plan.doc, room)!;
    expect(debugRoomAreaTraces, traces + 1);
    expect(after.map((p) => p.x).reduce(math.max), closeTo(16899.5, 1e-6));
  });
}

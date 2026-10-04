// Spec 10 D19: the Room tool (M). One click inside a face places one room,
// seeded at the raw pointer, named with the lowest free `Room N`, in one undo
// step; the hover previews the face the room would get, traced with the
// same code as the room's `generate`; a band, an unbounded face and a face
// that already holds a room make nothing, and the last says so in the
// status line (decision 26, R-29). The hover short-circuits outside the
// bounding box of every place box and reuses its caches while the pointer
// stays in one face or one band.
//
// Expected areas are hand arithmetic next to the assertion; every expected
// label string is at least 0.0005 m² from a rounding tie. Seeds are
// fractional, and the fixtures run at the origin and at the corpus far
// origin with every wall and separator in its own rotated group.
import 'package:jet_cad_floor_plan/src/planner_shell.dart';
import 'package:jet_cad_floor_plan/src/parametric/dimension.dart';
import 'package:jet_cad_floor_plan/src/parametric/room.dart';
import 'package:jet_cad_floor_plan/src/parametric/live_objects.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_inputs.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_tool.dart';
import 'package:jet_cad_floor_plan/src/parametric/room_trace.dart';
import 'package:jet_cad_floor_plan/src/parametric/wall.dart';
import 'package:jet_cad_floor_plan/src/planner_view.dart';
import 'package:jet_cad_floor_plan/src/tool_palette.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

// ---------------------------------------------------------------------------
// The tool driven directly, as `opening_tool_test.dart` drives its tools.

typedef Rig = ({RoomTool tool, ToolContext ctx, RoomInputs inputs});

/// A Room tool over [doc] with its own [RoomInputs]: a camera at [scale]
/// pixels per mm (1 gives a 10 mm aperture), object snap on, no page (no
/// grid).
Rig roomRig(DraftDocument doc, {double scale = 1}) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.scale(scale, scale)));
  final selection = SelectionController(doc);
  final inputs = RoomInputs(doc);
  final tool = RoomTool(inputs);
  addTearDown(() {
    tool.dispose();
    inputs.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc, index: index, camera: camera, selection: selection),
    inputs: inputs,
  );
}

ToolPointerEvent pointerAt(Vector2 world, {int buttons = 0}) =>
    ToolPointerEvent(
        screen: Offset.zero,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: false,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);

void hoverTo(Rig rig, Vector2 world) =>
    rig.tool.onPointerMove(pointerAt(world), rig.ctx);

void pressAt(Rig rig, Vector2 world) =>
    rig.tool.onPointerDown(pointerAt(world, buttons: kPrimaryButton), rig.ctx);

/// Every live room, ascending.
List<Handle> rooms(DraftDocument doc) => liveObjectsOf<RoomParams>(doc);

/// The one room [doc] gained over [before].
Handle addedRoom(DraftDocument doc, List<Handle> before) =>
    rooms(doc).where((r) => !before.contains(r)).single;

/// A preview payload's points, less the repeated first point.
List<Vector2> ringOf(GeometryPayload p) {
  final c = p.coords;
  expect((c[c.length - 2], c[c.length - 1]), (c[0], c[1]),
      reason: 'an open polyline that closes on its first point');
  return [
    for (var i = 0; i + 3 < c.length; i += 2) Vector2(c[i], c[i + 1]),
  ];
}

/// [ring] is the polygon with plan corners [corners], in that cyclic order
/// (anticlockwise; the trace starts it at its least world vertex, which
/// turns with the placement), each within 1e-6 mm in world.
void expectRing(
    Plan plan, List<Vector2> ring, List<(double, double)> corners, String why) {
  expect(ring, hasLength(corners.length), reason: why);
  final first = plan.at(corners[0].$1, corners[0].$2);
  var k = 0;
  for (var i = 1; i < ring.length; i++) {
    if ((ring[i] - first).length < (ring[k] - first).length) k = i;
  }
  for (var i = 0; i < corners.length; i++) {
    final (x, y) = corners[i];
    final d = (ring[(k + i) % ring.length] - plan.at(x, y)).length;
    expect(d, lessThan(1e-6), reason: '$why: corner $i ($x, $y) off by $d');
  }
}

/// Decision 29's tied island (`room_tie_test.dart`'s fixture): a column
/// in the box, and a separator tying it to the south face.
const W tiedColumn = W(5000, 2000, 5400, 2000, 400);
const S tiedSeparator = (5200.5, 100, 5200.5, 1800);

/// The reviewer's connected plan (Task 15's review): [nx] × [ny] cells of
/// 3,000 mm, every cell edge a 200 mm wall, and a garden wall 6,000 mm
/// east of it, so the strip between lies inside the bounding box and
/// outside the building.
List<W> connectedGrid(int nx, int ny) => [
      for (var i = 0; i < nx; i++)
        for (var j = 0; j <= ny; j++)
          W(i * 3000.0, j * 3000.0, (i + 1) * 3000.0, j * 3000.0, 200),
      for (var i = 0; i <= nx; i++)
        for (var j = 0; j < ny; j++)
          W(i * 3000.0, j * 3000.0, i * 3000.0, (j + 1) * 3000.0, 200),
      W(nx * 3000.0 + 6000, 0, nx * 3000.0 + 6000, ny * 3000.0, 200),
    ];

/// A canvas that records every call made on it.
class CanvasSpy implements Canvas {
  final List<Symbol> calls = <Symbol>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      calls.add(invocation.memberName);
}

/// [got] is [want] up to 1e-6 mm per point, as a cycle: two traces of one
/// face from two seeds start at the same vertex only up to rounding of the
/// seed-relative frame.
void expectSameRing(List<Vector2> got, List<Vector2> want, String why) {
  expect(got, hasLength(want.length), reason: why);
  var k = 0;
  for (var i = 1; i < got.length; i++) {
    if ((got[i] - want[0]).length < (got[k] - want[0]).length) k = i;
  }
  for (var i = 0; i < want.length; i++) {
    final d = (got[(k + i) % got.length] - want[i]).length;
    expect(d, lessThan(1e-6), reason: '$why: point $i off by $d');
  }
}

// ---------------------------------------------------------------------------
// The shell.

/// [plan]'s document handed to the shell: its own parametric system is
/// disposed first, as `startupPlan` disposes its own, and the shell installs
/// one over the finished document.
Future<PlannerView> pumpPlan(WidgetTester tester, Plan plan) async {
  plan.system.dispose();
  plan.doc.commands.clearHistory();
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: plan.doc)));
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

Offset screenOf(WidgetTester tester, PlannerView view, Vector2 world) {
  final s = view.camera.value.worldToScreen(world);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

Future<void> clickAt(WidgetTester tester, PlannerView view, Vector2 p) async {
  await tester.tapAt(screenOf(tester, view, p));
  await tester.pump();
}

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await press(tester, LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

/// The shell's Room tool, found through its palette entry.
RoomTool shellRoomTool(WidgetTester tester) => tester
    .widget<ToolPalette>(find.byType(ToolPalette))
    .entries
    .firstWhere((e) => e.keyName == 'tool-room')
    .tool as RoomTool;

/// The sample plan's walls, column, separator and openings at the origin,
/// on a document the shell can paint (a `FlutterTextMeasurer`).
Plan shellSamplePlan() => buildPlan([...sampleWalls(), sampleColumn],
    seps: const [sampleSeparator],
    openings: sampleOpenings,
    measurer: FlutterTextMeasurer());

void main() {
  testWidgets(
      'TT1 M places one room with one click, one undo step, named Room 1, '
      'seeded at the raw point; the tool stays active and Esc returns to '
      'Select', (tester) async {
    // The tool driven directly, at the corpus far origin in own groups: a
    // fractional click, hovered first; then an unrelated edit raises the
    // handle seed before the click (X15-predict: the handle is allocated
    // inside the commit's build, never predicted).
    final plan = buildPlan(boxWalls, place: corpusGroups);
    final doc = plan.doc;
    final rig = roomRig(doc);
    final seed = plan.at(2345.625, 1789.375);
    hoverTo(rig, seed);
    expect(rig.tool.debugPreview, hasLength(1), reason: 'the face, no hole');
    final hovered = doc.handleSeed.current;
    doc.commands.execute(addDrafted(doc, EntityKind.line,
        linePayload(plan.at(-3000, -3000), plan.at(-2000, -3000.5)),
        layer: ReservedHandles.layerZero));
    final raised = doc.handleSeed.current;
    expect(raised.value, greaterThan(hovered.value),
        reason: 'premise: the edit raised the handle seed');
    final depth = doc.commands.undoDepth;
    pressAt(rig, seed);
    final room = rooms(doc).single;
    expect(room.value, greaterThan(raised.value),
        reason: 'allocated at the click');
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect((doc.tree[room]! as GroupNode).transform.isIdentity, isTrue,
        reason: 'its group at the identity');
    expect(doc.components.get<RoomParams>(room),
        RoomParams(seed.x, seed.y, 'Room 1'),
        reason: 'the raw point, exactly; Room 1; the label auto');
    // The box's inner faces 100 in: 7,800 × 3,800 = 29,640,000 mm²,
    // 29.64 m² (0.005 from a tie).
    expect(labelStrings(doc, room), ['Room 1', '29.64 m²']);
    expect(driftOf(doc), isEmpty);
    expect(rig.tool.debugPreview, isEmpty, reason: 'the face now holds a room');
    expect(rig.tool.notice.value, 'Already a room: Room 1');
    doc.commands.undo();
    expect(rooms(doc), isEmpty, reason: 'one undo takes it away');

    // The shell: M and the palette entry both activate the tool, a click
    // places a room, the tool stays active, and Esc returns to Select.
    final shell = shellSamplePlan();
    final view = await pumpPlan(tester, shell);
    final sdoc = view.document;
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-room')));
    await tester.pump();
    expect(status(tester), 'Room');
    final sdepth = sdoc.commands.undoDepth;
    await clickAt(tester, view, shell.at(18500.5, 9750.25));
    final kitchen = rooms(sdoc).single;
    expect(sdoc.commands.undoDepth, sdepth + 1);
    // The Kitchen: x 17,060-21,440, y 8,250-11,440: 4,380 × 3,190 =
    // 13,972,200 mm², 13.97 m² (0.0022 from a tie).
    expect(labelStrings(sdoc, kitchen), ['Room 1', '13.97 m²']);
    expect(status(tester), 'Room — Already a room: Room 1',
        reason: 'the tool stays active, over the face it just filled');
    await undoKey(tester);
    expect(rooms(sdoc), isEmpty);
    expect(status(tester), 'Room', reason: 'the face is free again');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
  });

  test(
      'TT2 the hover preview is the ring the room gets, bit for bit (the '
      'tied island of decision 29 included)', () {
    /// Hovers [seed] in [plan] with [rig]: the preview is the face with
    /// plan corners [ring] and [holes] (by hand); then clicks there, and
    /// the room's labels are [name] and [area], and its tint is the
    /// preview, bit for bit.
    void check(
        Plan plan,
        Rig rig,
        (double, double) seed,
        List<(double, double)> ring,
        List<List<(double, double)>> holes,
        String name,
        String area,
        String why) {
      final doc = plan.doc;
      final s = plan.at(seed.$1, seed.$2);
      hoverTo(rig, s);
      final preview = [for (final p in rig.tool.debugPreview) ringOf(p)];
      expect(preview, hasLength(1 + holes.length), reason: why);
      expectRing(plan, preview.first, ring, why);
      for (var k = 0; k < holes.length; k++) {
        expectRing(plan, preview[k + 1], holes[k], '$why: hole $k');
      }
      pressAt(rig, s);
      final room = rooms(doc).last;
      expect(labelStrings(doc, room), [name, area], reason: why);
      // The room's group is at the identity, so its tint stores each world
      // trace point q as `seed + (q − seed)` (its local frame is the
      // seed's): the preview mapped so is the tint's points.
      final tint = worldTintOf(doc, room);
      List<Vector2> stored(List<Vector2> r) => [for (final q in r) s + (q - s)];
      final outer = stored(preview.first);
      if (holes.isEmpty) {
        expect([
          for (final p in tint) (p.x, p.y)
        ], [
          for (final p in outer) (p.x, p.y)
        ], reason: '$why: the tint is the previewed ring');
        return;
      }
      // D9 step 1: the keyholed ring, the outer ring from its first point,
      // each hole walked in after a vertex, plus its two slit points.
      expect(
          tint,
          hasLength(outer.length +
              [for (final h in preview.skip(1)) h.length + 2]
                  .reduce((x, y) => x + y)),
          reason: why);
      var k = 0;
      for (final p in tint) {
        if (k < outer.length && p.x == outer[k].x && p.y == outer[k].y) k++;
      }
      expect(k, outer.length,
          reason: '$why: every outer point, in order, bit for bit');
      expect((tint.first.x, tint.first.y), (outer.first.x, outer.first.y));
      for (final h in preview.skip(1)) {
        for (final q in stored(h)) {
          expect(tint.any((p) => p.x == q.x && p.y == q.y), isTrue,
              reason: '$why: hole point $q');
        }
      }
    }

    for (final place in [origin, corpusGroups]) {
      // The box, the hollow column and the separator face to face at
      // x = 3,000: the left face has no hole, the right one the column. By
      // hand: the inner faces 100 in, the column's outer contour 4,950-
      // 5,650 × 1,450-2,150.
      final plan = boxAndSeparatorPlan(place);
      final doc = plan.doc;
      final rig = roomRig(doc);
      // 2,900 × 3,800 = 11,020,000: 11.02 m² (0.005 from a tie).
      check(
          plan,
          rig,
          (1500.25, 2000.5),
          const [(100, 100), (3000, 100), (3000, 3900), (100, 3900)],
          const [],
          'Room 1',
          '11.02 m²',
          'left, $place');
      // 4,900 × 3,800 − 700 × 700 = 18,130,000: 18.13 m² (0.005).
      check(
          plan,
          rig,
          (6500.75, 3000.25),
          const [(3000, 100), (7900, 100), (7900, 3900), (3000, 3900)],
          const [
            [(4950, 1450), (5650, 1450), (5650, 2150), (4950, 2150)],
          ],
          'Room 2',
          '18.13 m²',
          'right, $place');
      // The hollow column's courtyard lies in the right face's hole: not
      // that face, but a face of its own, 5,050-5,550 × 1,550-2,050.
      final traces = rig.tool.debugTraces;
      hoverTo(rig, plan.at(5300.25, 1800.5));
      expect(rig.tool.debugTraces, traces + 1,
          reason: 'not the cached face, $place');
      expectRing(
          plan,
          ringOf(rig.tool.debugPreview.single),
          const [(5050, 1550), (5550, 1550), (5550, 2050), (5050, 2050)],
          'the courtyard, $place');
      hoverTo(rig, plan.at(1700.5, 1200.25));
      expect(rig.tool.debugPreview, isEmpty, reason: 'occupied now');
      expect(driftOf(doc), isEmpty);

      // Decision 29's tied island: a 400 × 400 column, x 5,000-5,400, y
      // 1,800-2,200, tied to the south face by a separator. The tie's
      // doubled edges split out: the column is a hole and the room keeps
      // its fill. 7,800 × 3,800 − 400 × 400 = 29,480,000: 29.48 m² (0.005
      // from a tie).
      final tied = buildPlan([...boxWalls, tiedColumn],
          seps: const [tiedSeparator], place: place);
      check(
          tied,
          roomRig(tied.doc),
          (6500.75, 3000.25),
          const [(100, 100), (7900, 100), (7900, 3900), (100, 3900)],
          const [
            [(5000, 1800), (5400, 1800), (5400, 2200), (5000, 2200)],
          ],
          'Room 1',
          '29.48 m²',
          'the tied island, $place');
      expect(driftOf(tied.doc), isEmpty);
    }
  });

  test('TT3 no room in a band, in an unbounded face or in an occupied face',
      () {
    for (final place in [origin, corpusGroups]) {
      final plan = buildPlan(boxWalls, place: place);
      final doc = plan.doc;
      // Two rooms in the box's one face: Pantry, the lower handle, in a
      // turned, translated group whose local seed lies outside the face,
      // then Kitchen.
      final at =
          Transform2.translation(plan.at(-9000, 500).x, plan.at(-9000, 500).y)
              .multiply(Transform2.rotation(1.1));
      final pantry = addRoom(doc, plan.at(6200.5, 3100.25), 'Pantry', at: at);
      final local = doc.components.get<RoomParams>(pantry)!.seed;
      expect(faceAt(doc, local), isNot(isA<Traced>()),
          reason: 'premise: the local seed is outside the face, $place');
      addRoom(doc, plan.at(1500.25, 2000.5), 'Kitchen');
      final rig = roomRig(doc);
      final before = rooms(doc);
      for (final (what, (x, y), notice) in [
        ('in the south wall\'s band', (4000.5, 30.25), null),
        ('outside the box', (-2000.5, 2000.25), null),
        ('in the occupied face', (6000.75, 1200.5), 'Already a room: Pantry'),
      ]) {
        final why = '$what, $place';
        final p = plan.at(x, y);
        final depth = doc.commands.undoDepth;
        hoverTo(rig, p);
        expect(rig.tool.debugPreview, isEmpty, reason: '$why: no preview');
        expect(rig.tool.notice.value, notice, reason: why);
        pressAt(rig, p);
        expect(doc.commands.undoDepth, depth, reason: '$why: no command');
        expect(rooms(doc), before, reason: '$why: no room');
        expect(rig.tool.debugPreview, isEmpty, reason: why);
        expect(rig.tool.notice.value, notice, reason: '$why, after a click');
      }

      // An edit in the same task as the click, its change not yet
      // delivered: a hover caches the free face, a room lands in it, and
      // the click still finds the face occupied.
      final free = buildPlan(boxWalls, place: place);
      final frig = roomRig(free.doc);
      final q = free.at(4100.5, 2900.25);
      hoverTo(frig, q);
      expect(frig.tool.debugPreview, hasLength(1), reason: 'premise: free');
      addRoom(free.doc, free.at(1200.25, 900.5), 'Study');
      final fdepth = free.doc.commands.undoDepth;
      pressAt(frig, q);
      expect(free.doc.commands.undoDepth, fdepth,
          reason: 'a same-task edit, $place');
      expect(frig.tool.notice.value, 'Already a room: Study');
    }
  });

  test('TT4 a new room takes the lowest unused Room N', () {
    final plan = samplePlan(corpusGroups);
    final doc = plan.doc;
    Vector2 at(String name) {
      final (x, y) = sampleSeeds[name]!;
      return plan.at(x, y);
    }

    addRoom(doc, at('Hall'), 'Room 1');
    addRoom(doc, at('Bedroom 1'), 'Room 3');
    addRoom(doc, at('Kitchen'), 'Kitchen');
    // Names that are not exactly `Room N`: none of them takes an N.
    addRoom(doc, at('Bedroom 2'), 'Room 02');
    addRoom(doc, at('Dining'), 'Room 2 ');
    final rig = roomRig(doc);
    var before = rooms(doc);
    pressAt(rig, at('Bath'));
    final bath = addedRoom(doc, before);
    expect(doc.components.get<RoomParams>(bath)!.name, 'Room 2');
    before = rooms(doc);
    pressAt(rig, at('Living'));
    final living = addedRoom(doc, before);
    expect(doc.components.get<RoomParams>(living)!.name, 'Room 4');
    expect(driftOf(doc), isEmpty);
  });

  test('TT5 the seed is the raw point with object snap on beside a vertex', () {
    // At 0.25 px/mm the aperture is 40 mm; the raw point lies 30 mm from
    // the box's south-west inner corner, inside the room.
    final plan = buildPlan(boxWalls, place: corpusGroups);
    final doc = plan.doc;
    final rig = roomRig(doc, scale: 0.25);
    final corner = plan.at(100, 100);
    final raw = plan.at(100 + 21.2132034356, 100 + 21.2132034356);
    expect((raw - corner).length, closeTo(30, 1e-6));
    hoverTo(rig, raw);
    expect((rig.tool.hoverPoint - corner).length, lessThan(1e-6),
        reason: 'premise: the chain snaps to the face vertex');
    expect(faceAt(doc, rig.tool.hoverPoint), isA<SeedInWall>(),
        reason: 'premise: a seed there would be in a wall');
    // No snap marker: the seed is not snapped (the plain, no-snap glyph).
    final spy = CanvasSpy();
    rig.tool.paintOverlay(
        spy, rig.ctx.camera.value, const Size(800, 600), PaperPalette.light);
    expect(spy.calls, isEmpty, reason: 'no snap marker drawn');
    pressAt(rig, raw);
    final room = rooms(doc).single;
    final p = doc.components.get<RoomParams>(room)!;
    expect((p.seedX, p.seedY), (raw.x, raw.y), reason: 'the raw point');
    expect(labelStrings(doc, room), ['Room 1', '29.64 m²'],
        reason: 'the room lives: 7,800 × 3,800');
    expect(driftOf(doc), isEmpty);
  });

  test(
      'TT6 steady hovers re-trace nothing; outside the bounding box of every '
      'place box nothing is traced; the Kitchen seed, outside every place box '
      'but inside that box, is traced and previewed; a band\'s verdict is '
      'reused; an Unbounded hover at 600 walls is timed', () async {
    final plan = samplePlan(origin);
    final doc = plan.doc;
    final rig = roomRig(doc);
    final tool = rig.tool;
    ({int segments, int traces, int previews}) counters() => (
          segments: debugTracedSegments,
          traces: tool.debugTraces,
          previews: tool.debugPreviewBuilds,
        );

    // First, on a fresh generation, outside the bounding box of every
    // place box: nothing traced, and no outer contour built either. The box
    // test answers before the contour cache (spec 10 D19), which would
    // otherwise answer the same verdict only after building every
    // component's contour (M-10hover, Task 19: the contour cache masked it
    // once any hover had built the contours).
    const outside = [
      (11000.5, 12000.25),
      (19000.25, 7000.5),
      (27000.75, 16000.5),
      (19000.5, 18000.25),
    ];
    final fresh = counters();
    for (final (x, y) in outside) {
      final p = plan.at(x, y);
      expect(rig.inputs.bounds!.containsPoint(p), isFalse,
          reason: 'premise: ($x, $y) outside the bounding box');
      hoverTo(rig, p);
      expect(tool.debugPreview, isEmpty);
    }
    expect((counters(), tool.debugContourBuilds), (fresh, 0),
        reason: 'outside the box on a fresh generation: no trace, no '
            'contour');

    // The Kitchen seed, (19,000, 10,000): outside every place box (T-1: E1
    // reaches y 8,250, P3 starts at y 11,440, P1 ends at x 17,060, P5
    // starts at x 21,440), inside their bounding box.
    final kitchen = plan.at(19000, 10000);
    expect(
        rig.inputs
            .placedIn(Aabb2.raw(kitchen.x, kitchen.y, kitchen.x, kitchen.y)),
        isEmpty,
        reason: 'premise: outside every place box');
    expect(rig.inputs.bounds!.containsPoint(kitchen), isTrue,
        reason: 'premise: inside their bounding box');
    var c = counters();
    hoverTo(rig, kitchen);
    expect(debugTracedSegments, greaterThan(c.segments), reason: 'traced');
    expect(tool.debugPreviewBuilds, c.previews + 1, reason: 'previewed');
    expect(tool.debugPreview, hasLength(1));
    // The Kitchen: x 17,060-21,440 (P1's east face, P5's west face), y
    // 8,250-11,440 (E1's inner face, P3's south face).
    expectRing(
        plan,
        ringOf(tool.debugPreview.single),
        const [
          (17060, 8250),
          (21440, 8250),
          (21440, 11440),
          (17060, 11440),
        ],
        'the Kitchen');

    // Fifty hovers across the Kitchen: nothing traced, nothing built.
    c = counters();
    for (var i = 0; i < 50; i++) {
      hoverTo(rig, plan.at(17100.5 + 86.25 * i, 8300.25 + 61.5 * i));
      expect(tool.debugPreview, hasLength(1));
    }
    expect(counters(), c, reason: 'steady hovers in one face');

    // Outside the bounding box of every place box: nothing traced, no
    // preview.
    for (final (x, y) in outside) {
      hoverTo(rig, plan.at(x, y));
      expect(tool.debugPreview, isEmpty);
      expect(counters(), c, reason: 'outside the box, ($x, $y)');
    }

    // Inside E1's band: traced once, then reused while the pointer stays
    // in the band.
    hoverTo(rig, plan.at(15000.5, 8030.25));
    expect(tool.debugTraces, c.traces + 1, reason: 'the first band hover');
    expect(tool.debugPreview, isEmpty);
    c = counters();
    for (var i = 0; i < 20; i++) {
      hoverTo(rig, plan.at(14000.5 + 301.25 * i, 8010.25 + 10.5 * i));
    }
    expect(counters(), c, reason: 'the band\'s verdict reused');

    // Back in the Kitchen: its face is still cached.
    hoverTo(rig, plan.at(20000.5, 11000.25));
    expect(counters(), c);
    expect(tool.debugPreview, hasLength(1));

    // P5 moved 300.5 east: the cache is dropped on the document's change
    // (X15-stale), and the same pointer previews the wider Kitchen.
    doc.commands.execute(
        moveWall(plan, 8, const W(21800.5, 8125, 21800.5, 11500, 120)));
    await Future<void>.delayed(Duration.zero);
    hoverTo(rig, plan.at(20000.5, 11000.25));
    expect(tool.debugTraces, c.traces + 1, reason: 're-traced after the edit');
    expect(tool.debugPreviewBuilds, c.previews + 1);
    expectRing(
        plan,
        ringOf(tool.debugPreview.single),
        const [
          (17060, 8250),
          (21740.5, 8250),
          (21740.5, 11440),
          (17060, 11440),
        ],
        'the wider Kitchen');

    // Outside the building but inside the bounding box, among 600 walls
    // (07's WT12 method, timed, printed): the outer contours of every
    // component are built once, on the first such hover, and then answer
    // without a trace (the re-review's T-8 cache).
    // - a courtyard among 600 free walls: no wall meets another, so no
    //   face is bounded;
    // - the reviewer's connected plan: 15 × 20 cells of 3,000 mm, every
    //   cell edge a wall, and a garden wall 6,000 mm east of it; the point
    //   lies in the strip between.
    for (final (what, walls, (px, py)) in [
      (
        'a courtyard among 600 free walls',
        [
          for (var i = 0; i < 30; i++)
            for (var j = 0; j < 20; j++)
              W(i * 3000.0, j * 3000.0, i * 3000.0 + 1000, j * 3000.0, 200),
        ],
        (1500.5, 1500.25),
      ),
      (
        'outside a connected 636-wall plan',
        connectedGrid(15, 20),
        (48000.5, 30000.25)
      ),
    ]) {
      final grid = buildPlan(walls, place: corpus);
      final big = roomRig(grid.doc);
      final p = grid.at(px, py);
      expect(big.inputs.bounds!.containsPoint(p), isTrue,
          reason: 'premise: inside the bounding box, $what');
      expect(faceAt(grid.doc, p), isA<Unbounded>(),
          reason: 'premise: Unbounded, $what');
      final builds = big.tool.debugContourBuilds;
      final traces = big.tool.debugTraces;
      final segments = debugTracedSegments;
      final first = Stopwatch()..start();
      hoverTo(big, p);
      final build = first.elapsedMicroseconds;
      hoverTo(big, p);
      expect(big.tool.debugContourBuilds, builds + 1, reason: 'built once');
      expect((big.tool.debugTraces, debugTracedSegments), (traces, segments),
          reason: 'no trace, $what');
      expect(big.tool.debugPreview, isEmpty, reason: 'Unbounded, $what');
      final hover = <double>[];
      const batch = 50;
      for (var k = 0; k < 20; k++) {
        final sw = Stopwatch()..start();
        for (var i = 0; i < batch; i++) {
          hoverTo(big, p);
        }
        hover.add(sw.elapsedMicroseconds / batch);
      }
      expect((big.tool.debugTraces, big.tool.debugContourBuilds),
          (traces, builds + 1));
      hover.sort();
      // ignore: avoid_print
      print('TT6 ${walls.length} walls, $what: median per Unbounded hover '
          '${hover[hover.length ~/ 2].toStringAsFixed(1)} us; the first, '
          'which builds the contours, $build us');
    }
  });

  testWidgets(
      'TT7 a click in an occupied face places nothing and the status line '
      'says so; hovering there shows it; it clears on leaving the face and '
      'on deactivation', (tester) async {
    final plan = shellSamplePlan();
    addRoom(plan.doc, plan.at(19000, 10000), 'Kitchen');
    final view = await pumpPlan(tester, plan);
    final doc = view.document;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    Future<void> hover(double x, double y) async {
      await mouse.moveTo(screenOf(tester, view, plan.at(x, y)));
      await tester.pump();
    }

    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
    await hover(20500.5, 9000.25);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'hovering the occupied face');
    final before = rooms(doc);
    final depth = doc.commands.undoDepth;
    await clickAt(tester, view, plan.at(18200.5, 10800.25));
    expect(rooms(doc), before, reason: 'nothing placed');
    expect(doc.commands.undoDepth, depth);
    expect(status(tester), 'Room — Already a room: Kitchen',
        reason: 'after a click there');
    // The Bath: a face with no room.
    await hover(23500.5, 10000.25);
    expect(status(tester), 'Room', reason: 'cleared on leaving the face');
    await hover(19000.5, 10500.25);
    expect(status(tester), 'Room — Already a room: Kitchen');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select', reason: 'cleared on deactivation');
    expect(shellRoomTool(tester).notice.value, isNull);
    await press(tester, LogicalKeyboardKey.keyM);
    expect(status(tester), 'Room');
  });

  test(
      'TT8 the outer-contour cache answers every hover as the trace does, at '
      'every placement; a change drops it', () async {
    for (final place in placements) {
      for (final (what, plan, (x0, y0), (x1, y1), exterior) in [
        (
          'the sample plan',
          samplePlan(place),
          (11800.0, 7800.0),
          (26200.0, 17200.0),
          false
        ),
        (
          'the box, the hollow column and the separator',
          boxAndSeparatorPlan(place),
          (-150.0, -150.0),
          (8150.0, 4150.0),
          false
        ),
        (
          'the L',
          buildPlan(lWalls, place: place),
          (-150.0, -150.0),
          (6150.0, 5150.0),
          true
        ),
        (
          'a connected 4 × 3 grid and a garden wall',
          buildPlan(connectedGrid(4, 3), place: place),
          (-150.0, -150.0),
          (18150.0, 9150.0),
          true
        ),
      ]) {
        final why = '$what, $place';
        final rig = roomRig(plan.doc);
        var answered = 0, faces = 0;
        const n = 36;
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            final p = plan.at(x0 + (x1 - x0) * (i + 0.37) / n,
                y0 + (y1 - y0) * (j + 0.61) / n);
            final traces = rig.tool.debugTraces;
            hoverTo(rig, p);
            final want = traceRoomAmong(p, rig.inputs);
            final preview = [for (final q in rig.tool.debugPreview) ringOf(q)];
            if (want is Traced) {
              faces++;
              expect(preview, hasLength(1 + want.holes.length),
                  reason: '$why: $p');
              expectSameRing(preview.first, want.ring, '$why: $p');
              for (var k = 0; k < want.holes.length; k++) {
                expectSameRing(preview[k + 1], want.holes[k], '$why: $p');
              }
            } else {
              expect(preview, isEmpty, reason: '$why: $p is $want');
              if (want is Unbounded &&
                  rig.inputs.bounds!.containsPoint(p) &&
                  rig.tool.debugTraces == traces) {
                answered++;
              }
            }
          }
        }
        expect(rig.tool.debugContourBuilds, lessThanOrEqualTo(1), reason: why);
        expect(faces, greaterThan(0), reason: why);
        // ignore: avoid_print
        print('TT8 $why: $faces faces, $answered hovers answered by the '
            'contours');
        if (exterior) {
          expect(answered, greaterThan(0),
              reason: '$why: the cache answered hovers outside the building');
        }
      }
    }

    // The connected grid's strip closed by two walls: the cache is dropped
    // on the change, and the strip, x 12,100-17,900, y 100-8,900, is a face.
    final plan = buildPlan(connectedGrid(4, 3), place: corpusGroups);
    final rig = roomRig(plan.doc);
    final p = plan.at(15000.5, 4500.25);
    hoverTo(rig, p);
    expect(rig.tool.debugPreview, isEmpty, reason: 'premise: outside');
    expect(rig.tool.debugContourBuilds, 1);
    for (final w in const [
      W(12000, 0, 18000, 0, 200),
      W(12000, 9000, 18000, 9000, 200),
    ]) {
      final h = plan.doc.handleSeed.next();
      final t = Transform2.identity();
      final s = plan.at(w.sx, w.sy), e = plan.at(w.ex, w.ey);
      plan.doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: h,
            parent: plan.doc.rootHandle,
            transform: t,
            children: const [])),
        SetComponentCommand<WallParams>(
            h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
      ], label: 'Add wall'));
    }
    await Future<void>.delayed(Duration.zero);
    hoverTo(rig, p);
    expect(rig.tool.debugContourBuilds, 2, reason: 'rebuilt after the change');
    expectRing(
        plan,
        ringOf(rig.tool.debugPreview.single),
        const [(12100, 100), (17900, 100), (17900, 8900), (12100, 8900)],
        'the closed strip');
  });

  test(
      'TT9 a click and the re-read after a document change build no outer '
      'contours: a click needs only the trace (Task 15\'s review)', () async {
    for (final place in [origin, corpusGroups]) {
      final plan = samplePlan(place);
      final doc = plan.doc;
      final rig = roomRig(doc);
      final tool = rig.tool;
      final kitchen = plan.at(19000.5, 10000.25);
      hoverTo(rig, kitchen);
      final builds = tool.debugContourBuilds;
      expect(builds, 1, reason: 'premise: the hover built them, $place');
      expect(tool.debugPreview, hasLength(1), reason: 'premise, $place');

      // The click: invalidated inputs, a trace, the commit, the re-read.
      final traces = tool.debugTraces;
      pressAt(rig, kitchen);
      expect(rooms(doc), hasLength(1), reason: 'placed, $place');
      expect(tool.debugTraces, greaterThan(traces), reason: 'traced, $place');
      expect(tool.notice.value, 'Already a room: Room 1');
      expect(tool.debugContourBuilds, builds, reason: 'the click, $place');
      // The change listener re-reads the notice's face.
      await Future<void>.delayed(Duration.zero);
      expect(tool.notice.value, 'Already a room: Room 1');
      expect(tool.debugContourBuilds, builds,
          reason: 'the listener\'s re-read, $place');
      // An undo: the listener re-reads to a free face, and shows it.
      doc.commands.undo();
      await Future<void>.delayed(Duration.zero);
      expect(tool.notice.value, isNull, reason: 'the re-read ran, $place');
      expect(tool.debugPreview, hasLength(1), reason: 'free again, $place');
      expect(tool.debugContourBuilds, builds,
          reason: 'the listener\'s re-read after undo, $place');

      // The control: a hover in another face still takes the contour step,
      // once per generation.
      hoverTo(rig, plan.at(24500.5, 16000.25));
      expect(tool.debugContourBuilds, builds + 1,
          reason: 'a hover builds them, $place');
    }
  });

  test(
      'TT10 (fix/live-object-rule, the L2 review\'s m2) a file\'s dimension '
      'group carrying RoomParams is no room: its seed does not occupy the '
      'face, and its `Room N` name is not taken', () {
    for (final place in [origin, corpusGroups]) {
      final plan = buildPlan(boxWalls, place: place);
      final doc = plan.doc;
      // Two dimensions, each made as the app makes one (regenerated through
      // the dispatcher) in a turned, translated root-level group, then
      // given `RoomParams` straight through the store, as a file brings it
      // in. Dimension is registered after Room, so each is a dimension.
      Handle dimension(Transform2 at, Vector2 a, Vector2 b) {
        final h = doc.handleSeed.next();
        final toLocal = at.invert();
        final la = toLocal.transformPoint(a), lb = toLocal.transformPoint(b);
        doc.commands.execute(CompoundCommand([
          AddNodeCommand(GroupNode(
              handle: h,
              parent: doc.rootHandle,
              transform: at,
              children: const [])),
          SetComponentCommand<DimensionParams>(
              h,
              DimensionParams(FixedEnd(la.x, la.y), FixedEnd(lb.x, lb.y),
                  DimKind.aligned, 420.25)),
        ], label: 'Add dimension'));
        return h;
      }

      final atIn = Transform2.translation(
              plan.at(-7000.5, 900.25).x, plan.at(-7000.5, 900.25).y)
          .multiply(Transform2.rotation(0.8));
      final inFace =
          dimension(atIn, plan.at(1000.5, 5000.25), plan.at(6500.75, 5000.25));
      final atOut = Transform2.translation(
              plan.at(12000.25, -3000.5).x, plan.at(12000.25, -3000.5).y)
          .multiply(Transform2.rotation(-1.2));
      final outside =
          dimension(atOut, plan.at(9500.5, -1500.25), plan.at(9500.5, 3500.75));
      // [inFace]'s seed lies in the box's one face in world (its local
      // seed does not); [outside]'s lies outside the box, and it is named
      // `Room 1`.
      final seedIn = plan.at(5200.25, 2700.5);
      final seedOut = plan.at(-2500.75, 1800.25);
      final localIn = atIn.invert().transformPoint(seedIn);
      final localOut = atOut.invert().transformPoint(seedOut);
      doc.components
        ..attach<RoomParams>(inFace, RoomParams(localIn.x, localIn.y, 'Den'))
        ..attach<RoomParams>(
            outside, RoomParams(localOut.x, localOut.y, 'Room 1'));
      for (final h in [inFace, outside]) {
        expect(kids(doc, h), isNotEmpty,
            reason: 'premise: regenerated as a dimension, $place');
        expect(isLiveObject<DimensionParams>(doc, h), isTrue, reason: '$place');
        expect(doc.tree[h]!.parent, doc.rootHandle,
            reason: 'premise: a root-level group, $place');
      }
      expect(faceAt(doc, seedIn), isA<Traced>(),
          reason: 'premise: the world seed is in the face, $place');
      expect(faceAt(doc, localIn), isNot(isA<Traced>()),
          reason: 'premise: the local seed is not, $place');
      expect(faceAt(doc, seedOut), isNot(isA<Traced>()), reason: '$place');
      expect(rooms(doc), isEmpty, reason: 'no live room, $place');

      final rig = roomRig(doc);
      final p = plan.at(2100.5, 1300.75);
      hoverTo(rig, p);
      expect(rig.tool.notice.value, isNull, reason: 'the face is free, $place');
      expect(rig.tool.debugPreview, hasLength(1), reason: '$place');
      final depth = doc.commands.undoDepth;
      pressAt(rig, p);
      expect(doc.commands.undoDepth, depth + 1, reason: 'one step, $place');
      final room = rooms(doc).single;
      expect(
          doc.components.get<RoomParams>(room), RoomParams(p.x, p.y, 'Room 1'),
          reason: 'Room 1 is free: no live room holds it, $place');
      expect(rig.tool.notice.value, 'Already a room: Room 1',
          reason: 'control: a live room occupies the face, $place');
    }
  });

  testWidgets(
      'SG1 M and S typed into a text entry switch no tool (the shell\'s '
      'guard, X15-guardMS)', (tester) async {
    final plan = buildPlan(boxWalls, measurer: FlutterTextMeasurer());
    final view = await pumpPlan(tester, plan);
    await press(tester, LogicalKeyboardKey.keyT);
    expect(status(tester), 'Text');
    final s = view.camera.value.worldToScreen(Vector2(2000.5, 2000.25));
    await tester.tapAt(
        tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
    await tester.pump();
    expect(find.byKey(const Key('text-entry')), findsOneWidget);
    for (final k in [LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyS]) {
      await press(tester, k);
      expect(status(tester), 'Text', reason: '$k switched no tool');
      expect(find.byKey(const Key('text-entry')), findsOneWidget);
    }
  });
}

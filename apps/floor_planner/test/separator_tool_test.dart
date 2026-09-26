// Spec 10 D20: the Separator tool (S). Two clicks place one separator, one
// undo step, its group at the identity and its ends the resolved points;
// the tool is not chained. With object snap on (F3), an end inside a wall's
// uncut band is trimmed back to the face the segment enters it by; with it
// off, the ends are stored as placed. Both ends in one band, or a trimmed
// length within `roomTrace.linear`, place nothing. A new separator splits
// its room.
//
// Expected areas are hand arithmetic next to the assertion; every expected
// label string is at least 0.0005 m² from a rounding tie. Points are
// fractional; the relational cases run at the origin and at the corpus far
// origin with every wall in its own rotated group.
import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart';
import 'package:floor_planner/parametric/room_trace.dart';
import 'package:floor_planner/parametric/separator.dart';
import 'package:floor_planner/parametric/separator_tool.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/room_fixture.dart';

typedef Rig = ({SeparatorTool tool, ToolContext ctx, RoomInputs inputs});

/// A Separator tool over [doc] with its own [RoomInputs]: a camera at 1
/// pixel per mm (a 10 mm aperture), object snap as [objectSnap] says, no
/// page (no grid).
Rig separatorRig(DraftDocument doc, {bool objectSnap = true}) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final snap = SnapSettings(objectSnap: objectSnap);
  final inputs = RoomInputs(doc);
  final tool = SeparatorTool(inputs);
  addTearDown(() {
    tool.dispose();
    inputs.dispose();
    snap.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc,
        index: index,
        camera: camera,
        selection: selection,
        snap: snap),
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

/// Every live separator, ascending.
List<Handle> separators(DraftDocument doc) =>
    liveObjectsOf<SeparatorParams>(doc);

/// Every live room, ascending.
List<Handle> rooms(DraftDocument doc) => liveObjectsOf<RoomParams>(doc);

/// The distance from [p] to the line through [a] and [b], relative to [a].
double distToLine(Vector2 p, Vector2 a, Vector2 b) {
  final d = b - a, q = p - a;
  return (q.x * d.y - q.y * d.x).abs() / d.length;
}

/// The edge of wall [wall]'s band (its room input) nearest [p], as its two
/// world points: the face [p] was trimmed to.
(Vector2, Vector2) faceNear(RoomInputs inputs, Handle wall, Vector2 p) {
  final pts = inputs.inputOf(wall)!.points;
  (Vector2, Vector2)? best;
  var bestD = double.infinity;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i], b = pts[(i + 1) % pts.length];
    final d = distToSegment(p, a, b);
    if (d < bestD) {
      bestD = d;
      best = (a, b);
    }
  }
  return best!;
}

/// Places a separator from [a] to [b] with [rig]: two presses, hovering to
/// each first.
void draw(Rig rig, Vector2 a, Vector2 b) {
  hoverTo(rig, a);
  pressAt(rig, a);
  hoverTo(rig, b);
  pressAt(rig, b);
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  testWidgets('ST1 S places one separator in two clicks, one undo step',
      (tester) async {
    // The box at the corpus far origin in own groups; a LINE whose end lies
    // 4 mm from the first click, so that click resolves to it.
    final plan = buildPlan(boxWalls, place: corpusGroups);
    final doc = plan.doc;
    final tick = plan.at(1700.25, 1300.5);
    doc.commands.execute(addDrafted(
        doc, EntityKind.line, linePayload(tick, plan.at(1400.25, 900.5))));
    final rig = separatorRig(doc);
    final tool = rig.tool;
    final first = plan.at(1702.75, 1303.625);
    final second = plan.at(5812.375, 2716.125);
    hoverTo(rig, first);
    expect((tool.hoverPoint.x, tool.hoverPoint.y), (tick.x, tick.y),
        reason: 'premise: the first click resolves to the LINE\'s end');
    pressAt(rig, first);
    expect(tool.isPending, isTrue);
    expect(separators(doc), isEmpty, reason: 'one click places nothing');
    hoverTo(rig, second);
    expect((tool.hoverPoint.x, tool.hoverPoint.y), (second.x, second.y),
        reason: 'premise: nothing within the aperture of the second');
    final band = tool.debugBand!;
    expect([
      band.$1.x,
      band.$1.y,
      band.$2.x,
      band.$2.y
    ], [
      tick.x,
      tick.y,
      second.x,
      second.y
    ], reason: 'the rubber band, as it would be stored');
    final depth = doc.commands.undoDepth;
    pressAt(rig, second);
    final s = separators(doc).single;
    expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
    expect((doc.tree[s]! as GroupNode).transform.isIdentity, isTrue,
        reason: 'its group at the identity');
    expect(doc.components.get<SeparatorParams>(s),
        SeparatorParams(tick.x, tick.y, second.x, second.y),
        reason: 'the resolved points, both in open space');
    expect(kindsOf(doc, s), [EntityKind.polyline]);
    expect(tool.isPending, isFalse, reason: 'not chained');
    expect(tool.debugBand, isNull);
    // A third click starts a new separator and places nothing.
    pressAt(rig, plan.at(6100.5, 3000.25));
    expect(tool.isPending, isTrue);
    expect(separators(doc), [s]);
    doc.commands.undo();
    expect(separators(doc), isEmpty, reason: 'one undo takes it away');
    expect(driftOf(doc), isEmpty);

    // The shell: S and the palette entry activate it; Esc cancels a
    // pending start, then returns to Select.
    final shell = buildPlan(boxWalls, measurer: FlutterTextMeasurer());
    shell.system.dispose();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester
        .pumpWidget(MaterialApp(home: PlannerShell(document: shell.doc)));
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    await press(tester, LogicalKeyboardKey.keyS);
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-separator')));
    await tester.pump();
    expect(status(tester), 'Separator');
    final sep = view.tools.active as SeparatorTool;
    final p = view.camera.value.worldToScreen(Vector2(2500.5, 2000.25));
    await tester.tapAt(
        tester.getTopLeft(find.byType(InteractionLayer)) + Offset(p.x, p.y));
    await tester.pump();
    expect(sep.isPending, isTrue);
    await press(tester, LogicalKeyboardKey.escape);
    expect(sep.isPending, isFalse, reason: 'the pending start cancelled');
    expect(status(tester), 'Separator');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    expect(separators(shell.doc), isEmpty);
  });

  test(
      'ST2 an end inside a band is trimmed to the face with object snap on, '
      'and kept as placed with it off', () {
    for (final place in [origin, corpusGroups]) {
      // Walls 0-3: south, east, north, west; inner faces 100 in.
      for (final (what, a, b, trimA, trimB) in [
        // Centreline to centreline: both ends trimmed, to y 100 and 3,900.
        ('across', (3000.5, 0.25), (3000.5, 3999.75), 0, 2),
        // From open space into the east wall's band: that end trimmed to
        // x 7,900, the other kept.
        ('into the east wall', (5000.25, 2000.5), (8030.5, 2500.75), null, 1),
      ]) {
        final why = '$what, $place';
        final pa = place.at(a.$1, a.$2), pb = place.at(b.$1, b.$2);
        for (final snap in [true, false]) {
          final plan = buildPlan(boxWalls, place: place);
          final doc = plan.doc;
          final rig = separatorRig(doc, objectSnap: snap);
          draw(rig, pa, pb);
          final p =
              doc.components.get<SeparatorParams>(separators(doc).single)!;
          if (!snap) {
            expect(p, SeparatorParams(pa.x, pa.y, pb.x, pb.y),
                reason: '$why, F3 off: as placed');
            continue;
          }
          for (final (end, placed, wall) in [
            (p.start, pa, trimA),
            (p.end, pb, trimB),
          ]) {
            if (wall == null) {
              expect((end.x, end.y), (placed.x, placed.y),
                  reason: '$why: an end in open space stays');
              continue;
            }
            final (f1, f2) = faceNear(rig.inputs, plan.walls[wall], end);
            expect(distToLine(end, f1, f2), lessThan(1e-8),
                reason: '$why: on the face');
            expect(distToLine(end, pa, pb), lessThan(1e-8),
                reason: '$why: on the drawn segment');
            // The face by hand: 100 in from the wall's centreline.
            final (h1, h2) = switch (wall) {
              0 => (place.at(0, 100), place.at(8000, 100)),
              1 => (place.at(7900, 0), place.at(7900, 4000)),
              _ => (place.at(0, 3900), place.at(8000, 3900)),
            };
            expect(distToLine(end, h1, h2), lessThan(1e-6),
                reason: '$why: the inner face');
            expect((end - placed).length, greaterThan(20),
                reason: '$why: moved out of the band');
          }
          expect(driftOf(doc), isEmpty);
        }
      }

      // A wall added in the same task as the second click, its change not
      // yet delivered: the click still trims to its face, y 1,900.
      final plan = buildPlan(boxWalls, place: place);
      final doc = plan.doc;
      final rig = separatorRig(doc);
      final pa = place.at(3000.5, 1000.25), pb = place.at(3000.5, 2030.5);
      hoverTo(rig, pa);
      pressAt(rig, pa);
      hoverTo(rig, pb);
      final mid = doc.handleSeed.next();
      final ms = place.at(0, 2000), me = place.at(8000, 2000);
      doc.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: mid,
            parent: doc.rootHandle,
            transform: Transform2.identity(),
            children: const [])),
        SetComponentCommand<WallParams>(
            mid, WallParams(ms.x, ms.y, me.x, me.y, 200, Justification.centre)),
      ], label: 'Add wall'));
      pressAt(rig, pb);
      final end =
          doc.components.get<SeparatorParams>(separators(doc).single)!.end;
      expect(distToLine(end, place.at(0, 1900), place.at(8000, 1900)),
          lessThan(1e-6),
          reason: 'trimmed to the new wall\'s face, $place');
    }
  });

  test(
      'ST3 both ends in one band, or a trimmed length within the tolerance, '
      'places nothing', () {
    final plan = buildPlan(boxWalls);
    final doc = plan.doc;
    for (final (what, a, b, snap) in [
      // Both ends in the south wall's band (y -100..100).
      (
        'both in one band',
        Vector2(1500.25, -40.5),
        Vector2(6500.75, 60.25),
        true
      ),
      // From inside the band to 5e-7 mm above its inner face: trimmed to
      // the face, 5e-7 long.
      (
        'trimmed too short',
        Vector2(4000.5, 50.25),
        Vector2(4000.5, 100.0000005),
        true
      ),
      // Placed 5e-7 mm long, F3 off.
      (
        'placed too short',
        Vector2(4000.5, 2000.25),
        Vector2(4000.5, 2000.2500005),
        false
      ),
    ]) {
      final rig = separatorRig(doc, objectSnap: snap);
      final depth = doc.commands.undoDepth;
      draw(rig, a, b);
      expect(rig.tool.debugBand, isNull, reason: '$what: no rubber band');
      expect(separators(doc), isEmpty, reason: what);
      expect(doc.commands.undoDepth, depth, reason: what);
      expect(rig.tool.isPending, isTrue, reason: '$what: the start stays');
      expect(trimSeparator(a, b, rig.inputs, objectSnap: snap), isNull,
          reason: what);
    }
  });

  test('ST4 a new separator splits its room: one side keeps the room', () {
    for (final place in [origin, corpusGroups]) {
      for (final snap in [true, false]) {
        final why = '$place, F3 ${snap ? 'on' : 'off'}';
        final plan = buildPlan(boxWalls, place: place);
        final doc = plan.doc;
        attachPage(doc, PageComponent());
        final room = addRoom(doc, plan.at(1500.25, 2000.5), 'Room 1');
        // Inner faces 100 in: 7,800 × 3,800 = 29,640,000, 29.64 m² (0.005
        // from a tie).
        expect(labelStrings(doc, room), ['Room 1', '29.64 m²'], reason: why);
        final rig = separatorRig(doc, objectSnap: snap);
        final depth = doc.commands.undoDepth;
        draw(rig, plan.at(3000.5, 0.25), plan.at(3000.5, 3999.75));
        expect(doc.commands.undoDepth, depth + 1, reason: why);
        // Left of x = 3,000.5: 2,900.5 × 3,800 = 11,021,900, 11.02 m²
        // (0.0031 from a tie).
        final left = faceAt(doc, plan.at(1500.25, 2000.5)) as Traced;
        expect(left.area, closeTo(11021900, 1e-2), reason: why);
        expect(labelStrings(doc, room), ['Room 1', '11.02 m²'], reason: why);
        // Right: 4,899.5 × 3,800 = 18,618,100, and no room's seed in it.
        final right = faceAt(doc, plan.at(6000.5, 2000.25)) as Traced;
        expect(right.area, closeTo(18618100, 1e-2), reason: why);
        expect(rooms(doc), [room], reason: '$why: the other side has none');
        expect(driftOf(doc), isEmpty);
        doc.commands.undo();
        expect(labelStrings(doc, room), ['Room 1', '29.64 m²'], reason: why);
      }
    }
  });
}

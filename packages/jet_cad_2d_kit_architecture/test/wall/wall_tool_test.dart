// Ported from jet_cad_floor_plan/test/wall_tool_test.dart (3a Task 12):
// the cases that drive the Wall tool directly (WT10-WT13, WT15-WT18,
// WT20), assertions unchanged. The shell cases (WT1-WT9, WT14, RF2, WT19)
// run in jet_cad_2d_integration. The rig reads the tool's settings through
// a function, as the plan's services give them, and builds the band cache
// over the kit tests' catalog.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

typedef Rig = ({
  WallTool tool,
  ToolContext ctx,
  ValueNotifier<WallSettings> settings
});

/// The Wall tool driven directly, wired as the plan wires it, over [doc]:
/// its settings read through [Rig.settings], its own band cache over the
/// kit tests' catalog, a unit camera (a 10 mm aperture), object snap on, no
/// page (no grid). Today's `directRig` (wall_tool_test.dart:168-189).
Rig directRig(DraftDocument doc) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final settings = ValueNotifier<WallSettings>(const WallSettings());
  final bands = WallBands(liveOf(doc));
  final tool = WallTool(() => settings.value, bands);
  addTearDown(() {
    tool.dispose();
    bands.dispose();
    settings.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc, index: index, camera: camera, selection: selection),
    settings: settings,
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

/// Median of [xs].
double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

void main() {
  test(
      'WT10 a hover with no chain pending scans no wall band and leaves the '
      'rubber band alone (review round 2, I2)', () {
    final doc = wallDoc();
    doc.commands.execute(addWall(doc, const Handle(1300), plan(0, 0),
        plan(4000, 0), 200, Justification.centre));
    final rig = directRig(doc);
    final inBand = plan(1200, 60);
    hoverTo(rig, inBand);
    expect(rig.tool.debugBandScans, 0);
    expect(xy(rig.tool.debugBandEnd), [0, 0]);
    pressAt(rig, plan(1500, 1500));
    final scans = rig.tool.debugBandScans;
    hoverTo(rig, inBand);
    expect(rig.tool.debugBandScans, scans + 1);
    expect(distToLine(rig.tool.debugBandEnd, plan(0, 0), plan(4000, 0)),
        lessThan(1e-6));
  });

  test(
      'WT11 after a wall moves, a hover joins its band where it is now, not '
      'where it was: the cache follows the document (review round 2, I2)',
      () async {
    final doc = wallDoc();
    const h = Handle(1300);
    doc.commands.execute(
        addWall(doc, h, plan(0, 0), plan(4000, 0), 200, Justification.centre));
    final rig = directRig(doc);
    pressAt(rig, plan(1500, 2500));
    hoverTo(rig, plan(1200, 60));
    expect(distToLine(rig.tool.debugBandEnd, plan(0, 0), plan(4000, 0)),
        lessThan(1e-6));
    // Move H 700 mm across itself, in world.
    final shift = plan(0, 700) - plan(0, 0);
    doc.commands.execute(TransformNodeCommand(
        h,
        Transform2.translation(shift.x, shift.y)
            .multiply(doc.tree.accumulatedTransform(h))));
    await Future<void>.delayed(Duration.zero);
    final w = worldWallOf(doc, h);
    hoverTo(rig, plan(1200, 760));
    expect(distToLine(rig.tool.debugBandEnd, w.s, w.e), lessThan(1e-6),
        reason: 'joined onto the moved wall');
    final old = plan(1200, 60);
    hoverTo(rig, old);
    expect((rig.tool.debugBandEnd - old).length, lessThan(1e-6),
        reason: 'the old band is empty now');
    // A click there joins the moved wall too.
    pressAt(rig, plan(2600, 640));
    final stem = walls(doc).last;
    expect(distToLine(doc.components.get<WallParams>(stem)!.end, w.s, w.e),
        lessThan(wallJoin.linear));
  });

  test(
      'WT12 the per-hover cost at 600 walls, printed, not asserted (review '
      'round 2, I2)', () {
    final doc = wallDoc();
    var next = 1000;
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < 30; i++)
        for (var j = 0; j < 20; j++)
          addWall(doc, Handle(next += 10), plan(i * 3000.0, j * 3000.0),
              plan(i * 3000.0 + 1000, j * 3000.0), 200, Justification.centre),
    ], label: 'Add 600 walls'));
    expect(walls(doc), hasLength(600));
    final rig = directRig(doc);
    pressAt(rig, plan(-5000, -5000));
    // Between the walls: in no band, so every hover scans all 600.
    final p = plan(1500, 1500);
    final raw = Vector2.zero();
    final hover = <double>[], scan = <double>[];
    const batch = 50;
    for (var k = 0; k < 200; k++) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, p);
      }
      hover.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        rig.tool.hovered(raw);
      }
      scan.add(sw.elapsedMicroseconds / batch);
    }
    expect(xy(rig.tool.debugBandEnd), xy(p), reason: 'in no band');
    // ignore: avoid_print
    print('WT12 n=600: median per hover ${median(hover).toStringAsFixed(2)} '
        'us (whole pointer move), band scan alone '
        '${median(scan).toStringAsFixed(2)} us');
  });

  test(
      'WT13 a click inside two crossing bands joins the lower handle '
      '(review round 2, m4)', () {
    final doc = wallDoc();
    final c = plan(0, 0);
    // Lower handle X1 along the plan's x; X2 crosses it at 60 degrees.
    doc.commands.execute(addWall(doc, const Handle(1300), plan(-2000, 0),
        plan(2000, 0), 200, Justification.centre));
    doc.commands.execute(addWall(doc, const Handle(2600), polar(c, 83, -2000),
        polar(c, 83, 2000), 200, Justification.centre));
    final x1 = worldWallOf(doc, const Handle(1300));
    final x2 = worldWallOf(doc, const Handle(2600));
    final rig = directRig(doc);
    pressAt(rig, plan(-1500, 1500));
    // 40 along X1 and 30 off it: about 20 off X2, inside both bands and
    // outside the 10 mm aperture of either centreline.
    final p = plan(40, 30);
    expect(distToLine(p, x2.s, x2.e), inInclusiveRange(15, 25));
    pressAt(rig, p);
    final end = doc.components.get<WallParams>(walls(doc).last)!.end;
    expect(distToLine(end, x1.s, x1.e), lessThan(wallJoin.linear));
    expect(distToLine(end, x2.s, x2.e), greaterThan(30));
  });

  test(
      'WT15 a click in the same synchronous task as an edit joins the band '
      'where the wall is now: a move, then an undo, each with no await '
      '(Task 6 review, m1)', () async {
    final doc = wallDoc();
    const h = Handle(1300);
    doc.commands.execute(
        addWall(doc, h, plan(0, 0), plan(4000, 0), 200, Justification.centre));
    final rig = directRig(doc);
    // The chain's start builds the band cache with H where it is.
    pressAt(rig, plan(1500, 2500));
    // Move H 700 mm across itself, in world, and click in its old band
    // before the change stream has delivered.
    final shift = plan(0, 700) - plan(0, 0);
    doc.commands.execute(TransformNodeCommand(
        h,
        Transform2.translation(shift.x, shift.y)
            .multiply(doc.tree.accumulatedTransform(h))));
    final old = plan(1200, 60);
    pressAt(rig, old);
    final first = walls(doc).last;
    expect(first, isNot(h));
    final end = doc.components.get<WallParams>(first)!.end;
    expect(xy(end), xy(old), reason: 'the old band is empty: not joined');
    // Let the stream deliver, and a hover rebuild the cache with H moved.
    // Then undo that wall and the move and click in the moved band: H is
    // back where it was, so the click stays where it landed.
    await Future<void>.delayed(Duration.zero);
    hoverTo(rig, plan(2000, 2000));
    doc.commands.undo();
    doc.commands.undo();
    final moved = plan(1300, 760);
    pressAt(rig, moved);
    final second = walls(doc).last;
    expect(xy(doc.components.get<WallParams>(second)!.end), xy(moved),
        reason: 'the moved band is gone again: not joined');
    expect(distToLine(moved, plan(0, 0), plan(4000, 0)), greaterThan(700));
  });

  test(
      "WT16 a click right after the tool's own commit, with no await, joins "
      "the new wall's band (Task 6 review, m2)", () {
    final doc = wallDoc();
    final rig = directRig(doc);
    pressAt(rig, plan(0, 0));
    hoverTo(rig, plan(2000, 900));
    pressAt(rig, plan(3000, 0));
    final a = walls(doc).single;
    final wa = worldWallOf(doc, a);
    pressAt(rig, plan(1500, 70));
    final end = doc.components.get<WallParams>(walls(doc).last)!.end;
    expect(distToLine(end, wa.s, wa.e), lessThan(wallJoin.linear),
        reason: "on A's centreline");
  });

  test(
      "WT17 a hover right after the tool's own commit, with no await, joins "
      "the new wall's band (Task 6 review, m2)", () {
    final doc = wallDoc();
    final rig = directRig(doc);
    pressAt(rig, plan(0, 0));
    hoverTo(rig, plan(2000, 900));
    pressAt(rig, plan(3000, 0));
    final wa = worldWallOf(doc, walls(doc).single);
    hoverTo(rig, plan(1500, 70));
    expect(distToLine(rig.tool.debugBandEnd, wa.s, wa.e), lessThan(1e-6),
        reason: "the rubber band ends on A's centreline");
  });

  test(
      'WT18 settings holding a thickness at or below wallJoin.linear commit '
      'no wall and end the chain; just above it, a wall lands (final review '
      'm1)', () {
    final doc = wallDoc();
    final rig = directRig(doc);
    for (final t in [1e-12, wallJoin.linear]) {
      rig.settings.value = WallSettings(thickness: t);
      final seed = doc.handleSeed.current;
      final before = enc(doc);
      pressAt(rig, plan(0, 0));
      expect(rig.tool.isPending, isTrue, reason: '$t');
      pressAt(rig, plan(3000, 0));
      expect(walls(doc), isEmpty, reason: '$t');
      expect(doc.handleSeed.current, seed, reason: '$t');
      expect(enc(doc), before, reason: '$t');
      expect(doc.commands.undoDepth, 0, reason: '$t');
      expect(rig.tool.isPending, isFalse, reason: '$t: the chain ends');
    }
    rig.settings.value = WallSettings(thickness: 2 * wallJoin.linear);
    pressAt(rig, plan(0, 0));
    pressAt(rig, plan(3000, 0));
    final h = walls(doc).single;
    expect(doc.components.get<WallParams>(h)!.thickness, 2 * wallJoin.linear);
    expect(driftOf(doc), isEmpty);
  });

  test(
      'WT20 settings holding a thickness above kWallMaxThickness, set through '
      "the tool's notifier, commit no wall on a diagonal click at the far "
      'turned origin and end the chain; at the ceiling a wall lands '
      '(post-11 (c), Q4 review m2)', () {
    final doc = wallDoc();
    final rig = directRig(doc);
    // Off both axes in world, which is the wall group's local space: 1e25
    // over this ~3,030 mm wall collapses its band (t/L ~ 3e21), and the
    // region check would throw out of the click.
    final s = plan(400, 900), e = plan(3400, 1300);
    for (final t in [1e25, nextUp(kWallMaxThickness)]) {
      rig.settings.value = WallSettings(thickness: t);
      final seed = doc.handleSeed.current;
      final before = enc(doc);
      pressAt(rig, s);
      expect(rig.tool.isPending, isTrue, reason: '$t');
      expect(() => pressAt(rig, e), returnsNormally, reason: '$t');
      expect(walls(doc), isEmpty, reason: '$t');
      expect(doc.handleSeed.current, seed, reason: '$t');
      expect(enc(doc), before, reason: '$t');
      expect(doc.commands.undoDepth, 0, reason: '$t');
      expect(rig.tool.isPending, isFalse, reason: '$t: the chain ends');
    }
    rig.settings.value = const WallSettings(thickness: kWallMaxThickness);
    pressAt(rig, s);
    pressAt(rig, e);
    final h = walls(doc).single;
    expect(doc.components.get<WallParams>(h)!.thickness, kWallMaxThickness);
    expect(driftOf(doc), isEmpty);
  });
}

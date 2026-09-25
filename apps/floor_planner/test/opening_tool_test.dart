// Spec 08 D14: the Door (D), Window (N) and Gap (G) tools. One click on a
// wall's band places one opening, centred at the resolved click projected
// onto the host's centreline, stored where it is drawn; a door's swing is
// the clicked side of the band's midline and its hinge the nearer end's
// jamb. The shared band cache finds the host (Ruling 08-11); the tool
// caches the host's frame (Ruling 08-13). Every wall is at the far origin
// in its own rotated group, none is axis-aligned, and no click is central.
// Expected positions come from `support/opening_fixture.dart`'s oracles,
// which never call `opening_geometry.dart`.
import 'dart:math' as math;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/opening_geometry.dart';
import 'package:floor_planner/parametric/opening_tool.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/tool_palette.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/opening_fixture.dart';
import 'support/wall_fixture.dart';
import 'support/wall_shell.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

// ---------------------------------------------------------------------------
// The shell.

/// The camera's scale in pixels per mm: the snap aperture is 10 / 0.15 ≈
/// 66.7 mm.
const double _scale = 0.15;

/// The page's grid step: every click resolves to a grid point a few mm off
/// the raw pointer point.
const double gridStep = 10;

final Vector2 _centre = plan(2500, 1500);

/// A 1:20 page near the far origin with grid snap on at [gridStep], and no
/// wall yet: [pumpTools] installs the parametric system, then the walls are
/// added.
DraftDocument toolShellDoc(FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          gridStepMm: gridStep)));
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell, then sets a rotated, non-reflecting camera centred on
/// the plan at the far origin.
Future<PlannerView> pumpTools(WidgetTester tester, DraftDocument doc) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(_centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

/// A primary click at world [p].
Future<void> clickAt(WidgetTester tester, PlannerView view, Vector2 p) async {
  final s = view.camera.value.worldToScreen(p);
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
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

/// The shell's opening tool behind palette entry [keyName].
OpeningTool openingTool(WidgetTester tester, String keyName) => tester
    .widget<ToolPalette>(find.byType(ToolPalette))
    .entries
    .firstWhere((e) => e.keyName == keyName)
    .tool as OpeningTool;

/// The page grid's point nearest [p], as the snap chain computes it.
Vector2 gridOf(DraftDocument doc, Vector2 p) =>
    snapToGrid(p, gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// Every opening, ascending.
List<Handle> openings(DraftDocument doc) =>
    doc.components.withComponent<OpeningParams>().toList();

/// Adds wall [h]'s command with a handle from the seed, as a tool would, so
/// that later objects take higher handles.
Handle addWallFromSeed(
    DraftDocument doc, Vector2 s, Vector2 e, double t, Justification j) {
  final h = doc.handleSeed.next();
  doc.commands.execute(addWall(doc, h, s, e, t, j));
  return h;
}

// ---------------------------------------------------------------------------
// The tool driven directly, as `wall_tool_test.dart` drives the Wall tool.

typedef Rig = ({OpeningTool tool, ToolContext ctx});

/// An opening tool of [kind] over [doc]: a unit camera (a 10 mm aperture),
/// object snap on, no page (no grid).
Rig directRig(DraftDocument doc, OpeningKind kind) {
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.identity()));
  final selection = SelectionController(doc);
  final settings = ValueNotifier(OpeningSettings.defaultFor(kind));
  final tool = OpeningTool(kind, settings);
  addTearDown(() {
    tool.dispose();
    settings.dispose();
    selection.dispose();
    camera.dispose();
    index.dispose();
  });
  return (
    tool: tool,
    ctx: ToolContext(
        document: doc, index: index, camera: camera, selection: selection),
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

double median(List<double> xs) => (xs.toList()..sort())[xs.length ~/ 2];

/// The one opening [doc] gained over [before], ascending.
Handle added(DraftDocument doc, List<Handle> before) =>
    openings(doc).where((o) => !before.contains(o)).single;

/// [p]'s numbers, for comparing payloads.
List<double> numbersOf(GeometryPayload p) => [...p.coords, ...p.scalars];

void main() {
  testWidgets(
      'OT1 (M-08b, X9-raw, X9-unclamped) D, N and G each place one opening '
      'with one click and one undo step, centred at the resolved click '
      'projected onto the host, at the tool\'s width; a click near a mitre '
      'stores the clamped centre and nothing is diagnosed; a click in no '
      'band places nothing; the tool stays active, and Esc returns to '
      'Select', (tester) async {
    final view = await pumpTools(tester, toolShellDoc(FlutterTextMeasurer()));
    final doc = view.document;
    // An L: A (200, centred) runs into B (115, left-justified) at a mitre.
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    final b = addWallFromSeed(doc, plan(5000, 0), plan(5000, 3000), 115, left);
    doc.commands.clearHistory();
    await tester.pump();
    expect(diagnosticsOf(doc), isEmpty);
    final fa = oracleFrameOf(doc, a), fb = oracleFrameOf(doc, b);

    // The palette reaches every tool.
    for (final (key, name) in const [
      ('tool-door', 'Door'),
      ('tool-window', 'Window'),
      ('tool-gap', 'Gap'),
      ('tool-select', 'Select'),
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(status(tester), name, reason: key);
    }

    /// One click at [raw] with [tool] active places one opening: returns it
    /// and checks the undo depth, the resolved point and the tool.
    Future<Handle> place(OpeningTool tool, Vector2 raw) async {
      final before = openings(doc);
      final depth = doc.commands.undoDepth;
      await clickAt(tester, view, raw);
      expect(xy(tool.hoverPoint), xy(gridOf(doc, raw)),
          reason: 'resolved to the grid point, not snapped to an entity');
      expect(openings(doc), hasLength(before.length + 1), reason: 'one more');
      expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
      expect(status(tester), tool.name, reason: 'the tool stays active');
      return added(doc, before);
    }

    // D: a door at a non-default width, 1,300 along A and 37 off it.
    final door = openingTool(tester, 'tool-door');
    door.settings.value = const OpeningSettings(width: 750);
    await press(tester, LogicalKeyboardKey.keyD);
    expect(status(tester), 'Door');
    final r1 = oracleAt(fa, 1300, 37);
    // A mouse hover first: the preview is built and painted (a leaf, an
    // arc and two jambs), and nothing is committed.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final s1 = view.camera.value.worldToScreen(r1);
    await mouse.moveTo(
        tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s1.x, s1.y));
    await tester.pump();
    expect([for (final (k, _) in door.debugPreview) k],
        [EntityKind.line, EntityKind.arc, EntityKind.line, EntityKind.line]);
    expect(openings(doc), isEmpty);
    final d1 = await place(door, r1);
    final p1 = doc.components.get<OpeningParams>(d1)!;
    expect(p1.host, a);
    expect(p1.kind, OpeningKind.door);
    expect(p1.width, 750);
    expect(p1.position, closeTo(oracleU(fa, gridOf(doc, r1)), 1e-6),
        reason: 'the resolved click projected onto A');

    // N: a window. The raw click is 3 mm inside A's left face; its grid
    // point lies outside the band (so the host comes from the raw point),
    // and is what is projected.
    final window = openingTool(tester, 'tool-window');
    window.settings.value = const OpeningSettings(width: 1000);
    await press(tester, LogicalKeyboardKey.keyN);
    expect(status(tester), 'Window');
    Vector2? r2;
    for (var u = 2400.0; u < 2800; u += 3) {
      final raw = oracleAt(fa, u, 97);
      final g = gridOf(doc, raw);
      if ((g - fa.s).dot(fa.n) > 101) {
        r2 = raw;
        break;
      }
    }
    expect(r2, isNotNull, reason: 'a click whose grid point leaves the band');
    final w2 = await place(window, r2!);
    final p2 = doc.components.get<OpeningParams>(w2)!;
    expect(p2.host, a);
    expect(p2.kind, OpeningKind.window);
    expect(p2.width, 1000);
    expect(p2.position, closeTo(oracleU(fa, gridOf(doc, r2)), 1e-6));
    expect((p2.hinge, p2.swing), (HingeEnd.start, SwingSide.left));

    // G: a gap on B, 1,100 along it and 20 right of it.
    final gap = openingTool(tester, 'tool-gap');
    gap.settings.value = const OpeningSettings(width: 640);
    await press(tester, LogicalKeyboardKey.keyG);
    expect(status(tester), 'Gap');
    final r3 = oracleAt(fb, 1100, 20);
    final g3 = await place(gap, r3);
    final p3 = doc.components.get<OpeningParams>(g3)!;
    expect(p3.host, b);
    expect(p3.kind, OpeningKind.gap);
    expect(p3.width, 640);
    expect(p3.position, closeTo(oracleU(fb, gridOf(doc, r3)), 1e-6));
    expect((p3.hinge, p3.swing), (HingeEnd.start, SwingSide.left));
    expect(diagnosticsOf(doc), isEmpty);

    // D near A's mitre: 150 short of the straight span's end, so the door's
    // stored interval would run into the corner; it is stored at the
    // clamped centre, where it is drawn, and is not diagnosed.
    await press(tester, LogicalKeyboardKey.keyD);
    final (_, uE) = OpeningOracle(doc).span(a);
    final r4 = oracleAt(fa, uE - 150, -45);
    final d4 = await place(door, r4);
    final p4 = doc.components.get<OpeningParams>(d4)!;
    final projected = oracleU(fa, gridOf(doc, r4));
    expect(projected + 375, greaterThan(uE + 100), reason: 'into the corner');
    expect(diagnosticsOf(doc), isEmpty, reason: 'not clamped from birth');
    expect(OpeningOracle(doc).cut(p4)!.a, closeTo(p4.position - 375, 1e-6),
        reason: 'drawn where it is stored');
    expect(p4.position, closeTo(uE - 375, 1e-6), reason: 'the clamped centre');
    expect(driftOf(doc), isEmpty);

    // A click in no band places nothing.
    final before = openings(doc);
    final depth = doc.commands.undoDepth;
    await clickAt(tester, view, plan(2500, 1500));
    expect(openings(doc), before);
    expect(doc.commands.undoDepth, depth);

    // One undo step takes the last door away; Esc returns to Select.
    await undoKey(tester);
    expect(openings(doc), [d1, w2, g3]);
    expect(status(tester), 'Door');
    await press(tester, LogicalKeyboardKey.escape);
    expect(status(tester), 'Select');
    expect(driftOf(doc), isEmpty);
  });

  test(
      'OT1 (stored centre, X9-naive) a clamped click is stored where it is '
      'drawn and is never clamped from birth: 90 clicks by a mitre and on '
      'both sides of a T stem each store the oracle\'s clamped centre and '
      'are not diagnosed; storedCentreOf corrects the ulp that (a + w/2) − '
      'w/2 loses, at either end of a stretch', () {
    // Pure: two cases where the naive centre re-places one ulp outside
    // [a, b − w] and would be clamped.
    for (final (a, w, b, low) in const [
      (3830.887022352582, 1013.3495204029557, 7518.696506958233, true),
      (2472.472015491887, 1083.4929773972992, 5122.026963351282, false),
    ]) {
      final x = low ? a : b - w;
      final naive = placeCut([(a, b)], x + w / 2, w)!;
      expect(naive.clamped, isTrue, reason: 'the naive centre, $low');
      final c = storedCentreOf([(a, b)], (a: x, b: x + w, clamped: true), w);
      final again = placeCut([(a, b)], c, w)!;
      expect(again.clamped, isFalse, reason: 'corrected, $low');
      expect(again.a, closeTo(x, 1e-9), reason: 'the same place, $low');
      expect((c - (x + w / 2)).abs(), lessThan(1e-9), reason: '$low');
    }

    // Through the tool: A (200, centred) meets B at its start in a 60°
    // mitre, and a 115 stem ends on A's centreline 3,400 along it: a T.
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(6000, 0), 200, centre);
    addWallFromSeed(doc, plan(1300, 2250), plan(0, 0), 150, right);
    final fa0 = oracleFrameOf(doc, a);
    final foot = oracleAt(fa0, 3400, 0);
    addWallFromSeed(doc, polar(foot, 23 + 70, 2200), foot, 115, left);
    doc.commands.clearHistory();
    expect(diagnosticsOf(doc), isEmpty);
    final oracle = OpeningOracle(doc);
    final f = oracleFrameOf(doc, a);
    final (uS, _) = oracle.span(a);
    final [(o1, o2)] = oracle.obstacles(a);
    expect(uS, greaterThan(50), reason: 'the mitre sets the span back');
    final rig = directRig(doc, OpeningKind.door);
    const w = 900.0;
    var clicks = 0;
    for (var k = 0; k < 30; k++) {
      for (final (u, want) in [
        (uS + 60 + 7.3 * k, uS + w / 2),
        (o1 - 90 - 5.1 * k, o1 - w / 2),
        (o2 + 90 + 5.1 * k, o2 + w / 2),
      ]) {
        final before = openings(doc);
        pressAt(rig, oracleAt(f, u, 40));
        final o = doc.components.get<OpeningParams>(added(doc, before))!;
        clicks++;
        final why = 'a click at $u';
        expect(diagnosticsOf(doc), isEmpty, reason: why);
        expect(o.position, closeTo(want, 1e-6), reason: why);
        expect(OpeningOracle(doc).cut(o)!.a, closeTo(o.position - w / 2, 1e-6),
            reason: '$why: drawn where it is stored');
        doc.commands.undo();
      }
    }
    expect(clicks, 90);
  });

  test(
      'OT2 (M-08z, M-08z2, M-08z3) a door swings out of the clicked side of '
      'the band\'s midline and hangs on the nearer end\'s jamb: on a centred '
      '200 host, clicks 30 mm either side at 0.3·L and 0.7·L; on a '
      'right-justified 200 host, clicks 30 mm either side of the midline, '
      'both inside the band', () {
    final doc = wallDoc();
    final c = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    final r = addWallFromSeed(doc, plan(0, 3000), plan(5000, 3000), 200, right);
    doc.commands.clearHistory();
    final rig = directRig(doc, OpeningKind.door);

    OpeningParams clickDoor(Handle host, double u, double off) {
      final before = openings(doc);
      pressAt(rig, oracleAt(oracleFrameOf(doc, host), u, off));
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.host, host);
      doc.commands.undo();
      return o;
    }

    final fc = oracleFrameOf(doc, c);
    for (final (u, off, hinge, swing) in [
      (0.3 * fc.len, 30.0, HingeEnd.start, SwingSide.left),
      (0.3 * fc.len, -30.0, HingeEnd.start, SwingSide.right),
      (0.7 * fc.len, 30.0, HingeEnd.end, SwingSide.left),
      (0.7 * fc.len, -30.0, HingeEnd.end, SwingSide.right),
    ]) {
      final o = clickDoor(c, u, off);
      expect(o.position, closeTo(u, 1e-6), reason: 'unsnapped, unclamped');
      expect((o.hinge, o.swing), (hinge, swing), reason: 'at $u, $off');
    }

    // Right-justified: the band lies from 0 to -200 along n, its midline
    // at -100; the centreline is its left face.
    final fr = oracleFrameOf(doc, r);
    expect((fr.lo, fr.ro), (0, -200));
    for (final (off, swing) in [
      (-70.0, SwingSide.left),
      (-130.0, SwingSide.right),
    ]) {
      final o = clickDoor(r, 1700, off);
      expect((o.hinge, o.swing), (HingeEnd.start, swing), reason: 'at $off');
    }
    expect(driftOf(doc), isEmpty);
  });

  test(
      'OT4 (X9-cache, M-08h at the preview) with no wall under the pointer '
      'no preview is built and no frame computed, and a click commits '
      'nothing; over a wall the preview is the symbol the click commits and '
      'its cut\'s two jamb lines, in world; the frame cache is rebuilt only '
      'at a click or after a document change', () async {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, left);
    doc.commands.execute(addOpening(doc, doc.handleSeed.next(),
        OpeningParams(a, 3900, 800, OpeningKind.window)));
    doc.commands.clearHistory();
    final rig = directRig(doc, OpeningKind.door);
    final tool = rig.tool;
    final off = plan(2500, 1500);

    for (var i = 0; i < 3; i++) {
      hoverTo(rig, off + Vector2(i * 7.0, 0));
    }
    expect(tool.debugPreviewBuilds, 0);
    expect(tool.debugFrameBuilds, 0);
    expect(tool.debugPreview, isEmpty);
    final before = openings(doc);
    pressAt(rig, off);
    expect(openings(doc), before, reason: 'nothing committed');
    expect(doc.commands.undoDepth, 0);
    expect(tool.debugFrameBuilds, 0);

    // Over A: one frame, one preview per move.
    final f = oracleFrameOf(doc, a);
    for (var i = 0; i < 5; i++) {
      hoverTo(rig, oracleAt(f, 1200 + 40.0 * i, 60));
    }
    expect(tool.debugFrameBuilds, 1);
    expect(tool.debugPreviewBuilds, 5);
    hoverTo(rig, off);
    expect(tool.debugPreview, isEmpty, reason: 'off the wall again');
    expect(tool.debugPreviewBuilds, 5);

    // The preview is what the click commits: the door's leaf and arc, then
    // the two jamb lines of its cut, on the oracle.
    final p = oracleAt(f, 1330, 140);
    hoverTo(rig, p);
    expect(tool.debugFrameBuilds, 1, reason: 'the same host, no change');
    final preview = [
      for (final (k, g) in tool.debugPreview) (k, numbersOf(g)),
    ];
    pressAt(rig, p);
    final d = added(doc, before);
    final o = doc.components.get<OpeningParams>(d)!;
    expect(o.position, closeTo(1330, 1e-6));
    final kids0 = kids(doc, d);
    expect([for (final (k, _) in preview) k],
        [EntityKind.line, EntityKind.arc, EntityKind.line, EntityKind.line]);
    for (var i = 0; i < 2; i++) {
      final want = numbersOf(payloadOf(doc, kids0[i]));
      final got = preview[i].$2;
      expect(got, hasLength(want.length));
      for (var j = 0; j < want.length; j++) {
        expect(got[j], closeTo(want[j], 1e-9), reason: 'symbol $i [$j]');
      }
    }
    expect(doc.tree.accumulatedTransform(d).isIdentity, isTrue,
        reason: 'own group at the identity: its local space is world');
    final cut = OpeningOracle(doc).cut(o)!;
    for (final (i, u) in [(2, cut.a), (3, cut.b)]) {
      final l = preview[i].$2;
      expect(
          (Vector2(l[0], l[1]) - oracleAt(f, u, f.lo)).length, lessThan(1e-6),
          reason: 'jamb $i on the left face');
      expect(
          (Vector2(l[2], l[3]) - oracleAt(f, u, f.ro)).length, lessThan(1e-6),
          reason: 'jamb $i on the right face');
    }

    // The click rebuilt the frame; hovers then reuse it.
    hoverTo(rig, oracleAt(f, 2500, 50));
    hoverTo(rig, oracleAt(f, 2520, 50));
    expect(tool.debugFrameBuilds, 2);

    // A document change: A moves 700 mm across itself. The next hover
    // rebuilds the frame and previews on A where it is now.
    final shift = plan(0, 700) - plan(0, 0);
    doc.commands.execute(TransformNodeCommand(
        a,
        Transform2.translation(shift.x, shift.y)
            .multiply(doc.tree.accumulatedTransform(a))));
    await Future<void>.delayed(Duration.zero);
    final g = oracleFrameOf(doc, a);
    hoverTo(rig, oracleAt(g, 2500, 50));
    expect(tool.debugFrameBuilds, 3);
    final jamb = tool.debugPreview[2].$2.coords;
    expect(distToLine(Vector2(jamb[0], jamb[1]), g.s, oracleEnd(g, 1)) - g.lo,
        closeTo(0, 1e-6),
        reason: 'on the moved wall\'s left face');
    hoverTo(rig, oracleAt(g, 2540, 50));
    expect(tool.debugFrameBuilds, 3);
  });

  test(
      'OT4 (cost) the per-hover cost at 600 walls, printed, not asserted '
      '(07 WT12\'s method)', () {
    final doc = wallDoc();
    var next = 1000;
    doc.commands.execute(CompoundCommand([
      for (var i = 0; i < 30; i++)
        for (var j = 0; j < 20; j++)
          addWall(doc, Handle(next += 10), plan(i * 3000.0, j * 3000.0),
              plan(i * 3000.0 + 1000, j * 3000.0), 200, centre),
    ], label: 'Add 600 walls'));
    doc.handleSeed.raiseTo(Handle(next + 10000));
    expect(walls(doc), hasLength(600));
    final rig = directRig(doc, OpeningKind.door);
    // Between the walls: in no band, so every hover scans all 600.
    final p = plan(1500, 1500);
    // On the last wall scanned: a frame (once) and a preview per move.
    final q = plan(29 * 3000.0 + 400, 19 * 3000.0 + 30);
    final raw = Vector2.zero();
    final none = <double>[], scan = <double>[], over = <double>[];
    const batch = 50;
    for (var k = 0; k < 200; k++) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, p);
      }
      none.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        rig.tool.hovered(raw);
      }
      scan.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, q);
      }
      over.add(sw.elapsedMicroseconds / batch);
    }
    expect(rig.tool.debugFrameBuilds, 1);
    expect(rig.tool.debugPreviewBuilds, 200 * batch);
    // ignore: avoid_print
    print('OT4 n=600: median per hover over no wall '
        '${median(none).toStringAsFixed(2)} us (whole pointer move), host '
        'scan alone ${median(scan).toStringAsFixed(2)} us; over a wall, with '
        'the preview, ${median(over).toStringAsFixed(2)} us');
  });

  test(
      'HF7 on OG9\'s random plans (50 trials), the document adapter agrees '
      'with the view adapter bit for bit: at every opening\'s gap, '
      'frame.at(a, 0) and frame.at(b, 0) are the stored centreline pieces\' '
      'endpoints, and every wall\'s stored centreline pieces are the '
      'document adapter\'s (Ruling 08-8)', () {
    final rnd = math.Random(808);
    final cover = math.Random(809);
    final stats = RandomPlanStats();
    var walls = 0, cutWalls = 0, fitting = 0, edges = 0, dropped = 0;
    var mismatched = 0;
    final failures = <String>[];
    for (var trial = 0; trial < 50; trial++) {
      final (:doc, :checked) = randomOpeningPlan(rnd, cover, trial, stats);
      for (final h in checked) {
        walls++;
        final layout = layoutInDocument(doc, h)!;
        final f = layout.frame;
        final os = openingsInDocument(doc, h);
        final placed = cutsOf(f, layout.stretches, [
          for (final (_, o) in os) (o.position, o.width),
        ]);
        final stored = [
          for (final k in centrelineHandles(doc, h))
            payloadOf(doc, k).coords.toList(),
        ];
        final p = doc.components.get<WallParams>(h)!;
        final want = placed.merged.isEmpty
            ? [
                [p.sx, p.sy, p.ex, p.ey],
              ]
            : [
                for (final l in centrelinePieces(f, placed.merged))
                  [l[0].x, l[0].y, l[1].x, l[1].y],
              ];
        if (placed.merged.isNotEmpty) cutWalls++;
        if (stored.toString() != want.toString()) {
          mismatched++;
          failures.add('trial $trial wall ${h.value}: stored $stored, the '
              'document adapter $want');
        }
        final ends = {
          for (final l in stored) ...[
            (l[0], l[1]),
            (l[2], l[3]),
          ],
        };
        final kept = {
          for (final l in want) ...[
            (l[0], l[1]),
            (l[2], l[3]),
          ],
        };
        for (final cut in placed.cuts) {
          if (cut == null) continue;
          fitting++;
          final gap =
              placed.merged.firstWhere((g) => g.$1 <= cut.a && cut.b <= g.$2);
          for (final u in [gap.$1, gap.$2]) {
            final q = f.at(u, 0);
            edges++;
            if (ends.contains((q.x, q.y))) continue;
            if (!kept.contains((q.x, q.y))) {
              // The piece beyond this edge is no longer than the tolerance
              // and dropped (D9): no centreline ends here.
              dropped++;
              continue;
            }
            mismatched++;
            failures.add('trial $trial wall ${h.value}: the gap edge at $u '
                'is not a stored centreline end');
          }
        }
      }
    }
    // ignore: avoid_print
    print('HF7: $walls walls ($cutWalls cut), ${stats.openings} openings, '
        '$fitting fitting, $edges gap edges ($dropped beyond a dropped '
        'piece), $mismatched mismatches');
    expect(stats.refused, 0);
    expect(mismatched, 0, reason: failures.take(5).join('\n'));
    expect(fitting, greaterThan(200), reason: 'not vacuous');
    expect(cutWalls, greaterThan(100), reason: 'not vacuous');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

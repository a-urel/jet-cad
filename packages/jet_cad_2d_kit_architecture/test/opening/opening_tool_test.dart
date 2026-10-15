// Ported from jet_cad_floor_plan/test/opening_tool_test.dart (spec 3a C3.3, C7, R15-5).
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

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_tool.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';
import '../support/wall_shell.dart';

const centre = Justification.centre;
const left = Justification.left;
const right = Justification.right;

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
// The tool driven directly, as `wall_tool_test.dart` drives the Wall tool,
// over the kit's test double of the plan's services (spec 3a C1.11).

typedef Rig = ({
  OpeningTool tool,
  ToolContext ctx,
  Map<String, Object> settings,
});

/// An opening tool of [kind] over [doc]: a camera at [scale] pixels per mm
/// (the default, 1, gives a 10 mm aperture), object snap as [snap] says
/// (none: on), no page (no grid), the tool's settings at today's default
/// in [Rig.settings], which the services read at each event ([setWidth]),
/// and [frozen] objects the services call not live (spec 2a E2).
Rig directRig(DraftDocument doc, OpeningKind kind,
    {double scale = 1, SnapSettings? snap, Set<Handle> frozen = const {}}) {
  final settings = <String, Object>{
    openingToolIdOf(kind): OpeningSettings.defaultFor(kind),
  };
  final services = FakePlanServices(
      document: doc,
      catalog: testCatalog(),
      frozen: frozen,
      scale: scale,
      settings: settings);
  final index = SpatialIndex(doc);
  final camera = CameraController(
      ViewportTransform(worldToScreenMatrix: Transform2.scale(scale, scale)));
  final selection = SelectionController(doc);
  final tool = OpeningTool(kind, services);
  addTearDown(() {
    tool.dispose();
    services.dispose();
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
    settings: settings,
  );
}

/// The tool's settings now hold [width] (today's `tool.settings.value =
/// OpeningSettings(width: width)`).
void setWidth(Rig rig, double width) =>
    rig.settings[openingToolIdOf(rig.tool.kind)] =
        OpeningSettings(width: width);

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

/// A canvas that records the snap marker's squares (an endpoint's marker,
/// 05 D9) and ignores everything else.
class MarkerSpy implements Canvas {
  final List<Rect> rects = <Rect>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add(rect);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
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
      'OT1 (ffw-noFitRaw) a no-fit position is stored clamped to [0, L], as '
      'the slide grip stores it (D6; the final review\'s m1): D on a 700 '
      'wall, too short for a 900 door, clicked just inside each end where '
      'object snap resolves the click to a line\'s end 6 mm past it', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(700, 0), 200, centre);
    final f = oracleFrameOf(doc, a);
    // Two lines along the wall, off its centreline, each with an end 6 mm
    // past one of the wall's ends: in a 10 mm aperture of a click 1 mm
    // inside that end.
    for (final (from, to) in [(706.0, 1606.0), (-6.0, -906.0)]) {
      doc.commands.execute(addDrafted(doc, EntityKind.line,
          linePayload(oracleAt(f, from, 80), oracleAt(f, to, 80)),
          layer: ReservedHandles.layerZero));
    }
    doc.commands.clearHistory();
    final p = doc.components.get<WallParams>(a)!;
    final l = (p.end - p.start).length;
    final rig = directRig(doc, OpeningKind.door);
    for (final (u, want) in [(699.0, l), (1.0, 0.0)]) {
      final before = openings(doc);
      pressAt(rig, oracleAt(f, u, 80));
      final h = added(doc, before);
      final o = doc.components.get<OpeningParams>(h)!;
      expect(o.width, 900);
      expect(
          diagnosticsOf(doc)
              .any((d) => d.code == 'opening.nofit' && d.handles.contains(h)),
          isTrue,
          reason: 'too short: no-fit');
      expect(o.position, want, reason: 'a click at $u, resolved 6 mm past');
    }
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
      'OT2 (rv9-hingeRaw) the hinge follows the stored centre, not the '
      'click: a click at 2,400 on a 5,000 host runs into a T obstacle at '
      '[2,300, 2,420], is clamped past L/2 and hangs on the end jamb '
      '(Task 9 review m1)', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    // A 120 stem, square to A, ending on A's centreline at 2,360: A's band
    // is blocked from 2,300 to 2,420.
    final foot = oracleAt(oracleFrameOf(doc, a), 2360, 0);
    addWallFromSeed(doc, polar(foot, 23 + 90, 1800), foot, 120, centre);
    doc.commands.clearHistory();
    final [(o1, o2)] = OpeningOracle(doc).obstacles(a);
    expect(o1, closeTo(2300, 1e-6));
    expect(o2, closeTo(2420, 1e-6));
    final f = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door);
    pressAt(rig, oracleAt(f, 2400, -40));
    final o = doc.components.get<OpeningParams>(openings(doc).single)!;
    expect(o.host, a);
    expect(o.position, closeTo(o2 + 450, 1e-6),
        reason: 'the nearer stretch is past the obstacle: clamped to 2,870');
    expect(2400, lessThan(f.len / 2), reason: 'the click is on the start half');
    expect(o.position, greaterThan(f.len / 2));
    expect(o.hinge, HingeEnd.end, reason: 'the stored centre is past L/2');
    expect(o.swing, SwingSide.right);
    expect(diagnosticsOf(doc), isEmpty);
  });

  test(
      'OT2 (rv9-swingResolved) the swing follows the raw click, not the '
      'resolved point: at 0.15 px/mm, clicks 30 mm either side of a centred '
      'wall at 2,510 snap to its centreline\'s midpoint, and still swing '
      'left and right (Task 9 review m2)', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    doc.commands.clearHistory();
    final f = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door, scale: 0.15);
    for (final (off, swing) in [
      (30.0, SwingSide.left),
      (-30.0, SwingSide.right),
    ]) {
      final before = openings(doc);
      pressAt(rig, oracleAt(f, 2510, off));
      final resolved = rig.tool.hoverPoint;
      expect(rig.tool.hoverKind, SnapKind.midpoint, reason: 'at $off');
      expect(oracleU(f, resolved), closeTo(2500, 1e-6), reason: 'at $off');
      expect(((resolved - f.s).dot(f.n)).abs(), lessThan(1e-6),
          reason: 'the resolved point is on the centreline (at $off)');
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.swing, swing, reason: 'the raw click is $off off');
      doc.commands.undo();
    }
  });

  test(
      'OT1 (rv9-selfFirst) the new opening is admitted with the handle its '
      'commit allocates, after the host\'s openings: an 800 door clicked at '
      '1,700 on a 2,000 wall whose 1,200 window cuts [0, 1,200] would leave '
      'no piece, so it is no-fit, stored at the projected click, and its '
      'preview has no jambs (Task 9 review m3)', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(2000, 0), 200, centre);
    final win = doc.handleSeed.next();
    doc.commands.execute(
        addOpening(doc, win, OpeningParams(a, 600, 1200, OpeningKind.window)));
    doc.commands.clearHistory();
    final f = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door);
    setWidth(rig, 800);
    final p = oracleAt(f, 1700, 40);
    hoverTo(rig, p);
    expect([
      for (final (k, _) in rig.tool.debugPreview) k
    ], [
      EntityKind.line,
      EntityKind.arc
    ], reason: 'the no-fit symbol alone: no cut, no jambs');
    pressAt(rig, p);
    final d = added(doc, [win]);
    expect(d.value, greaterThan(win.value));
    final o = doc.components.get<OpeningParams>(d)!;
    expect(o.position, closeTo(1700, 1e-6), reason: 'no-fit: the click');
    final oracle = OpeningOracle(doc);
    expect(oracle.cut(o), isNotNull,
        reason: 'alone it would fit, clamped to [1,200, 2,000]');
    expect([
      for (final (h, c) in oracle.cutsOn(a)) (h, c == null)
    ], [
      (win, false),
      (d, true)
    ], reason: 'admitted after the window, it would leave no piece');
    expect([
      for (final g in diagnosticsOf(doc))
        if (g.code == 'opening.nofit') g.handles,
    ], [
      [d],
    ]);
  });

  test(
      'OT1 (liveness) a stray WallParams on a handle with no node, or on a '
      'nested group, lying over a live wall at a lower handle, is not a '
      'host: D places on the live wall (Task 9 review m5)', () {
    final doc = wallDoc();
    final bare = doc.handleSeed.next();
    final plain = doc.handleSeed.next();
    final nested = doc.handleSeed.next();
    final a = addWallFromSeed(doc, plan(0, 0), plan(4000, 0), 200, centre);
    final f = oracleFrameOf(doc, a);
    // In world: a node-less handle's accumulated transform is the identity,
    // and the nested group and its parent sit at the identity.
    final s = oracleAt(f, 0, 0), e = oracleAt(f, f.len, 0);
    final over = WallParams(s.x, s.y, e.x, e.y, 600, centre);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: plain,
          parent: doc.rootHandle,
          transform: Transform2.identity(),
          children: const [])),
      AddNodeCommand(GroupNode(
          handle: nested,
          parent: plain,
          transform: Transform2.identity(),
          children: const [])),
    ], label: 'Add groups'));
    // Written straight into the store, as a file brings them in: an edit
    // that writes one is refused (fix/post-11, spec 06 D5).
    doc.components
      ..attach<WallParams>(bare, over)
      ..attach<WallParams>(nested, over);
    doc.commands.clearHistory();
    expect(doc.tree[bare], isNull, reason: 'no node');
    expect(doc.tree[nested]!.parent, plain, reason: 'not root-level');
    expect(bare.value < a.value && nested.value < a.value, isTrue);
    final rig = directRig(doc, OpeningKind.door);
    pressAt(rig, oracleAt(f, 1300, 60));
    expect(openings(doc), hasLength(1), reason: 'placed');
    final o = doc.components.get<OpeningParams>(openings(doc).single)!;
    expect(o.host, a);
    expect(o.position, closeTo(1300, 1e-6));
  });

  test(
      'OT3 (M-08sn, pure) edgeSnap: an edge within the aperture of a stretch '
      'end or another opening\'s cut edge moves the centre to put it there; '
      'the nearest pair wins, ties go to the lower centre, nothing in range '
      'gives null', () {
    const stretches = [(137.25, 2061.5), (2311.75, 5890.125)];
    const cuts = [(3000.5, 3900.5)];
    const w = 800.0;
    double? snap(double u, [double aperture = 20]) =>
        edgeSnap(stretches, cuts, u, w, aperture);
    // Each edge against each kind of candidate.
    expect(snap(137.25 + 400 + 12), 137.25 + 400, reason: 'span start');
    expect(snap(2061.5 - 400 - 7), 2061.5 - 400, reason: 'obstacle, right');
    expect(snap(2311.75 + 400 + 19.5), 2311.75 + 400, reason: 'obstacle');
    expect(snap(3000.5 - 400 - 3), 3000.5 - 400, reason: 'cut, right edge');
    expect(snap(3900.5 + 400 + 16), 3900.5 + 400, reason: 'cut, left edge');
    expect(snap(5890.125 - 400 + 11), 5890.125 - 400, reason: 'span end');
    // Within the aperture means at most it; beyond it, nothing.
    expect(snap(137.25 + 400 + 20), 137.25 + 400);
    expect(snap(137.25 + 400 + 20.5), isNull);
    expect(snap(1000), isNull);
    // Two candidates in range: the nearer wins, whichever edge it is.
    const two = [(1000.0, 1803.0)];
    expect(edgeSnap(two, const [], 1401, w, 20), 1400, reason: '1 against 2');
    expect(edgeSnap(two, const [], 1402.5, w, 20), 1403,
        reason: '2.5 against 0.5');
    // A tie (1.5 each way): the lower centre.
    expect(edgeSnap(two, const [], 1401.5, w, 20), 1400);
    expect(edgeSnap(const [(1000.0, 1797.0)], const [], 1398.5, w, 20), 1397,
        reason: 'a tie the other way round: still the lower centre');
  });

  test(
      'OT3 (M-08sn, X10-gate) a door\'s edge snaps to a T obstacle\'s edges, '
      'to a window\'s drawn edges and to the span\'s end, the nearer '
      'candidate winning; with F3 off it stores the chain\'s projected '
      'point', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(6000, 0), 200, centre);
    // A 115 stem at 80° to A, ending on A's centreline at 2,000: a T.
    final foot = oracleAt(oracleFrameOf(doc, a), 2000, 0);
    addWallFromSeed(doc, polar(foot, 23 + 80, 1800), foot, 115, left);
    final [(o1, o2)] = OpeningOracle(doc).obstacles(a);
    // The window's left edge is 903 past the obstacle: a 900 door fits
    // between them with 3 mm to spare.
    final win = doc.handleSeed.next();
    final wc = o2 + 1403;
    doc.commands.execute(
        addOpening(doc, win, OpeningParams(a, wc, 1000, OpeningKind.window)));
    doc.commands.clearHistory();
    expect(diagnosticsOf(doc), isEmpty);
    final f = oracleFrameOf(doc, a);
    // What the wall draws: the stretch ends the tool snaps to, exactly.
    final [(s0, e0), (s1, e1)] =
        layoutInDocument(doc, a, liveOf(doc))!.stretches;
    for (final (app, oracle) in [(e0, o1), (s1, o2), (e1, f.len)]) {
      expect(app, closeTo(oracle, 1e-6), reason: 'the oracle agrees');
    }
    expect(s0, closeTo(0, 1e-6));

    // 0.5 px/mm: a 20 mm aperture.
    final on = directRig(doc, OpeningKind.door, scale: 0.5);
    final off = directRig(doc, OpeningKind.door,
        scale: 0.5, snap: SnapSettings(objectSnap: false));
    double storedAt(Rig rig, double u) {
      final before = openings(doc);
      pressAt(rig, oracleAt(f, u, -40));
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.host, a);
      expect(diagnosticsOf(doc), isEmpty, reason: 'at $u');
      doc.commands.undo();
      return o.position;
    }

    // A 600 door has one candidate in range at a time; a 900 door spans
    // the gap between the obstacle and the window, and has both.
    for (final (w, u, edge, want, why) in [
      (
        600.0,
        s1 + 300 + 13,
        -1,
        s1,
        'the left edge on the obstacle\'s far edge'
      ),
      (600.0, e0 - 300 - 11, 1, e0, 'the right edge on its near edge'),
      (600.0, wc - 500 - 300 - 8, 1, wc - 500, 'on the window\'s left edge'),
      (600.0, wc + 500 + 300 + 12, -1, wc + 500, 'on the window\'s right edge'),
      (600.0, e1 - 300 - 17, 1, e1, 'the right edge on the span\'s end'),
      (900.0, s1 + 450 + 1, -1, s1, '1 mm against 2: the obstacle'),
      (900.0, s1 + 450 + 2.5, 1, wc - 500, '2.5 mm against 0.5: the window'),
    ]) {
      for (final rig in [on, off]) {
        setWidth(rig, w);
      }
      final c = storedAt(on, u);
      // Within a few ulps of u (1e-11), well inside the plan's 1e-9: the
      // snapped centre is stored as computed, never re-projected from its
      // world point at the far origin (~1e-10 off, t10-reproject).
      expect(c + edge * w / 2, closeTo(want, 1e-11), reason: why);
      expect((c - u).abs(), greaterThan(0.4), reason: 'not the click: $why');
      // F3 off: the chain's point (the raw point: no grid), projected.
      expect(storedAt(off, u), closeTo(u, 1e-6), reason: 'F3 off: $why');
    }
    // Nothing in range (25 mm): the chain's point.
    setWidth(on, 600);
    expect(storedAt(on, s1 + 300 + 25), closeTo(s1 + 325, 1e-6));

    // The aperture is in world (t10-apertureLocal): on a host whose group
    // is scaled 2×, 20 mm in world is 10 local units. A 600 (local) door
    // whose right edge is 8 units from the end snaps; at 15 units (30 mm in
    // world) it does not.
    final hb = doc.handleSeed.next();
    doc.commands.execute(addWall(
        doc, hb, plan(0, 4000), plan(4000, 4000), 200, centre,
        at: groupAt(hb.value).multiply(Transform2.scale(2, 2))));
    doc.commands.clearHistory();
    final fb = oracleFrameOf(doc, hb);
    expect(fb.len, closeTo(4000, 1e-6), reason: 'in world');
    for (final (gap, want) in [(8.0, 1700.0), (15.0, 1685.0)]) {
      final before = openings(doc);
      pressAt(on, oracleAt(fb, 2 * (2000 - 300 - gap), -40));
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.host, hb);
      expect(o.position, closeTo(want, 1e-6), reason: '$gap units off');
      doc.commands.undo();
    }
  });

  test(
      'OT3 (rv10-storedCuts) another opening\'s candidates are its drawn '
      'edges: a clamped window\'s drawn edge attracts a door and its stored '
      'edge does not; a no-fit opening\'s stored edges attract nothing', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(6000, 0), 200, centre);
    final foot = oracleAt(oracleFrameOf(doc, a), 2000, 0);
    addWallFromSeed(doc, polar(foot, 23 + 80, 1800), foot, 115, left);
    final [(_, o2)] = OpeningOracle(doc).obstacles(a);
    // Stored [o2 − 100, o2 + 900], so it is drawn clamped at [o2, o2 + 1000].
    final win = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, win, OpeningParams(a, o2 + 400, 1000, OpeningKind.window)));
    // 4,000 wide: no stretch holds it (the longest runs from o2 to the end,
    // ~3,940). Stored [o2 + 1700, o2 + 5700], drawn nowhere.
    final nofit = doc.handleSeed.next();
    doc.commands.execute(addOpening(
        doc, nofit, OpeningParams(a, o2 + 3700, 4000, OpeningKind.window)));
    doc.commands.clearHistory();
    final oracle = OpeningOracle(doc);
    final wc = oracle.cut(doc.components.get<OpeningParams>(win)!)!;
    expect(wc.clamped, isTrue);
    expect([wc.a - o2, wc.b - o2], [closeTo(0, 1e-6), closeTo(1000, 1e-6)]);
    expect(oracle.cut(doc.components.get<OpeningParams>(nofit)!), isNull);

    // 0.5 px/mm: a 20 mm aperture. A 600 door, pressed 40 off the
    // centreline.
    final f = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door, scale: 0.5);
    setWidth(rig, 600);
    for (final (u, want, why) in [
      (
        o2 + 1000 + 300 + 12,
        wc.b + 300,
        'left edge 12 from the window\'s drawn right edge: snapped'
      ),
      (
        o2 + 900 + 300 + 5,
        o2 + 1205,
        'left edge 5 from its stored right edge: not snapped'
      ),
      (
        o2 + 1700 - 300 - 6,
        o2 + 1394,
        'right edge 6 from the no-fit\'s stored left edge: not snapped'
      ),
    ]) {
      final before = openings(doc);
      pressAt(rig, oracleAt(f, u, -40));
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.host, a);
      expect(o.position, closeTo(want, 1e-6), reason: why);
      doc.commands.undo();
    }
  });

  test(
      'OT3 (t11-apertureDir) on a host scaled non-uniformly the aperture is '
      'measured along its centreline: an edge within the world aperture '
      'snaps, one just beyond it does not', () {
    final doc = wallDoc();
    final h = doc.handleSeed.next();
    doc.commands.execute(addWall(doc, h, plan(0, 0), plan(4000, 0), 200, centre,
        at: groupAt(h.value).multiply(Transform2.scale(2, 0.5))));
    final p = doc.components.get<WallParams>(h)!;
    final local = (Vector2(p.ex, p.ey) - Vector2(p.sx, p.sy)).length;
    final f = oracleFrameOf(doc, h);
    // World mm per local unit along the centreline: far from the group's
    // geometric mean scale, 1, so √|det| would be the wrong divisor.
    final k = f.len / local;
    expect((k - 1).abs(), greaterThan(0.2), reason: 'k = $k');
    // A 600 (local) window, unclamped, 60% along: its left edge is the only
    // candidate near the door.
    final wc = 0.6 * local;
    doc.commands.execute(addOpening(doc, doc.handleSeed.next(),
        OpeningParams(h, wc, 600, OpeningKind.window)));
    doc.commands.clearHistory();
    expect(diagnosticsOf(doc), isEmpty);

    // 0.5 px/mm: a 20 mm aperture in world. A 600 (local) door whose right
    // edge is `world` mm (in world) short of the window's left edge, pressed
    // on the centreline: the group does not keep right angles, so a point
    // off the centreline would project elsewhere in local space.
    final rig = directRig(doc, OpeningKind.door, scale: 0.5);
    setWidth(rig, 600);
    for (final (world, snaps) in [(19.9, true), (20.1, false)]) {
      final u = wc - 300 - 300 - world / k;
      final before = openings(doc);
      pressAt(rig, oracleAt(f, u * k, 0));
      final o = doc.components.get<OpeningParams>(added(doc, before))!;
      expect(o.host, h);
      expect(o.position, closeTo(snaps ? wc - 600 : u, 1e-6),
          reason: '$world mm in world');
      doc.commands.undo();
    }
  });

  test(
      'OT5 (X10-marker) the snap marker is painted at the projected point on '
      'the host\'s centreline, not at the chain\'s point; off every wall, '
      'at the chain\'s point', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    // A loose line whose end lies inside A's band, 70 mm off its centreline:
    // the chain snaps to it.
    final f = oracleFrameOf(doc, a);
    final tip = oracleAt(f, 1900, 70);
    final far = oracleAt(f, 1900, 900);
    doc.commands.execute(addDrafted(doc, EntityKind.line, linePayload(tip, far),
        layer: ReservedHandles.layerZero));
    doc.commands.clearHistory();
    final rig = directRig(doc, OpeningKind.door, scale: 0.5);
    Offset marker() {
      final spy = MarkerSpy();
      rig.tool.paintOverlay(
          spy, rig.ctx.camera.value, const Size(800, 600), PaperPalette.light);
      final r = spy.rects.single;
      return r.center;
    }

    Offset screen(Vector2 p) {
      final s = rig.ctx.camera.value.worldToScreen(p);
      return Offset(s.x, s.y);
    }

    // Over A, near the line's end: the chain's point is the end, 70 mm off
    // the centreline; the marker is its projection.
    hoverTo(rig, oracleAt(f, 1904, 63));
    expect(xy(rig.tool.hoverPoint), xy(tip), reason: 'the chain snapped');
    final want = screen(oracleAt(f, 1900, 0));
    expect((marker() - want).distance, lessThan(1e-6));
    expect((marker() - screen(tip)).distance, greaterThan(30),
        reason: 'not the chain\'s point: 35 px away');
    // Off every wall, near the line's other end: the chain's point.
    hoverTo(rig, oracleAt(f, 1903, 896));
    expect((marker() - screen(far)).distance, lessThan(1e-6));
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
      'OT4 (t10-scanMemo) the host scan is shared by the edge snap and the '
      'preview, once per raw point, and never outlives a change: a wall '
      'moved away in the same task as a press where the pointer last '
      'hovered is not placed on', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    doc.commands.clearHistory();
    final f = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door);
    final p = oracleAt(f, 2300, 40);
    hoverTo(rig, p);
    expect(rig.tool.debugPreview, isNotEmpty, reason: 'over A');
    // A moves 700 mm across itself; the change stream has not delivered.
    final shift = plan(0, 700) - plan(0, 0);
    doc.commands.execute(TransformNodeCommand(
        a,
        Transform2.translation(shift.x, shift.y)
            .multiply(doc.tree.accumulatedTransform(a))));
    pressAt(rig, p);
    expect(openings(doc), isEmpty, reason: 'no wall under the press now');
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
    // Between the walls: in no band, so every hover scans all 600. Each
    // point alternates with one 0.5 mm away, as a moving pointer does: the
    // tool scans once per raw point (the edge snap and the preview share
    // the scan), so a repeated point would measure no scan at all.
    final p = [plan(1500, 1500), plan(1500.5, 1500)];
    // On the last wall scanned: a frame (once) and a preview per move.
    final q = [
      plan(29 * 3000.0 + 400, 19 * 3000.0 + 30),
      plan(29 * 3000.0 + 400.5, 19 * 3000.0 + 30),
    ];
    final raw = [Vector2.zero(), Vector2(0.5, 0)];
    final none = <double>[], scan = <double>[], over = <double>[];
    const batch = 50;
    for (var k = 0; k < 200; k++) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, p[i & 1]);
      }
      none.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        rig.tool.hovered(raw[i & 1]);
      }
      scan.add(sw.elapsedMicroseconds / batch);
      sw
        ..reset()
        ..start();
      for (var i = 0; i < batch; i++) {
        hoverTo(rig, q[i & 1]);
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
        final layout = layoutInDocument(doc, h, liveOf(doc))!;
        final f = layout.frame;
        final os = openingsInDocument(doc, h, liveOf(doc));
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

  test(
      'OT1 (preview) the hover of OT1 (shell), in the kit (R15-2): with the '
      'Door tool at 750, a hover 1,300 along A and 37 off it builds the '
      'leaf, the arc and the two jambs, and commits nothing', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    addWallFromSeed(doc, plan(5000, 0), plan(5000, 3000), 115, left);
    doc.commands.clearHistory();
    final fa = oracleFrameOf(doc, a);
    final rig = directRig(doc, OpeningKind.door);
    setWidth(rig, 750);
    hoverTo(rig, oracleAt(fa, 1300, 37));
    expect([for (final (k, _) in rig.tool.debugPreview) k],
        [EntityKind.line, EntityKind.arc, EntityKind.line, EntityKind.line]);
    expect(openings(doc), isEmpty);
  });

  test(
      'OL-tools (spec 3a C3.3) D, N and G: ids, letters, needs; each '
      'tool\'s settings start at today\'s defaults (900, 1,200, 900) and '
      'refuse a width its kind may not take; the kit carries them right '
      'after the Wall tool, and validates', () {
    final tools = [doorPlanTool, windowPlanTool, gapPlanTool];
    expect([
      for (final t in tools) (t.id, t.letter)
    ], [
      (ArchitectureTools.door, 'D'),
      (ArchitectureTools.window, 'N'),
      (ArchitectureTools.gap, 'G'),
    ]);
    for (final t in tools) {
      expect(t.needs,
          {Capability.structure, Capability.components, Capability.geometry},
          reason: t.id);
    }
    expect(
        [for (final t in tools) (t.settings!.initial as OpeningSettings).width],
        [900, 1200, 900]);

    Object? kept;
    final gap = gapPlanTool.settings!
        .fieldsOf(const OpeningSettings(width: 900), (v) => kept = v,
            toolId: ArchitectureTools.gap)
        .single;
    expect(gap.wordId, 'property:architecture.gap.width');
    expect(() => gap.commit!(0.000004), throwsArgumentError);
    expect(kept, isNull, reason: 'not above 4 × wallJoin.linear');
    gap.commit!(0.000005);
    expect(kept, const OpeningSettings(width: 0.000005));
    final door = doorPlanTool.settings!
        .fieldsOf(const OpeningSettings(width: 900), (v) => kept = v,
            toolId: ArchitectureTools.door)
        .single;
    expect(() => door.commit!(0.000001), throwsArgumentError);
    door.commit!(0.000004);
    expect(kept, const OpeningSettings(width: 0.000004));

    final ids = [for (final t in architectureKit.tools) t.id];
    final w = ids.indexOf(ArchitectureTools.wall);
    expect(ids.sublist(w, w + 4), [
      ArchitectureTools.wall,
      ArchitectureTools.door,
      ArchitectureTools.window,
      ArchitectureTools.gap,
    ]);
    expect(architectureKit.validate(), isEmpty);
  });

  test(
      'OL-settings (spec 3a C3.3, R15-1) the tool reads its width from the '
      'plan\'s settings at each click: a change between two clicks gives '
      'the second door the new width', () {
    final doc = wallDoc();
    final a = addWallFromSeed(doc, plan(0, 0), plan(5000, 0), 200, centre);
    final f = oracleFrameOf(doc, a);
    doc.commands.clearHistory();
    final rig = directRig(doc, OpeningKind.door);
    final none = openings(doc);
    pressAt(rig, oracleAt(f, 1200, 40));
    final first = added(doc, none);
    setWidth(rig, 750);
    final one = openings(doc);
    pressAt(rig, oracleAt(f, 3600, 40));
    final second = added(doc, one);
    expect([
      for (final h in [first, second])
        doc.components.get<OpeningParams>(h)!.width
    ], [
      900,
      750
    ]);
  });

  test(
      'OL-frozen (spec 3a C1.5) a wall the plan has frozen is no host and '
      'no obstacle for the opening tools: a click on it places nothing; a '
      'door clicked on a live wall where the frozen one crosses it is '
      'stored at the click, unclamped', () {
    final doc = wallDoc();
    final a = addWallFromSeed(
        doc, plan(0, 0), plan(4000, 0), 200, Justification.left);
    final fa = oracleFrameOf(doc, a);
    final x = addWallFromSeed(
        doc, oracleAt(fa, 1800, -900), oracleAt(fa, 1950, 900), 150, centre);
    final fx = oracleFrameOf(doc, x);
    doc.commands.clearHistory();
    expect(OpeningOracle(doc).obstacles(a), hasLength(1),
        reason: 'premise: X crosses A');
    final rig = directRig(doc, OpeningKind.door,
        frozen: {x}, snap: SnapSettings(objectSnap: false));
    // On X, away from A.
    pressAt(rig, oracleAt(fx, 1500, 30));
    expect(openings(doc), isEmpty, reason: 'a frozen wall hosts nothing');
    expect(doc.commands.undoDepth, 0);
    // On A, where X crosses it: no obstacle, so no clamp.
    pressAt(rig, oracleAt(fa, 1875, 60));
    final o = doc.components.get<OpeningParams>(openings(doc).single)!;
    expect(o.host, a);
    expect(o.position, closeTo(1875, 1e-6));
  });

  test(
      'OL-frozen (memo) (spec 3a C1.5) a freeze with no document change '
      'reaches the tool\'s own caches at its next hover, even at the same '
      'raw point: the host scan no longer finds the frozen wall, and the '
      'frame of the wall it crossed no longer counts it as an obstacle', () {
    final doc = wallDoc();
    final a = addWallFromSeed(
        doc, plan(0, 0), plan(4000, 0), 200, Justification.left);
    final fa = oracleFrameOf(doc, a);
    final x = addWallFromSeed(
        doc, oracleAt(fa, 1800, -900), oracleAt(fa, 1950, 900), 150, centre);
    final fx = oracleFrameOf(doc, x);
    doc.commands.clearHistory();
    final snap = SnapSettings(objectSnap: false);
    // The same press on A, where X crosses it, by a rig that has X frozen
    // from the start: the preview the tool must show once X is frozen.
    final q = oracleAt(fa, 1875, 60);
    final cold = directRig(doc, OpeningKind.door, frozen: {x}, snap: snap);
    hoverTo(cold, q);
    final want = [
      for (final (k, g) in cold.tool.debugPreview) [k, ...numbersOf(g)]
    ];
    expect(want, isNotEmpty, reason: 'premise: A hosts at q');

    // On X, away from A: X hosts while it is live.
    final frozen = <Handle>{};
    final rig = directRig(doc, OpeningKind.door, frozen: frozen, snap: snap);
    final p = oracleAt(fx, 1500, 30);
    hoverTo(rig, p);
    expect(rig.tool.debugPreview, isNotEmpty, reason: 'premise: X is live');
    frozen.add(x);
    hoverTo(rig, p);
    expect(rig.tool.debugPreview, isEmpty,
        reason: 'frozen since the last hover at this point: no host');

    // On A where X crosses it, by a second tool over its own services: X
    // is an obstacle while it is live.
    final frozen2 = <Handle>{};
    final rig2 = directRig(doc, OpeningKind.door, frozen: frozen2, snap: snap);
    hoverTo(rig2, q);
    List<List<Object>> preview() => [
          for (final (k, g) in rig2.tool.debugPreview) [k, ...numbersOf(g)]
        ];
    expect(preview(), isNot(want), reason: 'premise: X clamps the door');
    frozen2.add(x);
    hoverTo(rig2, q);
    expect(preview(), want,
        reason: 'frozen since the last hover at this point: no obstacle');
    expect(doc.commands.undoDepth, 0);
  });
}

// Spec 11 D12: the Dimension tool (I). Three clicks place one dimension in
// one undo step, its group at the identity: the first two points, then the
// dimension line's place. Without Shift the third click makes an aligned
// dimension; with it, a linear one by the side dragged to (R-21), with ortho
// off at the third click (R-20). Both ends are decided at the commit
// (decision 22), by position while F3 is on (decision 23), from candidates
// gathered against the document as it is then; any other end is fixed. The
// offset is D6's placement function. A degenerate second click is ignored
// (R-23); Esc drops pending points, Enter does nothing (R-33); the tool is
// not chained (R-25). I activates it, and a text field takes the letter
// (decision 10).
//
// Expected values are hand arithmetic beside the assertion. Every click
// states its aperture (10 px ÷ the camera's px/mm); every free click
// asserts that no object snap and no grid moved it. The relational cases
// run at the origin and at the corpus far origin in own groups; the
// world-axis cases (TL2, TL3) at the origin and at the corpus far origin
// unturned (the plan's Ruling 11-9).
import 'dart:math' as math;

import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/dimension.dart';
import 'package:floor_planner/parametric/dimension_attach.dart';
import 'package:floor_planner/parametric/dimension_tool.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/room_inputs.dart' show liveObjectsOf;
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/dimension_fixture.dart';

const l = WallSide.left, c = WallSide.centre, r = WallSide.right;

typedef Rig = ({DimensionTool tool, ToolContext ctx});

/// A Dimension tool over [doc] with a real [ToolContext]: a camera at
/// [pxPerMm] pixels per mm (the aperture is 10 px ÷ [pxPerMm]), object snap
/// as [objectSnap] says, and the document's page, if it has one (the grid).
Rig dimRig(DraftDocument doc, {double pxPerMm = 0.3, bool objectSnap = true}) {
  final index = SpatialIndex(doc);
  final camera = CameraController(ViewportTransform(
      worldToScreenMatrix: Transform2.scale(pxPerMm, pxPerMm)));
  final selection = SelectionController(doc);
  final snap = SnapSettings(objectSnap: objectSnap);
  final page = PageNotifier(doc);
  final tool = DimensionTool();
  addTearDown(() {
    tool.dispose();
    page.dispose();
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
        page: page,
        snap: snap),
  );
}

ToolPointerEvent pointerAt(Vector2 world,
        {int buttons = 0, bool shift = false}) =>
    ToolPointerEvent(
        screen: Offset.zero,
        world: world,
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 1);

void hoverTo(Rig rig, Vector2 world, {bool shift = false}) =>
    rig.tool.onPointerMove(pointerAt(world, shift: shift), rig.ctx);

/// A hover to [world], then a primary press there.
void clickAt(Rig rig, Vector2 world, {bool shift = false}) {
  hoverTo(rig, world, shift: shift);
  rig.tool.onPointerDown(
      pointerAt(world, buttons: kPrimaryButton, shift: shift), rig.ctx);
}

/// Premise for a free click at raw [raw] with no page: no object snap, and
/// the resolved point is [raw] itself (no grid).
void expectFree(Rig rig, Vector2 raw, String why) {
  expect(rig.ctx.page!.value, isNull, reason: '$why: premise: no page');
  expect(rig.tool.hoverKind, isNull, reason: '$why: premise: no object snap');
  expect([rig.tool.hoverPoint.x, rig.tool.hoverPoint.y], [raw.x, raw.y],
      reason: '$why: premise: the raw point');
}

/// Every live dimension, ascending.
List<Handle> dims(DraftDocument doc) => liveObjectsOf<DimensionParams>(doc);

DimensionParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<DimensionParams>(h)!;

/// Plan vector ([x], [y]) turned by [place]'s rotation: a plan direction in
/// world.
Vector2 turnedBy(Placement place, double x, double y) {
  final rad = place.deg * math.pi / 180;
  return Vector2(x * math.cos(rad) - y * math.sin(rad),
      x * math.sin(rad) + y * math.cos(rad));
}

/// A free 200 mm centred wall from world [s] to world [e], its group at the
/// identity, as the Wall tool commits it. Returns its handle.
Handle addWall(DraftDocument doc, Vector2 s, Vector2 e) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<WallParams>(
        h, WallParams(s.x, s.y, e.x, e.y, 200, Justification.centre)),
  ], label: 'Add wall'));
  return h;
}

String status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('status-text'))).data!;

Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

/// Pumps the shell over [doc] (keyed by [key], so a second document gets a
/// state of its own).
Future<PlannerView> pumpShell(
    WidgetTester tester, DraftDocument doc, String key) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: PlannerShell(key: ValueKey(key), document: doc)));
  await tester.pump();
  return tester.widget<PlannerView>(find.byType(PlannerView));
}

/// Sets [view]'s camera to [pxPerMm] pixels per mm, centred on world [at].
Future<void> centreOn(
    WidgetTester tester, PlannerView view, Vector2 at, double pxPerMm) async {
  final size = tester.getSize(find.byType(InteractionLayer));
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - pxPerMm * at.x, size.height / 2 - pxPerMm * at.y)
          .multiply(Transform2.scale(pxPerMm, pxPerMm)));
  await tester.pump();
}

/// A primary tap at world [p] through the shell.
Future<void> tapWorld(WidgetTester tester, PlannerView view, Vector2 p) async {
  final s = view.camera.value.worldToScreen(p);
  await tester.tapAt(
      tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y));
  await tester.pump();
}

void main() {
  for (final place in const [origin, corpusGroups]) {
    test(
        'TL1 three clicks place one dimension in one undo step; ends on '
        'wall end points attach, others are fixed; the tool then waits for a '
        'new first click, at $place', () {
      final plan = samplePlan(place);
      final doc = plan.doc;
      // A free wall F far east of the flat, its start (30,000.5, 12,000.25):
      // moved by a command mid-dimension below.
      final fEnd = plan.at(34000.5, 12000.25);
      final f = addWall(doc, plan.at(30000.5, 12000.25), fEnd);
      final rig = dimRig(doc); // 0.3 px/mm
      final tool = rig.tool;
      // The aperture: 10 px / 0.3 px/mm = 33.3 mm.
      expect(kSnapAperturePixels / 0.3, closeTo(33.33, 0.01));
      final [e1, _, _, _, p1, ...] = plan.walls;

      // -- The Hall's corners. E1/0/left: E1's inner face y = 8,125 + 125
      // meets E4's inner face x = 12,125 + 125, at (12,250, 8,250); it is
      // also E4/1/left (E4 runs south, its left face the inner one).
      // P1/0/left: P1 runs north from E1, its left face x = 17,000 − 60,
      // butting E1's inner face: (16,940, 8,250). Each click 5 mm off,
      // (3, 4) in the plan's frame, well inside the 33.3 mm aperture.
      final c0 = plan.at(12250, 8250), c1 = plan.at(16940, 8250);
      final depth = doc.commands.undoDepth;
      clickAt(rig, plan.at(12253, 8254));
      expect(tool.hoverKind, isNotNull, reason: 'premise: the corner snaps');
      expect((tool.hoverPoint - c0).length, lessThan(dimAttach.linear),
          reason: 'premise: onto the corner');
      clickAt(rig, plan.at(16937, 8254));
      expect(tool.hoverKind, isNotNull, reason: 'premise: the corner snaps');
      expect((tool.hoverPoint - c1).length, lessThan(dimAttach.linear),
          reason: 'premise: onto the corner');
      expect(tool.points, hasLength(2));
      expect(dims(doc), isEmpty, reason: 'two clicks place nothing');
      // The third click 900.25 mm up in the plan's frame, no Shift: aligned
      // along E1's face (u the plan's x, n its y), so the offset is the
      // height above both points, 9,150.25 − 8,250 = 900.25; nothing within
      // the aperture there.
      final q = plan.at(14600.5, 9150.25);
      clickAt(rig, q);
      expectFree(rig, q, 'the third click');
      final h = dims(doc).single;
      expect(doc.commands.undoDepth, depth + 1, reason: 'one undo step');
      final node = doc.tree[h]! as GroupNode;
      expect(node.parent, doc.rootHandle, reason: 'a root-level group');
      expect(node.transform.isIdentity, isTrue, reason: 'at the identity');
      final p = paramsOf(doc, h);
      // Aligned along E1 (σ_E1 = 0 at every placement), so the shared
      // corner is stored on E1, not E4.
      expect(p.a, AttachedEnd(e1, 0, l));
      expect(p.b, AttachedEnd(p1, 0, l));
      expect(p.kind, DimKind.aligned);
      expect(p.offset, closeTo(900.25, 1e-6));
      // The app's default page, metres: 16,940 − 12,250 = 4,690 mm, 4.69.
      expect(dimText(doc, h), '4.69');
      expect(driftOf(doc), isEmpty);
      // Not chained: no point pending, and the next click starts anew.
      expect(tool.points, isEmpty, reason: 'not chained');
      expect(tool.isPending, isFalse);
      final free = plan.at(15500.25, 9800.5);
      clickAt(rig, free);
      expectFree(rig, free, 'a new first click');
      expect(tool.points, hasLength(1));
      expect(dims(doc), [h], reason: 'a new first click places nothing');
      tool.cancel(rig.ctx);
      // One undo takes the group and its component away.
      doc.commands.undo();
      expect(doc.tree[h], isNull);
      expect(doc.components.get<DimensionParams>(h), isNull);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);

      // -- A fixed end: from the Hall corner to a mid-room point with
      // nothing within the aperture: that end is fixed at the raw world
      // point (the group is the identity), the corner still attached (the
      // pair runs (3,250.25, 1,550.5) in the plan: nearer E1's direction,
      // σ_E1 ≈ 0.43 < σ_E4 ≈ 0.90).
      clickAt(rig, plan.at(12253, 8254));
      clickAt(rig, free);
      expectFree(rig, free, 'the mid-room point');
      final q2 = plan.at(13000.5, 11000.75);
      clickAt(rig, q2);
      expectFree(rig, q2, 'the third click');
      final h2 = dims(doc).single;
      expect(paramsOf(doc, h2).a, AttachedEnd(e1, 0, l));
      expect(paramsOf(doc, h2).b, FixedEnd(free.x, free.y));
      expect(driftOf(doc), isEmpty);

      // -- The ends are gathered at the commit, against the document as it
      // is then (Ruling 11-8), and the handle is allocated in the build:
      // the second point lies in open space when it is placed; then another
      // edit raises the handle seed (a LINE far away), and a command moves
      // F's start exactly onto the second point. The commit attaches that
      // end to F's centre point, F/0/centre (R-4: the stored centreline
      // end), and places the dimension under the next handle.
      final x = plan.at(29000.25, 7500.5);
      clickAt(rig, plan.at(12253, 8254));
      clickAt(rig, x);
      expectFree(rig, x, 'the second point, in open space');
      expect(
          attachCandidates(doc, rig.ctx.index, x,
              objectSnap: true, thickest: thickestWall(doc)),
          isEmpty,
          reason: 'premise: nothing attaches there yet');
      doc.commands.execute(addDrafted(doc, EntityKind.line,
          linePayload(plan.at(40000.5, 30000.5), plan.at(40500.5, 30000.5))));
      doc.commands.execute(SetComponentCommand<WallParams>(
          f, WallParams(x.x, x.y, fEnd.x, fEnd.y, 200, Justification.centre)));
      final seed = doc.handleSeed.current.value;
      final q3 = plan.at(20000.5, 6000.75);
      clickAt(rig, q3);
      expectFree(rig, q3, 'the third click');
      final h3 = (dims(doc)..remove(h2)).single;
      expect(h3.value, seed + 1, reason: 'the handle after the other edit');
      // E1's direction: the pair runs (16,750.25, −749.5) in the plan.
      expect(paramsOf(doc, h3).a, AttachedEnd(e1, 0, l));
      expect(paramsOf(doc, h3).b, AttachedEnd(f, 0, c),
          reason: 'F\'s start, moved there after the second click');
      expect(driftOf(doc), isEmpty);

      // -- Decision 22 through the tool: the shared corner is decided at
      // the commit, with the committed kind's direction. AM3's L, B drawn
      // first (the lower handle): B (4000, 0) → (4000, 3000) and A (0, 0)
      // → (4000, 0), 200 centred, mitred at (4000, 0). The outer corner
      // (4100, −100) is B/0/right (B runs north, its right face x 4,100)
      // and A/1/right (A runs east, its right face y −100). The first click
      // 5 mm off it, the second at (3000, 3000), free.
      for (final shift in [false, true]) {
        final why = 'the outer corner, Shift $shift, $place';
        final lp = buildPlan(const [
          W(4000, 0, 4000, 3000, 200),
          W(0, 0, 4000, 0, 200),
        ], place: place);
        final ld = lp.doc;
        final [wb, wa] = lp.walls;
        final lr = dimRig(ld);
        final outer = lp.at(4100, -100), far = lp.at(3000, 3000);
        expect(
            attachCandidates(ld, lr.ctx.index, outer,
                objectSnap: true, thickest: thickestWall(ld)),
            [AttachedEnd(wb, 0, r), AttachedEnd(wa, 1, r)],
            reason: '$why: premise: both walls\' points');
        clickAt(lr, lp.at(4103, -104));
        expect(lr.tool.hoverKind, isNotNull, reason: '$why: premise: snaps');
        expect((lr.tool.hoverPoint - outer).length, lessThan(dimAttach.linear),
            reason: '$why: premise: onto the corner');
        clickAt(lr, far);
        expectFree(lr, far, why);
        final p0 = lr.tool.points[0];
        // Aligned: u runs (−1100, 3100) in the plan, sin to A's direction
        // 3100 / 3289.4 ≈ 0.94, to B's 1100 / 3289.4 ≈ 0.33: B, B/0/right.
        // Shift, the third click 1500 below both points in world, inside
        // their x span: e_y 1500 > e_x 0, horizontal, u = world x: σ_A =
        // sin 0° or sin 23°, σ_B = cos 0° or cos 23°: A, A/1/right, though
        // B has the lower handle.
        final q = shift
            ? Vector2((p0.x + far.x) / 2, math.min(p0.y, far.y) - 1500)
            : lp.at(1500.5, 1500.25);
        clickAt(lr, q, shift: shift);
        expectFree(lr, q, why);
        final got = paramsOf(ld, dims(ld).single);
        expect(got.kind, shift ? DimKind.horizontal : DimKind.aligned,
            reason: why);
        expect(got.a, shift ? AttachedEnd(wa, 1, r) : AttachedEnd(wb, 0, r),
            reason: why);
        expect(got.b, FixedEnd(far.x, far.y), reason: why);
        expect(driftOf(ld), isEmpty);
      }
    });
  }

  for (final place in const [origin, corpusAxis]) {
    test(
        'TL2 with Shift the third click is linear by the side dragged to, '
        'without it aligned; Shift at the second click is ortho, at the third '
        'it is not, at $place', () {
      // An empty document, F3 on, no page: every click is free. Points are
      // plan points added to the placement's translation (unturned).
      (Rig, DraftDocument) fresh() {
        final plan = buildPlan(const [], place: place);
        return (dimRig(plan.doc, pxPerMm: 1), plan.doc);
      }

      /// The dimension placed by clicks at [a], [b], [q], Shift as given at
      /// the second and third.
      DimensionParams place3(
          (double, double) a, (double, double) b, (double, double) q,
          {bool shift2 = false, bool shift3 = false}) {
        final (rig, doc) = fresh();
        for (final (i, (pt, shift))
            in [(a, false), (b, shift2), (q, shift3)].indexed) {
          final w = place.at(pt.$1, pt.$2);
          clickAt(rig, w, shift: shift);
          // An ortho-pinned second point is not the raw one.
          if (!(i == 1 && shift)) expectFree(rig, w, '$pt');
        }
        return paramsOf(doc, dims(doc).single);
      }

      const h = DimKind.horizontal, v = DimKind.vertical;
      // P0 (0, 0), P1 (3000, 1200): the spans x [0, 3000], y [0, 1200].
      for (final (q, shift, kind, offset) in [
        // Above: e_x 0, e_y 2000 − 1200 = 800 → horizontal; the line 800
        // above the upper point.
        ((1500.0, 2000.0), true, h, 800.0),
        // Right: e_x 500, e_y 0 → vertical; u = y, n = (−1, 0): h1 =
        // −3000, hq = −3500, below lo by 500 → −500.
        ((3500.0, 600.0), true, v, -500.0),
        // e_x 600 < e_y 800 → horizontal, 800.
        ((3600.0, 2000.0), true, h, 800.0),
        // e_x 900 > e_y 300 → vertical; hq −3900 → −900.
        ((3900.0, 1500.0), true, v, -900.0),
        // A tie inside the span box: |dx| 3000 ≥ |dy| 1200 → horizontal;
        // between the heights 0 and 1200, 600 from each: the upper, +0.0.
        ((1500.0, 600.0), true, h, 0.0),
      ]) {
        final p = place3((0, 0), (3000, 1200), q, shift3: shift);
        expect(p.kind, kind, reason: '$q');
        expect(p.offset, offset, reason: '$q');
        expect(p.offset.isNegative, offset.isNegative, reason: '$q');
      }
      // The same tie point without Shift: aligned. (1500, 600) lies on the
      // pair's line (1200 / 3000 = 600 / 1500), so the offset is 0.
      final aligned = place3((0, 0), (3000, 1200), (1500, 600));
      expect(aligned.kind, DimKind.aligned);
      expect(aligned.offset, closeTo(0, 1e-9));
      // A vertical pair dragged above: horizontal would measure |dx| = 0,
      // so vertical; q on the pair's line, offset +0.0.
      final pair = place3((0, 0), (0, 3000), (0, 3600), shift3: true);
      expect(pair.kind, DimKind.vertical, reason: 'the zero kind swapped');
      expect(pair.offset, 0.0);
      // The same within the tolerance: a pair 5e-7 mm apart in x (not
      // exactly 0, but ≤ wallJoin.linear, 1e-6) dragged above is vertical.
      final (rigT, docT) = fresh();
      final t0 = place.at(0, 0), t1 = t0 + Vector2(5e-7, 3000);
      clickAt(rigT, t0);
      clickAt(rigT, t1);
      expect(rigT.tool.points, hasLength(2));
      final tdx = rigT.tool.points[1].x - rigT.tool.points[0].x;
      expect(tdx, isNot(0.0), reason: 'premise: dx is not exactly 0');
      expect(tdx, lessThanOrEqualTo(wallJoin.linear), reason: 'premise');
      final tq = t0 + Vector2(0, 3600);
      clickAt(rigT, tq, shift: true);
      expectFree(rigT, tq, 'the near-vertical pair');
      expect(paramsOf(docT, dims(docT).single).kind, DimKind.vertical,
          reason: 'the zero kind within the tolerance swapped');

      // Ortho is off at the third click: a raw (1500, 1400) with Shift is
      // horizontal with the line at y 1,400, offset 1400 − 1200 = +200. An
      // ortho-pinned (1500, 1200) (from P1, |dx| 1500 > |dy| 200) would
      // have been a tie, +0.0, the line at 1,200.
      final (rig, doc) = fresh();
      clickAt(rig, place.at(0, 0));
      clickAt(rig, place.at(3000, 1200));
      final q = place.at(1500, 1400);
      clickAt(rig, q, shift: true);
      expectFree(rig, q, 'the third click, Shift held');
      final d = dims(doc).single;
      expect(paramsOf(doc, d).kind, DimKind.horizontal);
      expect(paramsOf(doc, d).offset, 200);
      final line = dimLines(doc, d).first;
      expect([line.$1.y, line.$2.y], [q.y, q.y], reason: 'the line at 1,400');

      // Ortho is on at the second click: from P0 (0, 0), a raw (3000,
      // 1250) with Shift is pinned to (3000, 0). Released before the third
      // (Review Focus #2): the third click at (1500, 2000) is aligned, 2000
      // above the pair.
      final (rig2, doc2) = fresh();
      clickAt(rig2, place.at(0, 0));
      clickAt(rig2, place.at(3000, 1250), shift: true);
      final pinned = place.at(3000, 0);
      expect(
          [rig2.tool.points[1].x, rig2.tool.points[1].y], [pinned.x, pinned.y],
          reason: 'ortho from the first point');
      clickAt(rig2, place.at(1500, 2000));
      final p2 = paramsOf(doc2, dims(doc2).single);
      expect(p2.kind, DimKind.aligned, reason: 'Shift released: aligned');
      expect(p2.b, FixedEnd(pinned.x, pinned.y));
      expect(p2.offset, 2000);
    });

    test(
        'TL3 the third click\'s offset runs from the outermost point, '
        'sticks to the nearer extreme inside the band, and keeps its side in '
        'the sign bit, at $place', () {
      // Horizontal over (0, 0) and (3000, 1200), Shift held, the third
      // click at x 1500: u = x, n = y, the heights 0 and 1200.
      for (final (y, offset, lineY) in const [
        // Above the upper point: 2000 − 1200 = +800, the line at 2,000.
        (2000.0, 800.0, 2000.0),
        // Below the lower: −(0 − (−300)) = −300, the line at −300.
        (-300.0, -300.0, -300.0),
        // Between, 300 from the upper and 900 from the lower: the upper,
        // +0.0, the line through (3000, 1200).
        (900.0, 0.0, 1200.0),
        // Between, 800 from the upper and 400 from the lower: the lower,
        // −0.0, the line through (0, 0).
        (400.0, -0.0, 0.0),
      ]) {
        final plan = buildPlan(const [], place: place);
        final doc = plan.doc;
        final rig = dimRig(doc, pxPerMm: 1);
        clickAt(rig, place.at(0, 0));
        clickAt(rig, place.at(3000, 1200));
        final q = place.at(1500, y);
        clickAt(rig, q, shift: true);
        expectFree(rig, q, 'y $y');
        final d = dims(doc).single;
        final p = paramsOf(doc, d);
        expect(p.kind, DimKind.horizontal, reason: 'y $y');
        expect(p.offset, offset, reason: 'y $y');
        expect(p.offset.isNegative, offset.isNegative,
            reason: 'y $y: the side is the sign bit');
        final line = dimLines(doc, d).first;
        final want = place.at(0, lineY).y;
        expect(line.$1.y, closeTo(want, 1e-6), reason: 'y $y: the line');
        expect(line.$2.y, closeTo(want, 1e-6), reason: 'y $y: the line');
      }
    });
  }

  testWidgets(
      'TL4 Esc drops one or two pending points and places nothing, and Esc '
      'again returns to Select; a second click on the first point, or on the '
      'same wall end point 5 µm away, is ignored; Enter with points pending '
      'does nothing', (tester) async {
    for (final place in const [origin, corpusGroups]) {
      final plan = buildPlan([...sampleWalls(), sampleColumn],
          seps: const [sampleSeparator],
          openings: sampleOpenings,
          place: place,
          measurer: FlutterTextMeasurer());
      plan.system.dispose();
      plan.doc.commands.clearHistory();
      final doc = plan.doc;
      final view = await pumpShell(tester, doc, place.name);
      // The Hall's inner corner E1/0/left, (12,250, 8,250); the camera at
      // 0.3 px/mm on it: the aperture is 10 / 0.3 = 33.3 mm.
      final corner = plan.at(12250, 8250);
      await centreOn(tester, view, corner, 0.3);
      await press(tester, LogicalKeyboardKey.keyI);
      expect(status(tester), 'Dimension', reason: '$place');
      final tool = view.tools.active as DimensionTool;
      final near = plan.at(12253, 8254); // 5 mm off
      // Two points in the Hall, 650 mm and more from every wall (about
      // 200 px from the corner on screen, inside the canvas).
      final free = plan.at(12900.25, 8900.5);
      final free2 = plan.at(13300.75, 9150.25);
      final depth = doc.commands.undoDepth;

      // Esc with one point, then with two: nothing is placed.
      await tapWorld(tester, view, near);
      expect(tool.points, hasLength(1));
      expect((tool.points.first - corner).length, lessThan(dimAttach.linear),
          reason: 'premise: the click snaps onto the corner');
      await press(tester, LogicalKeyboardKey.escape);
      expect(tool.points, isEmpty);
      expect(status(tester), 'Dimension', reason: 'still the tool');
      await tapWorld(tester, view, near);
      await tapWorld(tester, view, free);
      expect(tool.points, hasLength(2));
      expect(tool.hoverKind, isNull, reason: 'premise: a free point');
      await press(tester, LogicalKeyboardKey.escape);
      expect(tool.points, isEmpty);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);

      // A second click on the first point: on the corner (both resolve to
      // the same stored vertex), and at a free point (the same raw point),
      // leaves one point pending.
      await tapWorld(tester, view, near);
      await tapWorld(tester, view, near);
      expect([
        tool.hoverPoint.x,
        tool.hoverPoint.y
      ], [
        tool.points.first.x,
        tool.points.first.y
      ], reason: 'premise: the same point');
      expect(tool.points, hasLength(1), reason: 'the corner twice');
      await press(tester, LogicalKeyboardKey.escape);
      await tapWorld(tester, view, free);
      await tapWorld(tester, view, free);
      expect(tool.hoverKind, isNull, reason: 'premise: a free point');
      expect([
        tool.hoverPoint.x,
        tool.hoverPoint.y
      ], [
        tool.points.first.x,
        tool.points.first.y
      ], reason: 'premise: the same point');
      expect(tool.points, hasLength(1), reason: 'a free point twice');

      // Enter with one point pending, then with two: nothing changes.
      final one = Vector2.copy(tool.points.first);
      await press(tester, LogicalKeyboardKey.enter);
      expect(tool.points, [one]);
      await tapWorld(tester, view, free2);
      expect(tool.points, hasLength(2));
      final two = Vector2.copy(tool.points[1]);
      await press(tester, LogicalKeyboardKey.enter);
      expect(tool.points, [one, two]);
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth);
      await press(tester, LogicalKeyboardKey.escape);

      // The same wall end point 5 µm away, at a legal zoom (0.052 px/mm:
      // the aperture is 10 / 0.052 = 192.3 mm). A fixed 500 mm grid, snap
      // on, whose origin is a node 5e-6 mm east of the outer corner
      // (12,000, 8,000), E1/0/right (E1's right face y 8,125 − 125 meets
      // E4's x 12,125 − 125). The first click, 5 mm off the corner, snaps
      // onto it (an object snap beats the grid). The second, (−170, −170)
      // from the corner in the plan's frame (240.4 mm, beyond the
      // aperture; turned 23°, about (−90, −223) in world, within 250 of
      // the node on both axes), resolves by the grid to the node.
      // 5e-6 > wallJoin.linear (1e-6), but both points' candidates hold
      // E1/0/right, 5e-6 < dimAttach.linear (1e-5): the click is ignored.
      final outer = plan.at(12000, 8000);
      final node = outer + Vector2(5e-6, 0);
      final page = PageComponent(
          originX: node.x, originY: node.y, gridStepMm: 500, snapToGrid: true);
      attachPage(doc, page);
      await tester.pump();
      await tester.pump();
      expect(view.page.value, page, reason: 'premise: the shell reads it');
      const pxPerMm = 0.052;
      expect(kSnapAperturePixels / pxPerMm, closeTo(192.3, 0.05));
      expect(dragGridStepMm(page, pxPerMm), 500);
      await centreOn(tester, view, outer, pxPerMm);
      await tapWorld(tester, view, outer + turnedBy(place, -3, -4));
      expect(tool.hoverKind, isNotNull, reason: 'premise: the corner snaps');
      final p0 = Vector2.copy(tool.points.single);
      expect((p0 - outer).length, lessThan(1e-7),
          reason: 'premise: onto the corner');
      final raw1 = outer + turnedBy(place, -170, -170);
      expect((raw1 - outer).length, closeTo(240.4, 0.05));
      await tapWorld(tester, view, raw1);
      expect(tool.hoverKind, isNull, reason: 'premise: no object snap');
      final p1 = Vector2.copy(tool.hoverPoint);
      expect([p1.x, p1.y], [node.x, node.y], reason: 'premise: the grid node');
      expect((p1 - p0).length, greaterThan(wallJoin.linear),
          reason: 'premise: not the same point');
      final index = SpatialIndex(doc);
      final t = thickestWall(doc);
      final at0 =
          attachCandidates(doc, index, p0, objectSnap: true, thickest: t);
      final at1 =
          attachCandidates(doc, index, p1, objectSnap: true, thickest: t);
      index.dispose();
      final e1 = plan.walls[0];
      expect(at0, contains(AttachedEnd(e1, 0, r)), reason: 'premise');
      expect(at1, contains(AttachedEnd(e1, 0, r)), reason: 'premise');
      expect(tool.points, [p0], reason: 'the same wall end point: ignored');

      // Esc drops it; Esc again returns to Select.
      await press(tester, LogicalKeyboardKey.escape);
      expect(tool.points, isEmpty);
      expect(status(tester), 'Dimension');
      await press(tester, LogicalKeyboardKey.escape);
      expect(status(tester), 'Select');
      expect(dims(doc), isEmpty);
      expect(doc.commands.undoDepth, depth + 1, reason: 'the page alone');
    }
  });

  for (final place in const [origin, corpusGroups]) {
    test(
        'TL6 decision 23 through the tool: with F3 on a grid point on a '
        'corner attaches and a flush door\'s jamb snap attaches the stem\'s '
        'corner; with F3 off every end is fixed, at $place', () {
      // -- The grid (the plan's Ruling 11-23). The sample's outer corner
      // (12,000, 8,000): E1's right face (y 8,125 − 125) meets E4's right
      // face (x 12,125 − 125); E1/0/right and E4/1/right. A fixed 500 mm
      // grid whose origin is the corner's world point, so the corner is a
      // grid node at every placement (the grid is laid in world axes).
      for (final objectSnap in [true, false]) {
        final why = 'grid, F3 ${objectSnap ? 'on' : 'off'}, $place';
        final plan = samplePlan(place);
        final doc = plan.doc;
        final corner = plan.at(12000, 8000);
        final page = PageComponent(
            originX: corner.x,
            originY: corner.y,
            gridStepMm: 500,
            snapToGrid: true);
        attachPage(doc, page);
        // 0.052 px/mm: the aperture is 10 / 0.052 = 192.3 mm.
        const pxPerMm = 0.052;
        const aperture = kSnapAperturePixels / pxPerMm;
        expect(aperture, closeTo(192.3, 0.05));
        final rig = dimRig(doc, pxPerMm: pxPerMm, objectSnap: objectSnap);
        expect(rig.ctx.page!.value, page, reason: 'premise: the page');
        expect(dragGridStepMm(page, pxPerMm), 500);

        /// Premise: [raw] resolves by the grid alone, onto [node] exactly.
        void onGrid(Vector2 raw, Vector2 node, {bool shift = false}) {
          final out = DragPoint();
          resolveDragPoint(
              raw: raw,
              orthoBase: null,
              index: rig.ctx.index,
              apertureWorld: aperture,
              objectSnap: true,
              page: page,
              gridStepMm: 500,
              scratch: SnapResult(),
              out: out);
          expect(out.objectKind, isNull, reason: '$why: premise: no snap');
          expect(out.grid, isTrue, reason: '$why: premise: the grid');
          expect([out.point.x, out.point.y], [node.x, node.y],
              reason: '$why: premise: the node');
          clickAt(rig, raw, shift: shift);
          expect(rig.tool.hoverKind, isNull, reason: '$why: no object snap');
          expect(
              [rig.tool.hoverPoint.x, rig.tool.hoverPoint.y], [node.x, node.y],
              reason: '$why: the tool resolves the node');
        }

        // The pointer (−170, −170) from the corner in the plan's frame:
        // |·| = 170 √2 = 240.4 mm, beyond the aperture; turned 23° it is
        // (−90.1, −222.9) in world, within 250 of the corner on both axes,
        // so it rounds to the corner on the 500 mm grid.
        final raw0 = corner + turnedBy(place, -170, -170);
        expect((raw0 - corner).length, closeTo(240.4, 0.05));
        onGrid(raw0, corner);
        // The second point, the node (3000, −1000) from the corner in
        // world, raw (37.5, −52.25) off it: south of the flat, in open
        // space at both placements.
        final n1 = corner + Vector2(3000, -1000);
        onGrid(n1 + Vector2(37.5, -52.25), n1);
        // The third, Shift held, the node (1500, −2500): e_x 0, e_y
        // 2500 − 1000 = 1500 → horizontal; n = y, the heights 0 and −1000,
        // hq −2500: −(−1000 − (−2500)) = −1500.
        final n2 = corner + Vector2(1500, -2500);
        onGrid(n2 + Vector2(20.5, -30.25), n2, shift: true);
        final p = paramsOf(doc, dims(doc).single);
        expect(p.kind, DimKind.horizontal, reason: why);
        expect(p.offset, closeTo(-1500, 1e-6), reason: why);
        // F3 on: the grid point on the corner attaches, on E1 (horizontal,
        // world x: σ_E1 = sin 0° or sin 23°, less than σ_E4 = cos 0° or
        // cos 23°). F3 off: fixed at the corner.
        expect(
            p.a,
            objectSnap
                ? AttachedEnd(plan.walls[0], 0, r)
                : FixedEnd(corner.x, corner.y),
            reason: why);
        expect(p.b, FixedEnd(n1.x, n1.y), reason: why);
        expect(driftOf(doc), isEmpty);
      }

      // -- The jamb (the plan's Ruling 11-7). Spike C5's T with a 900 mm
      // door on the stem S at c = 450, swinging left: the cut is clamped
      // flush with S's butt end on C's face, so S/0/left, (2,500 − 50,
      // 100), is the door's jamb corner and no vertex of S. At 0.3 px/mm
      // (a 33.3 mm aperture) a click 5 mm off it snaps there.
      for (final objectSnap in [true, false]) {
        final why = 'jamb, F3 ${objectSnap ? 'on' : 'off'}, $place';
        final plan = flushT(place);
        final doc = plan.doc;
        final rig = dimRig(doc, objectSnap: objectSnap);
        final jamb = plan.at(2450, 100);
        final raw0 = plan.at(2453, 104);
        clickAt(rig, raw0);
        if (objectSnap) {
          expect(rig.tool.hoverKind, SnapKind.endpoint,
              reason: '$why: premise: the jamb snaps');
          expect(
              (rig.tool.hoverPoint - jamb).length, lessThan(dimAttach.linear),
              reason: '$why: premise: onto the jamb corner');
        } else {
          expectFree(rig, raw0, why);
        }
        final raw1 = plan.at(1000.25, 1500.5);
        clickAt(rig, raw1);
        expectFree(rig, raw1, why);
        final q = plan.at(1700.75, 2200.25);
        clickAt(rig, q);
        expectFree(rig, q, why);
        final p = paramsOf(doc, dims(doc).single);
        expect(
            p.a,
            objectSnap
                ? AttachedEnd(plan.walls[1], 0, l)
                : FixedEnd(raw0.x, raw0.y),
            reason: why);
        expect(p.b, FixedEnd(raw1.x, raw1.y), reason: why);
        expect(driftOf(doc), isEmpty);
      }
    });
  }

  testWidgets(
      'TL7 I activates the Dimension tool from the canvas and the palette; '
      'typing I into a panel text field switches nothing', (tester) async {
    final doc = startupPlan(FlutterTextMeasurer());
    final view = await pumpShell(tester, doc, 'startup');
    expect(status(tester), 'Select');
    await press(tester, LogicalKeyboardKey.keyI);
    expect(status(tester), 'Dimension', reason: 'I on the canvas');
    expect(view.tools.active, isA<DimensionTool>());
    await press(tester, LogicalKeyboardKey.keyV);
    expect(status(tester), 'Select');
    await tester.tap(find.byKey(const Key('tool-dimension')));
    await tester.pump();
    expect(status(tester), 'Dimension', reason: 'the palette entry');
    await press(tester, LogicalKeyboardKey.keyV);

    // The Hall's Name field, focused: I types into it.
    final hall = doc.components
        .withComponent<RoomParams>()
        .firstWhere((h) => doc.components.get<RoomParams>(h)!.name == 'Hall');
    view.selection.replace([SelectionKey.root(hall)]);
    await tester.pump();
    final status0 = status(tester);
    expect(status0, startsWith('Select'));
    final name = find.byKey(const Key('room-name'));
    await tester.tap(name);
    await tester.pump();
    tester.testTextInput.enterText('');
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyI), isFalse,
        reason: 'I reaches the platform as text');
    tester.testTextInput.enterText('I');
    await tester.pump();
    expect(tester.widget<TextField>(name).controller!.text, 'I');
    expect(status(tester), status0, reason: 'I switched no tool');
    expect(view.tools.active, isNot(isA<DimensionTool>()));
  });
}

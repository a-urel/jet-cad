import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/catalog.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_grips.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/wall_fixture.dart';
import 'support/wall_shell.dart';

// Spec 07 D11: the end grips, through the shell. Every wall sits at the far
// origin in its own rotated group (`groupAt`, or a spoke's group at its
// hub), the plan is turned 23 degrees, and the camera is rotated.

/// The camera's scale in pixels per mm: the snap aperture is ~67 mm.
const double _scale = 0.15;

/// The page's fixed grid step.
const double _gridStep = 10;

/// A 1:20 page near the far origin with grid snap on at [_gridStep], and
/// the walls [build] adds, with no undo history.
DraftDocument gripDoc(
    FlutterTextMeasurer m, void Function(DraftDocument doc) build) {
  final doc = DraftDocument.empty(measurer: m);
  PageComponent.register(doc.components);
  doc.commands.execute(SetComponentCommand<PageComponent>(
      doc.rootHandle,
      PageComponent(
          scaleDenominator: 20,
          originX: ox - 2000,
          originY: oy - 2000,
          gridStepMm: _gridStep)));
  // The shell installs the parametric system itself; the walls are added
  // through a temporary one, which regenerates them as they are created.
  final system = installParametric(doc);
  build(doc);
  system.dispose();
  doc.commands.clearHistory();
  return doc;
}

/// Pumps the shell, then sets a rotated, non-reflecting camera centred on
/// [centre].
Future<PlannerView> pumpGrips(
    WidgetTester tester, DraftDocument doc, Vector2 centre) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home: PlannerShell(document: doc)));
  await tester.pump();
  final view = tester.widget<PlannerView>(find.byType(PlannerView));
  final size = tester.getSize(find.byType(InteractionLayer));
  final linear =
      Transform2.rotation(0.35).multiply(Transform2.scale(_scale, _scale));
  final mid = linear.transformPoint(centre);
  view.camera.value = ViewportTransform(
      worldToScreenMatrix: Transform2.translation(
              size.width / 2 - mid.x, size.height / 2 - mid.y)
          .multiply(linear));
  await tester.pump();
  return view;
}

Offset globalOf(WidgetTester tester, PlannerView view, Vector2 p) {
  final s = view.camera.value.worldToScreen(p);
  return tester.getTopLeft(find.byType(InteractionLayer)) + Offset(s.x, s.y);
}

/// Selects wall [h] with a click in the middle of its band, 40% along it,
/// away from both of its grips.
Future<void> selectWall(WidgetTester tester, PlannerView view, Handle h) async {
  final w = worldWallOf(view.document, h);
  final n = Vector2(-w.d.y, w.d.x);
  final (l, r) = facesOf(view.document.components.get<WallParams>(h)!);
  await tester.tapAt(
      globalOf(tester, view, w.s + (w.e - w.s) * 0.4 + n * ((l + r) / 2)));
  await tester.pump();
  expect(view.selection.keys, [SelectionKey.root(h)]);
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(
    WidgetTester tester, PlannerView view, Vector2 from, Vector2 to) async {
  final a = globalOf(tester, view, from), b = globalOf(tester, view, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// The page's grid point nearest [p]: where a drag released near [p]
/// lands when no object snap is near.
Vector2 gridOf(DraftDocument doc, Vector2 p) => snapToGrid(
    p, _gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// Wall [h]'s end [k] in world.
Vector2 endOf(DraftDocument doc, Handle h, int k) =>
    worldWallOf(doc, h).endpoint(k);

/// The shown grips of wall [h], as (index, x, y).
List<(int, double, double)> gripsOf(PlannerView view, Handle h) => [
      for (final r in view.grips.grips)
        if (r.key == SelectionKey.root(h)) (r.grip.index, r.grip.x, r.grip.y),
    ];

const Handle wa = Handle(1300), wb = Handle(2600), wc = Handle(3900);

/// An L at the far origin: A (200, centre) runs into [lCorner] and B (115,
/// left) runs out of it at 110 degrees, each in its own rotated group, so
/// their ends at the corner meet within rounding, not bitwise. C (150,
/// right) starts 3 mm from the corner: near it, but not joined.
final Vector2 lStart = plan(0, 0), lCorner = plan(3000, 0);
final Vector2 lEnd = polar(lCorner, 23 + 110, 2500);
final Vector2 cStart = polar(lCorner, 23 - 120, 3);

void addL(DraftDocument doc, {bool withC = true}) {
  doc.commands
      .execute(addWall(doc, wa, lStart, lCorner, 200, Justification.centre));
  doc.commands
      .execute(addWall(doc, wb, lCorner, lEnd, 115, Justification.left));
  if (withC) {
    doc.commands.execute(addWall(doc, wc, cStart, polar(cStart, 23 - 120, 1500),
        150, Justification.right));
  }
}

void main() {
  testWidgets(
      'EG1 a free end drags to the resolved point, stored in its own group, '
      'the other end untouched; one undo step; a degenerate drop is refused, '
      'and a drag back onto the grip dispatches nothing', (tester) async {
    final doc = gripDoc(FlutterTextMeasurer(), (doc) {
      doc.commands.execute(addWall(
          doc, wa, plan(0, 0), plan(3000, 400), 200, Justification.centre));
    });
    final view = await pumpGrips(tester, doc, plan(1500, 400));
    final before = canon(doc);
    final p0 = doc.components.get<WallParams>(wa)!;
    await selectWall(tester, view, wa);
    final q = gridOf(doc, plan(3300, 1200));
    await dragWorld(tester, view, endOf(doc, wa, 1), q);
    expect(doc.commands.undoDepth, 1);
    final p = doc.components.get<WallParams>(wa)!;
    expect(xy(p.start), xy(p0.start), reason: 'the start is untouched');
    final local = doc.tree.accumulatedTransform(wa).invert().transformPoint(q);
    expect(xy(p.end), xy(local), reason: "the group's local space, exactly");
    expect((endOf(doc, wa, 1) - q).length, lessThan(1e-6));
    expect([p.thickness, p.justification], [200, Justification.centre]);
    expectSquare(doc, wa);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);

    // Dropped onto its own start (object snap puts it there): the wall
    // would be degenerate, so the drag is refused and nothing changes.
    await dragWorld(
        tester, view, endOf(doc, wa, 1), endOf(doc, wa, 0) + Vector2(4, -3));
    expect(doc.commands.undoDepth, 0);
    expect(canon(doc), before);
    // Dragged out and back onto itself: the release resolves onto the
    // grip's own point, so the drag is a no-op and dispatches nothing
    // (Task 7 review, m1).
    final end = endOf(doc, wa, 1);
    final a = globalOf(tester, view, end);
    final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
    await gesture.down(a);
    await gesture.moveTo(a + const Offset(12, 0));
    await gesture.moveTo(globalOf(tester, view, plan(3600, 1500)));
    await tester.pump();
    await gesture.moveTo(a);
    await gesture.up();
    await gesture.removePointer();
    await tester.pump();
    expect(doc.commands.undoDepth, 0);
    expect(canon(doc), before);
    final g = WallGrips().gripsOf(doc, wa)[1];
    expect(WallGrips().drag(doc, wa, g, endOf(doc, wa, 0)), isNull);
    expect(WallGrips().preview(doc, wa, g, endOf(doc, wa, 0)), isEmpty);
  });

  testWidgets(
      'EG2 a selected wall shows two grips at the world endpoints of its '
      'rotated group; after a drag they sit at the new world endpoints',
      (tester) async {
    final doc = gripDoc(FlutterTextMeasurer(), (doc) => addL(doc));
    final view = await pumpGrips(tester, doc, lCorner);
    await selectWall(tester, view, wb);
    final w = worldWallOf(doc, wb);
    expect(gripsOf(view, wb), [(0, w.s.x, w.s.y), (1, w.e.x, w.e.y)],
        reason: 'bitwise where WorldWall puts them');
    expect(view.grips.grips.every((r) => r.object), isTrue);
    final local = doc.components.get<WallParams>(wb)!;
    expect((local.start - w.s).length, greaterThan(1000),
        reason: 'the group is not at the identity');
    final q = gridOf(doc, polar(lEnd, 23 + 20, 600));
    await dragWorld(tester, view, w.e, q);
    final after = worldWallOf(doc, wb);
    expect(xy(after.s), xy(w.s));
    expect((after.e - q).length, lessThan(1e-6));
    expect(gripsOf(view, wb),
        [(0, after.s.x, after.s.y), (1, after.e.x, after.e.y)]);
  });

  testWidgets(
      "EG3 dragging an L's shared end moves both walls' ends in one undo "
      'step, still mitred; a wall 3 mm off stays (Review Focus 3, M-07q)',
      (tester) async {
    final doc = gripDoc(FlutterTextMeasurer(), (doc) => addL(doc));
    expect((endOf(doc, wa, 1) - endOf(doc, wb, 0)).length,
        inExclusiveRange(0, wallJoin.linear),
        reason: 'joined within rounding, not bitwise');
    expectMitre(doc, wa, wb);
    final view = await pumpGrips(tester, doc, lCorner);
    final before = canon(doc);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    final pc = doc.components.get<WallParams>(wc)!;
    await selectWall(tester, view, wa);
    final q = gridOf(doc, plan(3500, -400));
    await dragWorld(tester, view, endOf(doc, wa, 1), q);
    expect(doc.commands.undoDepth, 1, reason: 'one undo step');
    for (final (h, k) in [(wa, 1), (wb, 0)]) {
      final local = doc.tree.accumulatedTransform(h).invert().transformPoint(q);
      final p = doc.components.get<WallParams>(h)!;
      expect(xy(k == 0 ? p.start : p.end), xy(local),
          reason: "${h.toHex()} in its own group's local space");
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6));
    }
    expect(xy(doc.components.get<WallParams>(wa)!.start), xy(pa.start));
    expect(xy(doc.components.get<WallParams>(wb)!.end), xy(pb.end));
    expect(doc.components.get<WallParams>(wc), pc, reason: 'C is not joined');
    expectMitre(doc, wa, wb);
    expectSquare(doc, wc);
    expect(driftOf(doc), isEmpty);
    expect(diagnosticsOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);
    expectMitre(doc, wa, wb);

    // The provider directly: the command's members ascend by handle, and
    // the preview is both moved centrelines, in world.
    final grips = WallGrips();
    final g = grips.gripsOf(doc, wa)[1];
    final c = grips.drag(doc, wa, g, q)! as CompoundCommand;
    expect([
      for (final m in c.children) (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb
    ]);
    final pieces = grips.preview(doc, wa, g, q);
    expect(pieces.map((p) => p.$1), [EntityKind.line, EntityKind.line]);
    final [a0, a1] = pointsOf(pieces[0].$2);
    final [b0, b1] = pointsOf(pieces[1].$2);
    expect((a0 - lStart).length, lessThan(1e-6));
    for (final p in [a1, b0]) {
      expect((p - q).length, lessThan(1e-6));
    }
    expect((b1 - lEnd).length, lessThan(1e-6));
    // Another grip of the same wall, through the same provider: A's free
    // start moves alone.
    final g0 = grips.gripsOf(doc, wa)[0];
    expect(grips.preview(doc, wa, g0, q), hasLength(1));

    // A degenerate wall D sitting on the corner joins nothing (D2): the
    // drag still moves A and B, and leaves D where it is.
    const wd = Handle(5200);
    doc.commands
        .execute(addWall(doc, wd, lCorner, lCorner, 90, Justification.centre));
    final d = grips.drag(doc, wa, grips.gripsOf(doc, wa)[1], q);
    expect([
      for (final m in (d! as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb
    ]);
  });

  testWidgets(
      "EG4 a three-way node's end drags all three walls' ends, one undo "
      'step', (tester) async {
    final hub = plan(1500, 1500);
    const spokes = [
      (wa, 20.0, 200.0, Justification.centre, true),
      (wb, 140.0, 115.0, Justification.left, false),
      (wc, 255.0, 150.0, Justification.right, true),
    ];
    final doc = gripDoc(FlutterTextMeasurer(), (doc) {
      for (final (h, deg, t, j, fromHub) in spokes) {
        doc.commands.execute(
            addSpoke(doc, h, hub, deg + 23, 2000, t, j, fromHub: fromHub));
      }
    });
    int hubEnd(bool fromHub) => fromHub ? 0 : 1;
    final far = {
      for (final (h, _, _, _, fromHub) in spokes)
        h: endOf(doc, h, 1 - hubEnd(fromHub)),
    };
    final view = await pumpGrips(tester, doc, hub);
    final before = canon(doc);
    await selectWall(tester, view, wb);
    final q = gridOf(doc, polar(hub, 23 + 80, 500));
    await dragWorld(tester, view, endOf(doc, wb, 1), q);
    expect(doc.commands.undoDepth, 1);
    for (final (h, _, _, _, fromHub) in spokes) {
      final k = hubEnd(fromHub);
      expect((endOf(doc, h, k) - q).length, lessThan(1e-6),
          reason: '${h.toHex()} follows');
      expect(xy(endOf(doc, h, 1 - k)), xy(far[h]!),
          reason: '${h.toHex()} keeps its far end');
      expect(worldOutline(doc, h), isNotEmpty);
    }
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expect(canon(doc), before);
    // One command per wall, ascending by handle, whichever end is dragged.
    final grips = WallGrips();
    final c = grips.drag(doc, wb, grips.gripsOf(doc, wb)[1], q);
    expect([
      for (final m in (c! as CompoundCommand).children)
        (m as SetComponentCommand<WallParams>).handle
    ], [
      wa,
      wb,
      wc
    ]);
  });

  testWidgets(
      'EG5 a whole-wall move detaches it: the moved wall and its old '
      'neighbour both square their ends, in one step', (tester) async {
    final doc =
        gripDoc(FlutterTextMeasurer(), (doc) => addL(doc, withC: false));
    expectMitre(doc, wa, wb);
    final pa = doc.components.get<WallParams>(wa)!;
    final pb = doc.components.get<WallParams>(wb)!;
    final view = await pumpGrips(tester, doc, lCorner);
    await selectWall(tester, view, wb);
    // A body drag from inside B's band, 700 mm away from A.
    final w = worldWallOf(doc, wb);
    final from = w.s + (w.e - w.s) * 0.5;
    await dragWorld(tester, view, from, polar(from, 23 - 30, 700));
    expect(doc.commands.undoDepth, 1);
    expect(doc.components.get<WallParams>(wb), pb,
        reason: 'a move changes the group, not the parameters');
    expect(doc.components.get<WallParams>(wa), pa);
    expect((endOf(doc, wb, 0) - lCorner).length, greaterThan(500));
    expectSquare(doc, wa);
    expectSquare(doc, wb);
    expect(driftOf(doc), isEmpty);
    await undoKey(tester);
    expectMitre(doc, wa, wb);
  });
}

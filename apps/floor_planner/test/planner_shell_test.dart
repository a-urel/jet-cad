import 'package:floor_planner/main.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The sample plan's wall whose stored start is (`sx`, `sy`) and end is
/// (`ex`, `ey`) (spec 08 D18's table).
Handle wallFrom(
        DraftDocument doc, double sx, double sy, double ex, double ey) =>
    doc.components.withComponent<WallParams>().singleWhere((w) {
      final p = doc.components.get<WallParams>(w)!;
      return p.sx == sx && p.sy == sy && p.ex == ex && p.ey == ey;
    });

/// E1, the south exterior wall, and E4, the west one (spec 08 D18).
Handle e1Of(DraftDocument doc) => wallFrom(doc, kPlanOriginX + 125,
    kPlanOriginY + 125, kPlanOriginX + kPlanWidth - 125, kPlanOriginY + 125);
Handle e4Of(DraftDocument doc) => wallFrom(doc, kPlanOriginX + 125,
    kPlanOriginY + kPlanHeight - 125, kPlanOriginX + 125, kPlanOriginY + 125);

/// [wall]'s openings, ascending.
List<Handle> openingsOf(DraftDocument doc, Handle wall) => [
      for (final o in doc.components.withComponent<OpeningParams>())
        if (doc.components.get<OpeningParams>(o)!.host == wall) o
    ]..sort((a, b) => a.value.compareTo(b.value));

/// [group]'s children, ascending.
List<Handle> childrenOf(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot)
    ]..sort((a, b) => a.value.compareTo(b.value));

/// Every live entity handle, ascending.
List<Handle> liveHandles(DraftDocument doc) => [
      for (final slot in doc.entities.liveSlots) doc.entities.handleAt(slot)
    ]..sort((a, b) => a.value.compareTo(b.value));

/// The lowest y of [wall]'s piece outlines: `y0` at a mitred south corner,
/// `y0 + 125` at a square end on E1's centreline.
double lowestY(DraftDocument doc, Handle wall) {
  var y = double.infinity;
  for (final k in childrenOf(doc, wall)) {
    final slot = doc.entities.slotOf(k)!;
    if (doc.entities.kindAt(slot) != EntityKind.polyline) continue;
    final p = doc.geometry.read(doc.entities.geomIndexAt(slot));
    for (var i = 0; i < p.pointCount; i++) {
      if (p.pointAt(i).y < y) y = p.pointAt(i).y;
    }
  }
  return y;
}

void main() {
  testWidgets('the shell shows a canvas over a non-empty, off-origin plan',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    expect(find.byType(DraftCanvas), findsOneWidget);
    expect(find.byType(CameraGestureDetector), findsOneWidget);
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(view.document.extents.minX, greaterThan(0));
    expect(view.camera.minScale, kMinScale);
    expect(view.camera.maxScale, kMaxScale);
  });

  // Ruling 01-2: fitted once to the size the view actually got, so the plan
  // is fully visible and the camera is not the nominal 1440 x 900 fit.
  //
  // M-04k. The drawing area is the RulerFrame's child, not the view, so the
  // camera fits the page to the DraftCanvas's own size, not the extents.
  testWidgets('the camera is fitted to the real viewport on first layout',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final page =
        view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final expected = fitToPage(page, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
  });

  testWidgets('the camera is fitted to the page at the drawing area\'s size',
      (tester) async {
    // M-04k. The drawing area is the RulerFrame's child, not the view.
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final page =
        view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final expected = fitToPage(page, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
    final extentsFit = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, isNot(closeTo(extentsFit.scale, 1e-9)));
  });

  testWidgets(
      'the page chrome and the rulers are in the tree, under the canvas',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    expect(find.byType(RulerFrame), findsOneWidget);
    final chrome = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PageChromePainter);
    expect(chrome, findsOneWidget);
    expect(tester.getSize(chrome), tester.getSize(find.byType(DraftCanvas)));
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    expect(view.document.entities.liveCount, greaterThanOrEqualTo(500));
  });

  testWidgets('the zoom text reads the scale and the fitted zoom',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final page =
        view.document.components.get<PageComponent>(view.document.rootHandle)!;
    final zoom = zoomOf(view.camera.value.scale, page, kLogicalPixelsPerMm);
    final text = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(text, '1:50 · ${(zoom * 100).round()}%');
    view.camera.zoomAt(const Offset(100, 100), 2.0);
    await tester.pump();
    final after = tester.widget<Text>(find.byKey(const Key('zoom-text'))).data;
    expect(after, '1:50 · ${(zoom * 2 * 100).round()}%');
  });

  testWidgets('the three chrome slots are laid out', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    for (final key in const [
      Key('chrome-top'),
      Key('chrome-left'),
      Key('chrome-right')
    ]) {
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getSize(find.byKey(key)).width, greaterThan(0));
    }
  });

  // Ruling 01-2's latch: the fit happens once. A resize after the user has
  // moved the camera must not re-fit and throw their view away.
  testWidgets('a resize after the first layout does not re-fit the camera',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    view.camera.zoomAt(const Offset(300, 200), 1.7);
    view.camera.panBy(const Offset(40, -25));
    final moved = view.camera.value.worldToScreenMatrix;

    await tester.binding.setSurfaceSize(const Size(1100, 750));
    await tester.pump();
    await tester.pump();

    expect(view.camera.value.worldToScreenMatrix, same(moved));
    expect(tester.getSize(find.byType(DraftCanvas)).width, greaterThan(500),
        reason: 'the canvas really did get a new size');
  });

  testWidgets('the status text shows the tool name and follows the selection',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final statusFinder = find.byKey(const Key('status-text'));
    expect(tester.widget<Text>(statusFinder).data, 'Select');

    // kPlanOriginX + 100, kPlanOriginY sits on the outer wall's top edge
    // (startup_plan.dart's first `rect`, from (x0, y0) to (x1, y0)).
    final world = Vector2(kPlanOriginX + 100, kPlanOriginY);
    final hit = HitPath();
    final hitFound =
        view.index.pickInto(world, 5.0, const QueryFilter.picking(), hit);
    expect(hitFound, isTrue, reason: 'the probe point must sit on a wall');
    final key = resolveHit(hit, view.document);
    expect(key, isNotNull);

    view.selection.replace([key!]);
    await tester.pump();

    expect(tester.widget<Text>(statusFinder).data, 'Select — 1 selected');
  });

  testWidgets('the interaction tree is in place', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    expect(find.byType(InteractionLayer), findsOneWidget);
    final overlayFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SelectionOverlayPainter);
    expect(overlayFinder, findsOneWidget);

    final overlaySize =
        tester.renderObject<RenderCustomPaint>(overlayFinder).size;
    expect(overlaySize, tester.getSize(find.byType(DraftCanvas)));
  });

  testWidgets('a click on a wall selects it in the running shell',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    // On E1's outer face, 3,000 mm along (spec 08 D18): the click selects
    // E1's group. Not 100 mm along: at this surface the pick radius is about
    // 366 mm, which reaches the corner where E1's and E4's centrelines end,
    // and a vertex hit outranks an edge hit, its tie going to the greater
    // handle, E4.
    final world = Vector2(kPlanOriginX + 3000, kPlanOriginY);
    final screen = view.camera.value.worldToScreen(world);
    final viewportSize = tester.getSize(find.byType(InteractionLayer));
    expect(screen.x, inInclusiveRange(0, viewportSize.width));
    expect(screen.y, inInclusiveRange(0, viewportSize.height));

    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    expect(view.selection.keys, [SelectionKey.root(e1Of(view.document))]);
  });

  // A5 / spec D12: the look asks the human to delete a wall and put it back,
  // and until this binding existed the shell had no way to put it back.
  testWidgets('cmd+Z undoes a Delete through the command log', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final doc = view.document;
    // E1's outer face, as the test above clicks it.
    final world = Vector2(kPlanOriginX + 3000, kPlanOriginY);
    final screen = view.camera.value.worldToScreen(world);
    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    // E1 and its front door (spec 08 D18); E2 and E4 mitre with E1 at the
    // south corners.
    final e1 = e1Of(doc);
    expect(view.selection.keys, [SelectionKey.root(e1)]);
    final [door] = openingsOf(doc, e1);
    final e2 = wallFrom(
        doc,
        kPlanOriginX + kPlanWidth - 125,
        kPlanOriginY + 125,
        kPlanOriginX + kPlanWidth - 125,
        kPlanOriginY + kPlanHeight - 125);
    final e4 = e4Of(doc);
    expect(lowestY(doc, e2), kPlanOriginY, reason: 'E2 mitres with E1');
    expect(lowestY(doc, e4), kPlanOriginY, reason: 'E4 mitres with E1');
    final removed = childrenOf(doc, e1).length + childrenOf(doc, door).length;
    expect(removed, 6 + 2, reason: 'two pieces, and a leaf and an arc');
    // The startup plan is itself built through the log, so the counts below
    // are what pin the undo to exactly one command: the Delete.
    final liveBefore = doc.entities.liveCount;
    final handlesBefore = liveHandles(doc);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    // The door goes with its host (spec 08 D4), in the same step, and the
    // neighbours' corners square.
    expect(doc.tree[e1], isNull);
    expect(doc.tree[door], isNull, reason: 'the cascade');
    expect(doc.commands.undoDepth, 1, reason: 'one step');
    expect(doc.entities.liveCount, liveBefore - removed);
    expect(lowestY(doc, e2), closeTo(kPlanOriginY + 125, 1e-9),
        reason: 'E2\'s corner squares');
    expect(lowestY(doc, e4), closeTo(kPlanOriginY + 125, 1e-9),
        reason: 'E4\'s corner squares');
    expect(view.selection.isEmpty, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(doc.tree[e1], isA<GroupNode>(), reason: 'the wall is back');
    expect(doc.tree[door], isA<GroupNode>(), reason: 'its door too');
    expect(doc.entities.liveCount, liveBefore,
        reason: 'exactly one command came off the log, not the plan under it');
    expect(liveHandles(doc), handlesBefore, reason: 'every child handle');
    expect(lowestY(doc, e2), kPlanOriginY);
    expect(lowestY(doc, e4), kPlanOriginY);
    expect(view.selection.isEmpty, isTrue,
        reason: 'undo replays the command log; it never restores the '
            "selection controller's own state");
  });

  testWidgets('ctrl+Z after deleting two walls brings both back in one step',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    Offset at(Vector2 world) {
      final s = view.camera.value.worldToScreen(world);
      return topLeft + Offset(s.x, s.y);
    }

    // E1 and E4 (spec 08 D18), by points on their outer faces: E1's 3,000
    // mm along, as above (its mid-edge is the front door's jamb), and E4's
    // mid-edge. Each is past the pick radius (about 366 mm here) of every
    // vertex of another object: the corners, the front door
    // (x0 + 6000..7000), E4's windows (y0 + 1700..2700, y0 + 5900..7300)
    // and P2's butt (y0 + 5000), so each tap can only mean one wall.
    final doc = view.document;
    final e1 = e1Of(doc), e4 = e4Of(doc);
    final objects = [e1, e4, ...openingsOf(doc, e1), ...openingsOf(doc, e4)];
    expect(objects, hasLength(5), reason: 'a door and two windows');
    var removed = 0;
    for (final o in objects) {
      removed += childrenOf(doc, o).length;
    }
    await tester.tapAt(at(Vector2(kPlanOriginX + 3000, kPlanOriginY)));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(at(Vector2(kPlanOriginX, kPlanOriginY + 4500)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(view.selection.keys.toSet(),
        {SelectionKey.root(e1), SelectionKey.root(e4)});
    // Ruling 04-1: the history is cleared at startup, so `undoDepth` here
    // would only count what happens from this point on; the live count
    // after exactly one ctrl+Z is what pins it to one entry regardless.
    final liveBefore = doc.entities.liveCount;
    final handlesBefore = liveHandles(doc);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    for (final o in objects) {
      expect(doc.tree[o], isNull, reason: 'object $o, with its wall');
    }
    expect(doc.commands.undoDepth, 1, reason: 'one step');
    expect(doc.entities.liveCount, liveBefore - removed);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(doc.entities.liveCount, liveBefore,
        reason: 'one ctrl+Z restores both walls, not one');
    for (final o in objects) {
      expect(doc.tree[o], isA<GroupNode>(), reason: 'object $o is back');
    }
    expect(liveHandles(doc), handlesBefore, reason: 'every child handle');
    expect(view.selection.isEmpty, isTrue);
  });
}

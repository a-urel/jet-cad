import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

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
    final world = Vector2(kPlanOriginX + 100, kPlanOriginY);
    final screen = view.camera.value.worldToScreen(world);
    final viewportSize = tester.getSize(find.byType(InteractionLayer));
    expect(screen.x, inInclusiveRange(0, viewportSize.width));
    expect(screen.y, inInclusiveRange(0, viewportSize.height));

    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    expect(view.selection.length, 1);
  });

  // A5 / spec D12: the look asks the human to delete a wall and put it back,
  // and until this binding existed the shell had no way to put it back.
  testWidgets('cmd+Z undoes a Delete through the command log', (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();

    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final world = Vector2(kPlanOriginX + 100, kPlanOriginY);
    final screen = view.camera.value.worldToScreen(world);
    final topLeft = tester.getTopLeft(find.byType(InteractionLayer));
    await tester.tapAt(topLeft + Offset(screen.x, screen.y));
    await tester.pump();

    expect(view.selection.length, 1);
    final handle = view.selection.keys.single.target;
    expect(view.document.entities.slotOf(handle), isNotNull);
    // The startup plan is itself built through the log, so the counts below
    // are what pin the undo to exactly one command: the Delete.
    final liveBefore = view.document.entities.liveCount;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(view.document.entities.slotOf(handle), isNull);
    expect(view.document.entities.liveCount, liveBefore - 1);
    expect(view.selection.isEmpty, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(view.document.entities.slotOf(handle), isNotNull,
        reason: 'the wall is back');
    expect(view.document.entities.liveCount, liveBefore,
        reason: 'exactly one command came off the log, not the plan under it');
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

    // The outer rectangle is four lines: its bottom edge and its left edge
    // are two entities. Both points sit mid-edge, well past the pick radius
    // of the corner, the door (x0 + 6000..7000) and the left-wall windows
    // (y0 + 1700..2700, y0 + 5900..7300), so each tap can only mean one wall.
    await tester.tapAt(at(Vector2(kPlanOriginX + 3000, kPlanOriginY)));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(at(Vector2(kPlanOriginX, kPlanOriginY + 3000)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(view.selection.length, 2);
    final handles = [for (final k in view.selection.keys) k.target];
    // Ruling 04-1: the history is cleared at startup, so `undoDepth` here
    // would only count what happens from this point on; the live count
    // after exactly one ctrl+Z is what pins it to one entry regardless.
    final liveBefore = view.document.entities.liveCount;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(view.document.entities.liveCount, liveBefore - 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(view.document.entities.liveCount, liveBefore,
        reason: 'one ctrl+Z restores both walls, not one');
    for (final h in handles) {
      expect(view.document.entities.slotOf(h), isNotNull);
    }
    expect(view.selection.isEmpty, isTrue);
  });
}

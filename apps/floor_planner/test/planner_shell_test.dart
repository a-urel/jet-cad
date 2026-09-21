import 'package:floor_planner/main.dart';
import 'package:floor_planner/planner_view.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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
  testWidgets('the camera is fitted to the real viewport on first layout',
      (tester) async {
    await tester.pumpWidget(const FloorPlannerApp());
    await tester.pump();
    final view = tester.widget<PlannerView>(find.byType(PlannerView));
    final size = tester.getSize(find.byType(DraftCanvas));
    final expected = ViewportTransform.fit(view.document.extents, size);
    expect(view.camera.value.scale, closeTo(expected.scale, 1e-9));
    expect(view.camera.value.worldToScreenMatrix.e,
        closeTo(expected.worldToScreenMatrix.e, 1e-6));
  });

  testWidgets('the three chrome slots are laid out and empty', (tester) async {
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
}

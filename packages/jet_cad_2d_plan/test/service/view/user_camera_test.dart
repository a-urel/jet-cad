// Sub-project 4a R2 H4: `userCamera: false` alone. With the flag off, no
// pan, pinch or wheel on the view moves the camera; the host's own
// `centerOn` and `zoomBy` still do. A control mount (the flag on) moves
// under the same gestures, so the pinned gestures are real ones.
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../../support/service_host.dart';

List<double> matrix(PlanController c) {
  final m = c.camera.value.worldToScreenMatrix;
  return [m.a, m.b, m.c, m.d, m.e, m.f];
}

/// A mouse drag, a two-finger pinch and a wheel notch over empty floor,
/// each pumped; the camera's matrix after each.
Future<List<List<double>>> gestures(
    WidgetTester tester, PlanController c) async {
  final corner = tester.getTopLeft(find.byType(InteractionLayer));
  final floor = corner + const Offset(60, 50);
  expect(c.unitAt(const Offset(60, 50)), isNull, reason: 'premise: floor');
  final seen = <List<double>>[];

  final drag = await tester.startGesture(floor, kind: PointerDeviceKind.mouse);
  await drag.moveTo(floor + const Offset(40, 25));
  await tester.pump();
  await drag.moveTo(floor + const Offset(90, 60));
  await tester.pump();
  await drag.up();
  await tester.pump(const Duration(milliseconds: 300));
  seen.add(matrix(c));

  final f1 = await tester.startGesture(floor + const Offset(100, 0),
      pointer: 41, kind: PointerDeviceKind.touch);
  final f2 = await tester.startGesture(floor + const Offset(160, 60),
      pointer: 42, kind: PointerDeviceKind.touch);
  for (var i = 1; i <= 3; i++) {
    await f1.moveTo(floor + Offset(100 - 12.0 * i, 0));
    await f2.moveTo(floor + Offset(160 + 20.0 * i, 60 + 15.0 * i));
    await tester.pump();
  }
  await f1.up();
  await f2.up();
  await tester.pump(const Duration(milliseconds: 300));
  seen.add(matrix(c));

  final wheel = TestPointer(1, PointerDeviceKind.mouse);
  await tester.sendEventToBinding(wheel.hover(floor + const Offset(200, 120)));
  await tester.sendEventToBinding(wheel.scroll(const Offset(0, -120)));
  await tester.pump();
  seen.add(matrix(c));
  return seen;
}

void main() {
  testWidgets(
      'H4 userCamera false: pan, pinch and wheel leave the camera; '
      'centerOn moves it', (tester) async {
    final c = serviceController();
    await pumpService(
        tester, c, PlanServiceView(controller: c, userCamera: false));
    final start = matrix(c);
    final seen = await gestures(tester, c);
    expect(seen[0], start, reason: 'a drag does not pan');
    expect(seen[1], start, reason: 'a pinch does not zoom or pan');
    expect(seen[2], start, reason: 'a wheel does not zoom');

    c.centerOn(const Offset(41600, -26900), scale: 0.2);
    await tester.pump();
    await tester.pump();
    expect(matrix(c), isNot(start), reason: 'the host\'s centerOn moves it');
    expect(c.camera.value.scale, closeTo(0.2, 1e-9));
  });

  testWidgets('H4 control: with userCamera true the same gestures move it',
      (tester) async {
    final c = serviceController();
    await pumpService(
        tester, c, PlanServiceView(controller: c, userCamera: true));
    final start = matrix(c);
    final seen = await gestures(tester, c);
    expect(seen[0], isNot(start), reason: 'the drag pans');
    expect(seen[1], isNot(seen[0]), reason: 'the pinch moves it');
    expect(seen[2], isNot(seen[1]), reason: 'the wheel zooms');
  });
}

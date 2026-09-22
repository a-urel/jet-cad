import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/page_fixture.dart';

void main() {
  Future<(RulerFrameState, int Function())> pump(WidgetTester tester,
      {CameraController? camera}) async {
    var childHovers = 0;
    final page = ValueNotifier<PageComponent?>(standardPage());
    final key = GlobalKey<RulerFrameState>();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 424,
          height: 324,
          child: RulerFrame(
            key: key,
            camera: camera ?? standardCamera(),
            page: page,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerHover: (_) => childHovers++,
              child: const SizedBox.expand(key: Key('child')),
            ),
          ),
        ),
      ),
    ));
    return (key.currentState!, () => childHovers);
  }

  testWidgets(
      'the bars are co-extensive with the child and the corner is 24 x 24',
      (tester) async {
    await pump(tester);
    final child = tester.getRect(find.byKey(const Key('child')));
    expect(child.size, const Size(400, 300));
    final top = tester.getRect(find.byKey(const Key('ruler-top')));
    final left = tester.getRect(find.byKey(const Key('ruler-left')));
    final corner = tester.getRect(find.byKey(const Key('ruler-corner')));
    expect(top.left, child.left);
    expect(top.width, child.width);
    expect(top.height, kRulerThickness);
    expect(left.top, child.top);
    expect(left.height, child.height);
    expect(left.width, kRulerThickness);
    expect(corner.size, const Size(kRulerThickness, kRulerThickness));
  });

  testWidgets(
      'hover feeds the pointer in child coordinates; exit clears it; '
      'the child still hears it', (tester) async {
    final (state, hovers) = await pump(tester);
    final child = tester.getRect(find.byKey(const Key('child')));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: child.topLeft + const Offset(50, 40));
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(child.topLeft + const Offset(51, 41));
    await tester.pump();
    expect(state.pointer.value, const Offset(51, 41));
    expect(hovers(), greaterThan(0));
    await gesture.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(state.pointer.value, isNull);
  });

  testWidgets(
      "the sheet corner's major tick sits at its screen x in the top bar",
      (tester) async {
    // S10: the frame-level check the painter test cannot make.
    //
    // The world point is the fixture's own sheet corner, not a value read back
    // out of the tick under test: inverting the camera on the tick and
    // re-applying it would assert only that the camera is invertible.
    final (state, _) = await pump(tester);
    final child = tester.getRect(find.byKey(const Key('child')));
    final topBar = tester.getRect(find.byKey(const Key('ruler-top')));
    // The bar shares the child's horizontal span, so a screen x means the same
    // thing in both and no offset has to be applied below.
    expect(topBar.left, child.left);
    expect(topBar.width, child.width);

    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('ruler-top')))
        .painter as RulerPainter;
    // Page x = 0 is a major tick by construction (the ladder is anchored on
    // the page origin), and the sheet corner is at world (7350, -1230).
    final cornerX = state.widget.camera.value.worldToScreen(Vector2(7350, 0)).x;
    expect(cornerX, closeTo(395.45, 1e-9),
        reason: 'fixture guard: the corner must land inside the 400 px bar, '
            'not off its end where no tick is emitted');
    expect(cornerX, inInclusiveRange(0, child.width));

    final majors =
        painter.debugLastTicks.where((t) => t.$2).map((t) => t.$1).toList();
    expect(majors, isNotEmpty);
    expect(majors.any((x) => (x - cornerX).abs() < 1e-6), isTrue,
        reason: 'the top bar emits a major tick at the sheet corner: '
            'majors were $majors, corner at $cornerX');
  });
}

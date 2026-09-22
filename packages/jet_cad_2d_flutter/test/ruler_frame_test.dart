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
      'a major tick in the top bar sits at its world point\'s x in the child',
      (tester) async {
    // S10: the frame-level check the painter test cannot make.
    final (state, _) = await pump(tester);
    final painter = tester
        .widget<CustomPaint>(find.byKey(const Key('ruler-top')))
        .painter as RulerPainter;
    final major = painter.debugLastTicks.firstWhere((t) => t.$2);
    final pageX = (major.$1 + 611.5) / 0.137 - 7350;
    final world = Vector2(7350 + pageX.roundToDouble(), 0);
    final inChild = state.widget.camera.value.worldToScreen(world).x;
    expect(major.$1, closeTo(inChild, 1e-6));
  });
}

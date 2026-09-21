import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// The widget's size under test; the box is centred, so its top-left in
/// the 800 x 600 test surface is (200, 150).
const Size kDetectorSize = Size(400, 300);
const Offset kDetectorTopLeft = Offset(200, 150);

/// A world point inside the fitted view, off the view centre.
final Vector2 kWorldProbe = Vector2(1030, 2015);

/// A focus **off the viewport centre** (spec: M-01c cannot die at the
/// centre), in the detector's local coordinates.
const Offset kLocalFocus = Offset(70, 230);

/// Off-origin world (1000..1100 x 2000..2050) fitted into 400 x 300 with the
/// 5% margin: scale 0.95 * min(4, 6) = 3.8. Never the identity.
CameraController fitOffOrigin(
        {double minScale = 0.0, double maxScale = double.infinity}) =>
    CameraController(
      ViewportTransform.fit(
          Aabb2(Vector2(1000, 2000), Vector2(1100, 2050)), kDetectorSize),
      minScale: minScale,
      maxScale: maxScale,
    );

/// Pumps a [CameraGestureDetector] over an inert child. The child is not a
/// `DraftCanvas`: these tests are about where the camera goes, and a canvas
/// would only add a document to keep paintable.
Future<void> pumpDetector(
    WidgetTester tester, CameraController camera, GesturePolicy policy) async {
  await tester.pumpWidget(Center(
    child: SizedBox(
      width: kDetectorSize.width,
      height: kDetectorSize.height,
      child: CameraGestureDetector(
        camera: camera,
        policy: policy,
        child: const ColoredBox(color: Color(0xFFFFFFFF)),
      ),
    ),
  ));
}

/// Where [world] is on the detector's surface, as an [Offset].
Offset screenOf(CameraController camera, Vector2 world) {
  final p = camera.value.worldToScreen(world);
  return Offset(p.x, p.y);
}

/// [kLocalFocus] in the test surface's global coordinates.
Offset globalFocus() => kDetectorTopLeft + kLocalFocus;

import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../core/handle.dart';
import '../geometry/aabb2.dart';
import '../geometry/primitives.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';

/// Supplies the laid-out box of a text entity.
///
/// An interface rather than an implementation because real layout needs a font
/// stack, and this package must not depend on Flutter. The widget layer
/// supplies a real measurer; the engine ships [InsertionPointMeasurer].
abstract class TextMeasurer {
  Aabb2 measure({
    required String text,
    required Handle style,
    required double height,
    required Vector2 insertion,
  });
}

/// Contributes only the insertion point.
///
/// Correct-but-minimal: extents computed with it are a lower bound, which is
/// the honest answer when no font stack is present. It also keeps engine tests
/// deterministic across machines, since real text layout is font- and
/// platform-dependent.
class InsertionPointMeasurer implements TextMeasurer {
  const InsertionPointMeasurer();

  @override
  Aabb2 measure({
    required String text,
    required Handle style,
    required double height,
    required Vector2 insertion,
  }) =>
      Aabb2(insertion, insertion);
}

/// Bounds one entity in its **owner's** space.
///
/// Callers transform the result into the enclosing space; this function knows
/// geometry, not placement.
Aabb2 entityBounds({
  required EntityKind kind,
  required GeometryPayload payload,
  required TextMeasurer measurer,
  required Handle textStyle,
  String text = '',
}) {
  switch (kind) {
    case EntityKind.point:
    case EntityKind.line:
    case EntityKind.polyline:
      var box = Aabb2.empty();
      for (var i = 0; i < payload.pointCount; i++) {
        box = box.expandedToPoint(payload.pointAt(i));
      }
      return box;

    case EntityKind.circle:
      final centre = payload.pointAt(0);
      final radius = payload.scalars[0];
      return Aabb2(
        Vector2(centre.x - radius, centre.y - radius),
        Vector2(centre.x + radius, centre.y + radius),
      );

    case EntityKind.arc:
      return arcBounds(
        payload.pointAt(0),
        payload.scalars[0],
        payload.scalars[1],
        payload.scalars[2],
      );

    case EntityKind.text:
    case EntityKind.attrib:
      return measurer.measure(
        text: text,
        style: textStyle,
        height: payload.scalars.isEmpty ? 0 : payload.scalars[0],
        insertion: payload.pointAt(0),
      );
  }
}

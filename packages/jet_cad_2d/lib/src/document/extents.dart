import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../geometry/aabb2.dart';
import '../geometry/primitives.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'tables.dart';
import 'text_geometry.dart';
import 'text_metrics.dart';

/// Bounds one entity in its **owner's** space.
///
/// Callers transform the result into the enclosing space; this function knows
/// geometry, not placement.
///
/// Takes the [TextStyleRecord] itself, not a style handle, because
/// [TextStyleRecord.fixedHeight] and the per-entity override bits in
/// [textAttrs] cannot be resolved from a handle alone, and giving this
/// function a document dependency so it could look one up would be worse:
/// every caller already holds the document and can resolve the record once.
Aabb2 entityBounds({
  required EntityKind kind,
  required GeometryPayload payload,
  required TextMeasurer measurer,
  required TextStyleRecord textStyle,
  int textAttrs = 0,
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
      final attrs = resolveTextAttributes(payload, textAttrs, textStyle);
      final metrics = measurer.measure(text: text, style: textStyle);
      return textLocalBounds(attrs, metrics).transformedBy(
          textLocalTransform(attrs, metrics, payload.pointAt(0)));

    case EntityKind.fill:
      // Task 9 gives this case the boundary's box. Until then a fill bounds
      // to nothing, which is what its own payload says.
      return Aabb2.empty();
  }
}

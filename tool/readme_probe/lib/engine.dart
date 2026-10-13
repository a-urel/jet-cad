// The README of packages/jet_cad_2d, its Example block verbatim.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() {
  final doc = DraftDocument.empty();
  final circle = addDrafted(
      doc, EntityKind.circle, circlePayload(Vector2(300, 250), 50),
      layer: ReservedHandles.layerZero);
  doc.commands.execute(circle);

  final index = SpatialIndex(doc);
  final hit = HitPath();
  if (index.pickInto(Vector2(300, 301), 2, const QueryFilter.picking(), hit)) {
    print(hit.entity == circle.record.handle); // true
  }

  doc.commands.undo(); // the circle is gone, and the index knows it
  print(DraftDocumentCodec.encodeToString(doc));
}

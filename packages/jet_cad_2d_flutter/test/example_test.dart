// The published example (spec D2): it builds, shows its document, and
// frames all of it.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart';

void main() {
  testWidgets('the example shows a line and a circle, framed whole',
      (tester) async {
    await tester.pumpWidget(const DraftExampleApp());
    final canvas = tester.widget<DraftCanvas>(find.byType(DraftCanvas));
    final doc = canvas.document;
    expect(doc.entities.liveCount, 2);

    // The circle is where the example says: a pick 1 unit outside its top
    // edge finds it, as an edge (a pick inside a closed circle would hit
    // its fill at any radius and test nothing).
    final hit = HitPath();
    expect(
        canvas.index
            .pickInto(Vector2(300, 301), 2, const QueryFilter.picking(), hit),
        isTrue);
    expect(doc.entities.kindAt(doc.entities.slotOf(hit.entity)!),
        EntityKind.circle);
    expect(hit.kind, HitKind.edge);

    // The camera frames the whole drawing.
    final size = tester.getSize(find.byType(DraftCanvas));
    final visible = canvas.camera.value.visibleWorld(size);
    final extents = doc.extents;
    expect(visible.minX, lessThanOrEqualTo(extents.minX));
    expect(visible.minY, lessThanOrEqualTo(extents.minY));
    expect(visible.maxX, greaterThanOrEqualTo(extents.maxX));
    expect(visible.maxY, greaterThanOrEqualTo(extents.maxY));
  });
}

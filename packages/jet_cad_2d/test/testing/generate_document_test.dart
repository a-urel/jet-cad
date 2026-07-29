import 'package:jet_cad_2d/testing.dart';
import 'package:test/test.dart';

void main() {
  test('generateDocument is deterministic across calls', () {
    // The generator seeds math.Random(0xC0FFEE). Two documents built with the
    // same arguments must agree entity for entity, or Plan 2's numbers and
    // Plan 3a's are not measured on the same drawing and cannot be compared.
    final a = generateDocument(2000, definitionCount: 20);
    final b = generateDocument(2000, definitionCount: 20);

    expect(a.entities.liveSlots.length, b.entities.liveSlots.length);
    for (final slot in a.entities.liveSlots) {
      expect(a.entities.handleAt(slot), b.entities.handleAt(slot));
      expect(a.entities.kindAt(slot), b.entities.kindAt(slot));
      expect(a.geometry.peek(a.entities.geomIndexAt(slot)).coords,
          b.geometry.peek(b.entities.geomIndexAt(slot)).coords);
    }
    expect(a.extents.minX, b.extents.minX);
    expect(a.extents.maxX, b.extents.maxX);
  });
}

// Spec K8: the code docs/kits.md and the README show is the example's, and
// it builds, decodes and conforms.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import '../../example/example.dart';

void main() {
  test('E1 the documented catalog builds, decodes and conforms', () {
    final catalog = buildCafeCatalog();
    final bytes = encodeLibrary(catalog);
    final library = SymbolLibrary.decode(bytes);
    expect(library.kits, ['cafe']);
    expect([for (final e in library.entries) e.id], ['cafe.table.round-two@1']);
    expect(library.entries.single.unit,
        UnitComponent(kind: UnitKinds.table, capacity: 2));
    // M-E1: give the example's table three chairs; the leaf count changes.
    expect(library.entries.single.leaves, hasLength(1 + 2 * 2));
    expect(
        conformance(
          catalog: catalog,
          committedLibrary: bytes,
          committedSnapshot: encodeSnapshot(geometrySnapshot(catalog)),
          names: cafeNames,
          locales: const ['tr'],
        ),
        isEmpty);
  });
}

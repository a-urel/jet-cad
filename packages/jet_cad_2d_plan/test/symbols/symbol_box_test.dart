// Spec 09c D2 (ported to the plan library, Task 14): a placed definition's
// box. Ported from jet_cad_floor_plan's symbol_box_test.dart, assertions
// unchanged. The box functions are the contract's since 3a Task 1 (spec
// C1.4), and so are their other tests (jet_cad_2d_kit's
// test/model/symbol_box_test.dart); this case stays because it places
// through the plan's placeSymbol. The furniture asset's literal boxes stay
// with that asset's kit (3a Task 28).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/symbol_fixtures.dart';

SymbolEntry entryIn(SymbolLibrary lib, String key) =>
    lib.entries.firstWhere((e) => e.symbol.key == key);

DraftDocument target() {
  final doc = DraftDocument.empty();
  registerKitComponents(doc.components);
  doc.header.units = DrawingUnits.millimeters;
  return doc;
}

Handle definitionOf(DraftDocument doc, String key) {
  for (final h in doc.components.withComponent<SymbolComponent>()) {
    if (doc.components.get<SymbolComponent>(h)!.key == key &&
        doc.tree.definition(h) != null) {
      return h;
    }
  }
  throw StateError('no $key');
}

void main() {
  group('boxOfDefinition', () {
    test('a placed definition gives the same box as its entry', () {
      final lib = SymbolLibrary.decode(bytesOf(buildValidLibrary()));
      final doc = target();
      final keys = [
        'fixture.sofa.three',
        'fixture.nightstand.single',
        'fixture.armchair.single'
      ];
      // Three definitions in one document (each box must read only its own
      // leaves), placed far from the origin, turned and mirrored or not:
      // the box is in the definition's coordinates, whatever the instance.
      for (var i = 0; i < keys.length; i++) {
        doc.commands.execute(placeSymbol(doc, entryIn(lib, keys[i]),
            at: Vector2(1e5 + 250.0 * i, -7e4 - 125.0 * i),
            quarterTurns: i + 1,
            mirrored: i.isOdd));
      }
      for (final key in keys) {
        expect(boxOfDefinition(doc, definitionOf(doc, key)),
            boxOfEntry(entryIn(lib, key)),
            reason: key);
      }
    });
  });
}

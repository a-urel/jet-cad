// Spec 2a P6 (R5): the code side docs/kits.md shows is the example's, and it
// validates, registers, edits and regenerates.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../../example/cafe_code.dart';

final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

void main() {
  test('R5-1 the documented code kit validates, edits and regenerates', () {
    expect(cafeCodeKit.validate(), isEmpty);
    expect(cafeCodeKit.propertyIds, [
      'cafe.sign.width',
      'cafe.sign.face',
      'cafe.sign.face.chalk',
      'cafe.sign.face.board',
      'cafe.sign.area',
    ]);
    final type = cafeCodeKit.types.single;
    final catalog = ParametricCatalog();
    type.registerInto(catalog);
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    ParametricSystem(doc, catalog).install();
    const sign = Handle(3100);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: sign,
          parent: doc.rootHandle,
          transform: Transform2.translation(1820.5, 640.25)
              .multiply(Transform2.rotation(math.pi / 5)),
          children: const [])),
      SetComponentCommand<CafeSign>(
          sign, const CafeSign(width: 900, face: SignFace.chalk)),
    ], label: 'Add sign'));
    final width = type.fieldsOf(doc, sign, words).first;
    expect(width.value, 900.0);
    // M-R5: the example's `min: 300` lowered to 200.
    expect(() => type.commitField(doc, sign, width, 250, words),
        throwsArgumentError);
    doc.commands.execute(type.commitField(doc, sign, width, 1500, words));
    final outline = [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == sign)
          doc.geometry.read(doc.entities.geomIndexAt(slot)).coords,
    ].single;
    expect(outline.sublist(0, 4), [-750.0, -40.0, 750.0, -40.0]);
    doc.commands.execute(type.recolour(doc, sign, 'ochre')!);
    expect(type.colourOf(doc, sign), 'ochre');
  });
}

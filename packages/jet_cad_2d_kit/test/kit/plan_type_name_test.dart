// The name capability of PlanType: an object's own name from its component.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/code_fixtures.dart';
import '../support/plan_type_fixtures.dart';

PlanType<Slab> namedSlab({bool nullName = false}) => PlanType<Slab>(
      id: Slab.id,
      fromJson: Slab.fromJson,
      parametric: LoggingType<Slab>(),
      name: (s) => nullName ? null : 'name:${s.label}',
    );

void main() {
  test('NM1 a type without name: hasName false, nameOf null', () {
    final type = slabType();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    expect(type.hasName, isFalse);
    expect(type.nameOf(doc, hSlab), isNull);
  });

  test('NM2 nameOf returns the capability\'s value for the group\'s component',
      () {
    final type = namedSlab();
    final (:doc, catalog: _) = objectDocument([type, postType()]);
    addTearDown(doc.dispose);
    final label = doc.components.get<Slab>(hSlab)!.label;
    expect(type.hasName, isTrue);
    expect(type.nameOf(doc, hSlab), 'name:$label');
    // No component of the type: null.
    expect(type.nameOf(doc, hBare), isNull);
    expect(type.nameOf(doc, hPost), isNull);
    // A capability returning null means no name.
    expect(namedSlab(nullName: true).nameOf(doc, hSlab), isNull);
  });
}

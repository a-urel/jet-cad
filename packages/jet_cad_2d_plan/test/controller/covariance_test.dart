// Review Focus 3 (spec 2a P1 "Covariance"): two kits whose types carry
// different component types are held as PlanType<Component>; they register,
// regenerate, show their fields, edit and recolour through the erased
// operations under the VM's covariance checks.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';

void main() {
  testWidgets(
      'C-covariance a slab and a disc register, regenerate, show their '
      'fields, edit and recolour through PlanType<Component>', (tester) async {
    final c = controllerFor(kits: [testKit(), discKit()]);
    final d = c.document;
    // M-C-cov-b: only the first kit's types registered.
    final slab = addObject<SlabComponent>(
        d, SlabComponent(width: 1800, height: 900, angle: 0.4),
        at: Vector2(2350, -1180));
    final disc = addObject<DiscComponent>(d, DiscComponent(radius: 650),
        at: Vector2(-3100, 2240));
    for (final (object, typeId, length, value) in [
      (slab, 'test.slab', 'width', 1800.0),
      (disc, 'disc.round', 'radius', 650.0),
    ]) {
      final before = List.of(coordsOf(d, leavesOf(d, object).single));
      // M-C-cov-a: typeOf answers the set's first type.
      final PlanType<Component> type = c.typeOf(object)!;
      expect(type.id, typeId);
      final fields = type.fieldsOf(
          d, object, c.servicesOf(type.id.split('.').first).words);
      for (final f in fields) {
        expect(f.wordId, startsWith('property:$typeId.'));
        expect(() => (f.value, f.enabled), returnsNormally);
      }
      final field = fields.singleWhere((f) => f.spec.id == length);
      expect(field.value, value);
      d.commands.execute(type.commitField(d, object, field, 2345.5,
          c.servicesOf(type.id.split('.').first).words));
      expect(
          type
              .fieldsOf(d, object, c.servicesOf(type.id.split('.').first).words)
              .singleWhere((f) => f.spec.id == length)
              .value,
          2345.5);
      expect(coordsOf(d, leavesOf(d, object).single), isNot(before),
          reason: 'regenerated');
      d.commands.execute(type.recolour(d, object, 'red')!);
      expect(type.colourOf(d, object), 'red');
    }
    expect(
        c.typeOf(addLine(d, Vector2(-500, 700), Vector2(1800, 2400))), isNull);
    await tester.pump();
  });
}

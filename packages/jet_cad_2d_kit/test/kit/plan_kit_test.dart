// Spec K5: the PlanKit descriptor's symbol part and its validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

List<KitProblemCode> codes(PlanKit kit) =>
    [for (final p in kit.validate()) p.code];

void main() {
  test('K1 a const descriptor with its defaults', () {
    const kit = PlanKit(id: 'sample', version: '0.1.0');
    expect(kit.symbols, isEmpty);
    expect(identical(kit.names, KitNames.empty), isTrue);
    expect(kit.validate(), isEmpty);
  });

  test('K2 a sound kit validates: own words, categories, English present', () {
    const kit = PlanKit(
      id: 'sample',
      version: '0.3.1',
      names: KitNames({
        'en': {
          'tool:sample.wall': 'Wall',
          'type:sample.wall': 'Wall',
          'property:sample.wall.height': 'Height',
        },
        'tr': {
          'symbol:sample.table.round': 'Yuvarlak masa',
          'category:sample/Tables': 'Masalar',
          'tool:sample.wall': 'Duvar',
          'property:sample.wall.height': 'Yükseklik',
        },
      }),
    );
    expect(kit.validate(), isEmpty);
  });

  test('K3 a bad id and an empty version', () {
    // M-K3a: drop the id check. M-K3b: test `version.isEmpty` only.
    expect(codes(const PlanKit(id: 'Sample', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'my-kit', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'sample', version: ' ')),
        [KitProblemCode.emptyVersion]);
  });

  test("K4 a word id under another kit's id, in every namespace", () {
    for (final id in [
      'symbol:other.table.round',
      'tool:other.wall',
      'type:other.wall',
      'property:other.wall.height',
      'tool:wall', // no kit segment at all
      // The kit's own id with no name. M-K4c: drop `!rest.contains('.')`.
      'tool:sample',
      'category:other/Tables', // M-K4b: categories exempt from the check
      'category:Tables', // no kit at all
    ]) {
      final kit = PlanKit(
          id: 'sample',
          version: '0.1.0',
          names: KitNames({
            'en': {id: 'x'},
          }));
      // M-K4: check the symbol namespace only.
      expect(codes(kit), [KitProblemCode.foreignWordId], reason: id);
      expect(kit.validate().single.message, contains(id));
    }
  });

  test('K5 a word id in no known namespace', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {'label:sample.x': 'x', 'sample.table.round': 'y'},
        }));
    expect(codes(kit),
        [KitProblemCode.unknownWordId, KitProblemCode.unknownWordId]);
  });

  test('K6 a tool, type or property word without English', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {
            'tool:sample.wall': 'Duvar',
            'symbol:sample.table.round': 'Yuvarlak masa',
            'category:sample/Tables': 'Masalar',
          },
        }));
    // M-K6: drop the English check; a symbol or category word needs none.
    expect(codes(kit), [KitProblemCode.missingEnglish]);
    expect(kit.validate().single.message, contains('tool:sample.wall'));
  });
}

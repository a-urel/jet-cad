// Spec 2b S4 "Words": a host's words (PlanController(words:)) are checked by
// validateHostWords: every id in a known namespace, naming a kit, any kit.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

void main() {
  test(
      'K2B-host-1 a word in every namespace, under any kit (loaded or not), '
      'in any locale, is sound', () {
    const words = KitNames({
      'en': {
        'symbol:acme.table.round': 'Round table',
        'category:acme/Tables': 'Tables',
        'tool:acme.wall': 'Wall',
        'type:acme.wall': 'Wall',
        'property:acme.wall.height': 'Height',
        'unit:acme/booth': 'Booth',
      },
      'fr': {'tool:other.door': 'Porte', 'unit:other/seat': 'Siège'},
    });
    // M-K2B-7: `'unit'` left out of the slash namespaces (unknownWordId).
    expect(validateHostWords(words), isEmpty);
    expect(validateHostWords(KitNames.empty), isEmpty);
  });

  test('K2B-host-2 a word in no known namespace, in the words\' order', () {
    final found = validateHostWords(const KitNames({
      'en': {'label:acme.x': 'x', 'acme.table.round': 'y'},
      'de': {'tool:wall': 'z'},
    }));
    // M-K2B-8: the default branch reporting nothing.
    expect(codes(found), [
      KitProblemCode.unknownWordId,
      KitProblemCode.unknownWordId,
      KitProblemCode.foreignWordId,
    ]);
    expect(found[0].message, contains('"label:acme.x"'));
    expect(found[0].message, startsWith('en: '));
    expect(found[1].message, contains('"acme.table.round"'));
    expect(found[2].message, startsWith('de: '));
  });

  test('K2B-host-3 a word that names no kit', () {
    for (final id in [
      'tool:wall',
      'type:Acme.wall',
      'symbol:acme',
      'property:acme',
      'category:Tables',
      'category:/Tables',
      'unit:booth',
      'unit:Acme/booth',
    ]) {
      final found = validateHostWords(KitNames({
        'de': {id: 'x'},
      }));
      // M-K2B-9: the kit check dropped (every id in a known namespace
      // passes).
      expect(codes(found), [KitProblemCode.foreignWordId], reason: id);
      expect(found.single.message, contains('"$id"'));
    }
  });
}

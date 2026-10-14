// Spec 2a P5: a kit's words at the plan's locale, read live.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// A kit's shared cache, written against the barrel alone.
final class Bands implements Disposable {
  int disposed = 0;

  @override
  void dispose() => disposed++;
}

const KitNames names = KitNames({
  'en': {'type:test.slab': 'Slab', 'tool:test.slab': 'Slab'},
  'tr': {'type:test.slab': 'Tezgâh'},
});

void main() {
  test('PT19 the locale, then English, then the id or null', () {
    var locale = const Locale('tr', 'TR');
    final words = KitNamesWords(names, () => locale);
    expect(words.word('type:test.slab'), 'Tezgâh');
    expect(words.word('tool:test.slab'), 'Slab');
    // M-PT19a: `word` answers '' for a missing word.
    expect(words.word('property:test.slab.width'), 'property:test.slab.width');
    expect(words.maybe('property:test.slab.width'), isNull);
    expect(words.maybe('tool:test.slab'), 'Slab');
    // M-PT19b: read the locale once, in the constructor.
    locale = const Locale('de');
    expect(words.locale, const Locale('de'));
    expect(words.word('type:test.slab'), 'Slab');
    expect(identical(words.names, names), isTrue);
  });

  test('PT24 Disposable is exported for kits to implement', () {
    // A premise of the export list, exempt from the mutation rule: without
    // the export this file does not compile.
    final Disposable bands = Bands()..dispose();
    expect((bands as Bands).disposed, 1);
  });

  test(
      'K2B-ref SymbolDefinitionRef holds its four fields; SymbolsState '
      'lists its three states', () {
    // A premise of the declarations, exempt from the mutation rule.
    final add = AddDefinitionCommand(Definition(
        handle: const Handle(0x4A2),
        name: 'Booth',
        basePoint: Vector2(2100.5, 1300.25),
        children: const []));
    final ref = SymbolDefinitionRef(
        handle: const Handle(0x4A2),
        add: add,
        basePoint: Vector2(2100.5, 1300.25),
        top: const Aabb2.raw(1650.5, 850.25, 2550.5, 1750.25));
    expect(ref.handle, const Handle(0x4A2));
    expect(identical(ref.add, add), isTrue);
    expect(ref.basePoint, Vector2(2100.5, 1300.25));
    expect([ref.top.minX, ref.top.minY, ref.top.maxX, ref.top.maxY],
        [1650.5, 850.25, 2550.5, 1750.25]);
    expect(
        SymbolsState.values.map((s) => s.name), ['loading', 'ready', 'failed']);
  });
}

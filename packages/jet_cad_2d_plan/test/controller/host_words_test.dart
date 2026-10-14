// Spec 2b S4 "Words": PlanController(words:) checks a host's words
// (validateHostWords) and merges them before each kit's own, per locale: a
// host overrides a kit's word or adds a locale the kit lacks. Every reader
// of a kit's words reads them: the services, the panel's lookup, the
// gallery's names, the palette's labels.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_tool_palette.dart'
    show planToolLabel;
import 'package:jet_cad_2d_plan/src/panels/kit_lookup.dart' show planWordOf;
import 'package:jet_cad_2d_plan/src/symbols/gallery_model.dart'
    show PlanSymbolWords;

import '../support/symbol_fixtures.dart';
import '../support/test_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'PB-words-1 the host\'s word first, per locale: it overrides the '
      'kit\'s, the kit\'s own locale still beats the host\'s English, and a '
      'locale the kit lacks is the host\'s', () {
    final c = PlanController(
        kits: [testKit(), discKit()],
        words: const KitNames({
          'en': {'type:test.slab': 'Floor slab'},
          'tr': {'tool:test.slab': 'Döşeme aracı'},
          'de': {'type:disc.round': 'Runde Scheibe'},
        }));
    addTearDown(c.dispose);
    final slab = c.servicesOf('test').words;
    final disc = c.servicesOf('disc').words;
    c.reportLocale(const Locale('tr'));
    // M-PB-W1: `kit.names.merge(words)` (the kit's word first).
    // M-PB-W2: the words ignored (KitNamesWords over kit.names).
    expect(slab.word('tool:test.slab'), 'Döşeme aracı');
    expect(slab.word('type:test.slab'), 'Döşeme',
        reason: "the kit's Turkish before the host's English");
    c.reportLocale(const Locale('en'));
    expect(slab.word('type:test.slab'), 'Floor slab');
    expect(slab.word('tool:test.slab'), 'Slab');
    c.reportLocale(const Locale('de'));
    expect(disc.word('type:disc.round'), 'Runde Scheibe');
    expect(disc.word('property:disc.round.radius'), 'Radius');
    expect(slab.word('type:test.slab'), 'Floor slab',
        reason: "no German: the host's English");
  });

  test(
      'PB-words-2 a host word in no known namespace, or naming no kit, is '
      'an ArgumentError naming the first problem; any kit is a kit', () {
    for (final (id, code) in [
      ('label:test.x', 'unknownWordId'),
      ('tool:slab', 'foreignWordId'),
    ]) {
      // M-PB-W3: the constructor not calling validateHostWords.
      expect(
          () => PlanController(
              kits: [testKit()],
              words: KitNames({
                'en': {id: 'x', 'type:nokit': 'y'},
              })),
          throwsA(isA<ArgumentError>().having(
              (e) => '${e.message}',
              'message',
              allOf(contains('"$id"'), contains(code),
                  isNot(contains('type:nokit'))))),
          reason: id);
    }
    final c = PlanController(
        kits: [testKit()],
        words: const KitNames({
          'en': {'tool:acme.wall': 'Wall'},
        }));
    addTearDown(c.dispose);
    expect(c.servicesOf('test').words.maybe('tool:acme.wall'), 'Wall',
        reason: "a word for a kit not loaded is sound, and merged");
  });

  test(
      'PB-words-3 the panel\'s word lookup and the gallery\'s symbol names '
      'read the host\'s words first', () async {
    final c = PlanController(
        kits: [testKit(), demoKit()],
        words: const KitNames({
          'tr': {
            'property:test.slab.width': 'En',
            'symbol:demo.sofa.two': 'İkili koltuk',
          },
        }));
    addTearDown(c.dispose);
    c.reportLocale(const Locale('tr'));
    // M-PB-W4: planWordOf reading kit.names.
    expect(planWordOf(c, 'test', 'property:test.slab.width'), 'En');
    expect(planWordOf(c, 'test', 'property:test.slab.height'), 'Yükseklik');
    expect(c.namesOf('nokit'), isNull);
    await settle();
    // M-PB-W5: the loaded symbols kept with the kit's names only.
    expect(const PlanSymbolWords('tr').name(c.symbolById('demo.sofa.two@1')!),
        'İkili koltuk');
    expect(const PlanSymbolWords('tr').name(c.symbolById('demo.sofa.three@1')!),
        'Üçlü kanepe');
  });

  testWidgets('PB-words-4 the palette\'s label of a kit\'s tool',
      (tester) async {
    final c = PlanController(
        kits: [testKit()],
        words: const KitNames({
          'en': {'tool:test.slab': 'Floor slab tool'},
        }));
    addTearDown(c.dispose);
    late String label;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      label = planToolLabel(context, c, 'test.slab');
      return const SizedBox();
    })));
    // M-PB-W6: planToolLabel reading kit.names.
    expect(label, 'Floor slab tool');
  });
}

// Spec 14d L5, L6 (revision 2): the values the engine and the planner hand
// out instead of sentences, worded in each language (M-14d-t). Ported from
// jet_cad_floor_plan (2a Task 9): VW1 (the layer-name problems); VW2-VW4
// (tables, numbering, rooms) are 2b's. W-VW5, W-VW6: the plan library's
// own words.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

const languages = <PlanStrings>[
  PlanStringsEn(),
  PlanStringsDe(),
  PlanStringsTr(),
];

/// [word] in each language: never empty, holding every [parts], and
/// different in each language.
void expectWorded(String Function(PlanStrings s) word,
    {List<String> parts = const [], String? english}) {
  final words = [for (final s in languages) word(s)];
  for (final (i, w) in words.indexed) {
    expect(w, isNotEmpty);
    for (final p in parts) {
      expect(w, contains(p), reason: '${languages[i].languageCode}: $w');
    }
  }
  expect(words.toSet(), hasLength(3), reason: '$words');
  if (english != null) expect(words.first, english);
}

void main() {
  test('VW1 every layer-name problem in each language', () {
    expectWorded((s) => s.layerNameProblem(const LayerNameEmpty()),
        english: 'A layer name cannot be empty.');
    expectWorded((s) => s.layerNameProblem(const LayerNameEdgeSpace()));
    expectWorded((s) => s.layerNameProblem(const LayerNameTooLong(255)),
        parts: ['255']);
    expectWorded((s) => s.layerNameProblem(const LayerNameBadCharacter(';')),
        parts: [';'], english: 'A layer name cannot contain ;.');
    expectWorded((s) => s.layerNameProblem(const LayerNameDuplicate('Wände')),
        parts: ['Wände']);
    // The engine's English and the planner's are one text.
    for (final p in const <LayerNameProblem>[
      LayerNameEmpty(),
      LayerNameEdgeSpace(),
      LayerNameTooLong(255),
      LayerNameBadCharacter('|'),
      LayerNameDuplicate('A'),
    ]) {
      expect(const PlanStringsEn().layerNameProblem(p), p.toString());
    }
  });

  test('W-VW5 the plan library\'s three new words in each language', () {
    // M-W-VW5: a language that returns the English text for a new word
    // (copy-paste) makes the three not distinct.
    expectWorded((s) => s.lockedHint, english: 'This object is locked');
    expectWorded((s) => s.sectionFailed,
        english: 'This section could not be shown');
    expectWorded((s) => s.planDamaged,
        english: 'An edit failed and the plan may be damaged');
  });

  test('W-VW6 every swatch is worded, differently, in each language', () {
    // M-W-VW6: `colorName` returning one word for teal and blue in a
    // language goes red on the per-language set size.
    for (final s in languages) {
      final names = {for (final c in PlanSwatch.values) s.colorName(c)};
      expect(names, hasLength(PlanSwatch.values.length),
          reason: s.languageCode);
    }
    expectWorded((s) => s.colorName(PlanSwatch.teal), english: 'Teal');
  });
}

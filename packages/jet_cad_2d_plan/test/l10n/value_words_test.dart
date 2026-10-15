// Spec 14d L5, L6 (revision 2): the values the engine and the planner hand
// out instead of sentences, worded in each language (M-14d-t). Ported from
// jet_cad_floor_plan (2a Task 9): VW1 (the layer-name problems); VW2-VW4
// (tables, numbering, rooms) are 2b's: VW4 here (2b Task 9). W-VW5,
// W-VW6: the plan library's own words.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/unit_fixtures.dart';

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

  test('VW2 unit-label problems and the clash in each language', () {
    for (final p in UnitLabelProblem.values) {
      expectWorded((s) => s.labelProblem(p));
    }
    expect(const PlanStringsEn().labelProblem(UnitLabelProblem.length),
        '1 to 8 characters');
    expectWorded((s) => s.labelUsed('12'),
        parts: ['12'], english: 'Number 12 is already used');
  });

  test('VW3 label warnings in each language (the Room notice is 3\'s)', () {
    expectWorded(
        (s) => s.labelWarning(const DuplicateLabel(label: '7', count: 3)),
        parts: ['7', '3'],
        english: 'Number 7 is used by 3 tables');
    expectWorded(
        (s) => s.labelWarning(
            const Unlabelled(kind: 'table', capacity: 4, symbolKey: 'k')),
        parts: ['4']);
    expect(
        const PlanStringsEn().labelWarning(
            const Unlabelled(kind: 'table', capacity: 1, symbolKey: null)),
        'A table with 1 seat has no number');
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

  test('LP-W the layer picker\'s lock word in each language', () {
    // M-LP-W: a language that returns the English text for the new word.
    expectWorded((s) => s.lockedNoLayer,
        english: 'Locked objects cannot change layer');
  });

  test('ED-W the file commands\' words in each language', () {
    // M-ED-W: a language that returns the English text for one of them.
    expectWorded((s) => s.newDocument, english: 'New');
    expectWorded((s) => s.open, english: 'Open…');
    expectWorded((s) => s.save, english: 'Save');
    expectWorded((s) => s.saveAs, english: 'Save As…');
  });

  testWidgets(
      'VW4 the controller\'s numbering warnings are values: duplicates by '
      'first appearance, then the unnumbered tables (L6)', (tester) async {
    // 2b Task 9: today's three numbered placements, the third renumbered
    // 1 and the second emptied, are placed here unlabelled and labelled by
    // hand (the first and the third 1, the second none); a fourth labelled
    // 4.
    final doc = unitPlan();
    final placed = [
      for (final (x, turns) in const [(-2600.5, 1), (2300.25, 0), (900.75, 2)])
        placeAt(doc, tableSymbol(seats: 4), Vector2(x, 1400.5),
            quarterTurns: turns),
    ];
    addUnitLabel(doc, placed[0], '1');
    addUnitLabel(doc, placed[2], '1');
    // A fourth table, numbered once: no warning.
    addUnitLabel(doc,
        placeAt(doc, tableSymbol(seats: 4), Vector2(4100.25, -900.5)), '4');
    final c = PlanController(
        kits: [fxKit()], json: encodePlan(doc, validateKitSet([fxKit()])));
    addTearDown(c.dispose);
    expect(c.labelWarnings, const [
      DuplicateLabel(label: '1', count: 2),
      Unlabelled(kind: 'table', capacity: 4, symbolKey: 'fx.table.two'),
    ]);
  });
}

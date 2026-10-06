// Spec 14d L5, L6 (revision 2): the values the engine and the planner hand
// out instead of sentences, worded in each language (M-14d-t), and the
// controller's numbering warnings as values.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_controller.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_de.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_en.dart';
import 'package:jet_cad_floor_plan/src/l10n/strings_tr.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/src/tables/table_numbers.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

const languages = <FloorPlanStrings>[
  FloorPlanStringsEn(),
  FloorPlanStringsDe(),
  FloorPlanStringsTr(),
];

/// [word] in each language: never empty, holding every [parts], and
/// different in each language.
void expectWorded(String Function(FloorPlanStrings s) word,
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
      expect(const FloorPlanStringsEn().layerNameProblem(p), p.toString());
    }
  });

  test('VW2 table-number problems and the clash in each language', () {
    for (final p in TableNumberProblem.values) {
      expectWorded((s) => s.tableNumberProblem(p));
    }
    expect(
        const FloorPlanStringsEn()
            .tableNumberProblem(TableNumberProblem.length),
        tableNumberError(''));
    expectWorded((s) => s.tableNumberUsed('12'),
        parts: ['12'], english: 'Number 12 is already used');
  });

  test('VW3 numbering warnings and the Room notice in each language', () {
    expectWorded(
        (s) => s.numberingWarning(const DuplicateNumber(number: '7', count: 3)),
        parts: ['7', '3'],
        english: 'Number 7 is used by 3 tables');
    expectWorded(
        (s) => s.numberingWarning(const Unnumbered(seats: 4, symbolKey: 'k')),
        parts: ['4']);
    expect(
        const FloorPlanStringsEn()
            .numberingWarning(const Unnumbered(seats: 1, symbolKey: null)),
        'A table with 1 seat has no number');
    expectWorded((s) => s.roomOccupied('Mutfak'),
        parts: ['Mutfak'], english: 'Already a room: Mutfak');
  });

  testWidgets(
      'VW4 the controller\'s numbering warnings are values: duplicates by '
      'first appearance, then the unnumbered tables (L6)', (tester) async {
    final doc = plan();
    for (final (x, turns) in const [(-2600.5, 1), (2300.25, 0), (900.75, 2)]) {
      doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol(seats: 4)),
          at: Vector2(x, 1400.5), quarterTurns: turns));
    }
    final survey = TableSurvey.of(doc);
    doc.commands.execute(SetEntityTextCommand(
        survey.withNumber('3').single.label!, '1', kTableLabelTag));
    doc.commands.execute(SetEntityTextCommand(
        survey.withNumber('2').single.label!, '', kTableLabelTag));
    // A fourth table, numbered once: no warning.
    doc.commands.execute(placeSymbol(doc, entryOf(tableSymbol(seats: 4)),
        at: Vector2(4100.25, -900.5)));
    final c = FloorPlanController(json: DraftDocumentCodec.encodeToString(doc));
    addTearDown(c.dispose);
    expect(c.numberingWarnings, const [
      DuplicateNumber(number: '1', count: 2),
      Unnumbered(seats: 4, symbolKey: 'test.table'),
    ]);
  });
}

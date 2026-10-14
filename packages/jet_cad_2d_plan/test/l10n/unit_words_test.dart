// 2b Task 10, spec S4 "Words": a unit kind's word -- the kit's (through its
// KitWords, a host's word first), else PlanStrings' for the contract's
// kinds, else the kind as stored -- and the new words in each language.
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_words.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/unit_fixtures.dart';

/// A booth (a kit's own kind), a table and a kiosk (no word anywhere) of
/// kit `bt`, each a closed outline off its base point.
CatalogSymbol unit(String key, String kind, int capacity) => CatalogSymbol(
      key: key,
      name: key,
      category: 'Tests',
      tags: const ['test'],
      unit: CatalogUnit(kind: kind, capacity: capacity),
      base: (410.5, 220.25),
      shapes: const [
        CatalogPolyline([(100, 50), (900, 50), (900, 650), (100, 650)],
            closed: true),
      ],
    );

final CatalogSymbol booth = unit('bt.booth.corner', 'booth', 6);
final CatalogSymbol table = unit('bt.table.round', UnitKinds.table, 4);
final CatalogSymbol kiosk = unit('bt.kiosk.small', 'kiosk', 2);

/// Kit `bt`: an English and a Turkish word for its booth; no type, no
/// library (the units are placed by hand).
PlanKit btKit() => PlanKit(
    id: 'bt',
    version: '1.0.0',
    names: const KitNames({
      'en': {'unit:bt/booth': 'Booth'},
      'tr': {'unit:bt/booth': 'Loca'},
    }));

String boothPlan() => planText([btKit()], (d) {
      placeAt(d, booth, Vector2(-2600.5, 1400.25), quarterTurns: 1);
      placeAt(d, table, Vector2(2300.75, 1400.5), mirrored: true);
      placeAt(d, kiosk, Vector2(900.25, -1700.75), quarterTurns: 3);
    });

/// The kind's word of the unit of kind [kind] in [c], at [locale].
String wordOf(PlanController c, String kind, String locale) {
  c.reportLocale(Locale(locale));
  return unitKindWord(c, c.unitIndex.units.singleWhere((u) => u.kind == kind));
}

void main() {
  test(
      'UW-kind-lookup the kit\'s word in Turkish, its English in German; '
      'PlanStrings\' word for a table; the stored kind with no word', () {
    final c = controllerFor(kits: [btKit()], json: boothPlan());
    // M-UW1: the kit's step skipped.
    expect(wordOf(c, 'booth', 'tr'), 'Loca');
    expect(wordOf(c, 'booth', 'de'), 'Booth', reason: 'the English fallback');
    // M-UW2: the PlanStrings step skipped.
    expect(wordOf(c, UnitKinds.table, 'tr'), 'Masa');
    expect(wordOf(c, UnitKinds.table, 'de'), 'Tisch');
    expect(wordOf(c, 'kiosk', 'tr'), 'kiosk');
  });

  test(
      'UW-host-word-first a host\'s word comes before the kit\'s, per '
      'locale; the kit\'s still answers where the host has none', () {
    final c = PlanController(
        kits: [btKit()],
        json: boothPlan(),
        words: const KitNames({
          'tr': {'unit:bt/booth': 'Bölme'},
        }));
    addTearDown(c.dispose);
    // M-UW3 (Task 4's merge, cross-check): `kit.names.merge(words)`.
    expect(wordOf(c, 'booth', 'tr'), 'Bölme');
    expect(wordOf(c, 'booth', 'en'), 'Booth');
  });

  test(
      'UW-words the unit words in each language: never empty, each '
      'language its own; unitKind for table and seat only', () {
    const languages = <PlanStrings>[
      PlanStringsEn(),
      PlanStringsDe(),
      PlanStringsTr(),
    ];
    for (final word in <String Function(PlanStrings)>[
      (s) => s.merge,
      (s) => s.split,
      (s) => s.number,
      (s) => s.label,
      (s) => s.capacity,
      (s) => s.rotateLeft,
      (s) => s.rotateRight,
      (s) => s.unitKind(UnitKinds.table)!,
      (s) => s.unitKind(UnitKinds.seat)!,
      (s) => s.labelWarning(
          const BadLabel(label: 'A\u0007', problem: UnitLabelProblem.control)),
    ]) {
      final words = [for (final s in languages) word(s)];
      expect(words, everyElement(isNotEmpty));
      expect(words.toSet(), hasLength(3), reason: '$words');
    }
    for (final s in languages) {
      // M-UW4: unitKind answering a word for any kind.
      expect(s.unitKind('booth'), isNull, reason: s.languageCode);
    }
    expect(const PlanStringsEn().unitKind(UnitKinds.seat), 'Seat');
  });
}

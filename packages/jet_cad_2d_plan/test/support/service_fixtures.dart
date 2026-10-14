// The service view tests' fixtures (2b Task 16): today's view_test.dart
// pagePlan (:39-55) and table_groups_toolbar_test.dart's toolbarPlanJson
// (:25-84), over the units' fixture (Tasks 6 and 8) and the fixture kit
// `fx`; the embedding fixture (Task 9) and the units' fixture re-exported,
// so a ported view test imports this file alone. Every placement is off
// the origin, turned or mirrored.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart' show planText;
import 'unit_fixtures.dart';

export 'unit_embedding_fixture.dart';
export 'unit_fixtures.dart'
    show
        addLayer,
        addUnitLabel,
        entryOf,
        fxKit,
        kDeg37,
        placeAt,
        placeUnit,
        placementAt,
        tableSymbol,
        trapezoidTable;

/// view_test.dart:39-55: tables 1 (a quarter turn, mirrored) and 2 on the
/// default page, off its centre; labelled as today's numbering placer
/// labelled them.
String pagePlan() => planText([fxKit()], (doc) {
      final sheet =
          sheetWorldRect(doc.components.get<PageComponent>(doc.rootHandle)!);
      final cx = (sheet.minX + sheet.maxX) / 2,
          cy = (sheet.minY + sheet.maxY) / 2;
      final one = placeAt(doc, tableSymbol(), Vector2(cx - 2600, cy + 900),
          quarterTurns: 1, mirrored: true);
      addUnitLabel(doc, one, '1');
      final two = placeAt(doc, tableSymbol(), Vector2(cx + 2100, cy - 700));
      addUnitLabel(doc, two, '2');
      doc.commands.clearHistory();
    });

/// table_groups_toolbar_test.dart:25.
const List<String> kToolbarNumbers = ['12', '3', '7', '20', '5', '8', '9'];

/// table_groups_toolbar_test.dart:33-84: tables labelled [kToolbarNumbers]
/// in handle order, each off the origin, turned or mirrored, table 3 an
/// asymmetric mirrored trapezoid; table 8 on a visible locked layer, table
/// 9 on a hidden one; two unlabelled tables last. [duplicate] renames
/// table 5 to "3" (a file duplicate).
String toolbarPlanJson({bool duplicate = false}) => planText([fxKit()], (doc) {
      final locked = addLayer(doc, 'Locked', visible: true, locked: true);
      final hidden = addLayer(doc, 'Hidden', visible: false, locked: false);
      final placements = [
        (tableSymbol(), placementAt(-2600, 1400, kDeg37, mirrored: true)),
        (
          trapezoidTable,
          placementAt(2300, 1700, kDeg37 * 2, mirrored: true, baseY: 650)
        ),
        (tableSymbol(), placementAt(5100, -900, -kDeg37, mirrored: true)),
        (tableSymbol(), placementAt(-4300, -2600, 0, mirrored: true)),
        (tableSymbol(), placementAt(800, -3300, kDeg37)),
        (tableSymbol(), placementAt(6400, 2400, kDeg37 * 3)),
        (tableSymbol(), placementAt(-6100, 3600, -kDeg37 * 2, mirrored: true)),
      ];
      for (var i = 0; i < placements.length; i++) {
        final (symbol, p) = placements[i];
        final h = placeUnit(doc, symbol,
            transform: p,
            layer: switch (i) { 5 => locked, 6 => hidden, _ => null });
        final n =
            duplicate && kToolbarNumbers[i] == '5' ? '3' : kToolbarNumbers[i];
        addUnitLabel(doc, h, n);
      }
      for (final p in [
        placementAt(3700, 4500, kDeg37 * 3, mirrored: true),
        placementAt(-1300, 4700, -kDeg37),
      ]) {
        placeUnit(doc, tableSymbol(), transform: p);
      }
      doc.commands.clearHistory();
    });

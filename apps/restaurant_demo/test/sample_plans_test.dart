// The demo's sample plans (apps/restaurant_demo/assets/plans): built here
// with the editor's own placement, and compared with the committed assets
// byte for byte. `UPDATE_SAMPLES=1 flutter test test/sample_plans_test.dart`
// rewrites them.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_floor_plan/editor.dart';
import 'package:jet_cad_restaurant_symbols/jet_cad_restaurant_symbols.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

/// The restaurant library, decoded once.
final List<SymbolEntry> _entries = SymbolLibrary.decode(Uint8List.fromList(
        utf8.encode(DraftDocumentCodec.encodeToString(
            buildSymbolLibrary(restaurantCatalog)))))
    .entries;

SymbolEntry _entry(String key) => _entries.firstWhere((e) => e.key == key);

/// A plan on the default page with [placements]: (key, x, y, quarter
/// turns), x and y in mm from the sheet's lower-left corner.
String _plan(List<(String, double, double, int)> placements) {
  final doc = newDocument(MetricModelMeasurer());
  final sheet =
      sheetWorldRect(doc.components.get<PageComponent>(doc.rootHandle)!);
  for (final (key, x, y, turns) in placements) {
    doc.commands.execute(placeSymbol(doc, _entry(key),
        at: Vector2(sheet.minX + x, sheet.minY + y), quarterTurns: turns));
  }
  return '${const JsonEncoder.withIndent(' ').convert(jsonDecode(DraftDocumentCodec.encodeToString(doc)))}\n';
}

/// Salon: four-seat tables, round six-seat tables, two booths, a bar with
/// four stools and a host stand. Numbered in this order: 1-3, 4-5, 6-7,
/// 8-11.
String salonPlan() => _plan([
      ('restaurant.table.rect.four', 2500, 7600, 0),
      ('restaurant.table.rect.four', 5000, 7600, 0),
      ('restaurant.table.rect.four', 7500, 7600, 0),
      ('restaurant.table.round.six', 2700, 4300, 0),
      ('restaurant.table.round.six', 5700, 4300, 0),
      ('restaurant.booth.four', 11000, 8300, 0),
      ('restaurant.booth.four', 11000, 5600, 0),
      ('restaurant.bar.stool', 7700, 2650, 0),
      ('restaurant.bar.stool', 8500, 2650, 0),
      ('restaurant.bar.stool', 9300, 2650, 0),
      ('restaurant.bar.stool', 10100, 2650, 0),
      ('restaurant.bar.counter', 8900, 1800, 0),
      ('restaurant.host.stand', 13600, 1300, 0),
    ]);

/// Teras: four round four-seat tables, two high tables and planters.
String terasPlan() => _plan([
      ('restaurant.table.round.four', 3000, 7000, 0),
      ('restaurant.table.round.four', 6000, 7000, 0),
      ('restaurant.table.round.four', 3000, 3800, 0),
      ('restaurant.table.round.four', 6000, 3800, 0),
      ('restaurant.bar.table.high.two', 9500, 7000, 0),
      ('restaurant.bar.table.high.two', 9500, 3800, 0),
      ('restaurant.planter.round', 1000, 9500, 0),
      ('restaurant.planter.round', 13500, 9500, 0),
      ('restaurant.planter.long', 7300, 1000, 0),
    ]);

void main() {
  for (final (name, build) in [('salon', salonPlan), ('teras', terasPlan)]) {
    test('the committed $name plan is the built one', () {
      final file = File('assets/plans/$name.json');
      final built = build();
      if (Platform.environment['UPDATE_SAMPLES'] == '1') {
        file.writeAsStringSync(built);
      }
      expect(file.readAsStringSync(), built);
    });
  }
}

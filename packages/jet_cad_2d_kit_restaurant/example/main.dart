// The restaurant kit as a host sees it. A host passes `restaurantKit` to the
// plan library -- `PlanController(kits: [restaurantKit])`, and a `PlanEditor`
// over it (the plan library's package) -- which this package does not depend
// on, nor does its example. What the example shows is the descriptor itself,
// and the library a `PlanBuild` places from: its categories, and the seated
// symbols, the numbered table units.
//
// The kit is a Flutter library (its source reads a bundled asset): the
// example is analysed with the package, and test/example_test.dart runs it.
import 'package:jet_cad_2d_kit_restaurant/jet_cad_2d_kit_restaurant.dart';

/// The kit's descriptor, line by line: its id and version, what `validate`
/// finds, the library's size, each category with its symbols, and one table
/// unit with its capacity.
List<String> describeRestaurantKit() {
  final kit = restaurantKit;
  final problems = kit.validate();
  final entries = restaurantSymbolEntries().values;
  final byCategory = <String, int>{};
  for (final e in entries) {
    byCategory.update(e.symbol.category, (n) => n + 1, ifAbsent: () => 1);
  }
  final units = entries.where((e) => e.unit != null);
  final table =
      restaurantSymbolEntries()['${RestaurantSymbols.tableRectSix}@1']!;
  return [
    '${kit.id} ${kit.version}: ${entries.length} symbols, '
        '${units.length} table units',
    problems.isEmpty
        ? 'validate: no problems'
        : 'validate: ${problems.length} problems',
    for (final MapEntry(key: category, value: n) in byCategory.entries)
      '$category: $n',
    '${table.symbol.name}: ${table.unit!.kind} unit, '
        '${table.unit!.capacity} seats',
  ];
}

void main() {
  for (final line in describeRestaurantKit()) {
    print(line);
  }
}

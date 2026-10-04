// The restaurant catalog (spec 14 V-6): every category in palette order.
// Pure Dart: the generator runs under plain `dart`.
import 'package:jet_cad_floor_plan/symbols.dart';

import 'bar.dart';
import 'booths.dart';
import 'kitchen.dart';
import 'outdoor.dart';
import 'service.dart';
import 'tables.dart';

/// The library's categories, in palette order.
const List<String> restaurantCategories = [
  restaurantTables,
  boothsAndLounge,
  bar,
  service,
  commercialKitchen,
  outdoorAndDecor,
];

/// Every restaurant symbol, in the order the library stores it: definition
/// and leaf handles ascend in this order.
final List<FurnitureSymbol> restaurantCatalog = List.unmodifiable([
  ...tablesCatalog,
  ...boothsCatalog,
  ...barCatalog,
  ...serviceCatalog,
  ...kitchenCatalog,
  ...outdoorCatalog,
]);

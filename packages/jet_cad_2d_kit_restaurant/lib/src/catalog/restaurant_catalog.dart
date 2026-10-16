// The restaurant catalog: every category in palette order, the 69 symbols of
// jet_cad_restaurant_symbols on the kit contract's authoring language.
//
// Pure Dart: the generator runs it under plain `dart run`.
import 'package:jet_cad_2d_kit/authoring.dart';

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
final Catalog restaurantCatalog = Catalog(kit: 'restaurant', symbols: [
  ...tablesCatalog,
  ...boothsCatalog,
  ...barCatalog,
  ...serviceCatalog,
  ...kitchenCatalog,
  ...outdoorCatalog,
]);

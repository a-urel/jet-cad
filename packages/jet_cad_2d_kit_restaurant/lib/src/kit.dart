// The restaurant kit's descriptor (spec 4a R1): its one symbol source and
// its words. No types, no tools, no attachments.
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'restaurant_names.dart';
import 'restaurant_source.dart';

/// The restaurant kit: a host passes it to the plan library,
/// `PlanController(kits: [restaurantKit])`.
final PlanKit restaurantKit = PlanKit(
  id: 'restaurant',
  version: '0.1.2',
  symbols: [restaurantSymbolSource],
  names: restaurantNames,
);

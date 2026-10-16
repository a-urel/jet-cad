// The Teras sample: four round four-seat tables, two high tables and three
// planters, as a `PlanBuild`. The old plan (assets/plans/teras.json, dropped
// with the old packages) held these nine placements and no wall; the
// positions are the old ones, in mm from the sheet's lower-left corner.
// Numbered in build order: 1-4 the round tables, 5-6 the high tables.
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords;

import 'place_tables.dart';

/// Builds the Teras into [document] (a `PlanBuild`).
void buildTeras(DraftDocument document, KitWords words) {
  final p = TablePlacer(document);
  p.place('restaurant.table.round.four', 3000, 7000);
  p.place('restaurant.table.round.four', 6000, 7000);
  p.place('restaurant.table.round.four', 3000, 3800);
  p.place('restaurant.table.round.four', 6000, 3800);
  p.place('restaurant.bar.table.high.two', 9500, 7000);
  p.place('restaurant.bar.table.high.two', 9500, 3800);
  p.place('restaurant.planter.round', 1000, 9500);
  p.place('restaurant.planter.round', 13500, 9500);
  p.place('restaurant.planter.long', 7300, 1000);
}

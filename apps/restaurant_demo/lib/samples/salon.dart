// The Salon sample: four-seat tables, round six-seat tables, two booths, a
// bar with four stools and a host stand, as a `PlanBuild`. The old plan
// (assets/plans/salon.json, dropped with the old packages) held these
// thirteen placements and no wall; the positions are the old ones, in mm
// from the sheet's lower-left corner. Numbered in build order: tables 1-3,
// 4-5, the booths 6-7, the stools 8-11.
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftDocument;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show KitWords;

import 'place_tables.dart';

/// Builds the Salon into [document] (a `PlanBuild`).
void buildSalon(DraftDocument document, KitWords words) {
  final p = TablePlacer(document);
  p.place('restaurant.table.rect.four', 2500, 7600);
  p.place('restaurant.table.rect.four', 5000, 7600);
  p.place('restaurant.table.rect.four', 7500, 7600);
  p.place('restaurant.table.round.six', 2700, 4300);
  p.place('restaurant.table.round.six', 5700, 4300);
  p.place('restaurant.booth.four', 11000, 8300);
  p.place('restaurant.booth.four', 11000, 5600);
  p.place('restaurant.bar.stool', 7700, 2650);
  p.place('restaurant.bar.stool', 8500, 2650);
  p.place('restaurant.bar.stool', 9300, 2650);
  p.place('restaurant.bar.stool', 10100, 2650);
  p.place('restaurant.bar.counter', 8900, 1800);
  p.place('restaurant.host.stand', 13600, 1300);
}

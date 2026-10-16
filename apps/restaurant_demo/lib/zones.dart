// The Salon's zones (zone spec Z22): host data, a table's attribute in a
// POS's database, never the plan's. A zone frames its tables and may fade
// the others.
import 'area.dart';

/// The demo's zones by area. Zone names are data, not translated.
const Map<String, Map<String, Set<String>>> kDemoZones = {
  'Salon': {
    'A': {'1', '2', '3', '4', '5'},
    'B': {'6', '7'},
    'C': {'8', '9', '10', '11'},
  },
};

/// A zone tab: the zone's tables framed, the page when none is drawn, and
/// the others faded when [fadeOthers].
void showZone(Area a, Set<String> numbers, {required bool fadeOthers}) {
  final c = a.controller;
  if (!c.fitToUnits(numbers)) c.fitToView();
  c.setUnitFocus(fadeOthers ? numbers : null);
}

/// The All tab: the page, no focus.
void showAllZones(Area a) {
  a.controller
    ..fitToView()
    ..setUnitFocus(null);
}

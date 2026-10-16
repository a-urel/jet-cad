// One dining area: its name, its own `PlanController` (nothing is shared
// between two areas, so a status, a selection or an undo in one never
// reaches the other), its zones and the host's status names. Pure state.
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// One dining area.
final class Area {
  Area(this.name, this.controller, {this.zones = const {}});

  final String name;
  final PlanController controller;

  /// The area's zones by name, each its table numbers: none for an area
  /// without zones.
  final Map<String, Set<String>> zones;

  /// The zone shown, null for all of them; kept with the area.
  String? zone;

  /// Whether the tables outside [zone] fade; kept with the area.
  bool fadeOthers = false;

  /// Each table's status by its `kStatuses` name, so the captions are
  /// worded again when the language changes.
  final Map<String, String> statusNames = {};

  /// Each group's status by name, as [statusNames].
  final Map<String, String> groupStatusNames = {};
}

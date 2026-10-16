// One dining area: its name, its own `PlanController` (nothing is shared
// between two areas, so a status, a selection or an undo in one never
// reaches the other), its zones, the plan last saved, the service layout last
// seen, its badges switch, its POS ids and the host's status names. Pure
// state.
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// One dining area.
final class Area {
  Area(this.name, this.controller,
      {this.zones = const {},
      this.offersBadges = false,
      this.tableIds = const {}});

  final String name;
  final PlanController controller;

  /// The plan last saved (`controller.save()`), in memory; null until a
  /// Save (a save settles the plan's decimal separator, so none is taken at
  /// the start). Revert reloads it, or makes a new plan when there is none.
  String? stored;

  /// The service layout last seen (`controller.serviceJson()`), kept on
  /// every change of the record, never on a mode switch or a load.
  String? layout;

  /// The POS's tables in this area, by id (`kDemoTableIds`).
  final Set<String> tableIds;

  /// Whether the service view offers the "Badges" switch.
  final bool offersBadges;

  /// Whether the service view shows a badge on each table; kept with the
  /// area.
  bool badges = false;

  /// The last answer of the demo's own bar's export dialog, as the planner
  /// remembers its own (`pageFlows` is internal, so the own bar keeps one).
  PlanExportAnswer ownAnswer = PlanExportAnswer.initial;

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

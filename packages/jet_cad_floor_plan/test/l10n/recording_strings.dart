// Generated from lib/src/l10n/strings.dart (spec 14d L1 as amended,
// V-10): a language whose every word is recorded as it is handed out, so a
// test can tell a word the planner asked for from a literal it did not.
// Regenerate with the plan's script when a member is added.
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show LayerNameProblem;
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart'
    show NumberingWarning;
import 'package:jet_cad_floor_plan/src/tables/table_numbers.dart'
    show TableNumberProblem;

class RecordingFloorPlanStrings implements FloorPlanStrings {
  RecordingFloorPlanStrings(this.inner);

  final FloorPlanStrings inner;

  /// Every string handed out.
  final Set<String> handedOut = {};

  /// Records [s] as handed out and returns it.
  String record(String s) {
    handedOut.add(s);
    return s;
  }

  @override
  String get languageCode => inner.languageCode;

  @override
  String get decimalSeparator => inner.decimalSeparator;

  @override
  String layerNameProblem(LayerNameProblem problem) =>
      record(inner.layerNameProblem(problem));

  @override
  String tableNumberProblem(TableNumberProblem problem) =>
      record(inner.tableNumberProblem(problem));

  @override
  String tableNumberUsed(String number) =>
      record(inner.tableNumberUsed(number));

  @override
  String numberingWarning(NumberingWarning warning) =>
      record(inner.numberingWarning(warning));

  @override
  String roomOccupied(String name) => record(inner.roomOccupied(name));
}

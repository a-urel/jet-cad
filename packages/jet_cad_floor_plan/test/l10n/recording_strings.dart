// Generated from lib/src/l10n/strings.dart (spec 14d L1 as amended,
// V-10): a language whose every word is recorded as it is handed out, so a
// test can tell a word the planner asked for from a literal it did not.
// Regenerate with the plan's script when a member is added.
import 'package:jet_cad_floor_plan/src/l10n/strings.dart';

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
}

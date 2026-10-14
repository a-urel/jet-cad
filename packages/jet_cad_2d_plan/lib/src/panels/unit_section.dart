// The unit section's model (spec 2b S4, the unit section; today's Table
// section, jet_cad_floor_plan/lib/src/selection_panel.dart:437-456,
// :1193-1248): which placed unit it shows and why a text cannot be its
// label. The widgets are the property panel's.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../l10n/strings.dart';
import '../units/unit_index.dart';
import '../units/unit_label.dart' show unitLabelProblem;

/// The placed unit [handle] names in [index], or null (no unit, or a
/// generated one: its object stands for it in design).
UnitInfo? placedUnitOf(UnitIndex index, Handle handle) {
  final u = index[handle];
  return u == null || u.generated ? null : u;
}

/// Why [text] (trimmed) cannot be [unit]'s label, worded on demand: the
/// text rule's problem, or a label another unit holds (today's
/// `_parseNumber`, :437-456). Null when it can, or when it is the unit's
/// own label (an unlabelled unit's empty field included: no error).
String Function(PlanStrings)? labelRefusal(
    UnitIndex index, UnitInfo unit, String text) {
  final t = text.trim();
  if (t == (unit.text ?? '')) return null;
  final problem = unitLabelProblem(t);
  if (problem != null) return (s) => s.labelProblem(problem);
  if (index.withLabel(t).any((o) => o.instance != unit.instance)) {
    return (s) => s.labelUsed(t);
  }
  return null;
}

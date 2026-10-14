// The units' diagnostics and label warnings (spec 2b S2 "Diagnostics",
// "Unlabelled, duplicate and bad labels"): today's table codes and
// NumberingWarning (jet_cad_floor_plan/lib/src/tables/table_index.dart:
// 228-243; host/floor_plan_types.dart:197-243), renamed, plus the bad label.
import 'unit_label.dart' show UnitLabelProblem;

/// The codes `UnitIndex.diagnostics` raises.
abstract final class UnitProblem {
  static const String duplicateLabel = 'unit.duplicate_label';
  static const String unlabelled = 'unit.unlabelled';
  static const String badLabel = 'unit.bad_label';
  static const String extraLabel = 'unit.extra_label';
  static const String nested = 'unit.nested';

  /// Host data outside the limits: kept as read, reads as none.
  static const String invalidData = 'unit.invalid_data';

  /// A colour of another shape, or a swatch this release does not know:
  /// kept as read, drawn as none.
  static const String invalidColour = 'unit.invalid_colour';
}

/// A problem with the plan's unit labels, as a value the host words, or
/// asks `PlanStrings.labelWarning` to. Never a handle.
sealed class UnitLabelWarning {
  const UnitLabelWarning();
}

/// [count] live units carry [label].
final class DuplicateLabel extends UnitLabelWarning {
  const DuplicateLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DuplicateLabel && other.label == label && other.count == count;

  @override
  int get hashCode => Object.hash(label, count);

  @override
  String toString() => 'DuplicateLabel($label, $count)';
}

/// A live unit carries no label. Two of one symbol read alike: the host
/// sees how many there are.
final class Unlabelled extends UnitLabelWarning {
  const Unlabelled(
      {required this.kind, required this.capacity, required this.symbolKey});

  final String kind;
  final int capacity;
  final String? symbolKey;

  @override
  bool operator ==(Object other) =>
      other is Unlabelled &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.symbolKey == symbolKey;

  @override
  int get hashCode => Object.hash(kind, capacity, symbolKey);

  @override
  String toString() => 'Unlabelled($kind, $capacity, $symbolKey)';
}

/// A live unit's [label] breaks the text rule ([problem]); it is still its
/// label, served by its text.
final class BadLabel extends UnitLabelWarning {
  const BadLabel({required this.label, required this.problem});

  final String label;
  final UnitLabelProblem problem;

  @override
  bool operator ==(Object other) =>
      other is BadLabel && other.label == label && other.problem == problem;

  @override
  int get hashCode => Object.hash(label, problem);

  @override
  String toString() => 'BadLabel($label, ${problem.name})';
}

// What a host reads of one object of the plan (spec D8, D9).
import 'package:flutter/foundation.dart' show immutable, mapEquals;

import 'object_ref.dart';

/// What an object is.
enum PlanObjectKind {
  /// A placed unit: a symbol that can be served, with a label.
  unit,

  /// A placed symbol that is not a unit.
  symbol,

  /// An object of a kit's type (a room, a wall).
  type,
}

/// One object of the plan as `PlanController.objectDetailOf` reads it.
@immutable
final class PlanObjectDetail {
  const PlanObjectDetail({
    required this.ref,
    required this.kind,
    this.typeId,
    this.symbolKey,
    this.label,
    this.data = const <String, String>{},
  });

  /// The object's name. Valid for the plan it was read from (and that plan
  /// saved and loaded again); drop it after `newPlan` or a load of another
  /// plan, and read it again.
  final PlanObjectRef ref;

  final PlanObjectKind kind;

  /// The type's id, for a [PlanObjectKind.type] object; else null.
  final String? typeId;

  /// The library key of the symbol, for a unit or a placed symbol; else
  /// null.
  final String? symbolKey;

  /// A unit's label (null when it has none); a type object's title word in
  /// the plan's words (a room's name); null for a plain symbol.
  final String? label;

  /// The host's data on the object, keys ascending, unmodifiable. Empty for
  /// none, and for stored data outside the limits (kept as read).
  final Map<String, String> data;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectDetail &&
      other.ref == ref &&
      other.kind == kind &&
      other.typeId == typeId &&
      other.symbolKey == symbolKey &&
      other.label == label &&
      mapEquals(other.data, data);

  @override
  int get hashCode => Object.hash(
      ref,
      kind,
      typeId,
      symbolKey,
      label,
      Object.hashAllUnordered([
        for (final e in data.entries) Object.hash(e.key, e.value),
      ]));

  @override
  String toString() => 'PlanObjectDetail($ref, $kind, typeId: $typeId, '
      'symbolKey: $symbolKey, label: $label, data: $data)';
}

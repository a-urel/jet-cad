// The designed plan's table changes, as `FloorPlanController.designChanges`
// reports them (host embedding API spec E-5): a table added, removed or
// changed by a design edit, an undo or a redo, and the whole plan replaced.
// Tables are matched by instance, which stays internal (umbrella D18): an
// undone delete re-adds the same instance, so it is an add of the same
// table, never a remove and an add of two.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart' show Handle;

import 'table_detail.dart';

/// One change of the designed plan's tables (spec E-5), as
/// `FloorPlanController.designChanges` reports it: [FloorPlanTableAdded],
/// [FloorPlanTableRemoved], [FloorPlanTableChanged] or
/// [FloorPlanPlanReplaced].
@immutable
sealed class FloorPlanDesignChange {
  const FloorPlanDesignChange();
}

/// A table now in the designed plan that was not: placed, pasted, or a
/// delete undone (then [table] equals the [FloorPlanTableRemoved.table] the
/// delete reported, its data included).
final class FloorPlanTableAdded extends FloorPlanDesignChange {
  const FloorPlanTableAdded(this.table);

  /// The table as it is now.
  final FloorPlanTableDetail table;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableAdded && other.table == table;

  @override
  int get hashCode => Object.hash(FloorPlanTableAdded, table);

  @override
  String toString() => 'FloorPlanTableAdded($table)';
}

/// A table no longer in the designed plan: deleted, or its placement
/// undone.
final class FloorPlanTableRemoved extends FloorPlanDesignChange {
  const FloorPlanTableRemoved(this.table);

  /// The table as it last was.
  final FloorPlanTableDetail table;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableRemoved && other.table == table;

  @override
  int get hashCode => Object.hash(FloorPlanTableRemoved, table);

  @override
  String toString() => 'FloorPlanTableRemoved($table)';
}

/// One table of the designed plan whose detail changed: its number, seats,
/// symbol, geometry, layer, lock, visibility or data. [before] and [after]
/// are the same table (the same instance), whatever its number reads.
final class FloorPlanTableChanged extends FloorPlanDesignChange {
  const FloorPlanTableChanged(this.before, this.after);

  /// The table as it was.
  final FloorPlanTableDetail before;

  /// The table as it is now.
  final FloorPlanTableDetail after;

  @override
  bool operator ==(Object other) =>
      other is FloorPlanTableChanged &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(FloorPlanTableChanged, before, after);

  @override
  String toString() => 'FloorPlanTableChanged($before, $after)';
}

/// The designed plan was replaced whole (`load`, `newPlan`), in either
/// mode: a host reads `tableDetails` again rather than expecting a change
/// per table.
final class FloorPlanPlanReplaced extends FloorPlanDesignChange {
  const FloorPlanPlanReplaced();

  @override
  bool operator ==(Object other) => other is FloorPlanPlanReplaced;

  @override
  int get hashCode => (FloorPlanPlanReplaced).hashCode;

  @override
  String toString() => 'FloorPlanPlanReplaced()';
}

/// The changes from [before] to [after] (spec E-5), each list ascending by
/// instance with [beforeInstances] and [afterInstances] naming each entry's
/// instance index for index: a table whose instance is only in [before] is
/// removed, only in [after] added, in both and unequal changed. Ascending
/// by instance. O(before + after).
List<FloorPlanDesignChange> diffTableDetails(
    List<Handle> beforeInstances,
    List<FloorPlanTableDetail> before,
    List<Handle> afterInstances,
    List<FloorPlanTableDetail> after) {
  final out = <FloorPlanDesignChange>[];
  var i = 0, j = 0;
  while (i < before.length || j < after.length) {
    final a = i < before.length ? beforeInstances[i].value : null;
    final b = j < after.length ? afterInstances[j].value : null;
    if (b == null || (a != null && a < b)) {
      out.add(FloorPlanTableRemoved(before[i++]));
    } else if (a == null || b < a) {
      out.add(FloorPlanTableAdded(after[j++]));
    } else {
      if (before[i] != after[j]) {
        out.add(FloorPlanTableChanged(before[i], after[j]));
      }
      i++;
      j++;
    }
  }
  return out;
}

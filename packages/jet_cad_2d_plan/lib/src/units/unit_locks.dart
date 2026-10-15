// The one lock predicate of a unit (spec 2b S2 "Locked units"): its layer
// is locked (today's locked table), or 2a's lock set covers it (a placed
// unit of a missing kit's symbol, a frozen object's or a missing kit's
// object's seat, a seat of a missing kit's definition). Used by the service
// tool, unitDetails.locked, the record's strict match and the design writes.
import 'package:jet_cad_2d/jet_cad_2d.dart';

import '../kits/locks.dart';

/// Whether the unit [instance] of [document] is locked.
bool isLockedUnit(CommandTarget document, LockSet locks, Handle instance) {
  final node = document.tree[instance];
  if (node is InstanceNode &&
      (document.tables.layers[node.layer]?.locked ?? false)) {
    return true;
  }
  return locks.covers(document, instance);
}

/// The type id of the first unknown kit-namespaced component on [group]:
/// what a group the lock set holds for a missing kit was, by the rule
/// `LockSet` reads ([unknownKitTypeIdOf]). Null when it carries none.
String? heldTypeOf(CommandTarget document, Handle group) =>
    unknownKitTypeIdOf(document, group);

// Spec 2a P2 "Permissions" (the select gates: move, rotate, reshape,
// delete) and P4 "Locks" (the gates refuse a locked object), 2a Task 12; and
// 2b S2 "In design, a generated unit stands for its object" and S4
// selectUnitsOnly (Task 8). One object on the select tool and on the grip
// cache, as today's shell shares one (planner_shell.dart:439-445,
// :648-657, :1797-1846). jet_cad_2d_flutter is unchanged: the gates replace
// the tool's pick and filter its band.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/permissions.dart';
import '../kits/locks.dart' show LockGates;
import '../service/unit_picker.dart';
import '../units/unit_index.dart';

/// Past this many parents a chain is taken as no object's (the tree refuses
/// cycles; this only bounds a malformed one).
const int _maxDepth = 4096;

/// The root-level object [h] stands for in design (spec S2), or null: the
/// root-level node above [h] when it is a [GroupNode] other than [h] that
/// is an object of a registered type ([ParametricCatalog.typeIdOf], frozen
/// objects included) or a lock-set object ([locked], the controller's
/// `locked`). A root-level key, and a key under a plain group, stand for
/// themselves. An entity key starts from its owner. Walks the parents
/// only: no allocation (hover rate).
Handle? generatingObjectOf(
    DraftDocument d, Handle h, ParametricCatalog catalog, Set<Handle> locked) {
  final root = d.rootHandle;
  var current = h;
  final slot = d.entities.slotOf(h);
  if (slot != null) current = d.entities.ownerAt(slot);
  if (current == root) return null;
  for (var depth = 0; depth < _maxDepth; depth++) {
    final node = d.tree[current];
    if (node == null) return null;
    final up = node.parent;
    if (up == root) {
      if (current == h || node is! GroupNode) return null;
      return catalog.typeIdOf(d, current) != null || locked.contains(current)
          ? current
          : null;
    }
    if (up.isNone || up == current) return null;
    current = up;
  }
  return null;
}

/// Whether [key] names a placed unit of [index] (today's `_isTableKey`,
/// planner_shell.dart:1787-1795): a root key whose target is a root-level
/// instance of a unit definition.
bool isPlacedUnitKey(UnitIndex index, SelectionKey key) =>
    key.chain.isEmpty && index[key.target]?.generated == false;

/// The select tool's and the grip cache's gates: each drag kind and Delete
/// need their [PlanPermissions] flag, and a selection holding a locked
/// object (or a key inside one) shuts them all ([LockGates]). In design the
/// pick and the band map a generated unit to its object (spec S2); under
/// [PlanPermissions.selectUnitsOnly] they pick placed units only.
///
/// The getters are read at every hover, key and frame (`SelectGates`'s
/// contract): the lock state is [LockGates]' cached `bool`, and the
/// permissions are read through one closure call.
final class PlanSelectGates extends LockGates {
  PlanSelectGates({
    required PlanPermissions Function() permissions,
    required super.selection,
    required super.locked,
    required ParametricCatalog catalog,
    required UnitPicker Function() picker,
    required UnitIndex Function() units,
  })  : _permissions = permissions,
        _lockedObjects = locked,
        _catalog = catalog,
        _picker = picker,
        _units = units;

  final PlanPermissions Function() _permissions;
  final ValueListenable<Set<Handle>> _lockedObjects;
  final ParametricCatalog _catalog;
  final UnitPicker Function() _picker;
  final UnitIndex Function() _units;
  final HitPath _hit = HitPath();

  /// The select tool's idle keys (Escape, Delete, Backspace while no
  /// gesture runs): the shortcuts' option (Task 16 sets it).
  @override
  bool idleKeys = true;

  /// The design's pick is always the gates' (spec S2).
  @override
  bool get restrictsPick => true;

  /// The tool's own pick (the precise radius, then a finger's reach,
  /// select_tool.dart:160-171), resolved by [resolveHit], then mapped to
  /// its object ([generatingObjectOf]). Under selectUnitsOnly, the
  /// units-only picker's: a placed unit's top, else its box, within the
  /// pick tolerance for a mouse and the reach for a finger; a locked unit
  /// passed over (planner_shell.dart:1817-1826).
  @override
  SelectionKey? pick(ToolPointerEvent e, ToolContext ctx) {
    if (_permissions().selectUnitsOnly) {
      final hit = _picker().pick(e.world,
          reach: e.isTouch ? e.reachRadiusWorld : e.pickRadiusWorld);
      return hit == null ? null : SelectionKey.root(hit.instance);
    }
    if (!ctx.index.pickInto(
            e.world, e.pickRadiusWorld, const QueryFilter.picking(), _hit) &&
        (e.reachRadiusWorld <= e.pickRadiusWorld ||
            !ctx.index.pickInto(e.world, e.reachRadiusWorld,
                const QueryFilter.picking(), _hit))) {
      return null;
    }
    final key = resolveHit(_hit, ctx.document);
    if (key == null) return null;
    final object = generatingObjectOf(
        ctx.document, key.target, _catalog, _lockedObjects.value);
    return object == null ? key : SelectionKey.root(object);
  }

  /// A key under a parametric or lock-set object is refused (the band's
  /// group rule gives the object itself: a crossing takes a row, a window
  /// over a seats-only row takes nothing, decision 9). Under
  /// selectUnitsOnly, placed units only.
  @override
  bool bandAccepts(DraftDocument d, SelectionKey key) {
    if (_permissions().selectUnitsOnly) return isPlacedUnitKey(_units(), key);
    return generatingObjectOf(d, key.target, _catalog, _lockedObjects.value) ==
        null;
  }

  @override
  bool get move => _permissions().move && super.move;

  @override
  bool get rotate => _permissions().rotate && super.rotate;

  @override
  bool get reshape => _permissions().reshape && super.reshape;

  @override
  bool get delete => _permissions().delete && super.delete;
}

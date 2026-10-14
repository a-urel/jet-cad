// Spec P2 "Permissions" (the select gates: move, rotate, reshape, delete)
// and P4 "Locks" (the gates refuse a locked object), Task 12. One object on
// the select tool and on the grip cache, as today's shell shares one
// (planner_shell.dart:439-445, :648-657).
import '../controller/permissions.dart';
import '../kits/locks.dart' show LockGates;

/// The select tool's and the grip cache's gates: each drag kind and Delete
/// need their [PlanPermissions] flag, and a selection holding a locked
/// object (or a key inside one) shuts them all ([LockGates]).
///
/// The getters are read at every hover, key and frame (`SelectGates`'s
/// contract) and allocate nothing: the lock state is [LockGates]' cached
/// `bool`, and the permissions are read through one closure call.
final class PlanSelectGates extends LockGates {
  PlanSelectGates({
    required PlanPermissions Function() permissions,
    required super.selection,
    required super.locked,
  }) : _permissions = permissions;

  final PlanPermissions Function() _permissions;

  /// The select tool's idle keys (Escape, Delete, Backspace while no
  /// gesture runs): the shortcuts' option (Task 16 sets it).
  @override
  bool idleKeys = true;

  @override
  bool get move => _permissions().move && super.move;

  @override
  bool get rotate => _permissions().rotate && super.rotate;

  @override
  bool get reshape => _permissions().reshape && super.reshape;

  @override
  bool get delete => _permissions().delete && super.delete;
}

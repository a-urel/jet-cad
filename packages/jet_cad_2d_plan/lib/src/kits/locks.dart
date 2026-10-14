// Spec P4 "Locks: a missing kit, a broken object" (umbrella A9). A locked
// object draws as saved and can be selected as a whole; it loses every
// change. Two layers: up front (no grips, the gates shut, no delete, no
// panel section) and on commit, where the lock is an expander stacked after
// the parametric system's (as jet_cad_floor_plan's TableLabelSystem
// stacks): it applies the command, checks every touched handle and its
// containers, and on a hit applies the inverse and throws [PlanLocked].
// A command names no handles before it applies (command.dart:122-137), so
// a check before apply cannot work.
import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'guard.dart' show KitHookFailure;

/// The refusal of a command that would change a locked object. A refusal,
/// not a kit diagnostic: the canvas shows a short hint.
final class PlanLocked implements Exception {
  const PlanLocked();

  @override
  String toString() => 'PlanLocked: the edit would change a locked object';
}

/// The locked objects of one document, and what they contain.
final class LockSet {
  LockSet._(this._missing, this._definitions, CommandTarget target) {
    _refresh(target);
  }

  /// Scans [document] once (spec P4 "Which objects are locked"):
  /// - a node other than the root that carries an unknown component whose
  ///   type id is kit-namespaced (a kit id, then a dot; not `jetcad`, not
  ///   `plan`), whatever [loaded] says: no loaded code knows the type;
  /// - a definition whose [SymbolComponent] key's kit is not [loaded], or
  ///   that carries such an unknown component, and every instance of it.
  factory LockSet.scan(
      DraftDocument document, bool Function(String kitId) loaded) {
    bool unknown(Handle h) {
      final kit = _unknownKit(document, h);
      return kit != null && _locksUnknown(kit, loaded);
    }

    final definitions = <Handle>{};
    for (final def in document.tree.definitions) {
      final symbol = document.components.get<SymbolComponent>(def.handle);
      if (unknown(def.handle) ||
          (symbol != null && !loaded(kitOfKey(symbol.key)))) {
        definitions.add(def.handle);
      }
    }
    final missing = <Handle>{};
    for (final node in document.tree.nodes) {
      if (node.handle == document.rootHandle) continue;
      if (unknown(node.handle) ||
          (node is InstanceNode && definitions.contains(node.definition))) {
        missing.add(node.handle);
      }
    }
    return LockSet._(missing, definitions, document);
  }

  /// The kit id of an unknown, kit-namespaced component on [h] (a kit id,
  /// then a dot; not `jetcad`, not `plan`), or null.
  static String? _unknownKit(DraftDocument d, Handle h) {
    for (final payload in d.components.unknownOf(h)) {
      final typeId = payload['typeId'];
      if (typeId is! String) continue;
      final dot = typeId.indexOf('.');
      if (dot <= 0) continue;
      final kit = typeId.substring(0, dot);
      if (isKitId(kit) && kit != 'jetcad' && kit != 'plan') return kit;
    }
    return null;
  }

  /// Whether an unknown component of [kit] locks its holder: always (plan
  /// decision), whether or not [kit] is loaded, since no loaded code knows
  /// the type.
  static bool _locksUnknown(String kit, bool Function(String) loaded) => true;

  /// Past this many containers a chain is taken as no lock's (the tree
  /// refuses cycles; this only bounds a malformed one).
  static const int _maxDepth = 4096;

  final Set<Handle> _missing;
  final Set<Handle> _definitions;
  final Set<Handle> _broken = {};

  /// [_missing], [_broken] and [_definitions]: the containers a lock
  /// starts from.
  final Set<Handle> _roots = {};

  /// Every node and entity under a root when the set last changed.
  final Set<Handle> _closure = {};

  /// The locked objects: a missing kit's, an unknown type's, a broken one's.
  /// The guarded definitions are not listed.
  Set<Handle> get objects => Set.unmodifiable({..._missing, ..._broken});

  bool get isEmpty => _roots.isEmpty;

  /// Whether [h] itself is a locked object.
  bool isLockedObject(Handle h) => _missing.contains(h) || _broken.contains(h);

  /// Whether [h] is locked: a locked object or guarded definition, inside
  /// one now (its containers, walked in [target]), or inside one when the
  /// set last changed (a handle a command just removed has no container
  /// left to walk).
  bool covers(CommandTarget target, Handle h) =>
      _closure.contains(h) || _walk(target, h);

  /// Adds [objects], broken (Task 11), and refreshes what they contain.
  void addBroken(CommandTarget target, Iterable<Handle> objects) {
    _broken.addAll(objects);
    _refresh(target);
  }

  void _refresh(CommandTarget t) {
    _roots
      ..clear()
      ..addAll(_missing)
      ..addAll(_broken)
      ..addAll(_definitions);
    _closure.clear();
    if (_roots.isEmpty) return;
    for (final node in t.tree.nodes) {
      if (_walk(t, node.handle)) _closure.add(node.handle);
    }
    for (final slot in t.entities.liveSlots) {
      final h = t.entities.handleAt(slot);
      if (_walk(t, h)) _closure.add(h);
    }
  }

  /// [start] or one of its containers (an entity's owner, a node's parent,
  /// up to the root or a definition) is a root.
  bool _walk(CommandTarget t, Handle start) {
    if (_roots.isEmpty) return false;
    var current = start;
    for (var depth = 0; depth < _maxDepth; depth++) {
      if (_roots.contains(current)) return true;
      final slot = t.entities.slotOf(current);
      final Handle up;
      if (slot != null) {
        up = t.entities.ownerAt(slot);
      } else {
        final node = t.tree[current];
        if (node == null) return false;
        up = node.parent;
      }
      if (up.isNone || up == current) return false;
      current = up;
    }
    return false;
  }
}

/// Stacks on the dispatcher's one expander slot (spec 06 D2), after the
/// parametric system: [install] keeps the expander it found and wraps what
/// that one returns; [dispose] puts it back. **Last in, first out**: the
/// controller installs this after `ParametricSystem.install` and disposes
/// it before `ParametricSystem.dispose`; [dispose] asserts that the slot
/// still holds its own.
final class LockExpander {
  LockExpander(this.document, this.locks);

  final DraftDocument document;
  final LockSet locks;
  DraftCommand Function(DraftCommand command)? _previous;
  bool _installed = false;

  void install() {
    if (_installed) throw StateError('the lock expander is installed already');
    _previous = document.commands.expander;
    document.commands.expander = _expand;
    _installed = true;
  }

  /// Puts the expander [install] found back, only if the slot still holds
  /// this one's own tear-off.
  void dispose() {
    if (!_installed) return;
    _installed = false;
    final mine = document.commands.expander == _expand;
    if (mine) document.commands.expander = _previous;
    _previous = null;
    assert(mine, 'LockExpander disposed out of order (spec P4)');
  }

  /// The previous expander's command for [command], or [command].
  DraftCommand expandInner(DraftCommand command) =>
      _previous?.call(command) ?? command;

  /// Called when the applied command threw a [KitHookFailure]: true when
  /// it froze something, so the edit is worth one retry (Task 11).
  bool Function(KitHookFailure failure)? onHookFailure;

  /// Called when the applied command left the target partially mutated
  /// (E3), before the error goes on to the caller (Task 11).
  void Function(PartialMutationError error)? onPartialMutation;

  DraftCommand _expand(DraftCommand command) {
    final inner = expandInner(command);
    if (locks.isEmpty && onHookFailure == null && onPartialMutation == null) {
      return inner;
    }
    return _LockCheck(this, command, inner);
  }
}

/// One edit and its lock check: [_applied] applies, then each touched
/// handle is tested; a hit undoes the edit and throws [PlanLocked]. Created
/// by [LockExpander], once per `execute`.
final class _LockCheck extends DraftCommand {
  _LockCheck(this._expander, this.original, this._applied);

  final LockExpander _expander;

  /// The command the caller executed, before any expansion.
  final DraftCommand original;

  /// The expanded command this check applies; the retry's, after a
  /// recovered failure (Task 11).
  DraftCommand _applied;

  @override
  String get label => _applied.label;

  @override
  Set<Capability> get capabilities => _applied.capabilities;

  /// Read by the dispatcher after [apply]: the applied command's own.
  @override
  Capability get capability => _applied.capability;

  @override
  CommandResult apply(CommandTarget target) {
    try {
      return _check(target, _first(target));
    } on PartialMutationError catch (error) {
      _expander.onPartialMutation?.call(error);
      rethrow;
    }
  }

  /// [_applied] applied; on a kit's hook failure that the boundary
  /// recovers from (it froze the failing objects), [original] expanded
  /// afresh (a ParametricEdit applies once) and applied once more. A second
  /// failure goes on: the command is refused.
  CommandResult _first(CommandTarget target) {
    try {
      return _applied.apply(target);
    } on KitHookFailure catch (failure) {
      final recover = _expander.onHookFailure;
      if (recover == null || !recover(failure)) rethrow;
      _applied = _expander.expandInner(original);
      return _applied.apply(target);
    }
  }

  CommandResult _check(CommandTarget target, CommandResult result) {
    final locks = _expander.locks;
    for (final h in result.touched) {
      if (!locks.covers(target, h)) continue;
      try {
        result.inverse.apply(target);
      } catch (rollbackError) {
        throw PartialMutationError('"$label": it touched a locked object, '
            'and undoing it then threw ($rollbackError); the target is '
            'partially mutated and nothing was recorded in history');
      }
      throw const PlanLocked();
    }
    return result;
  }
}

/// The grip provider a lock leaves: a covered group has no grips, no drag,
/// no preview and does not move; anything else is [inner]'s (no grips and
/// movable with no inner, as with no provider, `grip_cache.dart:61-66`).
final class LockedGrips implements ObjectGripProvider {
  LockedGrips(this._locks, this._inner);

  final LockSet _locks;
  final ObjectGripProvider? _inner;

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) {
    if (_locks.covers(d, group)) return const [];
    return _inner?.gripsOf(d, group) ?? const [];
  }

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_locks.covers(d, group)) return null;
    return _inner?.drag(d, group, grip, world);
  }

  @override
  List<(EntityKind, GeometryPayload)> preview(
      DraftDocument d, Handle group, Grip grip, Vector2 world) {
    if (_locks.covers(d, group)) return const [];
    return _inner?.preview(d, group, grip, world) ?? const [];
  }

  @override
  bool movable(DraftDocument d, Handle group) {
    if (_locks.covers(d, group)) return false;
    return _inner?.movable(d, group) ?? true;
  }
}

/// The select gates a lock shuts (spec P4 "Up front"): move, rotate,
/// reshape and delete refuse while a selected key's target, or a handle of
/// its chain, is in [locked]; a locked object stays selectable. The answer
/// is a cached `bool`, recomputed when the selection or the locked set
/// notifies, so the getters allocate nothing (`select_gates.dart:14-21`).
/// Task 12's `PlanSelectGates` extends it with the permissions (one lock
/// rule, not two).
base class LockGates extends SelectGates {
  LockGates({
    required SelectionController selection,
    required ValueListenable<Set<Handle>> locked,
  })  : _selection = selection,
        _locked = locked {
    _selection.addListener(_recompute);
    _locked.addListener(_recompute);
    _recompute();
  }

  final SelectionController _selection;
  final ValueListenable<Set<Handle>> _locked;
  bool _selectionLocked = false;

  /// Whether a selected key's target, or a handle of its chain, is locked.
  bool get selectionLocked => _selectionLocked;

  void _recompute() {
    final locked = _locked.value;
    var hit = false;
    if (locked.isNotEmpty) {
      for (final key in _selection.keys) {
        if (locked.contains(key.target)) {
          hit = true;
          break;
        }
        final chain = key.chain;
        for (var i = 0; i < chain.length && !hit; i++) {
          hit = locked.contains(Handle(chain[i]));
        }
        if (hit) break;
      }
    }
    _selectionLocked = hit;
  }

  @override
  bool get move => !_selectionLocked;

  @override
  bool get rotate => !_selectionLocked;

  @override
  bool get reshape => !_selectionLocked;

  @override
  bool get delete => !_selectionLocked;

  void dispose() {
    _selection.removeListener(_recompute);
    _locked.removeListener(_recompute);
  }
}

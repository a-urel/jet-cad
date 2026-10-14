// The plan's changes as a host hears them (spec 2a P2 "Events"): an
// object added, changed or removed, and the plan replaced. An object is a
// root-level element: a group or an instance whose parent is the root, or
// an entity the root owns; a part of it (a generated leaf) counts for it.
// Modelled on today's design changes (floor_plan_controller.dart:
// 1690-1775), which speak of tables.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

@immutable
sealed class PlanChange {
  const PlanChange();
}

/// An object now in the plan that was not: placed, pasted, or a delete
/// undone.
final class PlanObjectAdded extends PlanChange {
  const PlanObjectAdded(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectAdded && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectAdded, object);

  @override
  String toString() => 'PlanObjectAdded(${object.toHex()})';
}

/// An object whose data, geometry, place or parts changed.
final class PlanObjectChanged extends PlanChange {
  const PlanObjectChanged(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectChanged && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectChanged, object);

  @override
  String toString() => 'PlanObjectChanged(${object.toHex()})';
}

/// An object no longer in the plan: deleted, or its placement undone.
final class PlanObjectRemoved extends PlanChange {
  const PlanObjectRemoved(this.object);

  final Handle object;

  @override
  bool operator ==(Object other) =>
      other is PlanObjectRemoved && other.object == object;

  @override
  int get hashCode => Object.hash(PlanObjectRemoved, object);

  @override
  String toString() => 'PlanObjectRemoved(${object.toHex()})';
}

/// The whole plan was replaced (`load`, `newPlan`, `import`), or reloaded
/// in place (a rollback that failed, Task 11): no change per object.
final class PlanReplaced extends PlanChange {
  const PlanReplaced();

  @override
  bool operator ==(Object other) => other is PlanReplaced;

  @override
  int get hashCode => (PlanReplaced).hashCode;

  @override
  String toString() => 'PlanReplaced()';
}

/// The root-level object [h] is part of in [d], or null: the root itself,
/// a handle no longer in [d], a definition's leaf, a table record.
Handle? rootObjectOf(DraftDocument d, Handle h) {
  final root = d.rootHandle;
  if (h == root) return null;
  var current = h;
  final slot = d.entities.slotOf(h);
  if (slot != null) {
    final owner = d.entities.ownerAt(slot);
    if (owner == root) return h;
    current = owner;
  }
  // The tree refuses a cycle; the bound only keeps a malformed load from
  // looping.
  for (var depth = 0; depth < 1 << 20; depth++) {
    final node = d.tree[current];
    if (node == null) return null;
    if (node.parent == root) return current;
    current = node.parent;
  }
  return null;
}

/// Every root-level object of [d].
Set<Handle> rootObjects(DraftDocument d) {
  final root = d.rootHandle;
  final node = d.tree[root];
  return {
    if (node is GroupNode) ...d.tree.childNodesOf(node.children),
    for (final slot in d.entities.liveSlots)
      if (d.entities.ownerAt(slot) == root) d.entities.handleAt(slot),
  };
}

/// What [touched] changed against [objects] (updated in place), in
/// ascending handle order.
List<PlanChange> diffObjects(
    DraftDocument d, Set<Handle> objects, Set<Handle> touched) {
  final sorted = touched.toList()..sort((a, b) => a.value.compareTo(b.value));
  final added = <Handle>{}, changed = <Handle>{}, removed = <Handle>{};
  for (final h in sorted) {
    if (h == d.rootHandle) continue;
    final object = rootObjectOf(d, h);
    if (object != h && objects.remove(h)) removed.add(h);
    if (object == null) continue;
    if (objects.add(object)) {
      added.add(object);
    } else if (!added.contains(object)) {
      changed.add(object);
    }
  }
  final all = {...removed, ...added, ...changed}.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return [
    for (final h in all)
      if (removed.contains(h) && !added.contains(h))
        PlanObjectRemoved(h)
      else if (added.contains(h))
        PlanObjectAdded(h)
      else
        PlanObjectChanged(h),
  ];
}

/// Collects one document's changes synchronously, stacked on the
/// dispatcher's `onAfterMutate` (the spatial index's, kept and called
/// first), and reports them once per synchronous step, while anything
/// listens. [detach] reports what is still owed, at once.
final class PlanChangeTracker {
  PlanChangeTracker(this._emit);

  final void Function(PlanChange change) _emit;

  DraftDocument? _document;
  void Function(DocChange change)? _previous;
  void Function(DocChange change)? _hook;
  Set<Handle>? _objects;
  final Set<Handle> _touched = {};
  bool _loaded = false;
  bool _scheduled = false;
  bool _listening = false;

  /// Baselines built and steps read: what a listener costs.
  int debugScans = 0;

  void attach(DraftDocument document) {
    _document = document;
    final previous = _previous = document.commands.onAfterMutate;
    void hook(DocChange change) {
      previous?.call(change);
      _note(document, change);
    }

    _hook = hook;
    document.commands.onAfterMutate = hook;
    if (_listening) _rebase();
  }

  /// Reports what [attach]'s document still owes, then lets it go: its
  /// `onAfterMutate` is the one found. Before the index is disposed.
  void detach() {
    final d = _document;
    if (d == null) return;
    flush();
    if (identical(d.commands.onAfterMutate, _hook)) {
      d.commands.onAfterMutate = _previous;
    }
    _document = null;
    _hook = null;
    _previous = null;
    _objects = null;
    _touched.clear();
    _loaded = false;
  }

  /// The plan was replaced: [PlanReplaced], while anything listens.
  void replaced() {
    if (_listening) _emit(const PlanReplaced());
  }

  void listen() {
    _listening = true;
    _rebase();
  }

  void cancel() {
    _listening = false;
    _objects = null;
    _touched.clear();
    _loaded = false;
  }

  void _rebase() {
    final d = _document;
    if (d == null) return;
    debugScans++;
    _objects = rootObjects(d);
  }

  void _note(DraftDocument from, DocChange change) {
    if (!_listening || !identical(from, _document)) return;
    if (change is DocumentLoaded) {
      _loaded = true;
    } else if (change is DocumentPurged) {
      return; // handles are stable: nothing to report
    } else {
      _touched.addAll(change.touched);
    }
    if (_scheduled) return;
    _scheduled = true;
    scheduleMicrotask(_deliver);
  }

  void _deliver() {
    _scheduled = false;
    flush();
  }

  /// Reports what is owed now.
  void flush() {
    final d = _document;
    final objects = _objects;
    if (d == null || objects == null) return;
    if (_loaded) {
      _loaded = false;
      _touched.clear();
      _rebase();
      _emit(const PlanReplaced());
      return;
    }
    if (_touched.isEmpty) return;
    debugScans++;
    final changes = diffObjects(d, objects, _touched);
    _touched.clear();
    changes.forEach(_emit);
  }
}

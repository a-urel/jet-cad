import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

/// A selectable object, identified by the chain of instances a viewer
/// descended through to reach it plus the handle it bottoms out on.
///
/// `chain` is empty for anything selected at the root level: a root-level
/// entity, a root-level group (spec D2's "topmost group"), or a root-level
/// instance. It is non-empty only when a tool has descended *into* an
/// instance and is naming something inside it — no task before this one
/// produces such a key, but the shape is here from the start so a later task
/// does not have to widen it.
final class SelectionKey {
  SelectionKey(
      {required Uint32List chain,
      required int chainLength,
      required this.target})
      : chain =
            Uint32List.fromList(Uint32List.sublistView(chain, 0, chainLength));

  SelectionKey.root(this.target) : chain = Uint32List(0);

  final Uint32List chain;
  final Handle target;

  @override
  bool operator ==(Object other) {
    if (other is! SelectionKey || other.target != target) return false;
    if (other.chain.length != chain.length) return false;
    for (var i = 0; i < chain.length; i++) {
      if (other.chain[i] != chain[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(chain), target);

  @override
  String toString() => 'SelectionKey(${chain.join('>')} ${target.toHex()})';
}

/// Spec D2: the root-level object under a hit, or null for a miss or a
/// truncated chain. Never throws at hover rate.
SelectionKey? resolveHit(HitPath hit, DraftDocument document) {
  if (hit.entity.isNone || hit.truncated) return null;
  if (hit.chainLength > 0) return SelectionKey.root(Handle(hit.chain[0]));
  final slot = document.entities.slotOf(hit.entity);
  if (slot == null) return null;
  final owner = document.entities.ownerAt(slot);
  if (owner == document.rootHandle) return SelectionKey.root(hit.entity);
  final List<Handle> ancestors;
  try {
    ancestors = document.tree.ancestorsOf(owner);
  } on NodeCycleError {
    return SelectionKey.root(hit.entity);
  }
  return SelectionKey.root(
      topmostGroupOf(document, owner, ancestors) ?? hit.entity);
}

/// The last group in `[owner, ...ancestors]` before the root, or null when
/// none is a group. [ancestors] is `tree.ancestorsOf(owner)`, nearest first.
Handle? topmostGroupOf(
    DraftDocument document, Handle owner, List<Handle> ancestors) {
  Handle? topmost;
  for (final h in [owner, ...ancestors]) {
    if (h == document.rootHandle) break;
    if (document.tree[h] is GroupNode) topmost = h;
  }
  return topmost;
}

/// Application-only selection state (spec D6, D11).
///
/// Deliberately not part of [DraftDocument]: never serialised, never
/// undone. A document change can still invalidate a selected object — an
/// external undo, redo, or remove — so this listens to [DraftDocument.changes]
/// and prunes dead keys rather than letting the UI hold a dangling handle.
class SelectionController extends ChangeNotifier {
  SelectionController(this.document) {
    _subscription = document.changes.listen(_onChange);
  }

  final DraftDocument document;
  final Set<SelectionKey> _keys = <SelectionKey>{};
  SelectionKey? _hover;
  late final StreamSubscription<DocChange> _subscription;

  Set<SelectionKey> get keys => UnmodifiableSetView(_keys);
  int get length => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool contains(SelectionKey key) => _keys.contains(key);
  SelectionKey? get hover => _hover;

  void replace(Iterable<SelectionKey> next) {
    final incoming = next.toSet();
    if (setEquals(incoming, _keys)) return;
    _keys
      ..clear()
      ..addAll(incoming);
    notifyListeners();
  }

  void toggle(Iterable<SelectionKey> keys) {
    // A net-change check, not a per-key flag: a duplicate key in [keys]
    // toggles itself back to its starting membership (add then remove, or
    // remove then add), and a flag set unconditionally on loop entry would
    // still fire — violating "none when nothing changed" for an input as
    // small as `toggle([k, k])` on an empty selection.
    final before = Set<SelectionKey>.of(_keys);
    for (final k in keys) {
      if (!_keys.remove(k)) _keys.add(k);
    }
    if (!setEquals(before, _keys)) notifyListeners();
  }

  void remove(Iterable<SelectionKey> keys) {
    var changed = false;
    for (final k in keys) {
      changed = _keys.remove(k) || changed;
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_keys.isEmpty && _hover == null) return;
    _keys.clear();
    _hover = null;
    notifyListeners();
  }

  void setHover(SelectionKey? key) {
    if (key == _hover) return;
    _hover = key;
    notifyListeners();
  }

  @visibleForTesting
  void debugOnChange(DocChange change) => _onChange(change);

  void _onChange(DocChange change) {
    if (change is DocumentLoaded || change is DocumentPurged) {
      clear();
      return;
    }
    var changed = false;
    _keys.removeWhere((k) {
      final dead = !_resolves(k) || !_selectable(k);
      changed = changed || dead;
      return dead;
    });
    if (_hover != null && (!_resolves(_hover!) || !_selectable(_hover!))) {
      _hover = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Whether [k]'s target is on a layer picking could still select it
  /// through: its effective layer is neither hidden nor locked (spec 12b
  /// D8). A layer the table does not have counts as visible and unlocked,
  /// as `FilterEvaluator` treats it. Read for a key that [_resolves].
  ///
  /// O(chain) per key, with no allocation: a selection change costs
  /// O(selection), never a walk of the document.
  bool _selectable(SelectionKey k) {
    final layer = document.tables.layers[_effectiveLayerOf(k)];
    return layer == null || (layer.visible && !layer.locked);
  }

  /// [k]'s effective layer (spec 12b D6, D8): the style resolver's layer-0
  /// substitution, from the root (layer 0) down [k]'s chain of instances.
  ///
  /// - A root entity is on its own layer; a drafted region's fill is on its
  ///   boundary's (D12: a region's layer is its boundary's); a leaf on
  ///   layer 0 owned by an instance (an ATTRIB) is on its instance's.
  /// - An instance is on its own layer.
  /// - A group is a parametric object, on its `objectLayer`.
  Handle _effectiveLayerOf(SelectionKey k) {
    var context = ReservedHandles.layerZero;
    for (final h in k.chain) {
      context =
          _onLayer((document.tree[Handle(h)] as InstanceNode).layer, context);
    }
    final node = document.tree[k.target];
    if (node is InstanceNode) return _onLayer(node.layer, context);
    if (node is GroupNode) return objectLayer(document, k.target);
    if (node != null) return context;
    final entities = document.entities;
    var slot = entities.slotOf(k.target)!;
    if (entities.kindAt(slot) == EntityKind.fill) {
      final boundary = entities.slotOf(
          boundaryHandleOf(document.geometry.peek(entities.geomIndexAt(slot))));
      if (boundary != null) slot = boundary;
    }
    final own = entities.layerAt(slot);
    if (own != ReservedHandles.layerZero) return own;
    final owner = document.tree[entities.ownerAt(slot)];
    return owner is InstanceNode ? _onLayer(owner.layer, context) : context;
  }

  /// [own], or [context] when [own] is layer 0.
  static Handle _onLayer(Handle own, Handle context) =>
      own == ReservedHandles.layerZero ? context : own;

  bool _resolves(SelectionKey k) {
    for (final h in k.chain) {
      if (document.tree[Handle(h)] is! InstanceNode) return false;
    }
    return document.entities.slotOf(k.target) != null ||
        document.tree[k.target] != null;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

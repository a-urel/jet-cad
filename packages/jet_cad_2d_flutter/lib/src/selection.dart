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
    var changed = false;
    for (final k in keys) {
      changed = true;
      if (!_keys.remove(k)) _keys.add(k);
    }
    if (changed) notifyListeners();
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
      final dead = !_resolves(k);
      changed = changed || dead;
      return dead;
    });
    if (_hover != null && !_resolves(_hover!)) {
      _hover = null;
      changed = true;
    }
    if (changed) notifyListeners();
  }

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

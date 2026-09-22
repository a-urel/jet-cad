### Task 3: `SelectionKey`, `resolveHit`, `SelectionController`

**Files:**
- Create: `lib/src/selection.dart`
- Create: `test/support/selection_fixture.dart`
- Test: `test/selection_test.dart`

**Interfaces:**
- Consumes: `HitPath`, `DraftDocument` (`tree`, `entities.slotOf`, `changes`), `DocChange` subtypes.
- Produces (spec D6, D2, D11):

```dart
final class SelectionKey {
  SelectionKey({required Uint32List chain, required int chainLength, required Handle target});
  SelectionKey.root(Handle target);           // chain = []
  final Uint32List chain; final Handle target;
}
SelectionKey? resolveHit(HitPath hit, DraftDocument document);   // null on a miss or a truncated hit
class SelectionController extends ChangeNotifier {
  SelectionController(DraftDocument document);
  Set<SelectionKey> get keys; int get length; bool get isEmpty;
  bool contains(SelectionKey key);
  void replace(Iterable<SelectionKey> keys); void toggle(Iterable<SelectionKey> keys);
  void remove(Iterable<SelectionKey> keys); void clear();
  SelectionKey? get hover; void setHover(SelectionKey? key);
  @override void dispose();   // cancels the changes subscription
}
```

- [ ] **Step 1: The fixture file**

`test/support/selection_fixture.dart`: `addEntity` (copied from
`pick_test.dart`), `addInstance(doc, def, Transform2)`, `addGroup(doc,
parent, Transform2)`, `addDefinition(doc, name)`, `kPlacement` (the reference
placement), `cameraAt(scale, translation)` returning a `CameraController`
over `ViewportTransform(worldToScreenMatrix: Transform2(s, 0, 0, -s, tx,
ty))`, and `twoInstancesOfOneDefinition(doc)` returning `(def, a, b, leaf)`
with `a` at `kPlacement` and `b` at `Transform2.translation(900, 400)
.multiply(Transform2.rotation(-math.pi / 4)).multiply(Transform2.scale(0.8, 0.8))`.

- [ ] **Step 2: Failing tests**

`test/selection_test.dart`:

1. **M-02c′** — `'two instances of one definition are two keys; two leaves of one instance are one'`:
   pick under `a` and under `b` through `SpatialIndex.pickInto` at the
   world image of the leaf's midpoint; `resolveHit` each; both `target`s are
   `InstanceNode`s per `doc.tree[target]`; `replace([ka]); toggle([kb])`;
   `length == 2`. Then a second leaf in the definition, picked under `a`,
   resolves to a key `== ka`.
2. **M-02p** — `'a leaf owned by a nested group resolves to the outer group; a single-level group to itself'`:
   `outer` under root, `inner` under `outer`, leaf owned by `inner` →
   `target == outer`; leaf owned by a group directly under root → that
   group.
3. `'a truncated hit is a miss'`: build a `HitPath(2)` by hand with
   `truncated = true`, `chainLength = 2`, `entity` a real leaf → `null`.
4. **M-02k and its sibling** — `'an external remove prunes; an unrelated add does not'`:
   select a leaf and an instance; `execute(RemoveEntityCommand(leaf))`;
   `await Future<void>.delayed(Duration.zero)`; only the instance remains;
   then `execute(AddEntityCommand(...))` elsewhere; still there.
5. **M-02aa** — `'replace with the same set does not notify'`: counter
   listener; `replace([k])` twice → 1; `setHover(k)` twice → 1 more.
6. `'toggle adds then removes'`, `'remove drops only what it names'`,
   `'clear drops hover too'`, `'DocumentLoaded clears everything'` (emit by
   loading: `doc.commands` has no public emitter — use
   `JsonCodec`-free path: call `SelectionController`'s private handler
   through a `@visibleForTesting void debugOnChange(DocChange)`).
7. `'equality is by chain and target, not identity'`: two keys built from
   separate buffers with the same contents are `==` and share a hash.

- [ ] **Step 3: Implement `selection.dart`**

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

final class SelectionKey {
  SelectionKey({required Uint32List chain, required int chainLength, required this.target})
      : chain = Uint32List.fromList(Uint32List.sublistView(chain, 0, chainLength));

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
  return SelectionKey.root(topmostGroupOf(document, owner, ancestors) ?? hit.entity);
}

/// The last group in `[owner, ...ancestors]` before the root, or null when
/// none is a group. [ancestors] is `tree.ancestorsOf(owner)`, nearest first.
Handle? topmostGroupOf(DraftDocument document, Handle owner, List<Handle> ancestors) {
  Handle? topmost;
  for (final h in [owner, ...ancestors]) {
    if (h == document.rootHandle) break;
    if (document.tree[h] is GroupNode) topmost = h;
  }
  return topmost;
}

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
    _keys..clear()..addAll(incoming);
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
```

- [ ] **Step 4: Run, gate line, commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/selection_test.dart
CI=true flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/selection.dart test/selection_test.dart test/support/selection_fixture.dart
git commit -m "feat(selection): SelectionKey, resolveHit and SelectionController"
```

---


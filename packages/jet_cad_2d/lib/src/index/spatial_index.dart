import '../core/handle.dart';
import '../document/doc_change.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/style.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import 'container_index.dart';
import 'query_filter.dart';
import 'query_scratch.dart';

/// Every [ContainerIndex] in a document, kept current against its changes.
///
/// One index per indexed container: the tree root, plus every definition —
/// including definitions with no instances, since one may be placed at any
/// moment and building on demand would put an unbounded build inside a query.
///
/// **Definitions must be in place before construction, or followed by an
/// explicit [rebuildAll].** [DocumentTree.addDefinition] and
/// [DocumentTree.removeDefinition] are not commands — nothing calling either
/// one emits a [DocChange], so this class has no way to hear about it. A
/// definition added afterwards never gets a [ContainerIndex]; one removed
/// leaves a stale entry that [rebuildContainer] would reject and only
/// [rebuildAll] clears. A future plan that turns definition mutation into
/// commands removes this caveat along with the gap it names.
class SpatialIndex {
  SpatialIndex(this.document) {
    rebuildAll();
    // Synchronous, not `document.changes.listen`: that stream is an async
    // broadcast controller, so the index would be stale for the rest of the
    // current turn and a query issued right after an edit would quietly
    // return the old answer.
    document.commands.onAfterMutate = _onChange;
  }

  final DraftDocument document;
  final Map<Handle, ContainerIndex> _byContainer = <Handle, ContainerIndex>{};
  bool _disposed = false;

  ContainerIndex? indexFor(Handle container) => _byContainer[container];

  ContainerIndex get rootIndex {
    if (_disposed) {
      throw StateError('SpatialIndex used after dispose()');
    }
    return _byContainer[document.rootHandle]!;
  }

  int get containerCount => _byContainer.length;

  final QueryScratch _scratch = QueryScratch();

  /// A [QueryScratch], not a `List<Handle>`: `List.clear()` is not a cheap
  /// length reset in the Dart VM — it shrinks the backing array to empty
  /// once it has held anything, so every subsequent query regrows it from
  /// scratch. That is precisely the allocation [QueryScratch.reset] exists to
  /// avoid, so this buffer gets the same treatment even though its entries
  /// are instance [Handle.value]s rather than entity slots — see
  /// [QueryScratch.sortByValue], the sibling of [QueryScratch.sortByHandle]
  /// for a buffer that is already keyed by its own stored value.
  final QueryScratch _instanceScratch = QueryScratch();

  late final FilterEvaluator _filters = FilterEvaluator(document);

  /// The live capacity of the entity-query scratch buffer. Test-visible for
  /// the same reason as [rebuildCount]: the load-bearing guarantee is that a
  /// warmed query never regrows it.
  int get entityScratchCapacity => _scratch.capacity;

  /// The live capacity of the instance-query scratch buffer. Same reasoning
  /// as [entityScratchCapacity].
  int get instanceScratchCapacity => _instanceScratch.capacity;

  /// Visits the slot of every root-level leaf whose box overlaps [world],
  /// in ascending handle order.
  ///
  /// **Does not descend into instances.** A shared definition's entities would
  /// otherwise be reported once per instance, with no way to tell the
  /// instances apart — and the renderer does not want that, since it replays
  /// one cached picture per instance. Use [forEachInstanceInRect] for those,
  /// and `pickInto` when you need to descend.
  ///
  /// **Not reentrant.** Both rect queries share this index's scratch
  /// buffers; calling either one again from inside [visit] corrupts the
  /// outer call's in-progress buffer and silently truncates its results. A
  /// future task adds an explicit guard for this; until then, do not query
  /// from inside a query's callback.
  void forEachInRect(
      Aabb2 world, QueryFilter filter, void Function(int slot) visit) {
    final root = rootIndex; // throws if disposed, even for an empty rect
    if (world.isEmpty) return;
    _scratch.reset();
    root.searchLeaves(world, (slot) {
      if (_filters.acceptsEntity(slot, filter)) _scratch.add(slot);
    });
    _scratch.sortByHandle(document.entities);
    for (var i = 0; i < _scratch.length; i++) {
      visit(_scratch[i]);
    }
  }

  /// Visits every root-level instance whose box overlaps [world], ascending.
  ///
  /// See [forEachInRect]'s doc comment: the same not-reentrant caveat
  /// applies here too, since both methods share this index's scratch state.
  void forEachInstanceInRect(
      Aabb2 world, QueryFilter filter, void Function(Handle instance) visit) {
    final root = rootIndex; // throws if disposed, even for an empty rect
    if (world.isEmpty) return;
    _instanceScratch.reset();
    root.searchInstances(world, (node) {
      if (_filters.acceptsNode(node, filter)) {
        _instanceScratch.add(node.value);
      }
    });
    _instanceScratch.sortByValue();
    for (var i = 0; i < _instanceScratch.length; i++) {
      visit(Handle(_instanceScratch[i]));
    }
  }

  int _rebuildCount = 0;
  int _dirtyCount = 0;

  /// How many full container rebuilds have happened. Test-visible because the
  /// load-bearing guarantee is that certain edits cause *none*.
  int get rebuildCount => _rebuildCount;

  /// How many entries have been written to a dirty list. Same reasoning.
  int get dirtyCount => _dirtyCount;

  /// The slot each live entity occupied as of the last time this index saw
  /// it — either a rebuild or a reconciled edit.
  ///
  /// Removal notifies with only the handle: by the time [_reconcileEntity]
  /// runs, [DraftDocument.entities] has already forgotten the slot, so
  /// without this map there would be nothing to mark dead. Populated for
  /// every live entity in [rebuildAll] and kept current for every entity
  /// [_reconcileEntity] sees; a purge or load invalidates it exactly when it
  /// invalidates everything else slot-keyed, which is why [rebuildAll]
  /// rebuilds it from scratch rather than patching it.
  final Map<Handle, int> _lastKnownSlot = <Handle, int>{};

  /// Discards every index and rebuilds from scratch.
  ///
  /// One [ContainerIndex.leavesByOwner] pass is shared across every container,
  /// which is what keeps a whole-document build linear in entities rather than
  /// O(containers x entities).
  void rebuildAll() {
    _rebuildCount++;
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer
      ..clear()
      ..[document.rootHandle] =
          ContainerIndex.build(document, document.rootHandle, byOwner);
    for (final definition in document.tree.definitions) {
      _byContainer[definition.handle] =
          ContainerIndex.build(document, definition.handle, byOwner);
    }
    // Rebuilt from scratch, not patched: a rebuild also follows a purge or a
    // load, either of which may have renumbered or entirely replaced every
    // slot, so a stale entry here would mark the wrong slot dead on the next
    // removal.
    _lastKnownSlot.clear();
    for (final slot in document.entities.liveSlots) {
      _lastKnownSlot[document.entities.handleAt(slot)] = slot;
    }
    // A rebuild also follows a layer edit or a load, either of which may
    // change what a cached visibility answer means for a handle that is
    // reused. No shipped command can flip a layer's or node's visibility
    // today — see [FilterEvaluator]'s own doc comment — so this has no
    // observable effect yet; it is the conservative default for when one
    // does.
    _filters.invalidate();
  }

  /// Rebuilds one container, leaving the rest alone.
  ///
  /// [container] must already be an indexed container — the root or a live
  /// definition — never an arbitrary handle: this class indexes exactly the
  /// set [rebuildAll] builds, and letting an unrelated handle in here would
  /// silently grow that set with a phantom entry [rebuildAll] never produces
  /// and [indexFor] can never explain.
  void rebuildContainer(Handle container) {
    if (container != document.rootHandle &&
        document.tree.definition(container) == null) {
      throw ArgumentError.value(
        container,
        'container',
        'not an indexed container (must be the document root or a live '
            'definition)',
      );
    }
    _rebuildCount++;
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer[container] =
        ContainerIndex.build(document, container, byOwner);
  }

  /// **Re-derive and compare**, not a typed change kind.
  ///
  /// [DocChange] carries `(label, Set<Handle> touched)` with no change kind —
  /// [SetComponentCommand] touches the entity handle exactly as a geometry
  /// edit would. So this cannot be *told* what changed; it re-derives each
  /// touched handle's box from the document and compares it against what is
  /// indexed. An appearance edit finds the box unchanged and dirties nothing,
  /// which is what preserves the appearance-edits-do-not-touch-the-index
  /// guarantee by measurement rather than by a kind the stream cannot carry.
  void _onChange(DocChange change) {
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        // Slots were renumbered or the document replaced. Every slot-keyed
        // structure — the trees, the dirty lists, the dead bitmasks, and
        // [_lastKnownSlot] — is invalid, and there is no incremental path
        // back.
        rebuildAll();
      case CommandApplied(:final touched):
      case CommandUndone(:final touched):
      case CommandRedone(:final touched):
        _reconcile(touched);
    }
  }

  /// Re-derives the box of every touched handle and dirties what moved.
  void _reconcile(Set<Handle> touched) {
    if (touched.isEmpty) {
      // Defensive, not currently reachable: every `DraftCommand.apply` in
      // this package returns a non-empty `touched` (see `commands.dart`),
      // so `CommandDispatcher` never emits an empty set here today. Kept in
      // case a future command legitimately has nothing to name — falling
      // back to a full rebuild is the same conservative answer this class
      // already gives to every other "cannot pin down what changed" case.
      rebuildAll();
      return;
    }

    // A touched handle may be an entity, a node, or a definition. Ascending
    // order keeps the work deterministic, which matters because a rebuild
    // decision depends on how many entries land in a dirty list.
    final ordered = touched.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Not currently distinguishable from a simpler "let `_reconcileEntity`
    // find out" by any test: every shipped `DraftCommand.apply` returns a
    // singleton `touched`, so for the one handle in it, a node or
    // definition that still resolves reaches `rebuildAll()` here, and a
    // handle that resolves to *neither* an entity nor a node — a removal —
    // reaches the equally conservative fallback inside `_reconcileEntity`
    // (see its `last == null` branch). Either path ends this call with
    // exactly one `rebuildAll()`, so a single-handle touch cannot tell them
    // apart by outcome. The distinction only matters for a *batch* naming
    // more than one structural handle at once: this loop calls
    // `rebuildAll()` once after scanning the whole set, where routing every
    // structural handle through `_reconcileEntity` individually would call
    // it once per handle. No command in this package produces such a batch
    // today, so that saving is unexercised — kept for the shape of a
    // future command that touches several nodes in one edit, not because a
    // test proves it pays for itself yet.
    var structural = false;
    for (final handle in ordered) {
      if (document.tree.definition(handle) != null) {
        structural = true;
        continue;
      }
      if (document.tree[handle] != null) {
        structural = true;
        continue;
      }
      _reconcileEntity(handle);
    }

    if (structural) {
      // A node or definition changed: which container holds what, and where,
      // may have moved wholesale. Re-deriving one box is not enough, and
      // working out the minimal set is a Plan 3 optimisation if the
      // benchmark asks for it.
      rebuildAll();
      return;
    }

    // Snapshot the keys before iterating: `rebuildContainer` writes into
    // `_byContainer`, and iterating a map's values while a later call adds a
    // key throws ConcurrentModificationError. Nothing in this loop can add a
    // key that is not already in the snapshot — `rebuildContainer` only ever
    // overwrites a container that must already be indexed (its own guard
    // requires the root or a live definition), and the one path that *could*
    // grow `_byContainer` with a genuinely new entry, the `structural`
    // branch above, has already returned by this point.
    for (final container in _byContainer.keys.toList()) {
      if (_byContainer[container]?.needsRebuild ?? false) {
        rebuildContainer(container);
      }
    }
  }

  void _reconcileEntity(Handle handle) {
    final slot = document.entities.slotOf(handle);
    if (slot == null) {
      final last = _lastKnownSlot[handle];
      if (last == null) {
        // Never a live entity, and by the time `_reconcile` routed here it
        // no longer resolves to a node or definition either — so it *was*
        // one, and has just been removed (`RemoveNodeCommand`, most
        // directly, but anything with the same shape). `_reconcile`'s
        // structural rule only catches a handle that *still* resolves to a
        // node or definition when it is inspected; a removal is the one
        // case where the handle can no longer tell us that about itself,
        // which is why it falls through to here instead of setting
        // `structural`.
        //
        // Falling back to a full rebuild is the conservative version of the
        // fix: a precise one would mirror `_lastKnownSlot` for node and
        // definition handles too, but this class already accepts
        // `rebuildAll()` for every other structural change, so this is
        // consistent with the shipped design rather than a special case.
        // Without it, a removed node's leaves and instances — and a removed
        // definition's own `ContainerIndex` — stay indexed and keep being
        // found by every query until the next unrelated rebuild, a purge,
        // or a load.
        rebuildAll();
        return;
      }
      // A previously-seen entity that is now gone. Mark it dead everywhere
      // it might be indexed, and drop any dirty entry for it.
      for (final index in _byContainer.values) {
        index.markLeafDead(last);
        index.dirty.remove(last);
      }
      _lastKnownSlot.remove(handle);
      return;
    }

    _lastKnownSlot[handle] = slot;
    final owner = document.entities.ownerAt(slot);
    final index = _containerHolding(owner);
    if (index == null) {
      // Defensive, not currently reachable in a valid document: every
      // entity's owner chain terminates at the root, which is always
      // indexed, so this only fires if the tree is malformed (a broken
      // `parent` chain, or an owner naming neither a node nor an indexed
      // container). A full rebuild is the same conservative answer given
      // above rather than propagating a lookup failure into a query.
      rebuildAll();
      return;
    }

    final record = document.entities.read(slot);
    final current = entityBounds(
      kind: record.kind,
      payload: document.geometry.read(record.geomIndex),
      measurer: document.textMeasurer,
      textStyle: ReservedHandles.standardTextStyle,
    );
    // The indexed box is in container space; if this entity sits under a
    // flattened group — or is an ATTRIB owned directly by an instance node —
    // the two differ by that chain's composed transform. Comparing against
    // the composed box is what makes an unchanged entity register as
    // unchanged.
    final composed = _groupTransformOf(owner, index.container);
    final expected = current.transformedBy(composed);

    final indexed = index.boxOfLeaf(slot);
    if (indexed != null && _sameBox(indexed, expected)) {
      // Live, indexed, and unchanged.
      //
      // `index.dirty.remove(slot)` here is defensive, not currently
      // reachable: the only place this class ever calls `dirty.put` is right
      // below, paired unconditionally with `markLeafDead` in the same
      // breath, so a slot that still has a usable box (`indexed != null`,
      // i.e. not dead) can never also carry a dirty entry today. Kept
      // anyway — and cheap — in case a future change adds a second path
      // onto the dirty list without also going through `markLeafDead`; if
      // that ever happens this stops a stale entry from surviving an edit
      // that reverted to its original box.
      index.dirty.remove(slot);
      return;
    }

    // `boxOfLeaf` returns null for a dead item, so a restored entity lands
    // here rather than in the early return above. Bringing the tree entry
    // back to life is what makes remove-then-undo work; without it the dead
    // bit set by the remove would never clear.
    if (indexed == null && index.containsLeafSlot(slot)) {
      final revived = index.boxOfDeadLeaf(slot);
      if (revived != null && _sameBox(revived, expected)) {
        index.markLeafAlive(slot);
        index.dirty.remove(slot);
        return;
      }
    }

    index.markLeafDead(slot);
    index.dirty.put(slot, expected);
    _dirtyCount++;
  }

  /// The transform from [owner]'s space up to [container]'s space, composing
  /// every node's own transform in between.
  ///
  /// Ordinarily every node on this walk is a flattened [GroupNode] — see the
  /// class doc on [ContainerIndex] — but [owner] itself may instead be an
  /// *instance* node: an ATTRIB entity's owner is the INSERT that carries it,
  /// per [EntityRecord.owner], and [ContainerIndex.build] composes that
  /// instance's own transform into such a leaf's box exactly as it does a
  /// group's. Restricting this walk to [GroupNode] would stop at that first
  /// step and silently return an under-composed transform for every
  /// ATTRIB — not a failure to find [container], which
  /// [_containerHolding] has already resolved, but a wrong answer that
  /// [_sameBox] cannot tell from a real move. Every [Node] subtype carries a
  /// `transform`, so nothing but the loop's own termination needs to care
  /// which subtype is at each step.
  ///
  /// `seen`, not a numeric step cap: a numeric cap would silently truncate a
  /// legitimately deep chain of groups before it reaches [container],
  /// returning a partial — and therefore wrong — composed transform with no
  /// signal that anything was cut short. `seen` costs nothing a correct walk
  /// would not already pay, terminates a malformed, cyclic tree exactly as a
  /// cap would, and never truncates an acyclic one no matter how deep.
  Transform2 _groupTransformOf(Handle owner, Handle container) {
    var acc = Transform2.identity();
    var current = owner;
    final seen = <Handle>{};
    while (current != container) {
      if (!seen.add(current)) break; // cyclic tree; stop rather than hang
      final node = document.tree[current];
      if (node == null) break;
      acc = node.transform.multiply(acc);
      current = node.parent;
    }
    return acc;
  }

  /// The index of the container that holds [owner] — itself if it is
  /// indexed, otherwise the nearest indexed ancestor, since groups are
  /// flattened.
  ///
  /// `seen`, not a numeric step cap, for the same reason as
  /// [_groupTransformOf]: the failure mode here is milder — a cap firing on
  /// a legitimately deep tree only makes this return null, and every caller
  /// treats null as "fall back to [rebuildAll]", so a truncated walk cannot
  /// produce a *wrong* container, only an unnecessarily expensive correct
  /// one — but there is no reason to pay that cost when `seen` avoids it for
  /// free and still terminates a cyclic tree.
  ContainerIndex? _containerHolding(Handle owner) {
    var current = owner;
    final seen = <Handle>{};
    while (true) {
      if (!seen.add(current)) return null; // cyclic tree; stop rather than hang
      final direct = _byContainer[current];
      if (direct != null) return direct;
      final node = document.tree[current];
      if (node == null) return null;
      current = node.parent;
    }
  }

  /// Deliberately exact `==`, not a tolerance. This is a stored-value
  /// comparison — "is the indexed box byte-identical to the freshly derived
  /// one" — not a geometric decision. A tolerance here would let a real move
  /// slip through as unchanged.
  static bool _sameBox(Aabb2 a, Aabb2 b) =>
      a.minX == b.minX &&
      a.minY == b.minY &&
      a.maxX == b.maxX &&
      a.maxY == b.maxY;

  void dispose() {
    // Only detach the hook if it is still ours: a second index over the same
    // document would otherwise be silently unhooked by the first one's
    // disposal.
    //
    // `==`, not `identical`: two tear-offs of the same instance method on the
    // same receiver are `==` but never `identical` — each tear-off is a fresh
    // closure object. `identical` here would be false in every case,
    // including the single-index case this plan actually supports, so the
    // hook would never detach and a "disposed" index would keep rebuilding
    // itself on every future load and purge for the document's lifetime.
    if (document.commands.onAfterMutate == _onChange) {
      document.commands.onAfterMutate = null;
    }
    _byContainer.clear();
    _disposed = true;
  }
}

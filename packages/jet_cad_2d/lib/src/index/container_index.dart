import 'dart:math' as math;
import 'dart:typed_data';

import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/extents.dart';
import '../document/node.dart';
import '../document/style.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import 'dirty_list.dart';
import 'packed_rtree.dart';

/// The spatial index of one indexed container — the document root, or a
/// definition.
///
/// Holds two trees, not one: leaves keyed by entity slot, and instances keyed
/// by node handle. Two trees rather than one tagged tree because the callers
/// differ — culling wants leaves and instances separately, and a tagged tree
/// would make every visitor branch on the tag.
///
/// **Groups are flattened.** A group is a one-off: it is not shared, so a
/// per-group index buys no reuse while costing a recursion level on every
/// query. Its leaves are folded into the nearest indexed ancestor with the
/// group transform composed in. An instance is *not* flattened — it is the
/// sharing boundary, and folding it in would defeat the entire design.
class ContainerIndex {
  ContainerIndex._(
    this.container,
    this._leaves,
    this._instances,
    this._instanceHandles,
    this._instanceTransforms,
    this.bounds,
  ) : dirty = DirtyList();

  /// Builds the index for [container].
  ///
  /// [leavesByOwner] is shared across every container built in one pass; see
  /// [ContainerIndex.leavesByOwner]. Passing it in rather than recomputing it
  /// per container is what keeps a whole-document build linear in entities
  /// rather than O(containers x entities).
  factory ContainerIndex.build(
    DraftDocument doc,
    Handle container,
    Map<Handle, List<int>> leavesByOwner,
  ) {
    final leafSlots = <int>[];
    final leafBoxes = <double>[];
    final instanceHandles = <Handle>[];
    final instanceBoxes = <double>[];
    final instanceTransforms = <Transform2>[];
    var bounds = Aabb2.empty();

    void addBox(List<double> into, Aabb2 b) {
      into
        ..add(b.minX)
        ..add(b.minY)
        ..add(b.maxX)
        ..add(b.maxY);
    }

    void addLeaf(int slot, Transform2 composed) {
      final record = doc.entities.read(slot);
      final leafBox = entityBounds(
        kind: record.kind,
        payload: doc.geometry.read(record.geomIndex),
        measurer: doc.textMeasurer,
        textStyle: ReservedHandles.standardTextStyle,
      ).transformedBy(composed);
      leafSlots.add(slot);
      addBox(leafBoxes, leafBox);
      bounds = bounds.union(leafBox);
    }

    List<Handle> childNodesOf(Handle c) {
      final node = doc.tree[c];
      if (node is GroupNode) return doc.tree.childNodesOf(node.children);
      final definition = doc.tree.definition(c);
      if (definition != null) {
        return doc.tree.childNodesOf(definition.children);
      }
      return const [];
    }

    // Memoized per definition, not per instance: [DraftDocument.definitionBounds]
    // recomputes `leavesByOwner()` — a full entity-store scan — on every
    // call, so calling it once per instance makes a build over N instances of
    // one shared definition O(N x entities) instead of O(entities). A build
    // over 500 instances of an 8000-leaf definition measured ~5.7s uncached
    // versus a few ms cached; see task-5-report.md.
    final definitionBoundsCache = <Handle, Aabb2>{};
    Aabb2 boundsOfDefinition(Handle def) =>
        definitionBoundsCache[def] ??= doc.definitionBounds(def);

    // Explicit stack rather than recursion: a malformed tree must not blow
    // the Dart stack, and `validate()` reports tree.cycle for exactly that.
    //
    // No depth cap. `seen` below already bounds the walk to at most one push
    // per node — that is what actually prevents a cyclic graph from hanging
    // the build, since the stack is heap-allocated, not the Dart call stack,
    // so there is nothing a numeric depth limit would protect against that
    // `seen` does not already cover. A cap here would only ever silently
    // truncate a legitimately deep — or legitimately wide, since many
    // siblings are pending on the stack at once before any of them pops —
    // and otherwise acyclic tree, which is strictly worse than the hang it
    // would claim to prevent.
    final stack = <(Handle, Transform2)>[(container, Transform2.identity())];
    final seen = <Handle>{container};

    while (stack.isNotEmpty) {
      final (current, acc) = stack.removeLast();

      for (final slot in leavesByOwner[current] ?? const <int>[]) {
        addLeaf(slot, acc);
      }

      for (final child in childNodesOf(current)) {
        // `seen` also deduplicates a `children` list that names the same
        // child twice — tolerated on import (see
        // `DocumentTree._withoutAll`'s doc comment) but fatal to
        // `PackedRTree.build`, which requires unique payloads, if left
        // unguarded here.
        if (!seen.add(child)) continue;
        final node = doc.tree[child];
        switch (node) {
          case GroupNode(:final transform):
            // Flattened: recurse with the composed transform. `acc` is
            // applied second, so acc.multiply(transform) maps child space to
            // container space.
            stack.add((child, acc.multiply(transform)));
          case InstanceNode(:final definition, :final transform):
            final composed = acc.multiply(transform);
            final instanceBox =
                boundsOfDefinition(definition).transformedBy(composed);
            instanceHandles.add(child);
            instanceTransforms.add(composed);
            addBox(instanceBoxes, instanceBox);
            bounds = bounds.union(instanceBox);

            // Attributes belong to the INSERT, not to the definition: an
            // ATTRIB entity's owner is the instance node, and per
            // `EntityRecord.owner`'s governing rule ("leaf coordinates are
            // expressed in the owner's space") its coordinates are
            // instance-*local*, exactly like any other leaf owned by this
            // node — not already placed. They must therefore be transformed
            // by `composed`, the same as every other leaf this container
            // owns, which is what makes them differ per placement; sharing
            // one untransformed box across every instance, or dropping them
            // because `leavesByOwner[current]` alone never reaches a slot
            // owned by the instance, are the two ways to get this wrong. A
            // DXF importer must convert ATTRIB coordinates into
            // instance-local space on import — DXF stores them already
            // placed in world space, and re-using that value verbatim here
            // would double-apply the INSERT transform.
            for (final slot in leavesByOwner[child] ?? const <int>[]) {
              addLeaf(slot, composed);
            }
          case null:
            break;
        }
      }
    }

    return ContainerIndex._(
      container,
      _treeOf(leafSlots.length, leafBoxes, Uint32List.fromList(leafSlots)),
      _treeOf(instanceHandles.length, instanceBoxes,
          Uint32List.fromList([for (final h in instanceHandles) h.value])),
      instanceHandles,
      instanceTransforms,
      bounds,
    );
  }

  static PackedRTree _treeOf(
          int count, List<double> boxes, Uint32List payloads) =>
      count == 0
          ? PackedRTree.empty()
          : PackedRTree.build(count, Float64List.fromList(boxes), payloads);

  /// Every live entity slot bucketed by its owner, ascending within a bucket.
  ///
  /// Delegates to [DraftDocument.leavesByOwner] rather than keeping an
  /// independent copy of the bucketing loop: leaf containment is stated
  /// exactly once, by `EntityRecord.owner`, and that statement's one
  /// implementation lives on the document, which is also what
  /// `definitionBounds` and `extents` use. This static wrapper exists only
  /// so every call site in this file and its tests can write
  /// `ContainerIndex.leavesByOwner(doc)` uniformly, matching the shape the
  /// rest of this class's API uses. Never read leaves out of a `children`
  /// list — `children` holds child nodes only.
  static Map<Handle, List<int>> leavesByOwner(DraftDocument doc) =>
      doc.leavesByOwner();

  final Handle container;
  final PackedRTree _leaves;
  final PackedRTree _instances;
  final List<Handle> _instanceHandles;
  final List<Transform2> _instanceTransforms;

  /// The union of everything this container holds, in its own space.
  final Aabb2 bounds;

  final DirtyList dirty;

  int get leafCount => _leaves.itemCount;
  int get instanceCount => _instances.itemCount;

  /// Above this many dirty entries the tree is rebuilt.
  ///
  /// The floor of 64 keeps a small document from rebuilding on every second
  /// edit; the 5% term keeps a large one from linearly scanning a meaningful
  /// fraction of itself on every query.
  int get rebuildThreshold => math.max(64, (leafCount * 0.05).floor());

  bool get needsRebuild => dirty.length > rebuildThreshold;

  /// Visits the slot of every leaf whose box overlaps [local], which is
  /// expressed in this container's own space.
  ///
  /// Dirty entries are visited too, so a caller sees recent edits. A slot may
  /// be visited twice if it is both in the tree and dirty; the tree marks
  /// superseded entries dead to prevent that, and the invalidation path is
  /// responsible for doing so.
  void searchLeaves(Aabb2 local, void Function(int slot) visit) {
    if (local.isEmpty) return;
    _leaves.search(local.minX, local.minY, local.maxX, local.maxY, visit);
    dirty.search(local.minX, local.minY, local.maxX, local.maxY, visit);
  }

  void searchInstances(Aabb2 local, void Function(Handle node) visit) {
    if (local.isEmpty) return;
    _instances.search(local.minX, local.minY, local.maxX, local.maxY,
        (payload) => visit(Handle(payload)));
  }

  /// The composed container-space transform of [node], including every group
  /// transform between it and this container.
  Transform2 transformOfInstance(Handle node) {
    final at = _instanceHandles.indexOf(node);
    if (at < 0) return Transform2.identity();
    return _instanceTransforms[at];
  }

  /// Marks a leaf slot as superseded by a dirty entry.
  void markLeafDead(int slot) => _leaves.markDead(slot);
}

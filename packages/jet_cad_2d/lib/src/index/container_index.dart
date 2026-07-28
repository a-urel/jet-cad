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

    // Explicit stack rather than recursion: a malformed tree must not blow
    // the Dart stack, and `validate()` reports tree.cycle for exactly that.
    //
    // `seen` alone already makes a *cyclic* graph terminate — each handle can
    // be pushed at most once, ever — so `maxDepth` is a second, independent
    // guard against a *legitimately deep* (but acyclic) chain of nested
    // groups blowing the stack. It must therefore cap actual path depth, not
    // the number of items momentarily pending on the stack: a container with
    // many sibling groups pushes many entries in one pass before any of them
    // is popped, and bounding on `stack.length` would silently drop the
    // siblings past the cap even though the tree is only one level deep. Each
    // stack entry below carries its own depth for exactly this reason.
    const maxDepth = 256;
    final stack = <(Handle, Transform2, int)>[
      (container, Transform2.identity(), 0),
    ];
    final seen = <Handle>{container};

    while (stack.isNotEmpty) {
      final (current, acc, depth) = stack.removeLast();

      for (final slot in leavesByOwner[current] ?? const <int>[]) {
        addLeaf(slot, acc);
      }

      for (final child in childNodesOf(current)) {
        final node = doc.tree[child];
        switch (node) {
          case GroupNode(:final transform):
            // Flattened: recurse with the composed transform. `acc` is
            // applied second, so acc.multiply(transform) maps child space to
            // container space.
            if (seen.add(child) && depth + 1 < maxDepth) {
              stack.add((child, acc.multiply(transform), depth + 1));
            }
          case InstanceNode(:final definition, :final transform):
            final composed = acc.multiply(transform);
            final instanceBox =
                doc.definitionBounds(definition).transformedBy(composed);
            instanceHandles.add(child);
            instanceTransforms.add(composed);
            addBox(instanceBoxes, instanceBox);
            bounds = bounds.union(instanceBox);

            // Attributes belong to the INSERT, not to the definition: an
            // ATTRIB entity's owner is the instance node, and its
            // coordinates are already in the instance's placed position.
            // They are indexed into THIS container rather than into the
            // definition's index, because they differ per instance — that is
            // the whole point of an attribute. Missing this step leaves
            // every attribute in no index at all, unpickable and
            // unsnappable, while `attributesOf` still reports them.
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
  /// Leaf containment is stated exactly once, by `EntityRecord.owner`, and
  /// that statement is authoritative. Never read leaves out of a `children`
  /// list — `children` holds child nodes only.
  static Map<Handle, List<int>> leavesByOwner(DraftDocument doc) {
    final byOwner = <Handle, List<int>>{};
    // liveSlots yields ascending slots, so each bucket is ascending too.
    for (final slot in doc.entities.liveSlots) {
      (byOwner[doc.entities.ownerAt(slot)] ??= <int>[]).add(slot);
    }
    return byOwner;
  }

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

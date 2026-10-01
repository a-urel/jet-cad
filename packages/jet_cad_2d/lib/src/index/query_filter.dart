import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/node.dart';
import '../document/style.dart';

/// What a query should skip.
///
/// A filter is a query parameter rather than something the caller applies to
/// the results, because applying it afterwards means the index returns work the
/// caller throws away — at frame rate. Four callers want four answers:
/// "select all on this layer" wants everything, rendering wants visible,
/// picking wants visible, unlocked and pickable, and snapping wants visible
/// and pickable (a locked layer is still snapped to).
final class QueryFilter {
  const QueryFilter({
    required this.visibleOnly,
    required this.excludeLocked,
    this.excludeUnpickable = false,
  });

  /// Everything, hidden, locked and not-pickable included.
  const QueryFilter.all()
      : visibleOnly = false,
        excludeLocked = false,
        excludeUnpickable = false;

  /// What the renderer draws. A locked layer still draws, and so does an
  /// entity carrying [EntityFlags.unpickable].
  const QueryFilter.rendering()
      : visibleOnly = true,
        excludeLocked = false,
        excludeUnpickable = false;

  /// What a pointer can select: visible, unlocked, and not carrying
  /// [EntityFlags.unpickable].
  const QueryFilter.picking()
      : visibleOnly = true,
        excludeLocked = true,
        excludeUnpickable = true;

  /// What the cursor can snap to: what [QueryFilter.rendering] accepts, minus
  /// entities carrying [EntityFlags.unpickable] (spec 11 D19). A locked layer
  /// is still snapped to: it is how you draw relative to a locked reference.
  const QueryFilter.snapping()
      : visibleOnly = true,
        excludeLocked = false,
        excludeUnpickable = true;

  final bool visibleOnly;
  final bool excludeLocked;

  /// Rejects an entity whose flags carry [EntityFlags.unpickable].
  final bool excludeUnpickable;

  /// True when this filter rejects nothing, so callers can skip evaluation.
  bool get isPassthrough =>
      !visibleOnly && !excludeLocked && !excludeUnpickable;
}

/// Applies a [QueryFilter], caching what it can.
///
/// A layer lookup per entity per frame is a map hit per entity per frame, so
/// per-layer and per-container answers are memoised. The cache must be dropped
/// whenever a layer record or a node's visibility changes; [invalidate] is that
/// hook.
///
/// Since plan 12b the layer commands can flip a layer's `visible` and
/// `locked`, and a direct [DocumentTables] write can too. [SpatialIndex]
/// owns the long-lived evaluator and calls [invalidate] at the start of the
/// first query after `DocumentTables.mutationRevision` moved (spec 12b D6),
/// and on every full rebuild. Nothing rewrites [Node.visible] yet; the next
/// command that can must invalidate too — nothing here notices on its own.
///
/// **The effective layer (spec 12b D6, plan P-4).** A leaf or a nested
/// instance on layer 0 is tested against the layer of the context it is
/// placed through, the style resolver's substitution rule: [acceptsEntityOnLayer]
/// and [acceptsNodeOnLayer] take that context layer from the index's walk.
/// [acceptsEntity] and [acceptsNode] are the root context, whose layer is
/// layer 0 — except for a leaf owned by an [InstanceNode] (an ATTRIB), which
/// takes its owner's layer ([_ownerLayer]).
class FilterEvaluator {
  FilterEvaluator(this.document);

  final DraftDocument document;
  final Map<Handle, bool> _layerVisible = <Handle, bool>{};
  final Map<Handle, bool> _layerLocked = <Handle, bool>{};
  final Map<Handle, bool> _containerVisible = <Handle, bool>{};

  /// Per owner handle: the owner's own layer when it is an [InstanceNode],
  /// else [Handle.none]. Read for a layer-0 leaf not owned by the root — an
  /// ATTRIB's owner is its instance (`node.dart`) — so the ATTRIB follows the
  /// instance (spec 12b D6, S-2). An instance's layer changes only through a
  /// node replacement, which the index answers with a full rebuild, and
  /// every full rebuild calls [invalidate].
  final Map<Handle, Handle> _ownerLayer = <Handle, Handle>{};

  void invalidate() {
    _layerVisible.clear();
    _layerLocked.clear();
    _containerVisible.clear();
    _ownerLayer.clear();
  }

  /// [acceptsEntityOnLayer] in the root context: a leaf on layer 0 stays on
  /// layer 0 unless an [InstanceNode] owns it (an ATTRIB), which then takes
  /// its instance's layer.
  bool acceptsEntity(int slot, QueryFilter filter) =>
      acceptsEntityOnLayer(slot, filter, ReservedHandles.layerZero);

  /// Whether [filter] accepts the leaf at [slot], placed through a context
  /// whose effective layer is [context] (spec 12b D6, plan P-4).
  ///
  /// The layer tested is the leaf's own, unless that is layer 0: then it is
  /// its owning instance's layer when an [InstanceNode] owns it and that
  /// layer is not layer 0 (an ATTRIB, S-2), else [context] — the resolver's
  /// substitution rule (`style_resolver.dart`, `styleFor`). The answers are
  /// memoised per layer, so the substitution adds an int compare per leaf
  /// and, for a layer-0 leaf not owned by the root, one map hit.
  bool acceptsEntityOnLayer(int slot, QueryFilter filter, Handle context) {
    if (filter.isPassthrough) return true;
    // One bool test when the filter does not ask (`rendering()`, every
    // frame), one column read when it does (a pick or a snap). No
    // allocation, no map lookup (spec 11 D19).
    if (filter.excludeUnpickable &&
        document.entities.flagsAt(slot) & EntityFlags.unpickable != 0) {
      return false;
    }
    var layer = document.entities.layerAt(slot);
    if (layer == ReservedHandles.layerZero) {
      final owner = document.entities.ownerAt(slot);
      final ownLayer =
          owner == document.rootHandle ? Handle.none : _instanceLayer(owner);
      layer = ownLayer != Handle.none && ownLayer != ReservedHandles.layerZero
          ? ownLayer
          : context;
    }
    if (filter.visibleOnly) {
      // The entity's own bit first: it is a column read, where the other two
      // are map lookups, and DXF group code 60 outranks both — an entity
      // marked not-drawn is not drawn however visible its layer and owner are.
      if (document.entities.flagsAt(slot) & EntityFlags.invisible != 0) {
        return false;
      }
      if (!_visibleLayer(layer)) return false;
      if (!_visibleContainer(document.entities.ownerAt(slot))) return false;
    }
    if (filter.excludeLocked && _lockedLayer(layer)) return false;
    return true;
  }

  /// [acceptsNodeOnLayer] in the root context: an instance is tested
  /// against its own layer.
  bool acceptsNode(Handle node, QueryFilter filter) =>
      acceptsNodeOnLayer(node, filter, ReservedHandles.layerZero);

  /// Whether [filter] accepts [node], placed through a context whose
  /// effective layer is [context]: an [InstanceNode] on layer 0 is tested
  /// against [context] (spec 12b D6, S-7), the resolver's rule in
  /// `contextFor`.
  bool acceptsNodeOnLayer(Handle node, QueryFilter filter, Handle context) {
    if (filter.isPassthrough) return true;
    final resolved = document.tree[node];
    if (resolved == null) return true;
    final layer = resolved is InstanceNode
        ? (resolved.layer == ReservedHandles.layerZero
            ? context
            : resolved.layer)
        : ReservedHandles.layerZero;
    if (filter.visibleOnly) {
      // The node's own visibility and its ancestors' are the same question
      // _visibleContainer already answers for a leaf's owner — a node is
      // itself a container in that walk, so asking it directly (rather than
      // checking `resolved.visible` here and delegating only the ancestor
      // chain) reuses one path instead of keeping two, and gets the node's
      // own answer cached too.
      if (!_visibleContainer(node)) return false;
      if (resolved is InstanceNode && !_visibleLayer(layer)) return false;
    }
    if (filter.excludeLocked &&
        resolved is InstanceNode &&
        _lockedLayer(layer)) {
      return false;
    }
    return true;
  }

  /// [owner]'s own layer when it is an [InstanceNode], else [Handle.none];
  /// memoised in [_ownerLayer].
  Handle _instanceLayer(Handle owner) {
    final cached = _ownerLayer[owner];
    if (cached != null) return cached;
    final node = document.tree[owner];
    return _ownerLayer[owner] = node is InstanceNode ? node.layer : Handle.none;
  }

  /// A layer this document does not have is treated as visible and unlocked.
  ///
  /// A missing layer is `validate()`'s problem. Making the geometry silently
  /// unselectable instead would turn a reportable inconsistency into a user
  /// staring at something they cannot click.
  bool _visibleLayer(Handle layer) =>
      _layerVisible[layer] ??= document.tables.layers[layer]?.visible ?? true;

  bool _lockedLayer(Handle layer) =>
      _layerLocked[layer] ??= document.tables.layers[layer]?.locked ?? false;

  /// Visibility is inherited: a leaf under a hidden group is hidden, however
  /// many visible levels sit between them.
  ///
  /// Climbs `parent` pointers with a `seen` set rather than a numeric step
  /// budget. A budget would silently truncate a legitimate deep tree and,
  /// because this method returns a boolean rather than throwing, truncation
  /// would make a genuinely hidden leaf report as visible — the wrong side to
  /// fail on. A `seen` set costs nothing extra (the walk is already O(depth))
  /// and terminates on the only case a budget was ever protecting against: a
  /// cycle. On a cycle the walk stops without deciding the container hidden —
  /// a malformed containment graph is `validate()`'s problem, not something
  /// this query should throw over at frame rate.
  bool _visibleContainer(Handle container) {
    final cached = _containerVisible[container];
    if (cached != null) return cached;

    var current = container;
    final seen = <Handle>{};
    var visible = true;
    while (seen.add(current)) {
      final node = document.tree[current];
      if (node == null) break; // a definition, or past the root
      if (!node.visible) {
        visible = false;
        break;
      }
      current = node.parent;
    }
    return _containerVisible[container] = visible;
  }
}

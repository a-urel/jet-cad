import '../core/handle.dart';
import '../document/draft_document.dart';
import '../document/node.dart';
import '../document/style.dart';

/// What a query should skip.
///
/// A filter is a query parameter rather than something the caller applies to
/// the results, because applying it afterwards means the index returns work the
/// caller throws away — at frame rate. Three callers want three answers:
/// "select all on this layer" wants everything, rendering wants visible,
/// picking wants visible and unlocked.
final class QueryFilter {
  const QueryFilter({required this.visibleOnly, required this.excludeLocked});

  /// Everything, hidden and locked included.
  const QueryFilter.all()
      : visibleOnly = false,
        excludeLocked = false;

  /// What the renderer draws. A locked layer still draws.
  const QueryFilter.rendering()
      : visibleOnly = true,
        excludeLocked = false;

  /// What a pointer can select.
  const QueryFilter.picking()
      : visibleOnly = true,
        excludeLocked = true;

  final bool visibleOnly;
  final bool excludeLocked;

  /// True when this filter rejects nothing, so callers can skip evaluation.
  bool get isPassthrough => !visibleOnly && !excludeLocked;
}

/// Applies a [QueryFilter], caching what it can.
///
/// A layer lookup per entity per frame is a map hit per entity per frame, so
/// per-layer and per-container answers are memoised. The cache must be dropped
/// whenever a layer record or a node's visibility changes; [invalidate] is that
/// hook.
///
/// No command in `commands.dart` can currently cause that staleness:
/// [AddNodeCommand] refuses to overwrite an existing handle, [TransformNodeCommand]
/// rewrites only `transform`, and nothing rewrites [Node.visible] or a
/// [LayerRecord]'s `visible`/`locked` at all — table records go in only through
/// [DocumentTables], which this plan has not yet given a mutating command
/// either. So today, [invalidate] has no caller and every cache this class
/// builds is correct for the document's whole lifetime. **This is a fact about
/// today's command set, not a guarantee [FilterEvaluator] enforces** — the next
/// command that can flip a node's or a layer's visibility or lock state must
/// call [invalidate] itself; nothing here will notice on its own.
class FilterEvaluator {
  FilterEvaluator(this.document);

  final DraftDocument document;
  final Map<Handle, bool> _layerVisible = <Handle, bool>{};
  final Map<Handle, bool> _layerLocked = <Handle, bool>{};
  final Map<Handle, bool> _containerVisible = <Handle, bool>{};

  void invalidate() {
    _layerVisible.clear();
    _layerLocked.clear();
    _containerVisible.clear();
  }

  bool acceptsEntity(int slot, QueryFilter filter) {
    if (filter.isPassthrough) return true;
    final layer = document.entities.layerAt(slot);
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

  bool acceptsNode(Handle node, QueryFilter filter) {
    if (filter.isPassthrough) return true;
    final resolved = document.tree[node];
    if (resolved == null) return true;
    if (filter.visibleOnly) {
      // The node's own visibility and its ancestors' are the same question
      // _visibleContainer already answers for a leaf's owner — a node is
      // itself a container in that walk, so asking it directly (rather than
      // checking `resolved.visible` here and delegating only the ancestor
      // chain) reuses one path instead of keeping two, and gets the node's
      // own answer cached too.
      if (!_visibleContainer(node)) return false;
      if (resolved is InstanceNode && !_visibleLayer(resolved.layer)) {
        return false;
      }
    }
    if (filter.excludeLocked &&
        resolved is InstanceNode &&
        _lockedLayer(resolved.layer)) {
      return false;
    }
    return true;
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

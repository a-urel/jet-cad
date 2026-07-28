import '../core/handle.dart';
import '../document/node.dart';
import '../geometry/aabb2.dart';
import '../store/entity_store.dart';
import 'query_filter.dart';
import 'spatial_index.dart';

/// Query forms for tools, adapters and tests — everything not on the frame
/// path.
///
/// **This extension is the opposite of the rest of this file's contract.**
/// `forEachInRect`, `forEachInstanceInRect`, `pickInto` and `snapInto` are all
/// documented as not allocating in steady state, and mean it. Every method
/// here allocates on every call: each one builds a fresh `List<Handle>` and
/// hands it back as the return value. That is not an oversight — an
/// `Iterable` is the allocating, convenient form, and these exist so a tool,
/// an adapter, or a test has one obvious call to make instead of writing a
/// visitor. They are not a faster path you overlooked; they are a different
/// category with a different intended use.
///
/// **Three of the four are full O(n) scans with no index behind them:**
/// [onLayer] and [attributesOf] walk every live entity; [instancesOf] walks
/// every node in the tree. Nothing here is indexed by layer, by definition,
/// or by owner. Calling one of those three per frame — `onLayer` inside a
/// paint loop, for instance — is a full scan per frame, and the cost grows
/// with the document, not with the answer. [entitiesInRect] is the exception:
/// it wraps `forEachInRect`, so its cost is `O(log n)` plus the result size,
/// the same query the frame path already pays for, just materialised into a
/// list instead of streamed through a visitor.
///
/// **Do not call these on the frame path.** For a rect query, call
/// `forEachInRect` directly instead of `entitiesInRect` — the visitor form
/// costs nothing per call. For the other three, there is no visitor form to
/// fall back to; hoist the call out of the loop instead (compute it once,
/// after the mutation that could invalidate it, and reuse the result), or
/// build a real index if a paint loop genuinely needs the answer every frame.
///
/// **Every result is a materialised snapshot, not a lazy view.** Each method
/// runs its scan (or its `forEachInRect` call, which is guarded and not
/// reentrant) to completion and returns a plain `List<Handle>` before
/// returning to the caller. This is a deliberate choice, not the default a
/// `sync*` generator would have given for free: a lazily-evaluated iterable
/// is only walked when the caller iterates it, which may be after the
/// document has been mutated. That would make the result silently observe a
/// later, different document state than the one the caller queried against —
/// and, for [entitiesInRect], it would run `forEachInRect`'s guarded walk at
/// whatever arbitrary moment the caller chose to iterate, rather than inside
/// this call, which is exactly the kind of query-outside-a-query the
/// reentrancy guard (`QueryReentrancyError`, see [SpatialIndex]) exists to
/// catch. Eager materialisation costs one list allocation per call, paid
/// upfront, in exchange for a result that is a real snapshot: mutating the
/// document after the call cannot change what the caller already holds.
extension ConvenienceQueries on SpatialIndex {
  /// Root-level entities overlapping [world], ascending by handle.
  ///
  /// The allocating form of `forEachInRect`, with identical results and
  /// identical cost: `O(log n)` plus the result size. The only member of this
  /// extension that is not a full scan, because it is the only one with an
  /// index behind it. Prefer `forEachInRect` on the frame path — same query,
  /// no per-call allocation.
  Iterable<Handle> entitiesInRect(Aabb2 world, QueryFilter filter) {
    final out = <Handle>[];
    forEachInRect(
        world, filter, (slot) => out.add(document.entities.handleAt(slot)));
    return out;
  }

  /// Every entity on [layer], ascending by handle.
  ///
  /// **O(entities), unindexed.** A full scan of the entity store with no
  /// per-layer index behind it; the cost is the size of the whole document,
  /// not the size of the layer. Do not call this per frame.
  Iterable<Handle> onLayer(Handle layer) {
    final out = <Handle>[];
    for (final slot in document.entities.liveSlots) {
      if (document.entities.layerAt(slot) == layer) {
        out.add(document.entities.handleAt(slot));
      }
    }
    // liveSlots is ascending by slot (allocation order), which is not
    // handle order once a slot has been freed and reused — see this
    // extension's doc comment on why every query here returns handle order.
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  /// Every instance node placing [definition], ascending by handle.
  ///
  /// **O(nodes), unindexed.** A full scan of the scene tree with no
  /// per-definition index behind it. Do not call this per frame.
  Iterable<Handle> instancesOf(Handle definition) {
    final out = <Handle>[];
    // document.tree.nodes is documented ascending-by-handle already, so this
    // scan does not reorder anything; the extra sort below is defence in
    // depth, matching onLayer and attributesOf rather than trusting that
    // invariant silently.
    for (final node in document.tree.nodes) {
      if (node is InstanceNode && node.definition == definition) {
        out.add(node.handle);
      }
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  /// Attribute entities owned by [instance], ascending by handle.
  ///
  /// **O(entities), unindexed.** A full scan of the entity store with no
  /// per-owner index behind it. Do not call this per frame.
  Iterable<Handle> attributesOf(Handle instance) {
    final out = <Handle>[];
    for (final slot in document.entities.liveSlots) {
      if (document.entities.ownerAt(slot) == instance &&
          document.entities.kindAt(slot) == EntityKind.attrib) {
        out.add(document.entities.handleAt(slot));
      }
    }
    // See onLayer: liveSlots is allocation order, not handle order.
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }
}

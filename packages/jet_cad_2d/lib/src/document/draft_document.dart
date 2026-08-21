import 'dart:async';

import '../core/handle.dart';
import '../geometry/aabb2.dart';
import '../geometry/transform2.dart';
import '../store/entity_store.dart';
import '../store/geometry_store.dart';
import 'command.dart';
import 'component.dart';
import 'doc_change.dart';
import 'extents.dart';
import 'fill_index.dart';
import 'header.dart';
import 'node.dart';
import 'raw_data.dart';
import 'style.dart';
import 'tables.dart';
import 'text_metrics.dart';
import 'tree.dart';
import 'undo.dart';

/// The 2D CAD document.
///
/// Owns four kinds of state: object-per-record containers (nodes, definitions,
/// table records), columnar stores for leaves, sparse component stores, and the
/// opaque preserve-unknown slot. Mutation happens only through commands.
class DraftDocument implements CommandTarget {
  @override
  final EntityStore entities;
  @override
  final GeometryStore geometry;
  @override
  final DocumentTables tables;
  @override
  final ComponentRegistry components;
  @override
  final HandleSeed handleSeed;
  @override
  final DocumentTree tree;

  @override
  final FillIndex fills = FillIndex();

  final DocumentHeader header;
  final RawDataStore rawData;

  /// Top-level document fields written by a newer version of this package.
  ///
  /// Preserved verbatim and written back unchanged: no layer discards data it
  /// does not understand, and a document edited by an older build must not lose
  /// what a newer one wrote.
  final Map<String, Object?> unknownDocumentFields = {};

  /// `final`, not a plain mutable field: `entityBounds` reads this to compute
  /// `extents`, and `extents` caches that result in `_extentsCache` until
  /// [invalidateDerived] runs. A reassignable field would let a caller change
  /// what `entityBounds` returns without touching the cache, so `extents`
  /// would keep serving a box computed with the previous measurer. The brief
  /// only ever passes this as a constructor parameter, so fixing it at
  /// construction costs nothing a caller needs and removes the stale-cache
  /// hazard by construction rather than relying on every future writer to
  /// remember to invalidate.
  final TextMeasurer textMeasurer;

  late final CommandDispatcher commands;

  Aabb2? _extentsCache;

  DraftDocument._({
    required this.entities,
    required this.geometry,
    required this.tables,
    required this.components,
    required this.handleSeed,
    required this.tree,
    required this.header,
    required this.rawData,
    required this.textMeasurer,
    required DraftPermissions permissions,
    required int undoLimit,
  }) {
    commands = CommandDispatcher(
      target: this,
      permissions: permissions,
      undoLimit: undoLimit,
    );
  }

  factory DraftDocument.empty({
    TextMeasurer measurer = const InsertionPointMeasurer(),
    DraftPermissions permissions = DraftPermissions.all,
    int undoLimit = 200,
  }) {
    // The seed starts past every reserved handle, so an allocated handle can
    // never collide with layer 0 or the BYLAYER linetype.
    final seed = HandleSeed(ReservedHandles.firstFree);
    final root = GroupNode(
      handle: seed.next(),
      parent: Handle.none,
      transform: Transform2.identity(),
      children: const [],
    );
    return DraftDocument._(
      entities: EntityStore(),
      geometry: GeometryStore(),
      tables: DocumentTables.standard(),
      components: ComponentRegistry()..registerBuiltIns(),
      handleSeed: seed,
      tree: DocumentTree(rootNode: root),
      header: DocumentHeader(),
      rawData: RawDataStore(),
      textMeasurer: measurer,
      permissions: permissions,
      undoLimit: undoLimit,
    );
  }

  Handle get rootHandle => tree.root;

  /// Resolves [handle] to its [TextStyleRecord], falling back to a plain
  /// STANDARD-shaped record rather than a second table lookup.
  ///
  /// `JsonCodec._loadTables` clears the seeded defaults before loading a
  /// file's own table entries, and `TableSection.remove` is public, so a
  /// document whose `textStyles` table lacks even
  /// [ReservedHandles.standardTextStyle] is reachable, not hypothetical —
  /// chaining `?? tables.textStyles[ReservedHandles.standardTextStyle]!`
  /// crashes on exactly that document. The fallback's field values match
  /// [TextStyleRecord]'s own defaults (`widthFactor: 1.0`,
  /// `obliqueAngle: 0.0`, `fixedHeight: 0.0`), so a document with no
  /// resolvable style lays out text as if no deliberate override existed.
  ///
  /// Every call site that turns an entity's `textStyle` handle into a record
  /// for [entityBounds] goes through this one accessor, so the four
  /// production sites — including the incremental dirty-overlay re-derive
  /// and the differential oracle's own bounds call — cannot drift apart.
  TextStyleRecord textStyleOf(Handle handle) =>
      tables.textStyles[handle] ?? _fallbackTextStyle;

  static const TextStyleRecord _fallbackTextStyle = TextStyleRecord(
    handle: ReservedHandles.standardTextStyle,
    name: 'Standard',
    fontFamily: 'Roboto',
  );

  Stream<DocChange> get changes => commands.changes;

  @override
  void invalidateDerived() => _extentsCache = null;

  /// Working extents, in root space. Derived: recomputed on first read after a
  /// mutation, and never persisted.
  Aabb2 get extents => _extentsCache ??= _computeExtents();

  /// Bounds of a definition in its own local space.
  ///
  /// Computed once per definition and reused by every instance — the same
  /// sharing the spatial index and the picture cache rely on in later plans.
  ///
  /// [leavesByOwner], when supplied, is used in place of recomputing
  /// [DraftDocument.leavesByOwner] — a full entity-store scan. **A caller
  /// building many of these in one pass must pass it.**
  /// [ContainerIndex.build] already holds one such map, shared across every
  /// container built in that pass; without threading it through here, a
  /// document with many *distinct* definitions pays a full entity-store scan
  /// once per definition even though [ContainerIndex.build]'s own
  /// `definitionBoundsCache` already stops it from paying twice for the
  /// *same* definition. Task 18's benchmark measured this: 2,000 definitions
  /// over 32,000 entities took multiple seconds before this parameter was
  /// threaded through, against ~1.4s to build the default 500k-entity,
  /// 20-definition benchmark document — the defect scales with definition
  /// *count*, not entity count, and the gate's own default fixture is too
  /// small to see it. Left optional, not required, because a caller asking
  /// for one definition's bounds in isolation has no such map to share and
  /// should not have to build one just to call this.
  Aabb2 definitionBounds(Handle definition,
          [Map<Handle, List<int>>? leavesByOwner]) =>
      _boundsOfContainer(definition, <Handle>{}, <Handle, Aabb2>{},
          leavesByOwner ?? this.leavesByOwner());

  /// Compacts both columnar stores and clears history.
  ///
  /// Not a command and not undoable: slot values change, so no recorded inverse
  /// could be replayed against the new numbering.
  ///
  /// Refuses to run after [dispose] — and refuses *before* mutating anything,
  /// which is the whole point of the check. `commands.notifyPurged()` at the
  /// end throws `StateError` on the closed stream controller, so without this
  /// guard a caller saw an exception, reasonably concluded nothing had
  /// happened, and was wrong: both stores had already been compacted and every
  /// slot renumbered. `execute`, `undo` and `redo` guard the same way.
  void purge() {
    if (commands.isDisposed) {
      throw StateError('DraftDocument.purge() after dispose()');
    }
    final geometryRemap = geometry.purge();
    for (final slot in entities.liveSlots.toList()) {
      final record = entities.read(slot);
      final moved = geometryRemap[record.geomIndex];
      if (moved >= 0 && moved != record.geomIndex) {
        entities.replace(slot, record.copyWith(geomIndex: moved));
      }
    }
    entities.purge();
    // `fills` is deliberately untouched. It is keyed by handle, and purge
    // renumbers slots, not handles. Adding an invalidation here would be
    // correct-looking and wrong: it would throw away work nothing invalidated.
    invalidateDerived();
    commands.notifyPurged();
  }

  Future<void> dispose() => commands.dispose();

  Aabb2 _computeExtents() => _boundsOfContainer(
      tree.root, <Handle>{}, <Handle, Aabb2>{}, leavesByOwner());

  /// Every live entity slot bucketed by its owner, ascending within a bucket.
  ///
  /// Built once per bounds computation and threaded down the recursion. The
  /// previous shape asked "which live entities does *this* container own?"
  /// once per container by scanning the whole entity store and filtering on
  /// `ownerAt`, which made a full recompute O(containers x entities): 400
  /// groups over 8000 entities measured 90 ms, and `invalidateDerived()` fires
  /// on every command. One bucketing pass makes the walk linear in entities,
  /// which is what a million-entity document requires. The result is identical
  /// either way — this is the same filter, evaluated once instead of once per
  /// container.
  ///
  /// Leaf containment is stated exactly once here, by [EntityRecord.owner] —
  /// [ContainerIndex.leavesByOwner] delegates to this rather than keeping an
  /// independent copy of the same loop, so the statement stays singular.
  Map<Handle, List<int>> leavesByOwner() {
    final byOwner = <Handle, List<int>>{};
    // `liveSlots` yields ascending slots, so each bucket is ascending too.
    for (final slot in entities.liveSlots) {
      (byOwner[entities.ownerAt(slot)] ??= <int>[]).add(slot);
    }
    return byOwner;
  }

  /// Union of everything a container holds, expressed in that container's own
  /// space. Works for both a group node and a definition.
  Aabb2 _boundsOfContainer(
    Handle container,
    Set<Handle> visiting,
    Map<Handle, Aabb2> memo,
    Map<Handle, List<int>> leavesByOwner,
  ) {
    final cached = memo[container];
    if (cached != null) return cached;
    // Cycles are rejected on insert and repaired on import, but a guard here
    // keeps a malformed in-memory tree from recursing forever.
    if (!visiting.add(container)) return Aabb2.empty();

    final held = _childrenOf(container, leavesByOwner);
    var box = Aabb2.empty();

    for (final slot in held.leafSlots) {
      final record = entities.read(slot);
      box = box.union(entityBounds(
        kind: record.kind,
        payload: geometry.read(record.geomIndex),
        measurer: textMeasurer,
        textStyle: textStyleOf(record.textStyle),
        textAttrs: record.textAttrs,
        text: record.text,
      ));
    }

    for (final child in held.childNodes) {
      switch (tree[child]!) {
        case GroupNode(:final transform):
          box = box.union(
              _boundsOfContainer(child, visiting, memo, leavesByOwner)
                  .transformedBy(transform));
        case InstanceNode(:final definition, :final transform):
          box = box.union(
              _boundsOfContainer(definition, visiting, memo, leavesByOwner)
                  .transformedBy(transform));
      }
    }

    visiting.remove(container);
    memo[container] = box;
    return box;
  }

  /// What [container] holds: its leaf entities, and its child nodes.
  ///
  /// Leaf containment is stated exactly once, by [EntityRecord.owner], and
  /// that statement is authoritative. Leaves are therefore found by owner —
  /// through the [leavesByOwner] buckets — and never by reading a `children`
  /// list, which holds child **nodes** only. The two used to be independent
  /// copies of the same fact with nothing syncing them: [AddEntityCommand]
  /// sets `owner` and does not link, so a command-built definition reported no
  /// children while its own entities named it as owner, while a file-loaded
  /// one listed them; and [RemoveEntityCommand] does not unlist, so a loaded
  /// container kept a dangling child that every later save re-emitted.
  ///
  /// Leaves come back in ascending **slot** order, which is an implementation
  /// detail of this walk and not an ordering anyone may rely on: a slot moves
  /// under `purge()` and under undo. **Draw order is ascending handle value**,
  /// which is stable across undo, save, load and purge, and is what every
  /// query returns and what hit-test ties break on. A caller that needs draw
  /// order must sort by handle — `SpatialIndex` does this for its callers.
  /// Only [GroupNode.children] carries a deliberate order, and it orders
  /// child nodes.
  ///
  /// A `children` entry naming no node in the tree is skipped rather than
  /// treated as a leaf — this is [DocumentTree.childNodesOf], which is how
  /// leaf handles in older files are tolerated. [DraftDocumentCodec] applies
  /// the same filter on the way out, so they are never written back.
  ///
  /// A group and a definition are both containers here, because a node's
  /// `parent` may name either; the root is just the outermost group.
  ({List<int> leafSlots, List<Handle> childNodes}) _childrenOf(
    Handle container,
    Map<Handle, List<int>> leavesByOwner,
  ) =>
      (
        leafSlots: leavesByOwner[container] ?? const <int>[],
        childNodes: tree.childNodesOf(switch (tree[container]) {
          GroupNode(:final children) => children,
          _ => tree.definition(container)?.children ?? const <Handle>[],
        }),
      );
}

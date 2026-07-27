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
import 'header.dart';
import 'node.dart';
import 'raw_data.dart';
import 'style.dart';
import 'tables.dart';
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
  Aabb2 definitionBounds(Handle definition) => _boundsOfContainer(
      definition, <Handle>{}, <Handle, Aabb2>{}, _leavesByOwner());

  /// Compacts both columnar stores and clears history.
  ///
  /// Not a command and not undoable: slot values change, so no recorded inverse
  /// could be replayed against the new numbering.
  void purge() {
    final geometryRemap = geometry.purge();
    for (final slot in entities.liveSlots.toList()) {
      final record = entities.read(slot);
      final moved = geometryRemap[record.geomIndex];
      if (moved >= 0 && moved != record.geomIndex) {
        entities.replace(slot, record.copyWith(geomIndex: moved));
      }
    }
    entities.purge();
    invalidateDerived();
    commands.notifyPurged();
  }

  Future<void> dispose() => commands.dispose();

  Aabb2 _computeExtents() => _boundsOfContainer(
      tree.root, <Handle>{}, <Handle, Aabb2>{}, _leavesByOwner());

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
  Map<Handle, List<int>> _leavesByOwner() {
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
        textStyle: ReservedHandles.standardTextStyle,
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
  /// Leaves come back in ascending **slot** order. That is insertion order
  /// within a session and file order after a load, but it is emphatically not
  /// an explicit z-order and nothing may treat it as one: a leaf's slot moves
  /// under `purge()` and under undo, neither of which is a reordering anyone
  /// asked for. Only [GroupNode.children] carries a deliberate order, and it
  /// orders child nodes.
  ///
  /// A `children` entry naming no node in the tree is skipped rather than
  /// treated as a leaf — this is how leaf handles in older files are
  /// tolerated. [DraftDocumentCodec] applies the same filter on the way out,
  /// so they are never written back.
  ///
  /// A group and a definition are both containers here, because a node's
  /// `parent` may name either; the root is just the outermost group.
  ({List<int> leafSlots, List<Handle> childNodes}) _childrenOf(
    Handle container,
    Map<Handle, List<int>> leavesByOwner,
  ) =>
      (
        leafSlots: leavesByOwner[container] ?? const <int>[],
        childNodes: [
          for (final child in switch (tree[container]) {
            GroupNode(:final children) => children,
            _ => tree.definition(container)?.children ?? const <Handle>[],
          })
            if (tree[child] != null) child,
        ],
      );
}

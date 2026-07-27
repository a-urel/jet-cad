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
  Aabb2 definitionBounds(Handle definition) =>
      _boundsOfContainer(definition, <Handle>{}, <Handle, Aabb2>{});

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

  Aabb2 _computeExtents() {
    final memo = <Handle, Aabb2>{};
    return _boundsOfContainer(tree.root, <Handle>{}, memo);
  }

  /// Union of everything a container holds, expressed in that container's own
  /// space. Works for both a group node and a definition.
  Aabb2 _boundsOfContainer(
    Handle container,
    Set<Handle> visiting,
    Map<Handle, Aabb2> memo,
  ) {
    final cached = memo[container];
    if (cached != null) return cached;
    // Cycles are rejected on insert and repaired on import, but a guard here
    // keeps a malformed in-memory tree from recursing forever.
    if (!visiting.add(container)) return Aabb2.empty();

    var box = Aabb2.empty();

    for (final slot in entities.liveSlots) {
      if (entities.ownerAt(slot) != container) continue;
      final record = entities.read(slot);
      box = box.union(entityBounds(
        kind: record.kind,
        payload: geometry.read(record.geomIndex),
        measurer: textMeasurer,
        textStyle: ReservedHandles.standardTextStyle,
      ));
    }

    for (final child in _childrenOf(container)) {
      final node = tree[child];
      switch (node) {
        case GroupNode(:final transform):
          box = box.union(_boundsOfContainer(child, visiting, memo)
              .transformedBy(transform));
        case InstanceNode(:final definition, :final transform):
          box = box.union(_boundsOfContainer(definition, visiting, memo)
              .transformedBy(transform));
        case null:
          // A `children` list may name a leaf entity as well as a node — a
          // definition's children routinely do — and those are accounted for
          // by the entity scan above, not here.
          break;
      }
    }

    visiting.remove(container);
    memo[container] = box;
    return box;
  }

  /// What [container] holds, in the order it holds it.
  ///
  /// Reads the container's own `children` list. `DocumentTree` maintains that
  /// list on every add, replace and remove, so it is current for a live,
  /// mutated document and not only for one built by hand. It is also the same
  /// list the cycle-detection walks read, so extents and the cycle guard now
  /// agree on what containment means — and it is ordered, which a scan over
  /// every node keyed on `parent` was not.
  ///
  /// A group and a definition are both containers here, because a node's
  /// `parent` may name either; the root is just the outermost group.
  List<Handle> _childrenOf(Handle container) => switch (tree[container]) {
        GroupNode(:final children) => children,
        _ => tree.definition(container)?.children ?? const [],
      };
}

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
  TextMeasurer textMeasurer;

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
          // Unreachable in practice: every handle _childrenOf yields comes
          // from tree.nodes, so tree[child] is never null. Kept rather than
          // asserted, so a future _childrenOf that once again mixes in
          // entity handles fails safe instead of throwing here.
          break;
      }
    }

    visiting.remove(container);
    memo[container] = box;
    return box;
  }

  /// Nodes placed directly inside [container].
  ///
  /// Found by each node's own `parent` pointer, not by a container's
  /// `children`/`Definition.children` list. [AddNodeCommand] (see
  /// `commands.dart`) only inserts into the tree's node map and sets the new
  /// node's `parent` — it never appends to the parent's `children` list, so
  /// that list stays exactly as constructed and drifts from reality on every
  /// command-driven insert. `DocumentTree` itself documents `parent` and
  /// `children` as dual, independently-writable representations of the same
  /// edge; the `children` list is what the *cycle-detection* walks read, but
  /// `parent` is what this engine's commands actually maintain, so it is the
  /// only source that is current for a live, mutated document. This works
  /// uniformly for the root, a group, or a definition, because a node's
  /// `parent` may point at any of the three.
  List<Handle> _childrenOf(Handle container) => [
        for (final node in tree.nodes)
          if (node.parent == container) node.handle,
      ];
}

import '../core/handle.dart';
import '../document/doc_change.dart';
import '../document/draft_document.dart';
import 'container_index.dart';

/// Every [ContainerIndex] in a document, kept current against its changes.
///
/// One index per indexed container: the tree root, plus every definition —
/// including definitions with no instances, since one may be placed at any
/// moment and building on demand would put an unbounded build inside a query.
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

  ContainerIndex? indexFor(Handle container) => _byContainer[container];

  ContainerIndex get rootIndex => _byContainer[document.rootHandle]!;

  int get containerCount => _byContainer.length;

  /// Discards every index and rebuilds from scratch.
  ///
  /// One [ContainerIndex.leavesByOwner] pass is shared across every container,
  /// which is what keeps a whole-document build linear in entities rather than
  /// O(containers x entities).
  void rebuildAll() {
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer
      ..clear()
      ..[document.rootHandle] =
          ContainerIndex.build(document, document.rootHandle, byOwner);
    for (final definition in document.tree.definitions) {
      _byContainer[definition.handle] =
          ContainerIndex.build(document, definition.handle, byOwner);
    }
  }

  /// Rebuilds one container, leaving the rest alone.
  void rebuildContainer(Handle container) {
    final byOwner = ContainerIndex.leavesByOwner(document);
    _byContainer[container] =
        ContainerIndex.build(document, container, byOwner);
  }

  void _onChange(DocChange change) {
    // Task 7 replaces this with re-derive-and-compare. Until then the
    // conservative answer is correct but slow, and it is deliberately not the
    // shipped behaviour of this plan.
    switch (change) {
      case DocumentLoaded():
      case DocumentPurged():
        rebuildAll();
      default:
        break;
    }
  }

  void dispose() {
    // Only detach the hook if it is still ours: a second index over the same
    // document would otherwise be silently unhooked by the first one's
    // disposal.
    if (identical(document.commands.onAfterMutate, _onChange)) {
      document.commands.onAfterMutate = null;
    }
    _byContainer.clear();
  }
}

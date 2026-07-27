import '../core/diagnostic.dart';
import '../core/handle.dart';
import 'draft_document.dart';
import 'node.dart';

/// The codes [DocumentValidation.validate] can emit.
///
/// Constants rather than literals so a caller or a test matches a symbol the
/// compiler checks, instead of a string it does not.
abstract final class ValidationCodes {
  static const String rootMissing = 'tree.root_missing';
  static const String parentChildMismatch = 'tree.parent_child_mismatch';
  static const String danglingChild = 'tree.dangling_child';
  static const String leafInChildren = 'tree.leaf_in_children';
  static const String cycle = 'tree.cycle';
  static const String definitionCycle = 'tree.definition_cycle';
  static const String ownerMissing = 'entity.owner_missing';
}

extension DocumentValidation on DraftDocument {
  /// Structural problems in this document, in a stable order.
  ///
  /// Empty means well-formed. This reports and never mutates; the caller
  /// decides whether to reject, repair or warn. It is not redundant with
  /// [DocumentTree.repairCycles]: that method *mutates* — it drops the
  /// back-edge instance that closes a definition cycle, and the codec calls
  /// it on load — while this one only reports and never changes the tree.
  ///
  /// The index walks the container tree, so it is the first consumer a
  /// malformed document would corrupt — or, for [ValidationCodes.cycle],
  /// hang. Callers that index untrusted input should check this first.
  List<Diagnostic> validate() {
    final out = <Diagnostic>[];

    Diagnostic error(String code, String message, List<Handle> handles) =>
        Diagnostic(
          severity: DiagnosticSeverity.error,
          code: code,
          message: message,
          handles: handles,
        );

    // 1. The root must resolve.
    if (tree[tree.root] == null) {
      out.add(error(ValidationCodes.rootMissing,
          'The tree root ${tree.root.value} names no node.', [tree.root]));
    }

    // Containers are nodes plus definitions; an entity's owner may be either,
    // and the root is just the outermost group.
    bool isContainer(Handle h) => tree[h] != null || tree.definition(h) != null;

    // 2. Entity owners must resolve. Ascending slot order gives a stable
    //    result, and slots are ascending by construction in liveSlots.
    for (final slot in entities.liveSlots) {
      final owner = entities.ownerAt(slot);
      if (!isContainer(owner)) {
        out.add(error(
            ValidationCodes.ownerMissing,
            'Entity ${entities.handleAt(slot).value} names owner '
            '${owner.value}, which is not a container.',
            [entities.handleAt(slot), owner]));
      }
    }

    // Every `children` list in the document, keyed by its container.
    // `tree.nodes` and `tree.definitions` are both ascending by handle, so
    // this walk is stable without sorting.
    final childrenOf = <Handle, List<Handle>>{};
    for (final node in tree.nodes) {
      if (node is GroupNode) childrenOf[node.handle] = node.children;
    }
    for (final definition in tree.definitions) {
      childrenOf[definition.handle] = definition.children;
    }

    // 3. Children entries must resolve, and must name nodes rather than leaves.
    // 4. A node's `parent` must agree with the container that lists it.
    final listedBy = <Handle, Handle>{};
    for (final entry in childrenOf.entries) {
      for (final child in entry.value) {
        if (tree[child] != null) {
          listedBy[child] = entry.key;
          continue;
        }
        if (entities.containsHandle(child)) {
          out.add(error(
              ValidationCodes.leafInChildren,
              'Container ${entry.key.value} lists entity ${child.value} as a '
              'child node. Leaf containment is EntityRecord.owner.',
              [entry.key, child]));
        } else {
          out.add(error(
              ValidationCodes.danglingChild,
              'Container ${entry.key.value} lists ${child.value}, which '
              'resolves to nothing.',
              [entry.key, child]));
        }
      }
    }

    for (final node in tree.nodes) {
      if (node.handle == tree.root) continue;
      final listed = listedBy[node.handle];
      if (listed != node.parent) {
        out.add(error(
            ValidationCodes.parentChildMismatch,
            'Node ${node.handle.value} names parent ${node.parent.value} but '
            'is listed by ${listed?.value}.',
            [node.handle, node.parent]));
      }
    }

    // 5. Group cycles. White/grey/black DFS: a grey node reached again is a
    //    back edge. This must not use `ancestorsOf`, which throws rather than
    //    reporting, and must not recurse — a cycle would blow the stack.
    const white = 0, grey = 1, black = 2;
    final colour = <Handle, int>{};
    for (final start in childrenOf.keys) {
      if ((colour[start] ?? white) != white) continue;
      // Explicit stack of (container, next child index).
      final stack = <Handle>[start];
      final cursor = <int>[0];
      colour[start] = grey;
      while (stack.isNotEmpty) {
        final top = stack.last;
        final children = childrenOf[top] ?? const <Handle>[];
        if (cursor.last >= children.length) {
          colour[top] = black;
          stack.removeLast();
          cursor.removeLast();
          continue;
        }
        final child = children[cursor.last];
        cursor[cursor.length - 1] = cursor.last + 1;
        switch (colour[child] ?? white) {
          case grey:
            out.add(error(
                ValidationCodes.cycle,
                'Container ${top.value} reaches ${child.value}, which is '
                'already on the path: the container tree has a cycle.',
                [top, child]));
          case white:
            if (childrenOf.containsKey(child)) {
              colour[child] = grey;
              stack.add(child);
              cursor.add(0);
            } else {
              colour[child] = black;
            }
          default:
            break;
        }
      }
    }

    // 6. Definition cycles: an instance inside definition D that reaches D.
    // `reported` tracks definitions already flagged so a cyclic definition
    // graph cannot make `tree.definitionReaches` loop forever here: once a
    // definition has been reported, every other instance reaching the same
    // cycle is skipped rather than re-walked.
    final reportedDefinitions = <Handle>{};
    for (final definition in tree.definitions) {
      if (reportedDefinitions.contains(definition.handle)) continue;
      for (final child in definition.children) {
        final node = tree[child];
        if (node is! InstanceNode) continue;
        if (reportedDefinitions.contains(node.definition)) continue;
        if (node.definition == definition.handle ||
            tree.definitionReaches(node.definition, definition.handle)) {
          reportedDefinitions.add(definition.handle);
          out.add(error(
              ValidationCodes.definitionCycle,
              'Definition ${definition.handle.value} contains instance '
              '${child.value} of ${node.definition.value}, which reaches it.',
              [definition.handle, child, node.definition]));
          break;
        }
      }
    }

    return out;
  }
}

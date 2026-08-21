import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../store/entity_store.dart';
import 'commands.dart';
import 'draft_document.dart';
import 'node.dart';
import 'tree.dart';

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
  static const String fillBoundaryMissing = 'fill.boundary_missing';
  static const String fillBoundaryNotFillable = 'fill.boundary_not_fillable';
  static const String fillBoundaryNotClosed = 'fill.boundary_not_closed';
  static const String fillBoundaryForeignOwner = 'fill.boundary_foreign_owner';
  static const String fillDrawOrderInverted = 'fill.draw_order_inverted';
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
        } else if (tree.definition(child) != null) {
          // Resolves to something — a definition — just not to a node. A
          // definition cannot be placed directly; only an InstanceNode that
          // references it can be. Still `danglingChild`: the fault is the
          // same shape ("this children entry cannot be drawn as listed"),
          // and the seven codes are fixed, but the message must not claim
          // the handle resolves to nothing when it resolves to a definition.
          out.add(error(
              ValidationCodes.danglingChild,
              'Container ${entry.key.value} lists ${child.value}, which is '
              'a definition, not a node. A definition cannot be placed '
              'directly; only an InstanceNode referencing it can be.',
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
            [node.handle, node.parent, if (listed != null) listed]));
      }
    }

    // 5. Group cycles. White/grey/black DFS: a grey node reached again is a
    //    back edge. This must not use `ancestorsOf`, which throws rather than
    //    reporting, and must not recurse — a cycle would blow the stack.
    //
    //    This walks `children` only, deliberately: `parent` is not walked
    //    here, so a cycle that exists purely as a `parent`-pointer loop with
    //    no matching `children` entries is not found by this DFS. It does
    //    not go unreported — a `parent` chain that no `children` list agrees
    //    with is exactly what the parentChildMismatch loop above already
    //    catches, for every node on such a loop. Do not "fix" this into
    //    walking `parent` as well: `ancestorsOf`, which does walk `parent`,
    //    is the thing this method exists to avoid, precisely because it
    //    throws on a loop instead of reporting one.
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
    //
    // No "already reported" skip-set here: `tree.definitionReaches` carries
    // its own `visited` set (see tree.dart) and provably terminates on any
    // definition graph, cyclic or not, so nothing here needs to bound it.
    // Skipping a definition once one cycle involving it is found would also
    // be wrong, not just unnecessary: the same definition can sit on two
    // distinct cycles through two different instances — the common shape
    // for a repeatedly-instanced block — and a caller repairing only the
    // first-found edge deserves to see the second one immediately rather
    // than on a second pass.
    for (final definition in tree.definitions) {
      for (final child in definition.children) {
        final node = tree[child];
        if (node is! InstanceNode) continue;
        var reachesOwner = node.definition == definition.handle;
        if (!reachesOwner) {
          try {
            reachesOwner =
                tree.definitionReaches(node.definition, definition.handle);
          } on NodeCycleError {
            // definitionReaches walks group `children` while looking for an
            // instance of the target definition, and is documented to throw
            // NodeCycleError — not report — when that walk re-enters a
            // group already open on it. Step 5 above has already reported
            // that same group cycle as `tree.cycle`; without this catch the
            // exception would propagate out of validate() and discard every
            // diagnostic already collected in `out`, which is exactly the
            // "throws instead of reports" failure this method exists to
            // avoid. Do not change definitionReaches — other code depends
            // on it throwing here.
            continue;
          }
        }
        if (reachesOwner) {
          out.add(error(
              ValidationCodes.definitionCycle,
              'Definition ${definition.handle.value} contains instance '
              '${child.value} of ${node.definition.value}, which reaches it.',
              [definition.handle, child, node.definition]));
        }
      }
    }

    // 7. Fills. Every check reports; none repairs.
    for (final slot in entities.liveSlots) {
      if (entities.kindAt(slot) != EntityKind.fill) continue;
      final fill = entities.handleAt(slot);
      final boundary =
          boundaryHandleOf(geometry.peek(entities.geomIndexAt(slot)));
      final boundarySlot = entities.slotOf(boundary);
      if (boundarySlot == null) {
        out.add(error(
            ValidationCodes.fillBoundaryMissing,
            'fill ${fill.toHex()} names ${boundary.toHex()}, which is not in '
            'this document',
            [fill, boundary]));
        continue;
      }
      final kind = entities.kindAt(boundarySlot);
      if (kind != EntityKind.polyline && kind != EntityKind.circle) {
        out.add(error(
            ValidationCodes.fillBoundaryNotFillable,
            'fill ${fill.toHex()} names a ${kind.name}, which has no interior',
            [fill, boundary]));
      } else if (kind == EntityKind.polyline &&
          triangulationFor(
                  kind, geometry.peek(entities.geomIndexAt(boundarySlot))) ==
              null) {
        out.add(error(
            ValidationCodes.fillBoundaryNotClosed,
            'fill ${fill.toHex()} names an open polyline; closedness is the '
            'stored first point repeated as the last, compared exactly',
            [fill, boundary]));
      }
      if (entities.ownerAt(slot) != entities.ownerAt(boundarySlot)) {
        out.add(error(
            ValidationCodes.fillBoundaryForeignOwner,
            'fill ${fill.toHex()} and its boundary are in different owners, so '
            'the reference cannot resolve under an instance',
            [fill, boundary]));
      }
      if (fill.value > boundary.value) {
        out.add(error(
            ValidationCodes.fillDrawOrderInverted,
            'fill ${fill.toHex()} has a higher handle than its boundary '
            '${boundary.toHex()}, so it draws over its own outline',
            [fill, boundary]));
      }
    }

    return out;
  }
}

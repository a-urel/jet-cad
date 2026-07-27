import '../core/diagnostic.dart';
import '../core/handle.dart';
import '../geometry/transform2.dart';
import 'node.dart';

class CycleDetectedError implements Exception {
  final Handle ownerDefinition;
  final Handle referencedDefinition;

  const CycleDetectedError(this.ownerDefinition, this.referencedDefinition);

  @override
  String toString() =>
      'CycleDetectedError: definition ${ownerDefinition.toHex()} cannot '
      'contain an instance of ${referencedDefinition.toHex()}';
}

/// A containment loop in the *node* graph: a chain of `parent` pointers or of
/// [GroupNode.children] that returns to a node already on the walk.
///
/// A separate type from [CycleDetectedError] rather than a case of it, because
/// the two are different faults with different remedies. A definition cycle is
/// a legitimate user action that the tree refuses — the command is rejected,
/// the document stays valid, and [DocumentTree.repairCycles] can recover a file
/// that contains one. A containment cycle means the node graph itself is
/// inconsistent: no transform can be composed and no subtree can be walked
/// until it is repaired. It also carries different data — one handle, the point
/// where the loop closed, not an owner/referenced pair.
///
/// It is thrown rather than worked around because every alternative is worse. A
/// truncated ancestor chain yields a plausible-looking but wrong
/// [DocumentTree.accumulatedTransform], so geometry lands in the wrong place
/// with no indication anything failed; running the loop to exhaustion hangs and
/// grows without bound.
class NodeCycleError implements Exception {
  /// The node at which the walk re-entered its own path.
  final Handle handle;

  const NodeCycleError(this.handle);

  @override
  String toString() =>
      'NodeCycleError: the node graph loops back on ${handle.toHex()}';
}

/// An instance reference that closes a definition cycle: the offending node,
/// the definition it is placed inside, and the container whose `children` list
/// named it. A named typedef because the record is threaded through four
/// mutually recursive helpers and spelling it out at each one buries the code.
typedef _BackEdge = ({InstanceNode instance, Handle owner, Handle container});

/// The scene tree: container nodes plus the definitions they instance.
///
/// Leaf entities are not here — they live in the entity store and reference
/// their owner by handle.
class DocumentTree {
  final Map<Handle, Node> _nodes = {};
  final Map<Handle, Definition> _definitions = {};
  final Handle _root;

  DocumentTree({required GroupNode rootNode}) : _root = rootNode.handle {
    _nodes[rootNode.handle] = rootNode;
  }

  Handle get root => _root;

  Node? operator [](Handle handle) => _nodes[handle];

  Definition? definition(Handle handle) => _definitions[handle];

  /// Ascending handle order — serialization walks this, and byte-identical
  /// output cannot depend on hash order.
  Iterable<Node> get nodes {
    final handles = _nodes.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _nodes[h]!];
  }

  Iterable<Definition> get definitions {
    final handles = _definitions.keys.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return [for (final h in handles) _definitions[h]!];
  }

  /// Adds a node, rejecting anything that would close a definition cycle
  /// *through this node's own instance edge*. Nothing is mutated when it
  /// throws.
  ///
  /// What is guaranteed: an [InstanceNode] added or replaced here can never
  /// make its enclosing definition reach itself. Placing the check on the tree
  /// rather than in each command means no command that creates an instance can
  /// close that kind of cycle by forgetting to ask.
  ///
  /// What is **not** guaranteed, and must not be read into the above:
  ///
  /// - **Containment edges written through the definition API.** [addDefinition]
  ///   and [replaceDefinition] are unguarded, so
  ///   `replaceDefinition(def.copyWith(children: [...]))` can list an instance
  ///   that closes a cycle and no exception is raised.
  /// - **Containment edges written through [GroupNode.children].** The guard
  ///   reads `parent` pointers while the reachability walks read `children`
  ///   lists. Those are dual representations of one edge and only the `parent`
  ///   side is checked here, so a node whose two sides disagree — or a group
  ///   re-parented under its own descendant — passes the guard. The walks now
  ///   throw [NodeCycleError] on such a graph instead of hanging, but that is
  ///   detection at use, not prevention at write.
  /// - **[addNodeUnchecked]**, by construction.
  ///
  /// Two layers own the rest. Structural validation on import must verify that
  /// `parent` and `children` agree and that neither relation loops, since a
  /// file can assert anything. And whichever command later introduces
  /// re-parenting or grouping must run its own check before rewriting a
  /// `children` list or a `parent` pointer — this method cannot do it for them,
  /// because it never sees that edit.
  void addNode(Node node) {
    _guardCycle(node);
    _nodes[node.handle] = node;
  }

  /// Adds without the cycle check. Only an importer should use this, and only
  /// when it intends to call [repairCycles] afterwards — a file may legitimately
  /// contain a cycle that has to be diagnosed rather than rejected mid-parse.
  void addNodeUnchecked(Node node) => _nodes[node.handle] = node;

  void replaceNode(Node node) {
    _guardCycle(node);
    _nodes[node.handle] = node;
  }

  void removeNode(Handle handle) => _nodes.remove(handle);

  void addDefinition(Definition definition) =>
      _definitions[definition.handle] = definition;

  void replaceDefinition(Definition definition) =>
      _definitions[definition.handle] = definition;

  void removeDefinition(Handle handle) => _definitions.remove(handle);

  /// Ancestors of [handle], nearest first, excluding the node itself. Stops at
  /// the root or at a definition.
  ///
  /// Throws [NodeCycleError] if the `parent` chain loops.
  List<Handle> ancestorsOf(Handle handle) {
    final chain = <Handle>[];
    // A visited set rather than a step budget of [_nodes.length]. Both
    // terminate, but the set names the exact handle at which the chain closed
    // on itself, which is the one fact a caller needs to repair it; a budget
    // reports whichever node the counter happened to expire on, which need not
    // even be part of the loop. It is also free asymptotically here — the chain
    // list is already O(depth) — and it catches a self-parent, which is why
    // [handle] itself seeds the set.
    final seen = <Handle>{handle};
    var current = _nodes[handle]?.parent ?? Handle.none;
    while (!current.isNone && _nodes.containsKey(current)) {
      if (!seen.add(current)) throw NodeCycleError(current);
      chain.add(current);
      current = _nodes[current]!.parent;
    }
    return chain;
  }

  /// The transform from the enclosing space down to [handle], composed in
  /// `Float64`.
  ///
  /// The enclosing space is the root for a placed node, or the definition for a
  /// node inside a prototype — "world" would be the wrong word, since a
  /// prototype has no world position. The walk stops at a definition handle
  /// because a definition carries no transform of its own.
  Transform2 accumulatedTransform(Handle handle) {
    final node = _nodes[handle];
    if (node == null) return Transform2.identity();
    final chain = <Transform2>[node.transform];
    for (final ancestor in ancestorsOf(handle)) {
      chain.add(_nodes[ancestor]!.transform);
    }
    var composed = Transform2.identity();
    // Outermost first, so the node's own transform is applied last.
    for (final t in chain.reversed) {
      composed = composed.multiply(t);
    }
    return composed;
  }

  /// Whether the subtree of definition [from] contains, at any depth, an
  /// instance of [target].
  ///
  /// Throws [NodeCycleError] if a group's `children` loop back on themselves.
  bool definitionReaches(Handle from, Handle target) {
    final visited = <Handle>{};
    // Group handles currently open on the walk. A "seen ever" set would be
    // wrong: the same handle listed under two groups is a duplicated reference,
    // not a loop, and only a re-entry into a group still on the path is a
    // genuine containment cycle.
    final onNodePath = <Handle>{};

    // Declared before [walkDefinition] because Dart forbids referencing a
    // local function before its declaration; the mutual recursion is closed by
    // passing the definition-walker in as [into] rather than by name.
    bool walkNode(Handle nodeHandle, bool Function(Handle) into) {
      final node = _nodes[nodeHandle];
      switch (node) {
        case InstanceNode(:final definition):
          if (definition == target) return true;
          return into(definition);
        case GroupNode(:final children):
          if (!onNodePath.add(nodeHandle)) throw NodeCycleError(nodeHandle);
          try {
            for (final child in children) {
              if (walkNode(child, into)) return true;
            }
            return false;
          } finally {
            onNodePath.remove(nodeHandle);
          }
        case null:
          return false; // an entity handle, not a node
      }
    }

    // [visited] makes an already-expanded definition terminate immediately.
    // Without it a legitimately shared — and acyclic — definition graph would
    // be re-walked exponentially, and a cyclic one would not terminate at all.
    bool walkDefinition(Handle definitionHandle) {
      if (!visited.add(definitionHandle)) return false;
      final def = _definitions[definitionHandle];
      if (def == null) return false;
      for (final child in def.children) {
        if (walkNode(child, walkDefinition)) return true;
      }
      return false;
    }

    return walkDefinition(from);
  }

  bool wouldCreateCycle({
    required Handle ownerDefinition,
    required Handle referencedDefinition,
  }) =>
      ownerDefinition == referencedDefinition ||
      definitionReaches(referencedDefinition, ownerDefinition);

  /// Breaks every definition cycle by dropping the instance that closes it.
  ///
  /// Import calls this: a malformed file must not fail wholesale over one bad
  /// reference. Each drop is reported.
  ///
  /// What gets dropped is the *back edge* — the reference that points at a
  /// definition already open on the walk — and not the first reference met on
  /// the way in. Both would break the cycle, but only dropping the back edge
  /// leaves the forward structure the file described intact.
  ///
  /// This repairs *definition* cycles only. A containment cycle in the node
  /// graph throws [NodeCycleError] out of here rather than being repaired:
  /// breaking it means choosing which `children` entry or `parent` pointer the
  /// file got wrong, which is structural validation's decision and not this
  /// method's. A diagnosable throw is still strictly better than the unbounded
  /// recursion the same input used to produce.
  List<Diagnostic> repairCycles() {
    final diagnostics = <Diagnostic>[];
    // Each pass drops exactly one instance and then rescans from scratch, so
    // the scan never walks a collection it is mutating. Every pass removes a
    // node, so the loop is bounded by the node count and converges; on a tree
    // with no cycle the first scan finds nothing and the result is empty.
    for (var edge = _findBackEdge(); edge != null; edge = _findBackEdge()) {
      final (:instance, :owner, :container) = edge;
      _dropInstance(instance, container);
      diagnostics.add(Diagnostic(
        severity: DiagnosticSeverity.warning,
        code: 'tree.cycle_dropped',
        message: 'Dropped instance ${instance.handle.toHex()}: definition '
            '${owner.toHex()} cannot contain '
            '${instance.definition.toHex()}.',
        handles: [instance.handle, owner, instance.definition],
      ));
    }
    return diagnostics;
  }

  void clear() {
    _nodes.clear();
    _definitions.clear();
  }

  /// The first instance reference that points back at a definition already open
  /// on the walk, together with the definition that owns that instance and the
  /// container the walk actually found it in, or `null` when no definition
  /// cycle exists.
  ///
  /// A depth-first walk over every definition, colouring each one white (never
  /// seen), grey ([onPath]) or black ([expanded]). An edge into a grey
  /// definition is a back edge, and a directed graph has a cycle exactly when a
  /// depth-first walk from every vertex finds one.
  _BackEdge? _findBackEdge() {
    final expanded = <Handle>{};
    final onPath = <Handle>{};
    // Group handles open on the current walk; see [_scanNode].
    final onNodePath = <Handle>{};
    for (final def in definitions) {
      final found = _scanDefinition(def.handle, expanded, onPath, onNodePath);
      if (found != null) return found;
    }
    return null;
  }

  _BackEdge? _scanDefinition(
    Handle definitionHandle,
    Set<Handle> expanded,
    Set<Handle> onPath,
    Set<Handle> onNodePath,
  ) {
    // Already black: it was walked to completion earlier and produced no back
    // edge, so re-walking it cannot produce one now.
    if (!expanded.add(definitionHandle)) return null;
    final def = _definitions[definitionHandle];
    if (def == null) return null;
    onPath.add(definitionHandle);
    _BackEdge? found;
    for (final child in def.children) {
      // The definition is the immediate container of its own children.
      found = _scanNode(child, definitionHandle, definitionHandle, expanded,
          onPath, onNodePath);
      if (found != null) break;
    }
    onPath.remove(definitionHandle);
    return found;
  }

  /// [owner] is the definition whose subtree is being walked; it stays the same
  /// through nested groups, since a group is not an enclosing space of its own.
  /// [container] is the definition or group whose `children` list named
  /// [nodeHandle], and it does change on the way down — it is what a repair has
  /// to clean, and it is not always what the node's own `parent` says it is.
  ///
  /// Throws [NodeCycleError] when a group's `children` re-enter a group already
  /// open on this walk.
  _BackEdge? _scanNode(
    Handle nodeHandle,
    Handle container,
    Handle owner,
    Set<Handle> expanded,
    Set<Handle> onPath,
    Set<Handle> onNodePath,
  ) {
    final node = _nodes[nodeHandle];
    switch (node) {
      case InstanceNode():
        if (onPath.contains(node.definition)) {
          return (instance: node, owner: owner, container: container);
        }
        return _scanDefinition(node.definition, expanded, onPath, onNodePath);
      case GroupNode(:final children):
        if (!onNodePath.add(nodeHandle)) throw NodeCycleError(nodeHandle);
        try {
          for (final child in children) {
            // This group, not [container], holds the children below it.
            final found = _scanNode(
                child, nodeHandle, owner, expanded, onPath, onNodePath);
            if (found != null) return found;
          }
          return null;
        } finally {
          onNodePath.remove(nodeHandle);
        }
      case null:
        return null; // an entity handle, not a node
    }
  }

  /// The definition enclosing [start] — [start] itself when it is a definition
  /// handle — or [Handle.none] when the chain reaches the root instead.
  ///
  /// Throws [NodeCycleError] if the `parent` chain loops, for the same reason
  /// [ancestorsOf] does: a truncated answer here would silently skip the cycle
  /// guard in [_guardCycle] rather than fail.
  Handle _enclosingDefinitionAbove(Handle start) {
    // Visited set over step budget, for the reasons given in [ancestorsOf].
    final seen = <Handle>{};
    var current = start;
    while (!current.isNone) {
      if (_definitions.containsKey(current)) return current;
      if (!seen.add(current)) throw NodeCycleError(current);
      final parent = _nodes[current];
      if (parent == null) return Handle.none;
      current = parent.parent;
    }
    return Handle.none;
  }

  void _guardCycle(Node node) {
    if (node is! InstanceNode) return;
    // Walk up from the node's declared parent rather than from the node's own
    // handle: on [addNode] the node is not in the tree yet, so a lookup keyed
    // on its handle would find nothing and silently skip the check.
    final owner = _enclosingDefinitionAbove(node.parent);
    if (owner.isNone) return; // placed under the root: never a cycle
    if (owner == node.definition || definitionReaches(node.definition, owner)) {
      throw CycleDetectedError(owner, node.definition);
    }
  }

  /// Removes [node] and unlists it from [container].
  ///
  /// [container] is the container the scan actually walked through, not the one
  /// `node.parent` names. In a well-formed tree they are the same handle; in
  /// the malformed file this method exists to repair they need not be, and
  /// cleaning the `parent` side would leave the dropped handle listed in the
  /// `children` list that really referenced it — a dangling reference that
  /// serialization would then emit.
  void _dropInstance(InstanceNode node, Handle container) {
    _nodes.remove(node.handle);
    final group = _nodes[container];
    if (group is GroupNode) {
      _nodes[group.handle] = group.copyWith(
        children: _withoutAll(group.children, node.handle),
      );
      return;
    }
    final definition = _definitions[container];
    if (definition != null) {
      _definitions[definition.handle] = definition.copyWith(
        children: _withoutAll(definition.children, node.handle),
      );
    }
  }

  /// Every occurrence of [handle] removed, not just the first. A malformed file
  /// can list the same child twice, and `[...children]..remove(handle)` would
  /// leave the duplicate behind pointing at a node that no longer exists.
  static List<Handle> _withoutAll(List<Handle> children, Handle handle) => [
        for (final child in children)
          if (child != handle) child
      ];
}

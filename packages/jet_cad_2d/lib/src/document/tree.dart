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
  /// *through this node's own instance edge*, and listing it in its parent's
  /// `children`. Nothing is mutated when it throws.
  ///
  /// What is guaranteed: an [InstanceNode] added or replaced here can never
  /// make its enclosing definition reach itself. Placing the check on the tree
  /// rather than in each command means no command that creates an instance can
  /// close that kind of cycle by forgetting to ask. The guard is only able to
  /// see anything because of the `children` maintenance described on [_link]:
  /// the guard reads `parent` pointers, but the reachability walk it calls
  /// reads `children`, so a writer that maintained only `parent` would hand the
  /// walk an empty graph and every cycle would be accepted.
  ///
  /// What is **not** guaranteed, and must not be read into the above:
  ///
  /// - **Containment edges written through the definition API.** [addDefinition]
  ///   and [replaceDefinition] are unguarded, so
  ///   `replaceDefinition(def.copyWith(children: [...]))` can list an instance
  ///   that closes a cycle and no exception is raised. They do preserve a link
  ///   [addNode] already made — see [_relinkDefinition] — but that recovery
  ///   only appends what the incoming `children` omitted; it does not check,
  ///   remove, or reject an entry the incoming list already names.
  /// - **Containment edges written by rewriting [GroupNode.children] directly**
  ///   through [replaceNode]. This method syncs the `children` side from the
  ///   `parent` side, never the reverse, so a caller that hands over a group
  ///   whose `children` it rewrote by hand — or that re-parents a group under
  ///   its own descendant — still passes the guard. The walks throw
  ///   [NodeCycleError] on such a graph instead of hanging, but that is
  ///   detection at use, not prevention at write.
  /// - **[addNodeUnchecked]**, by construction.
  ///
  /// Two layers own the rest. Structural validation on import must verify that
  /// `parent` and `children` agree and that neither relation loops, since a
  /// file can assert anything. And whichever command later introduces
  /// re-parenting or grouping must run its own check before rewriting a
  /// `children` list or a `parent` pointer — this method cannot do it for them,
  /// because it never sees that edit.
  ///
  /// Also unlinks from the *previous* parent when [node] overwrites a handle
  /// already in the tree under a different one — the same treatment
  /// [replaceNode] documents, and for the same reason: without it, the old
  /// container keeps its entry and the handle ends up listed under two
  /// containers at once, which [DraftDocument._boundsOfContainer] then
  /// double-counts and serialization emits as a dangling child. The previous
  /// parent must be read before the overwrite — it is the only record of
  /// which container currently lists this handle.
  void addNode(Node node) {
    _guardCycle(node);
    final previousParent = _nodes[node.handle]?.parent;
    _nodes[node.handle] = node;
    if (previousParent != null && previousParent != node.parent) {
      _unlink(node.handle, previousParent);
    }
    _link(node.handle, node.parent);
  }

  /// Adds without the cycle check. Only an importer should use this, and only
  /// when it intends to call [repairCycles] afterwards — a file may legitimately
  /// contain a cycle that has to be diagnosed rather than rejected mid-parse.
  ///
  /// It deliberately does **not** [_link] either — the one node-adding entry
  /// point where that step is intentionally skipped. An importer rebuilds both
  /// sides from the file verbatim, and a file whose two sides disagree is
  /// exactly what [repairCycles] and structural validation exist to see;
  /// synthesising the missing `children` entry here would erase that evidence
  /// before either could read it. It would also actively corrupt the repair:
  /// [_dropInstance] unlists from the container the *scan walked*, so a
  /// fabricated entry under the container `parent` merely claimed would survive
  /// the drop as a dangling reference that serialization would then emit.
  ///
  /// This is not the only way the two sides can end up disagreeing — see the
  /// "what is **not** guaranteed" list on [addNode] for the others, which are
  /// about a container's own `children` being installed or rewritten with
  /// entries that do not match any node's `parent`, rather than about a
  /// missing link. The invariant [addNode], [replaceNode], [removeNode],
  /// [addDefinition] and [replaceDefinition] maintain is narrower than "the
  /// two sides always agree": it is "a link one of them established is never
  /// silently dropped by another". [addNodeUnchecked] is the only entry point
  /// that does not even try.
  void addNodeUnchecked(Node node) => _nodes[node.handle] = node;

  /// Replaces a node, re-listing it under a new parent when `parent` changed.
  ///
  /// Reads the outgoing node's `parent` before overwriting it: that is the only
  /// record of which container currently lists this handle, and unlinking after
  /// the overwrite would unlink from the new parent and leave the old one
  /// naming a node it no longer holds.
  void replaceNode(Node node) {
    _guardCycle(node);
    final previousParent = _nodes[node.handle]?.parent;
    _nodes[node.handle] = node;
    if (previousParent != null && previousParent != node.parent) {
      _unlink(node.handle, previousParent);
    }
    _link(node.handle, node.parent);
  }

  void removeNode(Handle handle) {
    final node = _nodes.remove(handle);
    if (node != null) _unlink(handle, node.parent);
  }

  /// Installs [definition], then re-establishes any link [addNode] or
  /// [replaceNode] already made that the incoming `children` omitted.
  ///
  /// Without the second step this would clobber the invariant [_link] exists
  /// to maintain: `_definitions[handle] = definition` is a wholesale
  /// overwrite, so a caller handing over a `Definition` whose `children`
  /// predates an already-linked node — built by hand, or read from a codec
  /// that constructs the record before its children arrive — would silently
  /// erase every link `addNode` made, restoring the empty-`children` state
  /// that let a command-built cycle through before `fb32258`. See
  /// [_relinkDefinition] for what "re-establish" does and does not mean.
  void addDefinition(Definition definition) {
    _definitions[definition.handle] = definition;
    _relinkDefinition(definition.handle);
  }

  /// See [addDefinition]: the same wholesale-overwrite hazard applies to a
  /// replacement, and the same recovery step follows it.
  void replaceDefinition(Definition definition) {
    _definitions[definition.handle] = definition;
    _relinkDefinition(definition.handle);
  }

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

  /// Lists [handle] among [parent]'s children, if it is not listed already.
  ///
  /// **The append must be conditional, not unconditional.** `children` is
  /// written twice by design: the file names it, and every insert here derives
  /// it from `parent`. The importer and the codec construct a container with
  /// its `children` already populated and *then* add the child nodes, so an
  /// unconditional append would give every loaded document a duplicate entry
  /// per child — each one drawn twice, walked twice by the reachability
  /// scans, and emitted twice on the next save. Being idempotent is what lets
  /// the two writers coexist without either having to know about the other.
  ///
  /// For the same reason a handle already listed keeps its position rather than
  /// being moved to the end: for a [GroupNode], `children` order *is* draw
  /// order, and it is the file's order that is authoritative, not the order the
  /// loader happened to visit the nodes in.
  ///
  /// A [parent] that is neither a container node nor a definition is a no-op.
  /// That covers [Handle.none] at the root, and it covers a node added before
  /// its own parent — an importer or a paste may legitimately emit children
  /// first. This method cannot distinguish "not added yet" from "never will
  /// be", so it refuses neither; an orphaned `parent` is structural
  /// validation's finding to report, with the whole file in hand.
  ///
  /// A node that names itself as its parent does get listed among its own
  /// children, and that is the right outcome: the graph is already malformed,
  /// and this keeps both representations saying so. [ancestorsOf] and the
  /// reachability walks each raise [NodeCycleError] on it either way.
  /// Appends every node already in the tree whose `parent` names
  /// [definitionHandle] but whose handle the definition's own `children` list
  /// does not contain — the recovery step [addDefinition] and
  /// [replaceDefinition] need after their wholesale overwrite, so a stale or
  /// hand-built `children` cannot erase a link [addNode] already made.
  ///
  /// Only appends; it never removes an incoming entry, even one whose named
  /// node disagrees with it or is not in the tree at all. A `children` list
  /// read from a file may legitimately name a node that has not been added
  /// yet — the codec constructs a definition before the nodes that fill it,
  /// same as it does for a [GroupNode] — and stripping that entry here would
  /// destroy exactly the ordering the file described, in the same situation
  /// [_link] already treats as "not added yet", not "wrong". A recovered
  /// handle is appended after the incoming order for the same reason
  /// [_link]'s append is order-preserving: `children` order is draw order,
  /// and the incoming order — the file's own, when there is one — is
  /// authoritative over the order this scan happens to visit `_nodes` in.
  void _relinkDefinition(Handle definitionHandle) {
    final definition = _definitions[definitionHandle];
    if (definition == null) return;
    final existing = definition.children.toSet();
    final recovered = [
      for (final node in _nodes.values)
        if (node.parent == definitionHandle && !existing.contains(node.handle))
          node.handle,
    ]..sort((a, b) => a.value.compareTo(b.value));
    if (recovered.isEmpty) return;
    _definitions[definitionHandle] = definition.copyWith(
      children: [...definition.children, ...recovered],
    );
  }

  void _link(Handle handle, Handle parent) {
    final node = _nodes[parent];
    if (node is GroupNode) {
      if (node.children.contains(handle)) return;
      _nodes[parent] = node.copyWith(children: [...node.children, handle]);
      return;
    }
    final definition = _definitions[parent];
    if (definition != null) {
      if (definition.children.contains(handle)) return;
      _definitions[parent] =
          definition.copyWith(children: [...definition.children, handle]);
    }
  }

  /// Unlists [handle] from [parent]. The mirror of [_link], and likewise a
  /// no-op when [parent] holds no children list.
  ///
  /// Distinct from [_dropInstance], which unlists from the container a *scan*
  /// walked through rather than the one `parent` names, for a malformed tree in
  /// which those differ. The two never contend: [_dropInstance] removes from
  /// `_nodes` itself and never calls [removeNode], and [_withoutAll] makes both
  /// paths tolerant of a handle that is already absent.
  void _unlink(Handle handle, Handle parent) {
    final node = _nodes[parent];
    if (node is GroupNode) {
      if (!node.children.contains(handle)) return;
      _nodes[parent] =
          node.copyWith(children: _withoutAll(node.children, handle));
      return;
    }
    final definition = _definitions[parent];
    if (definition != null && definition.children.contains(handle)) {
      _definitions[parent] = definition.copyWith(
          children: _withoutAll(definition.children, handle));
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

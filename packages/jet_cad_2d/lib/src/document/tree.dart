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

  /// Adds a node, rejecting anything that would close a definition cycle.
  ///
  /// The check lives here rather than in each command so that no command can
  /// close a cycle by forgetting to ask. Nothing is mutated when it throws.
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
  List<Handle> ancestorsOf(Handle handle) {
    final chain = <Handle>[];
    var current = _nodes[handle]?.parent ?? Handle.none;
    while (!current.isNone && _nodes.containsKey(current)) {
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
  bool definitionReaches(Handle from, Handle target) {
    final visited = <Handle>{};

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
          for (final child in children) {
            if (walkNode(child, into)) return true;
          }
          return false;
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
  List<Diagnostic> repairCycles() {
    final diagnostics = <Diagnostic>[];
    // Each pass drops exactly one instance and then rescans from scratch, so
    // the scan never walks a collection it is mutating. Every pass removes a
    // node, so the loop is bounded by the node count and converges; on a tree
    // with no cycle the first scan finds nothing and the result is empty.
    for (var edge = _findBackEdge(); edge != null; edge = _findBackEdge()) {
      final (:instance, :owner) = edge;
      _dropInstance(instance);
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
  /// on the walk, together with the definition that owns that instance, or
  /// `null` when no definition cycle exists.
  ///
  /// A depth-first walk over every definition, colouring each one white (never
  /// seen), grey ([onPath]) or black ([expanded]). An edge into a grey
  /// definition is a back edge, and a directed graph has a cycle exactly when a
  /// depth-first walk from every vertex finds one.
  ({InstanceNode instance, Handle owner})? _findBackEdge() {
    final expanded = <Handle>{};
    final onPath = <Handle>{};
    for (final def in definitions) {
      final found = _scanDefinition(def.handle, expanded, onPath);
      if (found != null) return found;
    }
    return null;
  }

  ({InstanceNode instance, Handle owner})? _scanDefinition(
    Handle definitionHandle,
    Set<Handle> expanded,
    Set<Handle> onPath,
  ) {
    // Already black: it was walked to completion earlier and produced no back
    // edge, so re-walking it cannot produce one now.
    if (!expanded.add(definitionHandle)) return null;
    final def = _definitions[definitionHandle];
    if (def == null) return null;
    onPath.add(definitionHandle);
    ({InstanceNode instance, Handle owner})? found;
    for (final child in def.children) {
      found = _scanNode(child, definitionHandle, expanded, onPath);
      if (found != null) break;
    }
    onPath.remove(definitionHandle);
    return found;
  }

  /// [owner] is the definition whose subtree is being walked; it stays the same
  /// through nested groups, since a group is not an enclosing space of its own.
  ({InstanceNode instance, Handle owner})? _scanNode(
    Handle nodeHandle,
    Handle owner,
    Set<Handle> expanded,
    Set<Handle> onPath,
  ) {
    final node = _nodes[nodeHandle];
    switch (node) {
      case InstanceNode():
        if (onPath.contains(node.definition)) {
          return (instance: node, owner: owner);
        }
        return _scanDefinition(node.definition, expanded, onPath);
      case GroupNode(:final children):
        for (final child in children) {
          final found = _scanNode(child, owner, expanded, onPath);
          if (found != null) return found;
        }
        return null;
      case null:
        return null; // an entity handle, not a node
    }
  }

  /// The definition enclosing [start] — [start] itself when it is a definition
  /// handle — or [Handle.none] when the chain reaches the root instead.
  Handle _enclosingDefinitionAbove(Handle start) {
    var current = start;
    while (!current.isNone) {
      if (_definitions.containsKey(current)) return current;
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

  void _dropInstance(InstanceNode node) {
    _nodes.remove(node.handle);
    final parent = _nodes[node.parent];
    if (parent is GroupNode) {
      _nodes[parent.handle] = parent.copyWith(
        children: [...parent.children]..remove(node.handle),
      );
      return;
    }
    final definition = _definitions[node.parent];
    if (definition != null) {
      _definitions[definition.handle] = definition.copyWith(
        children: [...definition.children]..remove(node.handle),
      );
    }
  }
}

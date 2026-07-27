import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

const tol = Tolerance.standard;

DocumentTree emptyTree() => DocumentTree(
      rootNode: GroupNode(
        handle: const Handle(100),
        parent: Handle.none,
        transform: Transform2.identity(),
        children: const [],
      ),
    );

Definition definitionWith(int handle, List<Handle> children) => Definition(
      handle: Handle(handle),
      name: 'D$handle',
      basePoint: Vector2.zero(),
      children: children,
    );

InstanceNode instanceIn(int handle, int parent, int definition) => InstanceNode(
      handle: Handle(handle),
      parent: Handle(parent),
      transform: Transform2.identity(),
      definition: Handle(definition),
      layer: ReservedHandles.layerZero,
    );

void main() {
  group('storage', () {
    test('root exists and is addressable', () {
      final tree = emptyTree();
      expect(tree.root, const Handle(100));
      expect(tree[tree.root], isA<GroupNode>());
    });

    test('nodes iterate in ascending handle order', () {
      final tree = emptyTree()
        ..addNode(instanceIn(30, 100, 200))
        ..addNode(instanceIn(10, 100, 200))
        ..addNode(instanceIn(20, 100, 200));
      tree.addDefinition(definitionWith(200, const []));
      expect([for (final n in tree.nodes) n.handle.value], [10, 20, 30, 100]);
    });

    test('replaceNode swaps the node and removeNode drops it', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 100, 200));
      tree.replaceNode(instanceIn(10, 100, 200).copyWith(visible: false));
      expect(tree[const Handle(10)]!.visible, isFalse);
      tree.removeNode(const Handle(10));
      expect(tree[const Handle(10)], isNull);
    });
  });

  group('accumulatedTransform', () {
    test('composes ancestor transforms in order', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.translation(10, 0),
        children: const [Handle(11)],
      ));
      tree.addNode(InstanceNode(
        handle: const Handle(11),
        parent: const Handle(10),
        transform: Transform2.scale(2, 2),
        definition: const Handle(200),
        layer: ReservedHandles.layerZero,
      ));
      final composed = tree.accumulatedTransform(const Handle(11));
      // Scale first, then the parent's translation.
      expect(
          tol.eqPoint(composed.transformPoint(Vector2(1, 0)), Vector2(12, 0)),
          isTrue);
    });

    test('stays exact at site-plan magnitudes', () {
      // The composition is Float64 all the way; only the renderer's residual
      // matrix is ever float32.
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.translation(4.5e6, -3.2e6),
        children: const [Handle(11)],
      ));
      tree.addNode(instanceIn(11, 10, 200));
      final p = tree
          .accumulatedTransform(const Handle(11))
          .transformPoint(Vector2(0.125, 0.125));
      expect(p.x, 4.5e6 + 0.125);
      expect(p.y, -3.2e6 + 0.125);
    });

    test('stops at a definition, because a prototype has no world position',
        () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(11)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(InstanceNode(
        handle: const Handle(11),
        parent: const Handle(200), // owned by a definition, not the root
        transform: Transform2.translation(7, 0),
        definition: const Handle(201),
        layer: ReservedHandles.layerZero,
      ));
      final composed = tree.accumulatedTransform(const Handle(11));
      expect(
          tol.eqPoint(composed.transformPoint(Vector2.zero()), Vector2(7, 0)),
          isTrue);
    });

    test('ancestorsOf lists nearest first and excludes the node itself', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(GroupNode(
        handle: const Handle(10),
        parent: const Handle(100),
        transform: Transform2.identity(),
        children: const [Handle(11)],
      ));
      tree.addNode(instanceIn(11, 10, 200));
      expect(tree.ancestorsOf(const Handle(11)),
          [const Handle(10), const Handle(100)]);
    });
  });

  group('cycle detection', () {
    test('definitionReaches finds a direct and a transitive reference', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const [Handle(22)]));
      tree.addDefinition(definitionWith(202, const []));
      tree.addNode(instanceIn(21, 200, 201));
      tree.addNode(instanceIn(22, 201, 202));
      expect(
          tree.definitionReaches(const Handle(200), const Handle(201)), isTrue);
      expect(
          tree.definitionReaches(const Handle(200), const Handle(202)), isTrue);
      expect(tree.definitionReaches(const Handle(202), const Handle(200)),
          isFalse);
    });

    test('finds a reference nested inside a group within a definition', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(GroupNode(
        handle: const Handle(21),
        parent: const Handle(200),
        transform: Transform2.identity(),
        children: const [Handle(22)],
      ));
      tree.addNode(instanceIn(22, 21, 201));
      expect(
          tree.definitionReaches(const Handle(200), const Handle(201)), isTrue);
    });

    test('rejects a self-reference and leaves the tree unmutated', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      expect(() => tree.addNode(instanceIn(21, 200, 200)),
          throwsA(isA<CycleDetectedError>()));
      expect(tree[const Handle(21)], isNull);
    });

    test('rejects a mutual reference and leaves the tree unmutated', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(instanceIn(21, 200, 201)); // 200 -> 201, fine
      expect(() => tree.addNode(instanceIn(22, 201, 200)),
          throwsA(isA<CycleDetectedError>()));
      expect(tree[const Handle(22)], isNull);
      expect(tree.definitionReaches(const Handle(201), const Handle(200)),
          isFalse);
    });

    // Beyond the brief: the guard's owner lookup must walk up from the node's
    // declared parent. Keyed on the node's own handle it finds nothing — the
    // node is not in the tree yet — and lets a cycle straight through whenever
    // the new instance sits inside a group rather than directly under the
    // definition.
    test('rejects a cycle closed from inside a group within a definition', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const [Handle(31)]));
      tree.addNode(instanceIn(21, 200, 201)); // 200 -> 201, fine
      tree.addNode(GroupNode(
        handle: const Handle(31),
        parent: const Handle(201),
        transform: Transform2.identity(),
        children: const [Handle(32)],
      ));
      expect(() => tree.addNode(instanceIn(32, 31, 200)),
          throwsA(isA<CycleDetectedError>()));
      expect(tree[const Handle(32)], isNull);
    });

    test('wouldCreateCycle answers without mutating', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(instanceIn(21, 200, 201));
      expect(
          tree.wouldCreateCycle(
              ownerDefinition: const Handle(201),
              referencedDefinition: const Handle(200)),
          isTrue);
      expect(
          tree.wouldCreateCycle(
              ownerDefinition: const Handle(200),
              referencedDefinition: const Handle(201)),
          isFalse);
    });

    test('repairCycles drops the offending instance and reports it', () {
      // Import must not fail the whole file over one bad reference: it
      // diagnoses and recovers.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addDefinition(definitionWith(201, const [Handle(22)]));
      tree.addNodeUnchecked(instanceIn(21, 200, 201));
      tree.addNodeUnchecked(instanceIn(22, 201, 200)); // closes the cycle

      final diagnostics = tree.repairCycles();
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.code, 'tree.cycle_dropped');
      expect(diagnostics.single.severity, DiagnosticSeverity.warning);
      expect(diagnostics.single.handles, contains(const Handle(22)));
      expect(tree[const Handle(22)], isNull);
      expect(tree.definition(const Handle(201))!.children, isEmpty);
      expect(tree.repairCycles(), isEmpty);
    });
  });
}

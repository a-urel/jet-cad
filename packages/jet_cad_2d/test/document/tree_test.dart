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

GroupNode groupIn(int handle, int parent, List<int> children) => GroupNode(
      handle: Handle(handle),
      parent: Handle(parent),
      transform: Transform2.identity(),
      children: [for (final c in children) Handle(c)],
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

    test('repairCycles cleans the container it walked, not node.parent', () {
      // The malformed case repairCycles exists for: `parent` and `children`
      // disagree. Group 21 is what actually lists the instance; the instance
      // claims the root as its parent. Cleaning the parent side would leave 21
      // still naming a node that no longer exists, and serialization would
      // then emit a dangling child reference.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addNodeUnchecked(groupIn(21, 200, const [22]));
      tree.addNodeUnchecked(
          instanceIn(22, 100, 200)); // parent lies: 100, not 21

      expect(tree.repairCycles(), hasLength(1));
      expect(tree[const Handle(22)], isNull);
      expect((tree[const Handle(21)]! as GroupNode).children, isEmpty);
    });

    test('repairCycles unlists a duplicated child handle completely', () {
      // A malformed file can name the same child twice; removing only the
      // first occurrence leaves a reference to a dropped node behind.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addNodeUnchecked(groupIn(21, 200, const [22, 22]));
      tree.addNodeUnchecked(instanceIn(22, 21, 200));

      expect(tree.repairCycles(), hasLength(1));
      expect((tree[const Handle(21)]! as GroupNode).children, isEmpty);
    });
  });

  // A cycle among *containers* is a different fault from a cycle among
  // definitions, and the ordinary checked API admits one: `_guardCycle` only
  // inspects instance nodes, so nothing stops two groups from being made each
  // other's parent, or each other's child. Both used to run away — the parent
  // form as an unbounded loop growing a list, the children form as unbounded
  // recursion. Each test is bounded so a regression fails fast instead of
  // stalling the suite.
  group('node graph cycles', () {
    test('a parent cycle throws rather than looping forever', () {
      final tree = emptyTree();
      // Both accepted by the fully-checked API: neither is an InstanceNode.
      tree.addNode(groupIn(10, 11, const []));
      tree.addNode(groupIn(11, 10, const []));

      expect(() => tree.ancestorsOf(const Handle(10)),
          throwsA(isA<NodeCycleError>()));
      expect(() => tree.accumulatedTransform(const Handle(10)),
          throwsA(isA<NodeCycleError>()));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('a self-parent throws rather than looping forever', () {
      final tree = emptyTree()..addNode(groupIn(10, 10, const []));
      expect(() => tree.ancestorsOf(const Handle(10)),
          throwsA(isA<NodeCycleError>()));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('a children cycle throws rather than recursing forever', () {
      // Parent pointers are consistent here, so only the children edge loops.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(10)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(groupIn(10, 200, const [11]));
      tree.addNode(groupIn(11, 10, const [10])); // closes the loop

      expect(() => tree.definitionReaches(const Handle(200), const Handle(201)),
          throwsA(isA<NodeCycleError>()));
      // The repair scan walks children too, and is bounded the same way.
      expect(() => tree.repairCycles(), throwsA(isA<NodeCycleError>()));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('the error names the handle the walk looped back on', () {
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(10)]));
      tree.addNode(groupIn(10, 200, const [11]));
      tree.addNode(groupIn(11, 10, const [10]));

      expect(
          () => tree.definitionReaches(const Handle(200), const Handle(999)),
          throwsA(isA<NodeCycleError>()
              .having((e) => e.handle, 'handle', const Handle(10))));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('a handle listed under two groups is a duplicate, not a cycle', () {
      // The walks use an on-path set, not a seen-ever set: re-entering a group
      // that is no longer open is a repeated reference and must stay legal.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(10), Handle(11)]));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(groupIn(10, 200, const [12]));
      tree.addNode(groupIn(11, 200, const [12]));
      tree.addNode(instanceIn(12, 10, 201));

      expect(
          tree.definitionReaches(const Handle(200), const Handle(201)), isTrue);
      expect(tree.repairCycles(), isEmpty);
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  // `parent` and `children` are dual representations of one containment edge.
  // Writers used to maintain only `parent` while every reachability walk read
  // `children`, so a document built the way commands actually build one had an
  // empty `children` everywhere and the cycle guard saw an empty graph.
  group('parent/children sync', () {
    test('a definition cycle built entirely through commands is rejected', () {
      final doc = DraftDocument.empty();
      final defA = doc.handleSeed.next();
      final defB = doc.handleSeed.next();
      doc.tree.addDefinition(Definition(
          handle: defA,
          name: 'A',
          basePoint: Vector2.zero(),
          children: const []));
      doc.tree.addDefinition(Definition(
          handle: defB,
          name: 'B',
          basePoint: Vector2.zero(),
          children: const []));

      // A contains an instance of B.
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: doc.handleSeed.next(),
        parent: defA,
        transform: Transform2.identity(),
        definition: defB,
        layer: ReservedHandles.layerZero,
      )));

      // B contains an instance of A — this closes A -> B -> A.
      expect(
        () => doc.commands.execute(AddNodeCommand(InstanceNode(
          handle: doc.handleSeed.next(),
          parent: defB,
          transform: Transform2.identity(),
          definition: defA,
          layer: ReservedHandles.layerZero,
        ))),
        throwsA(isA<CycleDetectedError>()),
      );

      // Pins the sync itself, not just the symptom: the guard can only see the
      // cycle because the first command linked its node into defA's children.
      expect(doc.tree.definition(defA)!.children, isNotEmpty);
    });

    test('addNode links the new node into its parent group', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 100, 200));
      expect(
          (tree[const Handle(100)]! as GroupNode).children, [const Handle(10)]);
    });

    test('addNode links the new node into its parent definition', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 200, 200 + 1));
      expect(tree.definition(const Handle(200))!.children, [const Handle(10)]);
    });

    test('linking is idempotent and preserves an existing position', () {
      // The importer and the codec add nodes whose parents already list them,
      // read verbatim from the file. Appending unconditionally would duplicate
      // the entry and reorder draw order.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const []));
      tree.addNode(groupIn(10, 100, const [21, 22, 23]));
      tree.addNode(instanceIn(21, 10, 200));
      tree.addNode(instanceIn(23, 10, 200));
      tree.addNode(instanceIn(22, 10, 200));
      expect((tree[const Handle(10)]! as GroupNode).children,
          [const Handle(21), const Handle(22), const Handle(23)]);
    });

    test('a genuinely new node appends after the existing children', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(groupIn(10, 100, const [21]));
      tree.addNode(instanceIn(21, 10, 200));
      tree.addNode(instanceIn(22, 10, 200));
      expect((tree[const Handle(10)]! as GroupNode).children,
          [const Handle(21), const Handle(22)]);
    });

    test('removeNode unlinks the node from its parent', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 100, 200));
      tree.addNode(instanceIn(11, 100, 200));
      tree.removeNode(const Handle(10));
      expect(
          (tree[const Handle(100)]! as GroupNode).children, [const Handle(11)]);
    });

    test('removeNode unlinks from a parent definition too', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addDefinition(definitionWith(201, const []));
      tree.addNode(instanceIn(10, 200, 201));
      expect(tree.definition(const Handle(200))!.children, [const Handle(10)]);
      tree.removeNode(const Handle(10));
      expect(tree.definition(const Handle(200))!.children, isEmpty);
    });

    test('replaceNode with a changed parent moves the child across', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(groupIn(10, 100, const []));
      tree.addNode(instanceIn(11, 100, 200));
      tree.replaceNode(instanceIn(11, 10, 200));
      expect(
          (tree[const Handle(100)]! as GroupNode).children, [const Handle(10)]);
      expect(
          (tree[const Handle(10)]! as GroupNode).children, [const Handle(11)]);
    });

    test('replaceNode that keeps the parent keeps the position', () {
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 100, 200));
      tree.addNode(instanceIn(11, 100, 200));
      tree.replaceNode(instanceIn(10, 100, 200).copyWith(visible: false));
      expect((tree[const Handle(100)]! as GroupNode).children,
          [const Handle(10), const Handle(11)]);
    });

    test(
        'addNodeUnchecked does not link, so a file\'s own disagreement '
        'survives to be repaired', () {
      // The importer reconstructs both sides from the file. Fabricating a
      // `children` entry here would hide the very disagreement repairCycles
      // exists to see — and would leave the fabricated entry dangling after
      // the offending node is dropped from the container the scan walked.
      final tree = emptyTree();
      tree.addDefinition(definitionWith(200, const [Handle(21)]));
      tree.addNodeUnchecked(groupIn(21, 200, const [22]));
      tree.addNodeUnchecked(instanceIn(22, 100, 200)); // parent lies

      expect((tree[const Handle(100)]! as GroupNode).children, isEmpty);
      expect(tree.repairCycles(), hasLength(1));
      expect((tree[const Handle(100)]! as GroupNode).children, isEmpty,
          reason: 'no fabricated child may be left dangling by the repair');
    });

    test('a parent absent from the tree is a no-op, not an error', () {
      // A node may legitimately be added before its parent: an importer or a
      // paste can emit children first. addNode cannot tell "not added yet"
      // from "will never exist", so it refuses neither.
      final tree = emptyTree()..addDefinition(definitionWith(200, const []));
      tree.addNode(instanceIn(10, 999, 200));
      expect(tree[const Handle(10)], isNotNull);
      expect(tree[const Handle(999)], isNull);
    });
  });
}

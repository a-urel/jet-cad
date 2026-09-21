import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

void main() {
  test(
      'two instances of one definition are two keys; two leaves of one '
      'instance are one', () {
    final doc = DraftDocument.empty();
    final (def, a, b, _) = twoInstancesOfOneDefinition(doc);
    // A second leaf in the same definition, well clear of the first once
    // placed, so a radius that hits one never accidentally hits the other.
    addEntity(doc, def, EntityKind.line, [5, 0, 7, 0], []);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    final worldA =
        doc.tree.accumulatedTransform(a).transformPoint(Vector2(1, 0));
    expect(index.pickInto(worldA, 0.5, const QueryFilter.all(), hit), isTrue);
    final ka = resolveHit(hit, doc);
    expect(ka, isNotNull);
    expect(doc.tree[ka!.target], isA<InstanceNode>());
    expect(ka.target, a);

    final worldB =
        doc.tree.accumulatedTransform(b).transformPoint(Vector2(1, 0));
    expect(index.pickInto(worldB, 0.5, const QueryFilter.all(), hit), isTrue);
    final kb = resolveHit(hit, doc);
    expect(kb, isNotNull);
    expect(doc.tree[kb!.target], isA<InstanceNode>());
    expect(kb.target, b);

    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    selection.replace([ka]);
    selection.toggle([kb]);
    expect(selection.length, 2);

    final worldLeaf2 =
        doc.tree.accumulatedTransform(a).transformPoint(Vector2(6, 0));
    expect(
        index.pickInto(worldLeaf2, 0.5, const QueryFilter.all(), hit), isTrue);
    final ka2 = resolveHit(hit, doc);
    expect(ka2, equals(ka),
        reason: 'a second leaf of the same instance resolves to the same '
            'selection key as the first');
  });

  test(
      'a leaf owned by a nested group resolves to the outer group; a '
      'single-level group to itself', () {
    final doc = DraftDocument.empty();
    final outer = addGroup(doc, doc.rootHandle, kPlacement);
    final inner = addGroup(doc, outer, Transform2.translation(10, 10));
    final nestedLeaf = addEntity(doc, inner, EntityKind.line, [0, 0, 1, 0], []);

    final single =
        addGroup(doc, doc.rootHandle, Transform2.translation(-500, -500));
    final singleLeaf =
        addEntity(doc, single, EntityKind.line, [0, 0, 1, 0], []);

    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final hit = HitPath();
    final worldNested =
        doc.tree.accumulatedTransform(inner).transformPoint(Vector2(0.5, 0));
    expect(
        index.pickInto(worldNested, 0.5, const QueryFilter.all(), hit), isTrue);
    expect(hit.entity, nestedLeaf);
    final nestedKey = resolveHit(hit, doc);
    expect(nestedKey, isNotNull);
    expect(nestedKey!.target, outer,
        reason: 'a leaf owned by a nested group selects the outermost group');

    final worldSingle =
        doc.tree.accumulatedTransform(single).transformPoint(Vector2(0.5, 0));
    expect(
        index.pickInto(worldSingle, 0.5, const QueryFilter.all(), hit), isTrue);
    expect(hit.entity, singleLeaf);
    final singleKey = resolveHit(hit, doc);
    expect(singleKey, isNotNull);
    expect(singleKey!.target, single,
        reason: 'a leaf owned by a single-level group selects that group');
  });

  test('a truncated hit is a miss', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);

    final hit = HitPath(2)
      ..entity = leaf
      ..chainLength = 2
      ..truncated = true;

    expect(resolveHit(hit, doc), isNull);
  });

  test('an external remove prunes; an unrelated add does not', () async {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final def = addDefinition(doc, 'Def');
    final instance = addInstance(doc, def, kPlacement);

    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final leafKey = SelectionKey.root(leaf);
    final instanceKey = SelectionKey.root(instance);
    selection.replace([leafKey, instanceKey]);
    expect(selection.length, 2);

    doc.commands.execute(RemoveEntityCommand(leaf));
    await Future<void>.delayed(Duration.zero);

    expect(selection.length, 1);
    expect(selection.contains(instanceKey), isTrue);
    expect(selection.contains(leafKey), isFalse);

    addEntity(doc, doc.rootHandle, EntityKind.line, [50, 50, 60, 50], []);
    await Future<void>.delayed(Duration.zero);

    expect(selection.length, 1,
        reason: 'an add unrelated to the current selection must not prune '
            'anything');
    expect(selection.contains(instanceKey), isTrue);
  });

  test('replace with the same set does not notify', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final k = SelectionKey.root(leaf);

    var count = 0;
    selection.addListener(() => count++);

    selection.replace([k]);
    selection.replace([k]);
    expect(count, 1, reason: 'the second replace names the same set');

    selection.setHover(k);
    selection.setHover(k);
    expect(count, 2, reason: 'the second setHover names the same key');
  });

  test('toggle adds then removes', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final k = SelectionKey.root(leaf);

    selection.toggle([k]);
    expect(selection.contains(k), isTrue);

    selection.toggle([k]);
    expect(selection.contains(k), isFalse);
  });

  test('remove drops only what it names', () {
    final doc = DraftDocument.empty();
    final leafA =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final leafB =
        addEntity(doc, doc.rootHandle, EntityKind.line, [2, 0, 3, 0], []);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final ka = SelectionKey.root(leafA);
    final kb = SelectionKey.root(leafB);

    selection.replace([ka, kb]);
    selection.remove([ka]);

    expect(selection.contains(ka), isFalse);
    expect(selection.contains(kb), isTrue);
    expect(selection.length, 1);
  });

  test('clear drops hover too', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final k = SelectionKey.root(leaf);

    selection.replace([k]);
    selection.setHover(k);
    selection.clear();

    expect(selection.isEmpty, isTrue);
    expect(selection.hover, isNull);
  });

  test('DocumentLoaded clears everything', () {
    final doc = DraftDocument.empty();
    final leaf =
        addEntity(doc, doc.rootHandle, EntityKind.line, [0, 0, 1, 0], []);
    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final k = SelectionKey.root(leaf);

    selection.replace([k]);
    selection.setHover(k);

    var count = 0;
    selection.addListener(() => count++);
    selection.debugOnChange(const DocumentLoaded());

    expect(selection.isEmpty, isTrue);
    expect(selection.hover, isNull);
    expect(count, 1);
  });

  test('equality is by chain and target, not identity', () {
    final chainA = Uint32List.fromList([7, 9, 0, 0]);
    final chainB = Uint32List.fromList([7, 9, 0, 0]);
    final ka =
        SelectionKey(chain: chainA, chainLength: 2, target: const Handle(42));
    final kb =
        SelectionKey(chain: chainB, chainLength: 2, target: const Handle(42));

    expect(identical(ka.chain, kb.chain), isFalse);
    expect(ka, equals(kb));
    expect(ka.hashCode, kb.hashCode);
  });
}

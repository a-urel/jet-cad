// Spec 12b D6 (render half): `OutlineCache`'s instance walk tests a
// definition's leaves and nested instances against their effective layer —
// layer 0 takes the enclosing context's, recursively — so an instance on A
// keeps its whole outline with layer 0 hidden, and loses it with A hidden.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/outline_cache.dart';
import 'package:jet_cad_2d_flutter/src/selection.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import '../support/layer_fixture.dart';

(SelectionController, OutlineCache) wire(DraftDocument doc) {
  final selection = SelectionController(doc);
  addTearDown(selection.dispose);
  final cache = OutlineCache(doc, selection);
  addTearDown(cache.dispose);
  return (selection, cache);
}

Future<void> run(LayerFixture f, DraftCommand command) async {
  f.doc.commands.execute(command);
  await Future<void>.delayed(Duration.zero);
}

/// The world segments a line from ([x1], [y1]) to ([x2], [y2]) placed by
/// [t] outlines as.
List<double> line(Transform2 t, double x1, double y1, double x2, double y2) {
  final p = t.transformPoint(Vector2(x1, y1));
  final q = t.transformPoint(Vector2(x2, y2));
  return [p.x, p.y, q.x, q.y];
}

void main() {
  late LayerFixture f;
  late SelectionController selection;
  late OutlineCache cache;
  late SelectionKey instance;

  final placed = LayerFixture.instanceTransform;
  final nestedPlaced =
      LayerFixture.instanceTransform.multiply(LayerFixture.nestedTransform);

  /// The instance's whole outline: the table's line, then the leg's line
  /// (two levels down); the table's circle as an arc.
  List<double> wholeSegments() =>
      [...line(placed, 10, 10, 70, 40), ...line(nestedPlaced, 5, 5, 25, 15)];

  setUp(() {
    f = LayerFixture();
    (selection, cache) = wire(f.doc);
    instance = SelectionKey.root(f.instance);
  });

  test('control: with every layer as built, the outline is the whole symbol',
      () {
    selection.replace({instance});
    expect(cache.debugWorldSegmentsOf(instance),
        pairwiseCompare(wholeSegments(), _close, 'within 1e-9 of'));
    final arcs = cache.debugWorldArcsOf(instance)!;
    final centre = placed.transformPoint(Vector2(-30, 20));
    expect(arcs, hasLength(5));
    expect(arcs[0], closeTo(centre.x, 1e-9));
    expect(arcs[1], closeTo(centre.y, 1e-9));
  });

  test(
      'an instance on A with layer 0 hidden keeps its whole outline, the '
      'nested instance\'s line included (M-LP-14, outline)', () async {
    selection.replace({instance});
    await run(f, SetCurrentLayerCommand(f.b));
    await run(
        f,
        SetLayerCommand(
            f.withState(ReservedHandles.layerZero, visible: false)));
    expect(selection.keys, {instance});
    expect(cache.debugWorldSegmentsOf(instance),
        pairwiseCompare(wholeSegments(), _close, 'within 1e-9 of'));
    expect(cache.debugWorldArcsOf(instance), hasLength(5));
  });

  test(
      'with A hidden the instance has no outline: its layer-0 contents follow '
      'A, two levels down', () {
    // A direct write: no DocChange, so the selection does not prune and the
    // walk itself decides.
    f.writeLayer(f.withState(f.a, visible: false));
    selection.replace({instance});
    expect(cache.debugWorldSegmentsOf(instance), isEmpty);
    expect(cache.debugWorldArcsOf(instance), isEmpty);
    expect(cache.worldBoundsOf(instance), isNull);
  });

  test('hiding A by a command removes the outline with the key', () async {
    selection.replace({instance});
    expect(cache.worldBoundsOf(instance), isNotNull);
    await run(f, SetLayerCommand(f.withState(f.a, visible: false)));
    expect(selection.keys, isEmpty);
    expect(cache.worldBoundsOf(instance), isNull);
    expect(cache.pathFor(instance, Vector2.zero()), isNull);
  });

  test(
      'a nested instance on the hidden layer leaves the outline; the table\'s '
      'own leaves stay', () async {
    selection.replace({instance});
    await run(f, SetInstanceLayerCommand(f.nested, f.c));
    expect(
        cache.debugWorldSegmentsOf(instance),
        pairwiseCompare(
            line(placed, 10, 10, 70, 40), _close, 'within 1e-9 of'));
    expect(cache.debugWorldArcsOf(instance), hasLength(5));
  });
}

bool _close(double expected, double actual) =>
    (expected - actual).abs() <= 1e-9;

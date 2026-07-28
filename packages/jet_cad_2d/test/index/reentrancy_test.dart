import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

Handle addLine(DraftDocument doc, double x, double y, {Handle? owner}) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner ?? doc.rootHandle,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: kByLayer,
      transparency: kByLayer,
      flags: 0,
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y, x + 1, y + 1]),
      scalars: Float64List(0),
    ),
  ));
  return handle;
}

Aabb2 rect(double a, double b, double c, double d) =>
    Aabb2(Vector2(a, b), Vector2(c, d));

void main() {
  test('a query inside a visitor throws rather than returning nonsense', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(),
          (_) {
        index.forEachInRect(
            rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {});
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });

  test('mutating the document inside a visitor throws', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(),
          (_) {
        addLine(doc, 5, 5);
      }),
      throwsA(isA<QueryReentrancyError>()),
      reason: 'mutation inside a visitor changes the structure being walked, '
          'and is the more likely of the two mistakes',
    );
  });

  test('undo inside a visitor throws too', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(),
          (_) {
        doc.commands.undo();
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });

  test('the flag clears after a query, including one that threw', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    try {
      index.forEachInRect(rect(-1, -1, 10, 10), const QueryFilter.all(), (_) {
        throw StateError('visitor blew up');
      });
    } on StateError {
      // expected
    }

    // If the flag leaked, this second query would throw QueryReentrancyError.
    var visits = 0;
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => visits++);
    expect(visits, 1);

    // And mutation is allowed again.
    expect(() => addLine(doc, 9, 9), returnsNormally);
  });

  test('sequential queries are fine — only nesting is forbidden', () {
    final doc = DraftDocument.empty();
    addLine(doc, 0, 0);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    var first = 0, second = 0;
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => first++);
    index.forEachInRect(
        rect(-1, -1, 10, 10), const QueryFilter.all(), (_) => second++);
    expect(first, 1);
    expect(second, 1);
  });

  test('forEachInstanceInRect is guarded as well', () {
    final doc = DraftDocument.empty();
    const def = Handle(200);
    doc.tree.addDefinition(Definition(
      handle: def,
      name: 'T',
      basePoint: Vector2.zero(),
      children: const [],
    ));
    // Owned by the definition, not the root: an empty definition has empty
    // bounds, so its instance would never overlap the query rect below and
    // the visitor — where the mutation this test is checking for happens —
    // would never run.
    addLine(doc, 0, 0, owner: def);
    doc.commands.execute(AddNodeCommand(
      InstanceNode(
        handle: const Handle(400),
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        definition: def,
        layer: ReservedHandles.layerZero,
      ),
    ));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    expect(
      () => index.forEachInstanceInRect(
          rect(-10, -10, 10, 10), const QueryFilter.all(), (_) {
        addLine(doc, 5, 5);
      }),
      throwsA(isA<QueryReentrancyError>()),
    );
  });
}

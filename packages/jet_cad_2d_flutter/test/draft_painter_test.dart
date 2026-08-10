import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

void main() {
  test('a conformal leaf reaches the sink under a translation-only residual',
      () {
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, doc.handleSeed.next(), EntityKind.line, [0, 0, 10, 4],
        const []);
    // Conformal: equal scale on both axes, plus a rotation. Ratio is 1.0, so
    // this leaf took the residual path before this task.
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: Transform2(2.4, 1.1, -1.1, 2.4, 60, 45),
      layer: ReservedHandles.layerZero,
    )));

    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final residuals = recording.ops.whereType<BeginResidualOp>().toList();
    expect(residuals, isNotEmpty);
    for (final r in residuals) {
      expect(r.residual.a, 1.0);
      expect(r.residual.b, 0.0);
      expect(r.residual.c, 0.0);
      expect(r.residual.d, 1.0);
    }
  });

  test('every frame pushes one residual value for its line-like leaves', () {
    // Two leaves in different definitions at different placements. If the
    // residual still carried the placement, these would differ — which is
    // exactly what stops a sink from batching them.
    //
    // Filtered to the residuals whose linear part is the exact identity.
    // `_emitScreenSpace` always pushes `Transform2.translation(...)`, so that
    // is the signature of the screen-space path and only that path — a
    // curve's residual still composes the camera matrix (unchanged by this
    // task), so it is never (1, 0, 0, 1) by coincidence in this fixture.
    // Left unfiltered, `generateDocument`'s default kind mix includes circles,
    // arcs and text, whose per-placement residuals still carry floating-point
    // noise from the unrelated chain path (about 41 distinct values here) and
    // would fail this assertion for a reason outside this task's scope.
    final doc = generateDocument(400, definitionCount: 8, instanceCount: 40);
    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final translations = recording.ops
        .whereType<BeginResidualOp>()
        .where((op) =>
            op.residual.a == 1.0 &&
            op.residual.b == 0.0 &&
            op.residual.c == 0.0 &&
            op.residual.d == 1.0)
        .map((op) => '${op.residual.e},${op.residual.f}')
        .toSet();
    expect(translations.length, 1,
        reason: 'one rebase origin per frame means one residual value; '
            'more than one means a placement is still riding along');
  });
}

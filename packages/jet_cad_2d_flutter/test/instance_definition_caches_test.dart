// Spec 09c D7, W-13: no command changed an instance's definition before
// SetInstanceDefinitionCommand. The render caches -- the selection outline
// and the painter, both kept across the change -- follow the new definition
// after the change, its undo and its redo, and a later edit to the new
// definition's leaf. Fixtures off the origin, the instance turned 37 degrees
// and mirrored, the two definitions' leaves far apart in world.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/selection_fixture.dart';

final Transform2 kPlace = Transform2.translation(4000, -2500)
    .multiply(Transform2.rotation(37 * math.pi / 180))
    .multiply(Transform2.scale(-1, 1));

const Size kViewport = Size(800, 600);

/// The first world point the painter drew, from the residual in force.
Vector2 firstWorldPoint(List<DrawOp> ops, ViewportTransform camera) {
  final begin = ops.whereType<BeginResidualOp>().first;
  final line = ops.whereType<PolylineOp>().first;
  return camera.screenToWorld(
      begin.residual.transformPoint(Vector2(line.points[0], line.points[1])));
}

void main() {
  test(
      'IC1 the outline and the painter follow a definition change, its undo, '
      'its redo and an edit of the new leaf (W-13, M-09c-bc)', () async {
    final doc = DraftDocument.empty();
    final a = addDefinition(doc, 'A');
    addEntity(doc, a, EntityKind.line, [30, 10, 90, 40], []);
    final b = addDefinition(doc, 'B');
    final leafB = addEntity(doc, b, EntityKind.line, [600, 700, 650, 900], []);
    final instance = addInstance(doc, a, kPlace);

    final selection = SelectionController(doc);
    addTearDown(selection.dispose);
    final outlines = OutlineCache(doc, selection);
    addTearDown(outlines.dispose);
    final key = SelectionKey.root(instance);
    selection.replace([key]);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(
        Aabb2(Vector2(3000, -3500), Vector2(5000, -1500)), kViewport);

    Future<(Vector2, Vector2)> state() async {
      await Future<void>.delayed(Duration.zero);
      final s = outlines.debugWorldSegmentsOf(key)!;
      final sink = RecordingDrawSink();
      painter.paint(sink, camera, kViewport);
      return (Vector2(s[0], s[1]), firstWorldPoint(sink.ops, camera));
    }

    void expectAt(Vector2 got, Vector2 want, String why) {
      expect(got.x, closeTo(want.x, 1e-6), reason: why);
      expect(got.y, closeTo(want.y, 1e-6), reason: why);
    }

    final atA = kPlace.transformPoint(Vector2(30, 10));
    final atB = kPlace.transformPoint(Vector2(600, 700));
    var (outline, painted) = await state();
    expectAt(outline, atA, 'outline before');
    expectAt(painted, atA, 'painted before');

    doc.commands.execute(SetInstanceDefinitionCommand(instance, b));
    (outline, painted) = await state();
    expectAt(outline, atB, 'outline after the change');
    expectAt(painted, atB, 'painted after the change');

    doc.commands.undo();
    (outline, painted) = await state();
    expectAt(outline, atA, 'outline after undo');
    expectAt(painted, atA, 'painted after undo');

    doc.commands.redo();
    (outline, painted) = await state();
    expectAt(outline, atB, 'outline after redo');
    expectAt(painted, atB, 'painted after redo');

    doc.commands.execute(SetEntityGeometryCommand(
        leafB,
        GeometryPayload(
            coords: Float64List.fromList([620, 1200, 650, 900]),
            scalars: Float64List(0))));
    final edited = kPlace.transformPoint(Vector2(620, 1200));
    (outline, painted) = await state();
    expectAt(outline, edited, 'outline after the edit');
    expectAt(painted, edited, 'painted after the edit');
  });
}

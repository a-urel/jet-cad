// Rebasing is frame-global by construction: `rebaseOriginFor` snaps the view
// centre to a power-of-two grid whose step comes from the view *span*
// (`camera_controller.dart:18-33`). Plan 3g bakes tiles through per-tile
// cameras, and a per-tile span would give each tile its own step and its own
// origin, and its `float32` residuals would differ from the live frame's,
// against a criterion that allows zero differing pixels.
//
// This pins that the override exists and that it wins. Mutant M17 deletes it.

import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'support/fixtures.dart';

/// World == screen, y flipped, no margin, over a 400 x 300 viewport.
///
/// **Not `ViewportTransform.fit`** — Ruling R3 of this task's brief: `fit`
/// applies a 0.95 margin, and deriving an expected on-screen position through
/// it is what cost Plan 3f two tasks. A local copy rather than a shared one
/// in `support/fixtures.dart`: `unitCamera()` already exists as a local in
/// `test/invariants/text_cache_invariants_test.dart`, a Plan 3f.1 file this
/// task has no business touching, and promoting it there would leave two
/// definitions of one name.
ViewportTransform unitCamera() =>
    ViewportTransform(worldToScreenMatrix: Transform2(1, 0, 0, -1, 0, 300));

void main() {
  test('an injected rebase origin overrides the one the view span would give',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // Far from the origin, so the rebase origin is a large number and a wrong
    // one is visible in the emitted coordinates rather than lost in rounding.
    // 4.5e6 is the magnitude `viewport_transform.dart`'s header names.
    addLine(doc, doc.rootHandle, const Handle(1001), 4.5e6, 4.5e6, 4.5e6 + 400,
        4.5e6 + 300);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    const viewport = Size(400, 300);
    final camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(1, 0, 0, -1, -4.5e6, 4.5e6 + viewport.height));

    Float64List firstPolyline(DraftPainter painter) {
      final sink = RecordingDrawSink();
      painter.paint(sink, camera, viewport);
      final op = sink.ops.whereType<PolylineOp>().first;
      return Float64List.fromList(op.points);
    }

    final derived = firstPolyline(DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc)));

    // A deliberately different origin: the same grid, one step over. The
    // emitted points are rebased against it, so every x moves by exactly the
    // difference and nothing else changes.
    final defaultOrigin = rebaseOriginFor(camera.visibleWorld(viewport));
    final shifted = Vector2(defaultOrigin.x + 4096, defaultOrigin.y);
    final overridden = firstPolyline(DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        debugRebaseOrigin: shifted));

    expect(overridden.length, derived.length);
    for (var i = 0; i < derived.length; i += 2) {
      expect(overridden[i], derived[i] - 4096,
          reason: 'x rebased against the injected origin');
      expect(overridden[i + 1], derived[i + 1], reason: 'y untouched');
    }
  });

  test('debugOnVisit reports every leaf drawn and every container descended',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // One root leaf, one definition holding one leaf, one instance placing it.
    // A root-only fixture would let M16 survive — see anti-degenerate clause 4.
    addLine(doc, doc.rootHandle, const Handle(1001), 10, 10, 90, 90);
    addDefinition(doc, const Handle(210), 'PLATE');
    addLine(doc, const Handle(210), const Handle(1002), 0, 0, 40, 40);
    addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
        Transform2(1, 0, 0, 1, 120, 20));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      debugOnVisit: seen.add,
    );
    painter.paint(RecordingDrawSink(), unitCamera(), const Size(400, 300));

    expect(seen, contains(const Handle(1001)), reason: 'the root leaf');
    expect(seen, contains(const Handle(1002)), reason: 'the definition leaf');
    expect(seen, contains(const Handle(300)),
        reason: 'the instance node itself — TransformNodeCommand reports only '
            'this handle, so a tile that never records it cannot find the '
            'pixels a drag left behind');
  });
}

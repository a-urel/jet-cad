import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'support/differential.dart';
import 'support/fixtures.dart';

GeometryPayload squareLoop() => GeometryPayload(
    coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
    scalars: Float64List(0));

AddRegionCommand region(DraftDocument doc) => AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: squareLoop(),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );

/// Paints one frame with a fresh index and painter, returning the painter so
/// its per-frame counters can be read.
DraftPainter paintOnce(DraftDocument doc, RecordingDrawSink sink) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc, index: index, resolver: DocumentStyleResolver(doc));
  painter.paint(sink, ViewportTransform.fit(doc.extents, kViewport), kViewport);
  return painter;
}

/// Paints a second frame with the same painter, so a counter's reset can be
/// told apart from a running total.
void paintAgain(DraftPainter painter, RecordingDrawSink sink) {
  painter.paint(sink,
      ViewportTransform.fit(painter.document.extents, kViewport), kViewport);
}

void main() {
  test('a region draws the fill before its boundary', () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    final sink = RecordingDrawSink();
    paintOnce(doc, sink);
    final fillAt = sink.ops.indexWhere((o) => o is FillPolygonOp);
    final strokeAt = sink.ops.indexWhere((o) => o is PolylineOp);
    expect(fillAt, isNonNegative);
    expect(fillAt, lessThan(strokeAt),
        reason: 'draw order is ascending handle value and the fill holds the '
            'lower one; if this inverts, the fill paints over its own outline');
  });

  test('an unfillable boundary is skipped and counted, not handed to a sink',
      () {
    final doc = DraftDocument.empty();
    final cmd = region(doc);
    doc.commands.execute(cmd);
    // Edit the boundary into a bow tie: still closed, no longer simple.
    doc.commands.execute(SetEntityGeometryCommand(
        cmd.boundary.handle,
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
            scalars: Float64List(0))));
    final sink = RecordingDrawSink();
    final painter = paintOnce(doc, sink);
    expect(sink.ops.whereType<FillPolygonOp>(), isEmpty,
        reason: 'CanvasDrawSink fills a self-intersecting path by non-zero '
            'winding while VerticesDrawSink draws nothing -- handing either '
            'one this fill manufactures a divergence on the refused case');
    expect(painter.skippedFillCount, 1);
  });

  test('a circle boundary draws a fillCircle, never a triangulated polygon',
      () {
    // The scale-dependence rule, as a drawing property.
    final doc = DraftDocument.empty();
    doc.commands.execute(AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.circle,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0]),
          scalars: Float64List.fromList([50])),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    ));
    final sink = RecordingDrawSink();
    paintOnce(doc, sink);
    expect(sink.ops.whereType<FillCircleOp>(), hasLength(1));
    expect(sink.ops.whereType<FillPolygonOp>(), isEmpty);
  });

  test('skippedFillCount is per frame, not a running total', () {
    // Plan 3c's Ruling 44: a counter that never resets prints a plausible
    // number beside two per-frame figures and reads as a working gate.
    final doc = DraftDocument.empty();
    doc.commands.execute(region(doc));
    doc.commands.execute(SetEntityGeometryCommand(
        doc.entities.handleAt(doc.entities.liveSlots.last),
        GeometryPayload(
            coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
            scalars: Float64List(0))));
    final painter = paintOnce(doc, RecordingDrawSink());
    paintAgain(painter, RecordingDrawSink());
    expect(painter.skippedFillCount, 1);
  });

  test('the painter walks fills and the reference walk agrees', () {
    // `expectPainterSupersetOfReference` in
    // `packages/jet_cad_2d_flutter/test/support/differential.dart` is the
    // existing oracle. It is a *superset* check by design, so it catches a
    // painter that forgets a fill and not one that draws an extra -- pair it
    // with the ordering test above, which is exact.
    final doc = DraftDocument.empty();
    doc.commands.execute(region(doc));
    expectPainterSupersetOfReference(
        paintToRecording(doc), referenceToRecording(doc), kViewport);
  });
}

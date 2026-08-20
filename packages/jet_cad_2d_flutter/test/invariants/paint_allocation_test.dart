// What a steady-state frame allocates through each sink.
//
// `CLAUDE.md`: "The frame path allocates nothing in steady state."
// `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` measures the
// query path and stops there. This measures the paint path, which is the half
// the vertices sink changes.
//
// The number is a *ratio against a control*, never an absolute: the VM's
// allocation profiler has a documented low-read artefact, and a run that reads
// low on both the control and the subject still reports the right ratio.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const Size _viewport = Size(800, 600);

DraftDocument _corpus() => generateDocument(
      4000,
      definitionCount: 40,
      instanceCount: 400,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );

void main() {
  testWidgets('a steady-state frame allocates O(1) per flush, not O(entities)',
      (tester) async {
    final doc = _corpus();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, _viewport);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink =
        VerticesDrawSink(pixelsPerPaperMm: kLogicalPixelsPerMm, canvas: canvas);

    // Warm up: the first frame grows the buffers, and growth is exactly what
    // the steady state is defined as being past.
    for (var i = 0; i < 3; i++) {
      painter.paint(sink, camera, _viewport);
      sink.flush();
    }

    // The subject frame. Flushes are counted, not assumed: the assertion below
    // is in units of flushes, so a frame that stopped flushing would make it
    // vacuous.
    sink.resetCounters();
    painter.paint(sink, camera, _viewport);
    sink.flush();

    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameSegmentCount, greaterThan(1000),
        reason: 'a degenerate corpus would make the bound meaningless');

    // The buffer must not have grown in the subject frame. Growth is the one
    // O(entities) allocation this sink can make, and it is the one the
    // steady-state claim is about.
    //
    // MUTATION: drop `_reserve`'s capacity-sufficiency guard and
    // unconditionally double, so every segment regrows the buffer instead of
    // only a call that needs more room. `debugCapacityVertices` no longer
    // holds still between the two reads -- it compounds every segment of the
    // frame and the run in fact throws an `OutOfMemoryError` from
    // `_reserve`'s `Float32List` allocation long before either `expect`
    // below runs, which is the steady-state property failing as loudly as
    // it can.
    final before = sink.debugCapacityVertices;
    painter.paint(sink, camera, _viewport);
    sink.flush();
    expect(sink.debugCapacityVertices, before,
        reason: 'the buffer grew in a steady-state frame, so the frame path '
            'allocates O(entities) and not O(1)');

    recorder.endRecording().dispose();
  });
}

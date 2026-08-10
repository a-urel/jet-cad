@Tags(['rig'])
library;

// ignore_for_file: avoid_print — printing the numbers is what a rig is for.

// Debug JIT, and a PictureRecorder records without rasterising. **A relative
// signal only**, and it cannot see raster at all — which is the cost this plan
// is trying to move. The binding number is R2, in the harness app. This rig
// exists to catch a mode that is catastrophically wrong before a profile run
// is spent on it, and to report the real-call counts, which are exact.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'rig_support.dart';

const int kEntities = 500000;

void main() {
  test('batch modes, working-set camera', () {
    // `rigCorpus`, `workingSetCamera` and `kRigViewport` are the same ones R1
    // and R3 use. Sharing them is the point: a spike measured on a different
    // corpus than the rig it is compared against measures nothing.
    final doc = rigCorpus(kEntities);
    final index = SpatialIndex(doc);
    final camera = workingSetCamera(doc);

    for (final mode in BatchMode.values) {
      final sink = CanvasDrawSink(pixelsPerPaperMm: 8.0, mode: mode);
      final painter = DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc));
      final samples = <double>[];
      var calls = 0;
      for (var i = 0; i < 12; i++) {
        final recorder = PictureRecorder();
        sink.canvas = Canvas(recorder);
        sink.resetCounters();
        final sw = Stopwatch()..start();
        painter.paint(sink, camera, kRigViewport);
        sink.flush();
        sw.stop();
        recorder.endRecording().dispose();
        if (i >= 2) samples.add(sw.elapsedMicroseconds / 1000.0);
        calls = sink.canvasCallCount;
      }
      samples.sort();
      print('${mode.name}: '
          'p50=${samples[samples.length ~/ 2].toStringAsFixed(2)}ms '
          'p95=${samples[(samples.length * 0.95).floor()].toStringAsFixed(2)}ms '
          'canvasCalls=$calls '
          'painterOps=${painter.screenSpaceLeafCount}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

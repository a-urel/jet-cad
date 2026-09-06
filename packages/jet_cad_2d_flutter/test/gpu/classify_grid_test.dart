import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_flutter/src/gpu/instance_record.dart';

import '../support/fixtures.dart';

/// Collects [doc] at its fit camera over the whole extents, the way a
/// rebuild does, and returns the collector's buffer and text list.
(Float32List, int, List<ResidentTextRecord>) collect(DraftDocument doc,
    FlutterTextMeasurer measurer, Size viewport, double dpr) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      minTextCapPixels: 0);
  final frame = collectionFrameFor(
      ViewportTransform.fit(doc.extents, viewport), doc.extents);
  final collector = GeometryCollector(
      pixelsPerPaperMm: kLogicalPixelsPerMm,
      devicePixelRatio: dpr,
      measurer: measurer,
      textStyleOf: doc.textStyleOf);
  painter.paint(collector, frame.camera, frame.viewport);
  return (collector.data, collector.instanceCount, collector.texts);
}

void expectSamePatches(List<TextPatch> a, List<TextPatch> b) {
  expect(a.length, b.length, reason: 'patch count');
  for (var i = 0; i < a.length; i++) {
    expect(a[i].textIndex, b[i].textIndex, reason: 'patch $i textIndex');
    expect(a[i].instanceCount, b[i].instanceCount,
        reason: 'patch $i instanceCount');
    final n = a[i].instanceCount * kFloatsPerInstance;
    expect(a[i].instances.sublist(0, n), b[i].instances.sublist(0, n),
        reason: 'patch $i sub-buffer, byte for byte, in main-buffer order');
  }
}

void main() {
  late FlutterTextMeasurer measurer;
  setUp(() {
    measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
  });

  test('grid and brute force agree byte for byte on the text-overlap fixture',
      () {
    final doc = textOverlapFixture(measurer);
    final (data, count, texts) = collect(doc, measurer, kViewport, 1.0);
    final stats = ClassifyStats();
    final grid = classifyTextPatches(data, count, texts,
        devicePixelRatio: 1.0, stats: stats);
    final brute = classifyTextPatchesBruteForce(data, count, texts,
        devicePixelRatio: 1.0);
    expectSamePatches(grid, brute);
    expect(grid.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(stats.candidatesTested, greaterThan(0));
  });

  test(
      '... and on a generated corpus with hundreds of labels, overflow included',
      () {
    final doc = generateDocument(
      3000,
      definitionCount: 20,
      instanceCount: 150,
      nestingDepth: 1,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
      labelFraction: 0.05,
      attributedInstanceFraction: 0.2,
      measurer: measurer,
    );
    // One line across the whole floor, at a handle above every label's: the
    // generated rooms are 30-120 units and a label box is hundreds, so no
    // room wall spans kClassifyOverflowCells cells on its own. This one
    // spans hundreds, reaches every label on the diagonal, and is what
    // makes `stats.overflow > 0` below a fact rather than a hope.
    final e = doc.extents;
    addLine(doc, doc.rootHandle, doc.handleSeed.next(), e.minX, e.minY, e.maxX,
        e.maxY);
    final (data, count, texts) =
        collect(doc, measurer, const Size(1400, 900), 2.0);
    expect(texts.length, greaterThan(50), reason: 'a real label population');
    final stats = ClassifyStats();
    final grid = classifyTextPatches(data, count, texts,
        devicePixelRatio: 2.0, stats: stats);
    final brute = classifyTextPatchesBruteForce(data, count, texts,
        devicePixelRatio: 2.0);
    // MUTATION (M-F9): skip the overflow list -> a long wall through a label
    // is missing from its patch. MUTATION (M-F10): bin by the min corner
    // only -- `cx1 = cx0` (and/or `cy1 = cy0`) at the binning site -- so a
    // multi-cell instance lands in one cell and a label in its other cells
    // misses it. (The plan's original M-F10, `.floor()` -> `.round()`, is
    // EQUIVALENT: one closure pair serves binning and lookup, and a
    // monotone shift of the whole grid stays conservative; recorded as
    // equivalent in the mutation log.)
    expectSamePatches(grid, brute);
    expect(grid.length, greaterThan(3));
    expect(grid.any((p) => p.instanceCount > 1), isTrue);
    expect(stats.overflow, greaterThan(0),
        reason: 'a long wall spans more than kClassifyOverflowCells cells, '
            'or the overflow branch is untested here');
    expect(stats.binned, greaterThan(1000));
    expect(stats.candidatesTested, lessThan(texts.length * count ~/ 2),
        reason: 'the grid must test a fraction of the pairs the brute force '
            'does, or it is not the lever criterion 7 needs');
    // Reported, not gated: the two costs side by side.
    final w1 = Stopwatch()..start();
    classifyTextPatches(data, count, texts, devicePixelRatio: 2.0);
    w1.stop();
    final w2 = Stopwatch()..start();
    classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 2.0);
    w2.stop();
    // ignore: avoid_print
    print('CLASSIFY grid=${w1.elapsedMicroseconds / 1000} ms '
        'brute=${w2.elapsedMicroseconds / 1000} ms '
        'instances=$count labels=${texts.length} '
        'binned=${stats.binned} overflow=${stats.overflow} '
        'skipped=${stats.skipped} tested=${stats.candidatesTested} '
        'cells=${stats.cellsX}x${stats.cellsY}');
  });

  test('no labels: an empty list, no grid built', () {
    final doc = textOverlapFixture(measurer);
    final (data, count, _) = collect(doc, measurer, kViewport, 1.0);
    final stats = ClassifyStats();
    expect(
        classifyTextPatches(data, count, const [],
            devicePixelRatio: 1.0, stats: stats),
        isEmpty);
    expect(stats.cellsX, 0);
  });
}

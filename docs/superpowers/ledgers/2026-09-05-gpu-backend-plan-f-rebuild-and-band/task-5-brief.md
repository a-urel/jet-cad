### Task 5: The classification gets a grid, and the brute force stays as the oracle

**Files:**
- Modify: `lib/src/gpu/text_patches.dart`
- Test: `test/gpu/classify_grid_test.dart`; `test/gpu/text_patches_test.dart` unchanged and still green

**Interfaces:**
- Consumes: `_reaches` (Plan E, unchanged), `TextPatch`, `ResidentTextRecord`,
  `InstanceFieldOffset`, `kFloatsPerInstance`, `generateDocument`
  (`package:jet_cad_2d/testing.dart`).
- Produces: `classifyTextPatches(data, count, texts, {devicePixelRatio,
  bandLowerScale, ClassifyStats? stats})` — same call shape, one optional
  parameter added — `classifyTextPatchesBruteForce(...)` (`@visibleForTesting`),
  `ClassifyStats`, `kClassifyOverflowCells`.

- [ ] **Step 1: Write the failing tests**

`test/gpu/classify_grid_test.dart`:

```dart
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
(Float32List, int, List<ResidentTextRecord>) collect(
    DraftDocument doc, FlutterTextMeasurer measurer, Size viewport, double dpr) {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      minTextCapPixels: 0);
  final frame =
      collectionFrameFor(ViewportTransform.fit(doc.extents, viewport), doc.extents);
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
    final brute =
        classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 1.0);
    expectSamePatches(grid, brute);
    expect(grid.length, 2, reason: 'COVERED and GRAZED (Plan E)');
    expect(stats.candidatesTested, greaterThan(0));
  });

  test('... and on a generated corpus with hundreds of labels, overflow included',
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
    final brute =
        classifyTextPatchesBruteForce(data, count, texts, devicePixelRatio: 2.0);
    // MUTATION (M-F9): skip the overflow list -> a long wall through a label
    // is missing from its patch. MUTATION (M-F10): `.floor()` -> `.round()`
    // on the cell range -> an instance in a cell's lower half is binned one
    // cell late and a label at that edge misses it.
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
    expect(classifyTextPatches(data, count, const [], devicePixelRatio: 1.0,
        stats: stats), isEmpty);
    expect(stats.cellsX, 0);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/gpu/classify_grid_test.dart`
Expected: FAIL — `ClassifyStats`, `classifyTextPatchesBruteForce` undefined.

- [ ] **Step 3: The grid**

In `lib/src/gpu/text_patches.dart`, add `import 'package:meta/meta.dart';`,
and beside `kBandLowerScale`/`kBandUpperScale`:

```dart
/// Cells an instance's reach-expanded box may span before it leaves the
/// grid for the overflow list, which every label tests. A long wall through
/// a floor plan would otherwise be appended to hundreds of buckets.
const int kClassifyOverflowCells = 16;

/// What one `classifyTextPatches` call did -- diagnostics, for the tests and
/// the harness. Zero everywhere when there are no labels.
class ClassifyStats {
  int cellsX = 0, cellsY = 0;

  /// Instances binned into cells; instances sent to the overflow list;
  /// instances whose expanded box misses every label's union (never tested).
  int binned = 0, overflow = 0, skipped = 0;

  /// `_reaches` calls made. The brute force makes `labels x later instances`.
  int candidatesTested = 0;
}
```

Rename the existing function to `classifyTextPatchesBruteForce`, mark it
`@visibleForTesting`, keep its body and doc comment word for word, and add
one line to the doc: *"**The oracle.** `classifyTextPatches` is the grid; this
is Plan E's loop, kept so `classify_grid_test.dart` can prove the two return
the same list byte for byte."*

Then the new `classifyTextPatches`, with the old function's doc comment
moved onto it and this paragraph added: *"**A uniform grid over the labels'
union** (Ruling F7). Cell size is the largest label box; an instance's
reach-expanded box is binned into every cell it touches, or into the overflow
list past [kClassifyOverflowCells]; a label tests only the instances in the
cells its box touches, deduplicated by a stamp array, plus the overflow list.
Hit indices are **sorted** so the sub-buffer stays a subsequence of the main
buffer in the main buffer's order -- indices, never the buffer."*

```dart
List<TextPatch> classifyTextPatches(
  Float32List data,
  int instanceCount,
  List<ResidentTextRecord> texts, {
  required double devicePixelRatio,
  double bandLowerScale = kBandLowerScale,
  ClassifyStats? stats,
}) {
  if (texts.isEmpty) return const <TextPatch>[];
  final unitsPerDevicePixel = 1.0 / (devicePixelRatio * bandLowerScale);

  // The labels' union, and the largest label box: the cell.
  var uMinX = double.infinity, uMinY = double.infinity;
  var uMaxX = double.negativeInfinity, uMaxY = double.negativeInfinity;
  var cell = 0.0;
  for (final t in texts) {
    if (t.boxMinX < uMinX) uMinX = t.boxMinX;
    if (t.boxMinY < uMinY) uMinY = t.boxMinY;
    if (t.boxMaxX > uMaxX) uMaxX = t.boxMaxX;
    if (t.boxMaxY > uMaxY) uMaxY = t.boxMaxY;
    final w = t.boxMaxX - t.boxMinX, h = t.boxMaxY - t.boxMinY;
    if (w > cell) cell = w;
    if (h > cell) cell = h;
  }
  if (!(cell > 0)) cell = 1.0;
  // No more than 256 cells a side: a huge union over tiny labels would
  // otherwise build a grid nobody can afford at rebuild.
  final cellW = math.max(cell, (uMaxX - uMinX) / 256);
  final cellH = math.max(cell, (uMaxY - uMinY) / 256);
  final nx = math.max(1, ((uMaxX - uMinX) / cellW).ceil());
  final ny = math.max(1, ((uMaxY - uMinY) / cellH).ceil());
  if (stats != null) {
    stats.cellsX = nx;
    stats.cellsY = ny;
  }
  int cellX(double x) => ((x - uMinX) / cellW).floor().clamp(0, nx - 1);
  int cellY(double y) => ((y - uMinY) / cellH).floor().clamp(0, ny - 1);

  final buckets = List<List<int>>.generate(nx * ny, (_) => <int>[]);
  final overflow = <int>[];
  final box = Float64List(4);
  for (var i = 0; i < instanceCount; i++) {
    _expandedBox(data, i, unitsPerDevicePixel, box);
    if (box[2] < uMinX || box[0] > uMaxX || box[3] < uMinY || box[1] > uMaxY) {
      if (stats != null) stats.skipped++;
      continue;
    }
    final cx0 = cellX(box[0]), cx1 = cellX(box[2]);
    final cy0 = cellY(box[1]), cy1 = cellY(box[3]);
    if ((cx1 - cx0 + 1) * (cy1 - cy0 + 1) > kClassifyOverflowCells) {
      overflow.add(i);
      if (stats != null) stats.overflow++;
      continue;
    }
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        buckets[cy * nx + cx].add(i);
      }
    }
    if (stats != null) stats.binned++;
  }

  // Stamp: the 1-based index of the label that last saw instance i. Zero is
  // "never", so no fill is needed.
  final stamp = Int32List(instanceCount);
  final patches = <TextPatch>[];
  final hits = <int>[];
  for (var ti = 0; ti < texts.length; ti++) {
    final t = texts[ti];
    final mark = ti + 1;
    hits.clear();
    final cx0 = cellX(t.boxMinX), cx1 = cellX(t.boxMaxX);
    final cy0 = cellY(t.boxMinY), cy1 = cellY(t.boxMaxY);
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        for (final i in buckets[cy * nx + cx]) {
          if (i < t.instanceIndex || stamp[i] == mark) continue;
          stamp[i] = mark;
          if (stats != null) stats.candidatesTested++;
          if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
        }
      }
    }
    for (final i in overflow) {
      if (i < t.instanceIndex) continue;
      if (stats != null) stats.candidatesTested++;
      if (_reaches(data, i, t, unitsPerDevicePixel)) hits.add(i);
    }
    if (hits.isEmpty) continue;
    // Indices, not the buffer: main-buffer order is the draw order.
    hits.sort();
    final sub = Float32List(hits.length * kFloatsPerInstance);
    for (var k = 0; k < hits.length; k++) {
      sub.setRange(k * kFloatsPerInstance, (k + 1) * kFloatsPerInstance, data,
          hits[k] * kFloatsPerInstance);
    }
    patches.add(
        TextPatch(textIndex: ti, instances: sub, instanceCount: hits.length));
  }
  return patches;
}

/// Instance [i]'s reach-expanded box into [out] as `minX, minY, maxX, maxY`
/// -- the same points-per-kind and reach-per-kind as [_reaches] (Rulings
/// E4, E5), written out rather than shared so [_reaches] stays Plan E's
/// oracle word for word; `classify_grid_test.dart` proves they agree.
void _expandedBox(
    Float32List d, int i, double unitsPerDevicePixel, Float64List out) {
  final o = i * kFloatsPerInstance;
  final kind = d[o + InstanceFieldOffset.kind];
  final half = d[o + InstanceFieldOffset.halfWidth];
  final int points;
  final double reachDevice;
  if (kind < 0.5) {
    points = 2;
    reachDevice = half;
  } else if (kind < 1.5) {
    points = 3;
    reachDevice = half * kMiterLimit;
  } else if (kind < 2.5) {
    points = 1;
    reachDevice = half;
  } else {
    points = 3;
    reachDevice = 0;
  }
  final reach = reachDevice * unitsPerDevicePixel;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (var p = 0; p < points; p++) {
    final x = d[o + InstanceFieldOffset.x0 + p * 2];
    final y = d[o + InstanceFieldOffset.y0 + p * 2];
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }
  out[0] = minX - reach;
  out[1] = minY - reach;
  out[2] = maxX + reach;
  out[3] = maxY + reach;
}
```

`import 'dart:math' as math;` at the top if the file does not already have it.

- [ ] **Step 4: Run the new file and Plan E's; expect PASS, and read the printed `CLASSIFY` line into the report**

Run: `flutter test test/gpu/classify_grid_test.dart test/gpu/text_patches_test.dart test/gpu/text_order_test.dart`

- [ ] **Step 5: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/text_patches.dart test/gpu/classify_grid_test.dart
git commit -m "perf(gpu): classifyTextPatches on a uniform grid, with Plan E's loop kept as the oracle"
```

---

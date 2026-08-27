// The naked-eye corpus, and the properties that make it worth looking at.
//
// A tile seam is a sub-pixel disagreement between what a baked tile holds and
// what the live fallback draws over the same world. Gap G1 says no widget test
// in this repo can produce one -- software Skia does not antialias
// `drawVertices` at all -- so this corpus exists to be looked at on a GPU, and
// these tests only guard the properties that make looking useful.
import 'package:dev_harness_2d/main.dart';
import 'package:dev_harness_2d/seam_corpus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

void main() {
  /// Every line's slope in the document, keyed to six decimals so two lines
  /// drawn at the same angle collapse to one entry. Verticals are dropped:
  /// they have no finite slope.
  Set<int> slopesOf(DraftDocument doc) {
    final slopes = <int>{};
    for (final slot in doc.entities.liveSlots) {
      final record = doc.entities.read(slot);
      if (record.kind != EntityKind.line) continue;
      final c = doc.geometry.read(record.geomIndex).coords;
      final dx = c[2] - c[0], dy = c[3] - c[1];
      if (dx == 0) continue;
      slopes.add((dy / dx * 1e6).round());
    }
    return slopes;
  }

  test('the fan carries at least eight distinct slopes', () {
    // A fan collapsed to a single angle -- or a loop that only ever emits its
    // last iteration -- leaves the grid's horizontals and nothing else.
    expect(slopesOf(seamCorpus()).length, greaterThanOrEqualTo(8));
  });

  test('at least four of those slopes are shallow', () {
    // Antialias beading is a shallow-angle phenomenon: a line at 45 degrees
    // steps one pixel per pixel and hides it. A fan of steep angles would
    // satisfy the count above and still show nothing.
    final shallow =
        slopesOf(seamCorpus()).where((s) => s != 0 && s.abs() < 200000);
    expect(shallow.length, greaterThanOrEqualTo(4));
  });

  test('the corpus spans a real area on both axes', () {
    final e = seamCorpus().extents;
    expect(e.maxX - e.minX, greaterThan(1000.0));
    expect(e.maxY - e.minY, greaterThan(1000.0));
  });

  test('the corpus sits far from the origin', () {
    // The dominant failure mode in this repo is the degenerate fixture, and a
    // drawing at the origin is one: the residual reaching float32 shrinks, the
    // rebase origin stops earning its keep, and a seam that only appears far
    // out never appears at all. This corpus sits where the measurement corpus
    // sits.
    final e = seamCorpus().extents;
    expect(e.minX.abs(), greaterThan(1e6));
    expect(e.minY.abs(), greaterThan(1e6));
  });

  test('curves are present alongside the straight lines', () {
    final kinds = <EntityKind>{};
    final doc = seamCorpus();
    for (final slot in doc.entities.liveSlots) {
      kinds.add(doc.entities.read(slot).kind);
    }
    expect(
        kinds,
        containsAll(<EntityKind>{
          EntityKind.line,
          EntityKind.circle,
          EntityKind.arc,
        }));
  });

  test('two lineweight regimes are on screen at once', () {
    // A thick stroke hides a half-pixel shift; a hairline shows it. Seeing
    // the difference requires both, so neither may be dropped.
    final weights = <int>{};
    final doc = seamCorpus();
    for (final slot in doc.entities.liveSlots) {
      weights.add(doc.entities.read(slot).lineweight);
    }
    expect(weights.length, greaterThanOrEqualTo(2));
  });

  test('the corpus stays small enough to read by eye', () {
    expect(seamCorpus().entities.liveCount, lessThan(200));
  });

  // The corpus being well-formed is not the same as the corpus being
  // paintable, and the first of these tests was written after a window that
  // came up empty. `DraftCanvas` requires the document to carry a
  // `FlutterTextMeasurer`; a document built on the default zero-metric
  // `InsertionPointMeasurer` throws an `ArgumentError` while building, which
  // in profile mode renders as a plain grey `ErrorWidget` -- no red screen, no
  // message, nothing in the log.
  testWidgets('the corpus paints', (tester) async {
    late CanvasDrawSink sink;
    VerticesDrawSink? vertices;
    await tester.pumpWidget(HarnessApp(
      document: seamCorpus(),
      onReady: (_, __, ___, s, v, ____, _____) {
        sink = s;
        vertices = v;
      },
    ));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Which counter carries the ink depends on the backend `DraftCanvas`
    // actually resolved, not on what was asked for: the vertices sink draws
    // through `drawVertices` and never touches `CanvasDrawSink`.
    final drew =
        vertices == null ? sink.canvasCallCount : vertices!.totalFlushCount;
    expect(drew, greaterThan(0));
  });

  test('the corpus carries a measurer DraftCanvas will accept', () {
    expect(seamCorpus().textMeasurer, isA<FlutterTextMeasurer>());
  });

  test('CORPUS accepts its two values and rejects anything else', () {
    expect(parseCorpus('measure'), HarnessCorpus.measure);
    expect(parseCorpus('simple'), HarnessCorpus.simple);
    // The rule every define in this harness follows: a value that is not
    // understood is an error, never a silent fall back to the default. Plan 3c
    // lost a full device run to `bool.fromEnvironment('TEXT')` reading
    // `TEXT=1` as false.
    expect(() => parseCorpus('1'), throwsStateError);
    expect(() => parseCorpus(''), throwsStateError);
  });
}

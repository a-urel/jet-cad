import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'rig/rig_support.dart';

const TextStyleRecord _style =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');

void main() {
  test('the same string in two colours is two entries, not one', () {
    final m = FlutterTextMeasurer();
    m.paragraphFor('WC', const Handle(7), _style, 0xFFFF0000);
    m.paragraphFor('WC', const Handle(7), _style, 0xFF00FF00);
    // ui.Paragraph bakes its colour and drawParagraph takes no Paint, so a key
    // without argb would draw one of these in the wrong colour.
    expect(m.layoutCount, 2);
    expect(m.liveParagraphCount, 2);
  });

  test('a repeat request lays out nothing and allocates no metrics', () {
    final m = FlutterTextMeasurer();
    final a = m.measure(text: 'WC', style: _style);
    final before = m.layoutCount;
    final b = m.measure(text: 'WC', style: _style);
    expect(m.layoutCount, before);
    // The pick path measures per candidate; a fresh object per call breaks
    // query_allocation_test.
    expect(identical(a, b), isTrue);
  });

  test('eviction disposes the paragraph', () {
    final m = FlutterTextMeasurer(limit: 2);
    m.paragraphFor('A', const Handle(7), _style, 0xFF000000);
    m.paragraphFor('B', const Handle(7), _style, 0xFF000000);
    m.paragraphFor('C', const Handle(7), _style, 0xFF000000);
    expect(m.evictionCount, 1);
    expect(m.liveParagraphCount, 2);
    // A Paragraph holds native glyph memory: a bound on the count is not a
    // bound on the memory unless eviction releases it.
    expect(m.debugLastEvicted!.debugDisposed, isTrue);
  });

  test('metrics are cap-height based and taken at the nominal size', () {
    final m = FlutterTextMeasurer();
    final metrics = m.measure(text: 'WC', style: _style);
    expect(
        metrics.capHeight, closeTo(kCapHeightRatio * kNominalTextPixels, 1e-9));
    // Exact, not `greaterThan(0)`: the layout em size is the one thing this
    // class must never get wrong, and a positivity check survives every wrong
    // size there is. flutter_test's own font is exactly 0.75em ascent /
    // 0.25em descent / 1em per character, so laying `WC` out at the nominal
    // size pins all three numbers. If a Flutter upgrade moves the test font,
    // this fails loudly rather than going quiet.
    expect(metrics.ascent, closeTo(0.75 * kNominalTextPixels, 1e-9));
    expect(metrics.descent, closeTo(0.25 * kNominalTextPixels, 1e-9));
    expect(metrics.advanceWidth, closeTo(2 * kNominalTextPixels, 1e-9));
  });

  test('an empty string measures zero, not the negative float floor', () {
    // `Paragraph.longestLine` is -FLT_MAX for an empty paragraph, and -FLT_MAX
    // is finite, so no isFinite guard downstream would catch it. entityBounds
    // has no isEmpty guard of its own (Task 10's guard is on the *draw* path,
    // not the bounds path), so an empty text entity would hand doc.extents and
    // the R-tree a box 3.4e38 wide.
    final flutter = FlutterTextMeasurer().measure(text: '', style: _style);
    expect(flutter.advanceWidth, 0.0);

    // The seam's whole premise is that the two measurers are interchangeable:
    // the differential oracle is only valid if they agree here.
    final model = MetricModelMeasurer().measure(text: '', style: _style);
    expect(flutter.advanceWidth, model.advanceWidth);
  });

  test('resetCounters zeroes the counters and keeps the cache warm', () {
    // The counters are per-measurement; the cache is what is being measured.
    // If reset also cleared the cache, every rig row would report one new
    // layout per visible string — and the exit gate's zero-new-layouts row
    // would read as failing on a cache that was working perfectly. Nothing
    // else in the suite would notice, because the numbers stay internally
    // consistent; they are just measurements of the wrong thing.
    final measurer = FlutterTextMeasurer();
    for (final text in ['WC', 'STAIR', 'LOBBY']) {
      measurer.paragraphFor(text, const Handle(7), _style, 0xFF000000);
    }
    expect(measurer.layoutCount, 3);
    expect(measurer.liveParagraphCount, 3);

    measurer.resetCounters();
    expect(measurer.layoutCount, 0);
    expect(measurer.evictionCount, 0);
    expect(measurer.liveParagraphCount, 3,
        reason: 'reset must not evict: the warm cache is the measurement');

    // The steady state the gate row asserts: the same strings again, no new
    // layouts. This reads zero either way if the cache were cleared *and* the
    // counters lied, so the entry count above is the load-bearing half.
    for (final text in ['WC', 'STAIR', 'LOBBY']) {
      measurer.paragraphFor(text, const Handle(7), _style, 0xFF000000);
    }
    expect(measurer.layoutCount, 0);
    expect(measurer.liveParagraphCount, 3);
  });

  test('TextKeySink keys the same triple this cache does', () {
    // `TextKeySink` exists to count the entries a frame would need, and that
    // count is the number the zero-new-layouts gate row's feasibility rests
    // on. It reimplements the cache key rather than sharing it — `_CacheKey`
    // is private, and a rig that reached into the cache would be measuring the
    // cache with itself — so the two definitions have to be checked against
    // each other, or the rig can under-report the pressure by exactly the
    // factor of the colour axis and nothing would ever say so.
    const style = Handle(7);
    final sink = TextKeySink();
    const red = ResolvedStyle(
        argb: 0xFFFF0000,
        lineweightHundredths: 25,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0);
    const green = ResolvedStyle(
        argb: 0xFF00FF00,
        lineweightHundredths: 25,
        linetype: ReservedHandles.continuousLinetype,
        linetypeScale: 1.0);

    sink
      ..text('WC', style, red)
      ..text('WC', style, red)
      ..text('WC', style, green)
      ..text('STAIR', style, red)
      ..text('WC', const Handle(8), red);
    expect(sink.textOps, 5);
    expect(sink.keys.length, 4);

    // The same five requests through the real cache: the rig's count and the
    // cache's entry count are the same number, which is the only reason
    // reading one tells you anything about the other.
    final measurer = FlutterTextMeasurer();
    measurer
      ..paragraphFor('WC', style, _style, red.argb)
      ..paragraphFor('WC', style, _style, red.argb)
      ..paragraphFor('WC', style, _style, green.argb)
      ..paragraphFor('STAIR', style, _style, red.argb)
      ..paragraphFor('WC', const Handle(8), _style, red.argb);
    expect(measurer.liveParagraphCount, sink.keys.length);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'rig/rig_support.dart';

const TextStyleRecord _style =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');

void main() {
  test('the same string in two colours is two entries, not one', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    m.paragraphFor('WC', const Handle(7), _style, 0xFFFF0000);
    m.paragraphFor('WC', const Handle(7), _style, 0xFF00FF00);
    // ui.Paragraph bakes its colour and drawParagraph takes no Paint, so a key
    // without argb would draw one of these in the wrong colour.
    expect(m.layoutCount, 2);
    expect(m.liveParagraphCount, 2);
  });

  test('a repeat request lays out nothing and allocates no metrics', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final a = m.measure(text: 'WC', style: _style);
    final before = m.layoutCount;
    final b = m.measure(text: 'WC', style: _style);
    expect(m.layoutCount, before);
    // The pick path measures per candidate; a fresh object per call breaks
    // query_allocation_test.
    expect(identical(a, b), isTrue);
  });

  test('eviction disposes the paragraph', () {
    final m = FlutterTextMeasurer(paragraphLimit: 2);
    addTearDown(m.clear);
    m.paragraphFor('A', const Handle(7), _style, 0xFF000000);
    m.paragraphFor('B', const Handle(7), _style, 0xFF000000);
    m.paragraphFor('C', const Handle(7), _style, 0xFF000000);
    expect(m.paragraphEvictionCount, 1);
    expect(m.liveParagraphCount, 2);
    // A Paragraph holds native glyph memory: a bound on the count is not a
    // bound on the memory unless eviction releases it.
    expect(m.debugLastEvicted!.debugDisposed, isTrue);
  });

  test('metrics are cap-height based and taken at the nominal size', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
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
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final flutter = measurer.measure(text: '', style: _style);
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
    addTearDown(measurer.clear);
    for (final text in ['WC', 'STAIR', 'LOBBY']) {
      measurer.paragraphFor(text, const Handle(7), _style, 0xFF000000);
    }
    expect(measurer.layoutCount, 3);
    expect(measurer.liveParagraphCount, 3);

    measurer.resetCounters();
    expect(measurer.layoutCount, 0);
    expect(measurer.paragraphEvictionCount, 0);
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
    addTearDown(measurer.clear);
    measurer
      ..paragraphFor('WC', style, _style, red.argb)
      ..paragraphFor('WC', style, _style, red.argb)
      ..paragraphFor('WC', style, _style, green.argb)
      ..paragraphFor('STAIR', style, _style, red.argb)
      ..paragraphFor('WC', const Handle(8), _style, red.argb);
    expect(measurer.liveParagraphCount, sink.keys.length);
  });

  test('measure disposes its probe and leaves no paragraph entry', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    m.measure(text: 'WC', style: _style);
    expect(m.layoutCount, 1);
    // The probe is built at kMetricsProbeArgb, which ACI 7 (white) is not, so
    // keeping it would hold two entries per string and halve the paragraph
    // cache's effective capacity.
    expect(m.liveParagraphCount, 0);
    expect(m.liveMetricsCount, 1);
    // A Paragraph holds native glyph memory: an entry-count bound proves
    // nothing about the probe's memory unless disposal actually released it.
    expect(m.debugLastProbe!.debugDisposed, isTrue);
  });

  test('a metrics sweep does not evict drawn paragraphs', () {
    // Row 10 of the exit gate, at unit scale: a full extents recomputation
    // walks every string in the document with no LOD protection. Before the
    // split it would have walked straight through the paragraph cache.
    final m = FlutterTextMeasurer(paragraphLimit: 4, metricsLimit: 1024);
    addTearDown(m.clear);
    for (final t in ['A', 'B', 'C', 'D']) {
      m.paragraphFor(t, const Handle(7), _style, 0xFFFFFFFF);
    }
    expect(m.liveParagraphCount, 4);

    for (var i = 0; i < 200; i++) {
      m.measure(text: 'SWEEP$i', style: _style);
    }
    expect(m.paragraphEvictionCount, 0);
    expect(m.liveParagraphCount, 4);

    final layoutsBefore = m.layoutCount;
    for (final t in ['A', 'B', 'C', 'D']) {
      m.paragraphFor(t, const Handle(7), _style, 0xFFFFFFFF);
    }
    expect(m.layoutCount, layoutsBefore,
        reason: 'the sweep must leave the drawn set warm');
  });

  test(
      'the metrics map evicts on its own bound, and it is not the paragraph one',
      () {
    final m = FlutterTextMeasurer(paragraphLimit: 512, metricsLimit: 2);
    addTearDown(m.clear);
    m.measure(text: 'A', style: _style);
    m.measure(text: 'B', style: _style);
    m.measure(text: 'C', style: _style);
    expect(m.metricsEvictionCount, 1);
    expect(m.paragraphEvictionCount, 0);
    expect(m.liveMetricsCount, 2);
  });

  test('the default metrics bound is not the paragraph bound', () {
    // **Landed because a named mutant survived.** Plan 3f's mutant 7 —
    // `metricsLimit` defaulted to `kParagraphCacheLimit` — passed the whole
    // suite when it was fired in Task 9, because every other test in this
    // file constructs the measurer with *both* limits given explicitly, so
    // the defaults themselves were untested. At rig scale the mutant is
    // plainly visible and unasserted: the 50,000-entity corpus reads
    // `liveMetrics=512 metricsEvictions=608634` under it against
    // `liveMetrics=4020 metricsEvictions=0` shipped. This is that difference
    // at unit scale, where something fails rather than merely prints.
    //
    // The behavioural assertions come first on purpose: a test whose only
    // failing line is `expect(m.metricsLimit, kMetricsCacheLimit)` restates
    // the mutation instead of observing it.
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    // One more distinct string than the paragraph cache could hold. A metrics
    // map bounded by the paragraph limit evicts here; the real one does not.
    for (var i = 0; i <= kParagraphCacheLimit; i++) {
      m.measure(text: 'SWEEP$i', style: _style);
    }
    expect(m.metricsEvictionCount, 0);
    expect(m.liveMetricsCount, kParagraphCacheLimit + 1);
    // And the sweep held no paragraphs at all, which is the other half of
    // why the two bounds are allowed to differ by an order of magnitude.
    expect(m.liveParagraphCount, 0);
    expect(m.paragraphLimit, kParagraphCacheLimit);
    expect(m.metricsLimit, kMetricsCacheLimit);
  });

  test('clear empties both maps', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final p = m.paragraphFor('WC', const Handle(7), _style, 0xFFFFFFFF);
    m.measure(text: 'STAIR', style: _style);
    expect(m.liveParagraphCount, 1);
    expect(m.liveMetricsCount, 1);
    m.clear();
    expect(m.liveParagraphCount, 0);
    expect(m.liveMetricsCount, 0);
    // A Paragraph holds native glyph memory: dropping it from the map is not
    // enough unless clear() actually disposes it.
    expect(p.debugDisposed, isTrue);
  });
}

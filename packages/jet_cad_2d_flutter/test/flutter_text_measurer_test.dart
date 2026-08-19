import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

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
}

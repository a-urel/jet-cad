import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

const _style = TextStyleRecord(
  handle: Handle(24),
  name: 'Standard',
  fontFamily: 'Roboto',
);

void main() {
  test(
      'the metric model is deterministic and its ascent differs from its descent',
      () {
    final m = MetricModelMeasurer();
    final metrics = m.measure(text: 'WC', style: _style);

    expect(metrics.advanceWidth, closeTo(2 * 0.55 * kNominalTextPixels, 1e-9));
    expect(metrics.ascent, closeTo(0.8 * kNominalTextPixels, 1e-9));
    expect(metrics.descent, closeTo(0.2 * kNominalTextPixels, 1e-9));
    expect(metrics.capHeight, closeTo(0.7 * kNominalTextPixels, 1e-9));
    // A model whose ascent equals its descent hides every vertical
    // justification defect, so this inequality is load-bearing.
    expect(metrics.ascent, isNot(closeTo(metrics.descent, 1e-9)));
  });

  test('measure returns the identical instance on a repeat call', () {
    final m = MetricModelMeasurer();
    final a = m.measure(text: 'T-0001', style: _style);
    final b = m.measure(text: 'T-0001', style: _style);
    // The pick path measures per candidate. A fresh object per call breaks
    // query_allocation_test.
    expect(identical(a, b), isTrue);
  });

  test('two models with different ratios do not share memoised metrics', () {
    // The memo is per measurer instance and keyed by string length alone, so
    // this is the test that would catch it going back to a shared map keyed
    // by length only — the second model would then silently read the first
    // model's cached metrics.
    final wide = MetricModelMeasurer(advanceRatio: 0.9);
    final narrow = MetricModelMeasurer(advanceRatio: 0.1);
    final wideMetrics = wide.measure(text: 'WC', style: _style);
    final narrowMetrics = narrow.measure(text: 'WC', style: _style);
    expect(wideMetrics.advanceWidth, isNot(equals(narrowMetrics.advanceWidth)));
  });

  test('the insertion-point measurer is a declared lower bound', () {
    expect(const InsertionPointMeasurer().measure(text: 'WC', style: _style),
        same(TextMetrics.zero));
  });
}

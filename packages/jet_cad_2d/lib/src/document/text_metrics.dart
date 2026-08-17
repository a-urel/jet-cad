import 'package:meta/meta.dart';

import 'tables.dart';

/// The em size every paragraph is laid out at.
///
/// Layout is size-independent here on purpose: height, rotation, width factor
/// and oblique angle are all transforms, so one laid-out paragraph serves the
/// same string at every size. Laying out at the *effective* size instead
/// renders correctly and silently destroys the cache.
const double kNominalTextPixels = 100.0;

/// Cap height as a fraction of the em size.
///
/// DXF's text height is the height of a capital letter; a font's `fontSize` is
/// the em size. `dart:ui` exposes no cap height — `computeLineMetrics` gives
/// ascent and descent only — so this constant stands in for it and the
/// deviation is declared rather than hidden.
const double kCapHeightRatio = 0.7;

/// Font metrics for one string laid out at [kNominalTextPixels].
///
/// Everything else a text entity needs — height, rotation, width factor,
/// oblique angle, insertion alignment — is a transform applied to this box,
/// not a reason to re-measure.
@immutable
class TextMetrics {
  const TextMetrics({
    required this.advanceWidth,
    required this.ascent,
    required this.descent,
    required this.capHeight,
  });

  final double advanceWidth;
  final double ascent;
  final double descent;
  final double capHeight;

  static const TextMetrics zero =
      TextMetrics(advanceWidth: 0, ascent: 0, descent: 0, capHeight: 0);
}

/// Supplies font metrics at [kNominalTextPixels].
///
/// Takes the [TextStyleRecord], not a handle: `fontFamily`, `widthFactor` and
/// `obliqueAngle` live on the record, and a measurer is constructed before the
/// document that owns the table, so it cannot look one up.
abstract class TextMeasurer {
  TextMetrics measure({required String text, required TextStyleRecord style});
}

/// Contributes nothing beyond the zero box.
///
/// Correct-but-minimal: metrics computed with it are a lower bound, which is
/// the honest answer when no font stack is present. It also keeps engine tests
/// deterministic across machines, since real text layout is font- and
/// platform-dependent.
class InsertionPointMeasurer implements TextMeasurer {
  const InsertionPointMeasurer();

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      TextMetrics.zero;
}

/// Deterministic, font-free metrics for engine tests.
///
/// Ascent and descent use different ratios on purpose: a model where they
/// match would hide every vertical-justification defect in code that
/// consumes [TextMetrics], since top- and bottom-anchored layouts would land
/// on the same result by accident.
class MetricModelMeasurer implements TextMeasurer {
  const MetricModelMeasurer({
    this.advanceRatio = 0.55,
    this.ascentRatio = 0.8,
    this.descentRatio = 0.2,
    this.capRatio = kCapHeightRatio,
  });

  final double advanceRatio;
  final double ascentRatio;
  final double descentRatio;
  final double capRatio;

  // Keyed by the ratios as well as the string length: two measurers with
  // different ratios must not collide on the same entry just because they
  // happen to be asked about strings of the same length. Memoised at all
  // because the pick path measures per candidate and the allocation harness
  // (test/invariants/query_allocation_test.dart) forbids a fresh object
  // there — a repeat call must return the identical instance.
  static final Map<
      (
        int length,
        double advanceRatio,
        double ascentRatio,
        double descentRatio,
        double capRatio
      ),
      TextMetrics> _cache = {};

  @override
  TextMetrics measure({required String text, required TextStyleRecord style}) =>
      _cache.putIfAbsent(
          (text.length, advanceRatio, ascentRatio, descentRatio, capRatio),
          () => TextMetrics(
                advanceWidth: text.length * advanceRatio * kNominalTextPixels,
                ascent: ascentRatio * kNominalTextPixels,
                descent: descentRatio * kNominalTextPixels,
                capHeight: capRatio * kNominalTextPixels,
              ));
}

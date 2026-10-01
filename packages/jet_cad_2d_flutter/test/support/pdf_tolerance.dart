import 'package:jet_cad_2d/jet_cad_2d.dart';

/// Half a unit in the fifth decimal: the most the `pdf` package's
/// `PdfNum.precision = 5` rounding moves any number it writes (spec 13 F-15).
const double kPdfRounding = 5e-6;

/// Slack for the double arithmetic on both sides of the comparison, and for
/// the second-order products of two rounding errors (at most 2.5e-11 each).
/// It is far below [kPdfRounding] at page magnitudes.
const double _arithmetic = 1e-9;

/// How far the package's writer moves [v]: `|v − round5(v)|`. `PdfNum`
/// writes `toStringAsFixed(5)`, which is mirrored here. The result is 0 for
/// `1`, `0` and any value already on the 1e-5 grid, and at most
/// [kPdfRounding].
double pdfRoundingError(double v) =>
    (v - double.parse(v.toStringAsFixed(5))).abs();

/// The bound on each page-space coordinate of a point that `PdfDrawSink`
/// wrote at the local operands ([x], [y]) under [residual] (spec 13 T-3).
///
/// The bound is derived from the 5-decimal rule and charges every written
/// number its **actual** rounding error ([pdfRoundingError]), rather than
/// the worst case 5e-6:
///
/// - **Screen space** (no residual): the page point is `(x̃, H̃ − ỹ)`. The
///   bound is `δx`, or `δy + δH` for y.
/// - **Under a residual `[a b c d e f]`**: the page x is `ã·x̃ + c̃·ỹ + ẽ`,
///   so its error is at most `δa·|x| + |a|·δx + δc·|y| + |c|·δy + δe`.
///   The page y is `H̃ − (b̃·x̃ + d̃·ỹ + f̃)`, and its error has the same form
///   with b, d, f, plus `δH`.
///
/// The larger of the two components is returned.
///
/// [pageHeight] is the page set-up's `H`. Without it, H is charged the
/// worst case. When [operandsKnown] is false, ([x], [y]) is a point the
/// sink did not write itself, such as a sample on a cubic whose controls
/// the test does not know. Each operand is then charged the worst case 5e-6.
double pdfTolerance(
  double x,
  double y,
  Transform2? residual, {
  double? pageHeight,
  bool operandsKnown = true,
}) {
  final dH = pageHeight == null ? kPdfRounding : pdfRoundingError(pageHeight);
  final dx = operandsKnown ? pdfRoundingError(x) : kPdfRounding;
  final dy = operandsKnown ? pdfRoundingError(y) : kPdfRounding;
  final slack = _arithmetic * (1 + x.abs() + y.abs());
  if (residual == null) {
    return (dx > dy + dH ? dx : dy + dH) + slack;
  }
  final r = residual;
  final ex = pdfRoundingError(r.a) * x.abs() +
      r.a.abs() * dx +
      pdfRoundingError(r.c) * y.abs() +
      r.c.abs() * dy +
      pdfRoundingError(r.e);
  final ey = pdfRoundingError(r.b) * x.abs() +
      r.b.abs() * dx +
      pdfRoundingError(r.d) * y.abs() +
      r.d.abs() * dy +
      pdfRoundingError(r.f) +
      dH;
  return (ex > ey ? ex : ey) + slack;
}

/// The bound on a stroke's width in page units, `w̃ · sqrt|det M̃|`, for an
/// expected [deviceWidth] under [residual] (none: screen space).
///
/// `w` is rounded once, which gives `5e-6 · s`. The determinant's relative
/// error is at most `5e-6·(|a| + |b| + |c| + |d|) / |det|`, and the square
/// root halves it.
double pdfWidthTolerance(double deviceWidth, Transform2? residual) {
  if (residual == null) return kPdfRounding + _arithmetic;
  final r = residual;
  final det = r.determinant.abs();
  final s = residual.scaleMagnitude;
  return kPdfRounding * s +
      deviceWidth *
          0.5 *
          kPdfRounding *
          (r.a.abs() + r.b.abs() + r.c.abs() + r.d.abs()) /
          det +
      _arithmetic;
}

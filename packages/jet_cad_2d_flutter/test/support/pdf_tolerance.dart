import 'package:jet_cad_2d/jet_cad_2d.dart';

/// Half a unit in the fifth decimal: the most the `pdf` package's
/// `PdfNum.precision = 5` rounding moves any number it writes (spec 13 F-15).
const double kPdfRounding = 5e-6;

/// Slack for the double arithmetic on both sides of the comparison. It is
/// far below [kPdfRounding] at page magnitudes.
const double _arithmetic = 1e-9;

/// The bound on each page-space coordinate of a point that `PdfDrawSink`
/// wrote at the local operands ([x], [y]) under [residual] (spec 13 T-3).
/// The bound is derived from the 5-decimal rule, not wished smaller:
///
/// - **In screen space** (no residual): the operand is rounded once
///   (5e-6), and the page set-up's `H` is rounded once (5e-6). The bound is
///   `1e-5`.
/// - **Under a residual `[a b c d e f]`**: the page x is
///   `ã·x̃ + c̃·ỹ + ẽ`.
///   - Every matrix entry carries 5e-6, which is multiplied by `|x|`, `|y|`
///     and 1.
///   - Every operand carries 5e-6, which is multiplied by `|a|` and `|c|`
///     (y: `|b|` and `|d|`).
///   - The page set-up's `H` adds 5e-6.
///
///   The bound is `5e-6·(|x| + |y| + 1) + 5e-6·max(|a| + |c|, |b| + |d|) +
///   5e-6`.
double pdfTolerance(double x, double y, Transform2? residual) {
  if (residual == null) return 2 * kPdfRounding + _arithmetic;
  final r = residual;
  final linear = (r.a.abs() + r.c.abs()) > (r.b.abs() + r.d.abs())
      ? r.a.abs() + r.c.abs()
      : r.b.abs() + r.d.abs();
  return kPdfRounding * (x.abs() + y.abs() + 1) +
      kPdfRounding * linear +
      kPdfRounding +
      _arithmetic * (1 + x.abs() + y.abs());
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

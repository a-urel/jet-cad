import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

/// Geometric tolerance: absolute, in document units, unaffected by zoom.
///
/// This answers "are these two points the same point". It is deliberately not
/// the same thing as interaction tolerance, which is measured in screen pixels
/// and converted to world units per zoom level and answers "did the user click
/// here". Collapsing the two into one number makes geometric equality
/// zoom-dependent, so they never share a type.
///
/// The tolerance is absolute rather than relative because it is tied to the
/// document's scale: a drawing in millimetres and a drawing in kilometres want
/// different values, and that choice belongs to the document, not to the
/// magnitude of whatever pair of numbers is being compared.
@immutable
class Tolerance {
  final double linear;
  final double angular;

  const Tolerance({required this.linear, required this.angular});

  static const Tolerance standard = Tolerance(linear: 1e-9, angular: 1e-9);

  bool eq(double a, double b) => (a - b).abs() <= linear;

  bool isZero(double v) => v.abs() <= linear;

  bool eqAngle(double a, double b) => (a - b).abs() <= angular;

  bool eqPoint(Vector2 a, Vector2 b) => eq(a.x, b.x) && eq(a.y, b.y);

  /// Three-way comparison that treats near-equal values as equal, so sorts
  /// built on it stay consistent with [eq].
  int compare(double a, double b) {
    if (eq(a, b)) return 0;
    return a < b ? -1 : 1;
  }
}

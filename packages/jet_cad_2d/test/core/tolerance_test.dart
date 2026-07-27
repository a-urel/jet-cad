import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  const t = Tolerance.standard;

  test('standard tolerance is absolute in document units', () {
    expect(t.linear, 1e-9);
    expect(t.angular, 1e-9);
  });

  test('eq accepts differences within the linear tolerance', () {
    expect(t.eq(1.0, 1.0 + 1e-12), isTrue);
    expect(t.eq(1.0, 1.0 + 1e-6), isFalse);
  });

  test('eq is absolute, not relative — it does not scale with magnitude', () {
    // A relative tolerance would call these equal. Geometric tolerance is tied
    // to document scale, so it must not.
    expect(t.eq(1e6, 1e6 + 1e-3), isFalse);
  });

  test('isZero and compare agree with eq', () {
    expect(t.isZero(1e-12), isTrue);
    expect(t.isZero(1e-6), isFalse);
    expect(t.compare(1.0, 1.0 + 1e-12), 0);
    expect(t.compare(1.0, 2.0), -1);
    expect(t.compare(2.0, 1.0), 1);
  });

  test('eqPoint compares both components', () {
    expect(t.eqPoint(Vector2(1, 2), Vector2(1 + 1e-12, 2 - 1e-12)), isTrue);
    expect(t.eqPoint(Vector2(1, 2), Vector2(1, 2.5)), isFalse);
  });

  test('eqAngle uses the angular tolerance, not the linear one', () {
    final loose = const Tolerance(linear: 1e-9, angular: 1e-3);
    expect(loose.eqAngle(0.0, 1e-4), isTrue);
    expect(loose.eq(0.0, 1e-4), isFalse);
  });
}

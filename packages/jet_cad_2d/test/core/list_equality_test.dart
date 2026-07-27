import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';

void main() {
  test('compares element-wise', () {
    expect(listEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(listEquals([1, 2, 3], [1, 2, 4]), isFalse);
  });

  test('differing lengths are unequal', () {
    expect(listEquals([1, 2], [1, 2, 3]), isFalse);
    expect(listEquals(<int>[], <int>[]), isTrue);
  });

  test('identical instances short-circuit', () {
    final list = [1, 2, 3];
    expect(listEquals(list, list), isTrue);
  });

  test('works across list implementations with the same elements', () {
    // Float64List is a List<double>; the geometry payload compares these.
    expect(listEquals<double>(Float64List.fromList([1, 2]), [1.0, 2.0]), isTrue);
  });

  test('uses element equality, so value types compare by value', () {
    expect(listEquals([const Handle(1)], [const Handle(1)]), isTrue);
  });
}

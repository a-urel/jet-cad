// The kit's published example: the descriptor, the library's categories and
// a table unit's capacity, over the synchronous entries.
import 'package:flutter_test/flutter_test.dart';

// The example is not under lib/, so a relative path is the only way to it.
// ignore: avoid_relative_lib_imports
import '../example/main.dart';

void main() {
  test(
      'the example names the kit and its version, the library\'s size, no '
      'problems, six categories that sum to the library, and a table unit\'s '
      'seats', () {
    final lines = describeRestaurantKit();
    expect(lines.first, 'restaurant 0.1.3: 69 symbols, 25 table units');
    expect(lines[1], 'validate: no problems');
    final categories = lines.sublist(2, lines.length - 1);
    expect(categories, hasLength(6));
    expect(
        categories.map((l) => int.parse(l.split(': ').last)).reduce(
              (a, b) => a + b,
            ),
        69);
    expect(lines.last, endsWith(': table unit, 6 seats'));
  });
}

import 'dart:async';

import 'package:test/test.dart';

import '../example/jet_cad_2d_example.dart' as example;

/// The published example is the package's front page on pub.dev: it must
/// run, and it must print what its comments say it prints.
void main() {
  test('the example runs and prints its walk-through', () async {
    final lines = <String>[];
    await runZoned(
      example.main,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => lines.add(line),
      ),
    );
    expect(lines, [
      'entities: 2',
      'extents: Aabb2(100.0, 100.0 .. 500.0, 300.0)',
      'pick (300, 301): the circle (edge)',
      'after undo, entities: 1',
      'pick (300, 301): nothing',
      'after redo, entities: 2',
      'pick (300, 301): the circle (edge)',
      'decoded copy: entities 2, encodes identically: true',
      'pick on the copy (300, 301): a circle (edge)',
    ]);
  });
}

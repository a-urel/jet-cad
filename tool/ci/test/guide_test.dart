// Spec 14d P2: the host guide's code blocks are the host probe's code.
// Run from tool/ci: the guide and the probe are read from the repository.
import 'dart:io';

import 'package:jet_cad_ci/guide.dart';
import 'package:test/test.dart';

final guide = File('../../docs/host-guide.md').readAsStringSync();
final dart = File('host_probe/lib/main.dart').readAsStringSync();
final yaml = File('host_probe/pubspec.yaml.in').readAsStringSync();

void main() {
  test('GD1 every block of the guide is in the probe', () {
    expect(
      fencedBlocks(guide, 'dart'),
      hasLength(greaterThan(8)),
      reason: 'premise: the guide shows its code',
    );
    expect(
      fencedBlocks(guide, 'yaml'),
      hasLength(2),
      reason: 'premise: §1\'s dependencies, §2\'s fonts',
    );
    expect(missingBlocks(guide, dart: dart, yaml: yaml), isEmpty);
  });

  test('GD2 a Dart block the probe does not have is named', () {
    expect(guide, contains('c.serviceJson()'), reason: 'premise');
    final renamed = guide.replaceFirst('c.serviceJson()', 'c.layoutJson()');
    expect(missingBlocks(renamed, dart: dart, yaml: yaml), [
      'dart: /// Keeps the service layout on every change of its record, never on a mode',
    ]);
  });

  test('GD3 a pubspec line the probe does not have is named', () {
    final moved = guide.replaceFirst(
      'jet_cad_2d_plan: ^0.9.0',
      'jet_cad_2d_plan: ^0.9.1',
    );
    expect(moved, isNot(guide), reason: 'premise');
    expect(missingBlocks(moved, dart: dart, yaml: yaml), [
      'yaml: dependencies:',
    ]);
  });

  test('GD4 the plan library\'s font asset line is the probe\'s', () {
    final moved = guide.replaceFirst('Roboto-Regular.ttf', 'Roboto.ttf');
    expect(moved, isNot(guide), reason: 'premise');
    expect(missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: flutter:']);
  });

  // Sub-project 4a R4: the guide is on the plan library and the kits, and
  // the old planner appears only in the section that maps it.
  test('GD6 no snippet names the old planner\'s packages or barrel', () {
    for (final block in [
      ...fencedBlocks(guide, 'dart'),
      ...fencedBlocks(guide, 'yaml'),
    ]) {
      expect(block, isNot(contains('jet_cad_floor_plan')));
      expect(block, isNot(contains('jet_cad_restaurant_symbols')));
      expect(block, isNot(contains('FloorPlan')));
    }
    expect(dart, isNot(contains('jet_cad_floor_plan')));
    expect(yaml, isNot(contains('jet_cad_floor_plan')));
  });

  test(
    'GD7 the guide says what a relabel does to a group (Review Focus 2)',
    () {
      // The prose, with the code blocks cut out: the warning is words.
      final prose = guide.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
      expect(prose, contains('does **not**\n> follow a relabel into a group'));
      expect(prose, contains('`ServiceRestore.droppedGroups`'));
      expect(
        fencedBlocks(
          guide,
          'dart',
        ).where((b) => b.contains('bool relabelTables')),
        hasLength(1),
      );
    },
  );

  test('GD5 indentation and line breaks are the formatter\'s', () {
    const source = '''
class A {
  void f() {
    g(1,
        2);
  }
}''';
    const block = '```dart\nvoid f() {\n  g(1, 2);\n}\n```\n';
    expect(missingBlocks(block, dart: source, yaml: ''), isEmpty);
    expect(
      missingBlocks(block.replaceFirst('g(1', 'h(1'), dart: source, yaml: ''),
      ['dart: void f() {'],
    );
  });
}

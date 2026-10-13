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
    expect(fencedBlocks(guide, 'dart'), hasLength(greaterThan(8)),
        reason: 'premise: the guide shows its code');
    expect(fencedBlocks(guide, 'yaml'), hasLength(3),
        reason: 'premise: §1\'s dependency, §2\'s fonts, the symbols\' asset');
    expect(missingBlocks(guide, dart: dart, yaml: yaml), isEmpty);
  });

  test('GD2 a Dart block the probe does not have is named', () {
    expect(guide, contains('controller.serviceLayoutJson()'),
        reason: 'premise');
    final renamed = guide.replaceFirst(
        'controller.serviceLayoutJson()', 'controller.layoutJson()');
    expect(missingBlocks(renamed, dart: dart, yaml: yaml),
        ['dart: Future<void> saveLayout() async {']);
  });

  test('GD3 a pubspec line the probe does not have is named', () {
    final moved = guide.replaceFirst(
        'jet_cad_floor_plan: ^0.7.1', 'jet_cad_floor_plan: ^0.7.2');
    expect(moved, isNot(guide), reason: 'premise');
    expect(
        missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: dependencies:']);
  });

  test('GD4 the symbols\' asset line is the probe\'s', () {
    final moved = guide.replaceFirst(
        '    - assets/restaurant.jetlib', '    - assets/symbols.jetlib');
    expect(moved, isNot(guide), reason: 'premise');
    expect(missingBlocks(moved, dart: dart, yaml: yaml), ['yaml: assets:']);
  });

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
        ['dart: void f() {']);
  });
}

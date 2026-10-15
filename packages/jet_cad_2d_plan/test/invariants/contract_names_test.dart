// 3a Task 1 (spec C1.4, Appendix A D-09): the symbol box family and the
// placement transform have one owner, the contract. The plan library
// declares none of them, under its own name or a private one, so a rule
// changed in the contract cannot drift from a copy here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A top-level declaration of one of the contract's names, public or
/// private.
final RegExp _declaration = RegExp(
    r'^(?:final\s+)?(?:class\s+_?SymbolBox\b|'
    r'(?:bool|Transform2|Aabb2|SymbolBox\??)\s+_?'
    r'(?:isOrthonormal|placementTransform|boxOfLeaves|boxOfEntry|'
    r'servedTopOfEntry|boxOfDefinition|footprintOf)\s*\()',
    multiLine: true);

void main() {
  test(
      'SB-one-owner no file under lib/ declares the symbol box family or '
      'the placement transform (M-SB-owner)', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThan(50), reason: 'premise: lib/ was read');
    final found = [
      for (final f in files)
        for (final m in _declaration.allMatches(f.readAsStringSync()))
          '${f.path}: ${m[0]}',
    ];
    expect(found, isEmpty);
  });

  test('SB-one-owner-probe the pattern finds each form it names', () {
    // The detector's own positive control (exempt from the mutation rule).
    for (final line in [
      'bool isOrthonormal(Transform2 g) {',
      'bool _isOrthonormal(Transform2 g) {',
      'Transform2 placementTransform({',
      'final class SymbolBox {',
      'SymbolBox? boxOfLeaves(Iterable<(EntityKind, GeometryPayload)> l) {',
      'Aabb2 footprintOf(SymbolBox box) =>',
    ]) {
      expect(_declaration.hasMatch(line), isTrue, reason: line);
    }
    expect(_declaration.hasMatch('  if (!isOrthonormal(t)) return null;'),
        isFalse);
  });
}

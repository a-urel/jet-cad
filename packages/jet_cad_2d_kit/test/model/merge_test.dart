// Spec K3: several libraries as one. Ported from jet_cad_floor_plan's
// symbol_sources_test LS1 and SymbolLibrary.merge.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/library_fixtures.dart';

/// The fixture library moved under the kit "other": every key and name
/// renamed in the text, so both libraries decode.
SymbolLibrary otherLibrary() {
  final text = utf8
      .decode(bytesOf(buildValidLibrary()))
      .replaceAll('"kit":"sample"', '"kit":"other"')
      .replaceAll('"sample.', '"other.')
      .replaceAll('"Living Room"', '"Lobby"');
  return SymbolLibrary.decode(Uint8List.fromList(utf8.encode(text)));
}

SymbolLibrary sampleLibrary() =>
    SymbolLibrary.decode(bytesOf(buildValidLibrary()));

void main() {
  test('M1 entries in order, kits and categories in first appearance', () {
    final merged = SymbolLibrary.merge([otherLibrary(), sampleLibrary()]);
    // M-M1: concatenate in reverse.
    expect([
      for (final e in merged.entries) e.id
    ], [
      'other.sofa.three@3',
      'other.table.high-top@2',
      'other.chair.arm@1',
      'sample.sofa.three@3',
      'sample.table.high-top@2',
      'sample.chair.arm@1',
    ]);
    expect(merged.kits, ['other', 'sample']);
    expect(merged.categories, ['Lobby', 'Bar', 'Living Room']);
  });

  test('M2 a key@version in two libraries names both, by position and kit', () {
    // M-M2: drop the check; the merge succeeds with six entries.
    expect(
        () => SymbolLibrary.merge(
            [sampleLibrary(), otherLibrary(), sampleLibrary()]),
        throwsA(isA<SymbolLibraryError>()
            .having((e) => e.rule, 'rule', 6)
            .having(
                (e) => e.message, 'message', contains('sample.sofa.three@3'))
            .having(
                (e) => e.message, 'message', contains('library 1 (kit sample)'))
            .having((e) => e.message, 'message',
                contains('library 3 (kit sample)'))));
  });

  test('M3 no library merges to none; one merges to its own entries', () {
    final none = SymbolLibrary.merge(const []);
    expect(none.entries, isEmpty);
    expect(none.kits, isEmpty);
    final one = SymbolLibrary.merge([sampleLibrary()]);
    expect([for (final e in one.entries) e.id],
        [for (final e in sampleLibrary().entries) e.id]);
    expect(one.kits, ['sample']);
  });
}

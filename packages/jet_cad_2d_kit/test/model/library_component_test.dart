// Spec K2: the library component on a library's root.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('L1 refusals: a kit that is not a kit id, a format below one', () {
    for (final kit in ['Sample', 'my-kit', '', 'sample.x']) {
      expect(() => LibraryComponent(kit: kit),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kit')),
          reason: kit);
    }
    // M-L1: drop the format check.
    expect(() => LibraryComponent(kit: 'sample', format: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'format')));
  });

  test(
      'L2 a newer format is a value the validator refuses, not the '
      'constructor', () {
    expect(LibraryComponent(kit: 'sample', format: 2).format, 2);
  });

  test('L3 equality, typeId and the pinned JSON', () {
    final a = LibraryComponent(kit: 'sample');
    expect(a, LibraryComponent(kit: 'sample'));
    expect(a.hashCode, LibraryComponent(kit: 'sample').hashCode);
    expect(a, isNot(LibraryComponent(kit: 'other')));
    // M-L3: drop format from ==.
    expect(a, isNot(LibraryComponent(kit: 'sample', format: 2)));
    expect(a.typeId, 'jetcad.library');
    expect(jsonEncode(a.toJson()), '{"format":1,"kit":"sample"}');
  });

  test('L4 fromJson reads back and refuses a missing or mistyped field', () {
    const full = <String, Object?>{'format': 1, 'kit': 'sample'};
    expect(LibraryComponent.fromJson(full), LibraryComponent(kit: 'sample'));
    for (final field in full.keys) {
      expect(() => LibraryComponent.fromJson({...full}..remove(field)),
          throwsFormatException,
          reason: field);
    }
    expect(() => LibraryComponent.fromJson({...full, 'format': '1'}),
        throwsFormatException);
  });

  test('L5 a field this build does not know is ignored', () {
    expect(
        LibraryComponent.fromJson(
            const {'format': 1, 'kit': 'sample', 'newer': true}),
        LibraryComponent(kit: 'sample'));
  });
}

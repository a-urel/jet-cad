// Spec K2, umbrella A8: the manifest on a plan's root.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

void main() {
  test('MF1 refusals: a key that is not a kit id, an empty version, format 0',
      () {
    expect(() => ManifestComponent(kits: const {'Restaurant': '0.1.0'}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kits')));
    expect(() => ManifestComponent(kits: const {'restaurant': ' '}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'kits')));
    expect(() => ManifestComponent(format: 0, kits: const {}),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'format')));
    expect(ManifestComponent(kits: const {}).kits, isEmpty);
  });

  test('MF2 kits are written sorted by id, whatever the insertion order', () {
    final m = ManifestComponent(
        kits: const {'restaurant': '0.1.0', 'architecture': '0.2.1'});
    // M-MF2: keep the caller's order; the text differs.
    expect(jsonEncode(m.toJson()),
        '{"format":1,"kits":{"architecture":"0.2.1","restaurant":"0.1.0"}}');
    expect(m.typeId, 'jetcad.manifest');
  });

  test('MF3 equality ignores insertion order and sees every value', () {
    final a = ManifestComponent(
        kits: const {'restaurant': '0.1.0', 'architecture': '0.2.1'});
    final b = ManifestComponent(
        kits: const {'architecture': '0.2.1', 'restaurant': '0.1.0'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    // M-MF3: compare the key sets only.
    expect(
        a,
        isNot(ManifestComponent(
            kits: const {'architecture': '0.2.2', 'restaurant': '0.1.0'})));
    expect(a, isNot(ManifestComponent(kits: const {'architecture': '0.2.1'})));
    expect(
        a,
        isNot(ManifestComponent(format: 2, kits: const {
          'architecture': '0.2.1',
          'restaurant': '0.1.0',
        })));
  });

  test('MF4 kits is an unmodifiable copy', () {
    final source = {'restaurant': '0.1.0'};
    final m = ManifestComponent(kits: source);
    source['restaurant'] = '9.9.9';
    expect(m.kits, {'restaurant': '0.1.0'});
    expect(() => m.kits['x'] = '1', throwsUnsupportedError);
  });

  test('MF5 fromJson reads back and refuses what is not a string map', () {
    final m = ManifestComponent(kits: const {'restaurant': '0.1.0'});
    expect(
        ManifestComponent.fromJson((jsonDecode(jsonEncode(m.toJson())) as Map)
            .cast<String, Object?>()),
        m);
    expect(() => ManifestComponent.fromJson(const {'format': 1}),
        throwsFormatException);
    expect(() => ManifestComponent.fromJson(const {'format': 1, 'kits': 'x'}),
        throwsFormatException);
    expect(
        () => ManifestComponent.fromJson(const {
              'format': 1,
              'kits': {'restaurant': 1},
            }),
        throwsFormatException);
  });
}

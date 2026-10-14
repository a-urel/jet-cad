// Spec P5 "Fonts": the plan's font and its licence are the package's
// assets, read under its `packages/` keys (ported from jet_cad_floor_plan's
// package_assets_test PA1, PA5), the font is the vendored face byte for
// byte, and registerFontLicences registers the licence under `Roboto`.
// PA6 and PA8 (ensurePlanFonts' retry and its one registration) are
// ported from the same file's V-11 group.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/fonts/plan_fonts.dart';

class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  // Written out, not read from the constants: a key that drifted back to
  // another package's must turn these red.
  const fontKey = 'packages/jet_cad_2d_plan/lib/fonts/Roboto-Regular.ttf';
  const licenceKey = 'packages/jet_cad_2d_plan/assets/fonts/Roboto_LICENSE.txt';

  test('PA1 the constants name the package keys', () {
    expect(kPlanFontAsset, fontKey);
    expect(kPlanFontLicenceAsset, licenceKey);
    expect(kPlanFontFamily, 'Roboto');
  });

  test('PA5 the pubspec declares the two font assets', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final asset in const [
      'lib/fonts/Roboto-Regular.ttf',
      'assets/fonts/Roboto_LICENSE.txt',
    ]) {
      expect(
          RegExp('^\\s*-\\s+${RegExp.escape(asset)}\\s*\$', multiLine: true)
              .hasMatch(pubspec),
          isTrue,
          reason: asset);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('W-F1 the font is the vendored face, byte for byte', () {
    // M-W-F1: any other file at lib/fonts/Roboto-Regular.ttf.
    final ours = File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();
    final vendored =
        File('../jet_cad_2d_flutter/test/golden/fonts/Roboto-Regular.ttf')
            .readAsBytesSync();
    expect(ours, orderedEquals(vendored));
    expect(
        File('assets/fonts/Roboto_LICENSE.txt').readAsStringSync(),
        File('../jet_cad_2d_flutter/test/golden/fonts/Roboto_LICENSE.txt')
            .readAsStringSync());
  });

  test(
      'W-F2 registerFontLicences adds one entry for Roboto, its text read '
      'from the given bundle under the package key', () async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    registerFontLicences(
        _MapBundle({licenceKey: utf8.encode('Licence text 7')}));
    final entries = await LicenseRegistry.licenses.toList();
    // M-W-F2a: the package named 'roboto' finds nothing here.
    final roboto = [
      for (final e in entries)
        if (e.packages.contains('Roboto')) e
    ];
    expect(roboto, hasLength(1));
    // M-W-F2b: `rootBundle` in place of the given bundle reads the real
    // licence (or nothing) instead.
    expect([for (final p in roboto.single.paragraphs) p.text].join('\n'),
        'Licence text 7');
  });

  group('V-11 ensurePlanFonts (ported PA6, PA8)', () {
    // The registration is process-wide: each test starts from none (review
    // F-3), and every call that reads a bundle runs in real async time.
    setUp(resetPlanFontsForTest);
    tearDown(resetPlanFontsForTest);

    Uint8List font() => File('lib/fonts/Roboto-Regular.ttf').readAsBytesSync();

    testWidgets(
        'PA6 a bundle without the font fails the registration, and the next '
        'call tries again', (tester) async {
      await tester.runAsync(() async {
        await expectLater(
            ensurePlanFonts(_MapBundle(const {})), throwsA(anything));
      });
      // Not held: this call registers from a bundle that has the bytes.
      final bytes = font();
      await tester
          .runAsync(() => ensurePlanFonts(_MapBundle({fontKey: bytes})));
    });

    testWidgets('PA8 a second call returns the first call\'s future',
        (tester) async {
      final bundle = _MapBundle({fontKey: font()});
      await tester.runAsync(() async {
        final first = ensurePlanFonts(bundle);
        expect(ensurePlanFonts(bundle), same(first));
        expect(ensurePlanFonts(), same(first),
            reason: 'a later call, whatever its bundle, gets the first');
        await first;
      });
    });
  });
}

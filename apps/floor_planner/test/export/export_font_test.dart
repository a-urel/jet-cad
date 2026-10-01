// Spec 13 D7, T-12, plan 13 Task 7: the bundled font is the render
// package's vendored Roboto, byte for byte, with its licence; the app reads
// it once through the asset bundle and registers the licence.
import 'dart:io';

import 'package:floor_planner/document_host.dart';
import 'package:floor_planner/export/export_font.dart';
import 'package:floor_planner/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/document_rig.dart' show hostOf;
import '../support/fake_document_files.dart';

const String vendoredDir =
    '../../packages/jet_cad_2d_flutter/test/golden/fonts';
const String recordedSha256 =
    '79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95';

Uint8List vendoredFont() =>
    File('$vendoredDir/Roboto-Regular.ttf').readAsBytesSync();

/// A bundle that serves fixed bytes under one key and records every key
/// asked for.
class _MapBundle extends CachingAssetBundle {
  _MapBundle(this.assets);

  final Map<String, Uint8List> assets;
  final List<String> asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    final bytes = assets[key];
    if (bytes == null) throw FlutterError('no asset $key');
    return ByteData.sublistView(bytes);
  }
}

void main() {
  group('T-12 the files', () {
    test('EF1 the app font equals the vendored one byte for byte', () {
      final app = File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync();
      final vendored = vendoredFont();
      expect(vendored.length, 171676, reason: 'premise: spec F-11');
      expect(app, orderedEquals(vendored));
    });

    test('EF2 the licence equals the vendored one byte for byte', () {
      final app = File('assets/fonts/Roboto_LICENSE.txt').readAsBytesSync();
      final vendored =
          File('$vendoredDir/Roboto_LICENSE.txt').readAsBytesSync();
      expect(app, isNotEmpty);
      expect(app, orderedEquals(vendored));
      expect(String.fromCharCodes(app), contains('Apache License'));
    });

    test(
        'EF3 the README records the SHA-256 (package:crypto is not a '
        'dependency: the digest is checked by sha256sum in the task report '
        'and the bytes equal the vendored file, whose README records the '
        'same digest)', () {
      final readme = File('assets/fonts/README.md').readAsStringSync();
      expect(readme, contains(recordedSha256));
      expect(readme, contains('Apache 2.0'));
      expect(readme, contains('Copied unmodified, 2026-10-01, plan 13 Task 7'));
      expect(File('$vendoredDir/README.md').readAsStringSync(),
          contains(recordedSha256));
    });
  });

  group('loadExportFont', () {
    testWidgets('EF4 reads the bundled font through rootBundle',
        (tester) async {
      final bytes = await loadExportFont();
      expect(bytes, orderedEquals(vendoredFont()));
    });

    testWidgets('EF5 reads from the bundle it is given', (tester) async {
      final fake = Uint8List.fromList(<int>[7, 1, 9, 3]);
      final bundle = _MapBundle(<String, Uint8List>{kExportFontAsset: fake});
      expect(await loadExportFont(bundle), orderedEquals(fake));
      expect(bundle.asked, <String>[kExportFontAsset]);
    });
  });

  group('the licence', () {
    setUp(LicenseRegistry.reset);
    tearDown(LicenseRegistry.reset);

    testWidgets('EF6 registerFontLicences lists the Apache text under Roboto',
        (tester) async {
      expect(await LicenseRegistry.licenses.toList(), isEmpty,
          reason: 'premise: a clean registry');
      registerFontLicences();
      final entries = await LicenseRegistry.licenses.toList();
      final roboto =
          entries.where((e) => e.packages.contains('Roboto')).toList();
      expect(roboto, hasLength(1));
      final text = roboto.single.paragraphs.map((p) => p.text).join('\n');
      expect(text, contains('Apache License'));
      expect(text, contains('Version 2.0'));
    });
  });

  group('ExportFontCache', () {
    test('EF7 reads once and returns the same future after', () async {
      var reads = 0;
      final bytes = Uint8List.fromList(<int>[4, 2]);
      final cache = ExportFontCache(load: () async {
        reads++;
        return bytes;
      });
      expect(reads, 0, reason: 'nothing is read until asked');
      final first = cache.bytes;
      expect(cache.bytes, same(first));
      expect(await first, same(bytes));
      expect(await cache.bytes, same(bytes));
      expect(reads, 1);
    });

    test('EF8 a failed read is not held: the next call reads again', () async {
      var reads = 0;
      final bytes = Uint8List.fromList(<int>[5]);
      final cache = ExportFontCache(load: () async {
        reads++;
        if (reads == 1) throw StateError('first read fails');
        return bytes;
      });
      await expectLater(cache.bytes, throwsStateError);
      expect(await cache.bytes, same(bytes));
      expect(reads, 2);
    });

    testWidgets(
        'EF9 the app hands its cache to the host, and keeps it across a '
        'document swap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cache = ExportFontCache();
      await tester.pumpWidget(
          FloorPlannerApp(files: FakeDocumentFiles(), exportFont: cache));
      await tester.pump();
      expect(tester.widget<DocumentHost>(find.byType(DocumentHost)).exportFont,
          same(cache));
      await hostOf(tester).newFlow();
      await tester.pump();
      expect(tester.widget<DocumentHost>(find.byType(DocumentHost)).exportFont,
          same(cache));
    });

    testWidgets('EF10 without a cache the app makes one over the bundled font',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(FloorPlannerApp(files: FakeDocumentFiles()));
      await tester.pump();
      final own =
          tester.widget<DocumentHost>(find.byType(DocumentHost)).exportFont;
      expect(own, isNotNull);
      expect(await own!.bytes, orderedEquals(vendoredFont()));
    });
  });

  group('main', () {
    // No test runs `main()` (it calls `runApp`), so the one line that makes
    // the licence appear in the running app is pinned by its source, as
    // the render package's T-11 pins page_export.dart (Task 7 review,
    // finding 1; mutant H).
    test('EF11 main() registers the font licence before runApp', () {
      final source = File('lib/main.dart').readAsStringSync();
      final start = source.indexOf('void main() {');
      expect(start, isNonNegative, reason: 'premise: main() is found');
      final end = source.indexOf('\n}', start);
      expect(end, greaterThan(start), reason: 'premise: its body ends');
      // Comments do not run: a commented-out call is no call.
      final body = source
          .substring(start, end)
          .replaceAll(RegExp(r'//[^\n]*'), '')
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
      final register = body.indexOf('registerFontLicences();');
      final run = body.indexOf('runApp(');
      expect(register, isNonNegative, reason: 'the licence is registered');
      expect(run, isNonNegative, reason: 'premise: main() runs the app');
      expect(register, lessThan(run), reason: 'before the app runs');
    });
  });
}

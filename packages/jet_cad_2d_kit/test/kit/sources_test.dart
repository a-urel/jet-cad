// Spec K5: a symbol source is a label and a reader; bundledLibrary reads an
// asset bundle (rootBundle when none is given), at read time.
import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../support/library_fixtures.dart';

const String key = 'packages/jet_cad_2d_kit_sample/assets/sample.jetlib';

/// A bundle that counts its loads and serves [assets].
class _Bundle extends CachingAssetBundle {
  _Bundle(this.assets);

  final Map<String, ByteData> assets;
  final List<String> loads = [];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    final data = assets[key];
    if (data == null) throw FlutterError('no asset $key');
    return data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('S1 a source is its label and its reader', () async {
    final source = SymbolLibrarySource(
        label: 'sample', read: () async => Uint8List.fromList([4, 5]));
    expect(source.label, 'sample');
    expect(await source.read(), [4, 5]);
    expect('$source', 'SymbolLibrarySource(sample)');
  });

  test("S2 the bundle's bytes, honouring the view's offset and length",
      () async {
    // A view into the middle of a larger buffer, as an engine hands out.
    final bundle = _Bundle({
      key:
          ByteData.sublistView(Uint8List.fromList([9, 9, 7, 1, 2, 3, 9]), 3, 6),
    });
    // M-S2: `data.buffer.asUint8List()` returns all seven bytes.
    expect(await bundledLibrary(key, bundle: bundle)(), [1, 2, 3]);
  });

  test('S3 nothing is loaded until the reader runs; each run loads once',
      () async {
    final bundle = _Bundle({key: ByteData(4)});
    final read = bundledLibrary(key, bundle: bundle);
    // M-S3: load eagerly in bundledLibrary and keep the future.
    expect(bundle.loads, isEmpty);
    await read();
    await read();
    expect(bundle.loads, [key, key]);
  });

  test('S4 without a bundle the root bundle is read', () async {
    final bytes = Uint8List.fromList([7, 8, 9]);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final asked = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      return asked == key ? ByteData.sublistView(bytes) : null;
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    // M-S4: `bundle!` in place of `bundle ?? rootBundle`.
    expect(await bundledLibrary(key)(), [7, 8, 9]);
  });

  test("S5 a missing asset fails the read with the bundle's error", () async {
    final read =
        bundledLibrary('packages/x/missing.jetlib', bundle: _Bundle(const {}));
    await expectLater(read(), throwsA(isA<FlutterError>()));
  });

  test('S6 a bundled library decodes through its source', () async {
    final source = SymbolLibrarySource(
        label: 'sample',
        read: bundledLibrary(key,
            bundle: _Bundle({
              key: ByteData.sublistView(bytesOf(buildValidLibrary())),
            })));
    final library = SymbolLibrary.decode(await source.read());
    expect(library.kits, ['sample']);
    expect(library.entries, hasLength(3));
  });
}

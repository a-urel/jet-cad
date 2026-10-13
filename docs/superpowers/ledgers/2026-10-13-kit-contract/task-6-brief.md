### Task 6: `SymbolLibrarySource`, `bundledLibrary` and `PlanKit` (K5)

**Files:**
- Create: `lib/src/kit/symbol_library_source.dart`, `lib/src/kit/bundled_library.dart`, `lib/src/kit/plan_kit.dart`
- Modify: `lib/jet_cad_2d_kit.dart` (three exports)
- Test: `test/kit/sources_test.dart`, `test/kit/plan_kit_test.dart`

**Interfaces:**
- Consumes: `KitNames`, `KitProblem`, `KitProblemCode`, `isKitId`, `kitOfKey`, `SymbolLibrary.decode` (Tasks 2-5); `buildValidLibrary`, `bytesOf` (test support, Task 4); from Flutter: `AssetBundle`, `CachingAssetBundle`, `rootBundle` (`package:flutter/services.dart`); from `flutter_test`: `TestWidgetsFlutterBinding.ensureInitialized()`, `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler`.
- Produces (exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart` only):
  - `final class SymbolLibrarySource` — `const SymbolLibrarySource({required String label, required Future<Uint8List> Function() read})`.
  - `Future<Uint8List> Function() bundledLibrary(String assetKey, {AssetBundle? bundle})`.
  - `final class PlanKit` — `const PlanKit({required String id, required String version, List<SymbolLibrarySource> symbols = const [], KitNames names = KitNames.empty})`; `List<KitProblem> validate()`.

Plan decision: `bundledLibrary` resolves the bundle when the reader is called, not when it is made (`bundle ?? rootBundle` inside the closure), so a kit's top-level source can be declared before the binding exists and a test can mock the asset channel.
Plan decision: `PlanKit.validate` also reports a word id in an unknown namespace (`unknownWordId`) and a `tool:`/`type:`/`property:` word present in some locale but missing from English (`missingEnglish`, K4: English is required for every word with no stored English); a `category:` word is under the kit when the part before its `/` is the kit's id (K4 as amended).

- [ ] **Step 1: Write the failing tests.** Create `test/kit/sources_test.dart`:

```dart
// Spec K5: a symbol source is a label and a reader; bundledLibrary reads an
// asset bundle (rootBundle when none is given), at read time.
import 'dart:convert';
import 'dart:typed_data';

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
      key: ByteData.sublistView(
          Uint8List.fromList([9, 9, 7, 1, 2, 3, 9]), 3, 6),
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
    final read = bundledLibrary('packages/x/missing.jetlib',
        bundle: _Bundle(const {}));
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
```

Create `test/kit/plan_kit_test.dart`:

```dart
// Spec K5: the PlanKit descriptor's symbol part and its validation.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

List<KitProblemCode> codes(PlanKit kit) =>
    [for (final p in kit.validate()) p.code];

void main() {
  test('K1 a const descriptor with its defaults', () {
    const kit = PlanKit(id: 'sample', version: '0.1.0');
    expect(kit.symbols, isEmpty);
    expect(identical(kit.names, KitNames.empty), isTrue);
    expect(kit.validate(), isEmpty);
  });

  test('K2 a sound kit validates: own words, categories, English present',
      () {
    const kit = PlanKit(
      id: 'sample',
      version: '0.3.1',
      names: KitNames({
        'en': {
          'tool:sample.wall': 'Wall',
          'type:sample.wall': 'Wall',
          'property:sample.wall.height': 'Height',
        },
        'tr': {
          'symbol:sample.table.round': 'Yuvarlak masa',
          'category:sample/Tables': 'Masalar',
          'tool:sample.wall': 'Duvar',
          'property:sample.wall.height': 'Yükseklik',
        },
      }),
    );
    expect(kit.validate(), isEmpty);
  });

  test('K3 a bad id and an empty version', () {
    // M-K3a: drop the id check. M-K3b: test `version.isEmpty` only.
    expect(codes(const PlanKit(id: 'Sample', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'my-kit', version: '0.1.0')),
        [KitProblemCode.badKitId]);
    expect(codes(const PlanKit(id: 'sample', version: ' ')),
        [KitProblemCode.emptyVersion]);
  });

  test("K4 a word id under another kit's id, in every namespace", () {
    for (final id in [
      'symbol:other.table.round',
      'tool:other.wall',
      'type:other.wall',
      'property:other.wall.height',
      'tool:wall', // no kit segment at all
      'category:other/Tables', // M-K4b: categories exempt from the check
      'category:Tables', // no kit at all
    ]) {
      final kit = PlanKit(
          id: 'sample',
          version: '0.1.0',
          names: KitNames({
            'en': {id: 'x'},
          }));
      // M-K4: check the symbol namespace only.
      expect(codes(kit), [KitProblemCode.foreignWordId], reason: id);
      expect(kit.validate().single.message, contains(id));
    }
  });

  test('K5 a word id in no known namespace', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {'label:sample.x': 'x', 'sample.table.round': 'y'},
        }));
    expect(codes(kit),
        [KitProblemCode.unknownWordId, KitProblemCode.unknownWordId]);
  });

  test('K6 a tool, type or property word without English', () {
    const kit = PlanKit(
        id: 'sample',
        version: '0.1.0',
        names: KitNames({
          'tr': {
            'tool:sample.wall': 'Duvar',
            'symbol:sample.table.round': 'Yuvarlak masa',
            'category:sample/Tables': 'Masalar',
          },
        }));
    // M-K6: drop the English check; a symbol or category word needs none.
    expect(codes(kit), [KitProblemCode.missingEnglish]);
    expect(kit.validate().single.message, contains('tool:sample.wall'));
  });
}
```

- [ ] **Step 2: Run them to see them fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit`. Expected: compilation errors (`Undefined class 'SymbolLibrarySource'`).

- [ ] **Step 3: The source.** Create `lib/src/kit/symbol_library_source.dart`:

```dart
// A symbol source (spec K5): plain data, a label for messages and a reader
// of a library's bytes. A kit's symbols are its sources' libraries.
import 'dart:typed_data';

import 'package:meta/meta.dart';

@immutable
final class SymbolLibrarySource {
  const SymbolLibrarySource({required this.label, required this.read});

  /// Names the source in messages.
  final String label;

  /// Reads the library's bytes. Every library a kit's sources read carries
  /// that kit's id; the plan library refuses one that does not.
  final Future<Uint8List> Function() read;

  @override
  String toString() => 'SymbolLibrarySource($label)';
}
```

- [ ] **Step 4: The bundled reader.** Create `lib/src/kit/bundled_library.dart`:

```dart
// A reader of a library bundled as a Flutter asset (spec K5). A kit's
// source is one line:
//   SymbolLibrarySource(label: 'restaurant', read: bundledLibrary(
//       'packages/jet_cad_2d_kit_restaurant/assets/restaurant.jetlib'))
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// A reader of [assetKey] in [bundle] ([rootBundle] when null), resolved
/// each time the reader runs.
Future<Uint8List> Function() bundledLibrary(String assetKey,
        {AssetBundle? bundle}) =>
    () async {
      final data = await (bundle ?? rootBundle).load(assetKey);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    };
```

- [ ] **Step 5: The descriptor.** Create `lib/src/kit/plan_kit.dart`:

```dart
// A kit's descriptor, its symbol part (spec K5). Sub-project 2 adds types,
// tools and attachments and extends validate.
import 'package:meta/meta.dart';

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import 'symbol_library_source.dart';

@immutable
final class PlanKit {
  const PlanKit({
    required this.id,
    required this.version,
    this.symbols = const [],
    this.names = KitNames.empty,
  });

  /// A kit id (K2): the first segment of the kit's keys, type and tool ids.
  final String id;

  /// The kit package's version, for the plan manifest.
  final String version;

  final List<SymbolLibrarySource> symbols;
  final KitNames names;

  /// The descriptor's problems: a bad id, an empty version, a word id under
  /// another kit's id or in no known namespace, a word with no stored
  /// English missing from English. Empty when sound.
  List<KitProblem> validate() {
    final problems = <KitProblem>[];
    if (!isKitId(id)) {
      problems.add(KitProblem(KitProblemCode.badKitId,
          '"$id" is not a kit id: a lower-case letter, then lower-case '
          'letters and digits'));
    }
    if (version.trim().isEmpty) {
      problems.add(KitProblem(
          KitProblemCode.emptyVersion, 'the kit "$id" has no version'));
    }
    final english = names.words[KitNames.english] ?? const <String, String>{};
    for (final MapEntry(key: locale, value: words) in names.words.entries) {
      for (final wordId in words.keys) {
        final colon = wordId.indexOf(':');
        final namespace = colon < 0 ? '' : wordId.substring(0, colon);
        final rest = wordId.substring(colon + 1);
        var foreign = false;
        switch (namespace) {
          case 'category':
            final slash = rest.indexOf('/');
            foreign = slash < 0 || rest.substring(0, slash) != id;
          case 'symbol' || 'tool' || 'type' || 'property':
            foreign = !rest.contains('.') || kitOfKey(rest) != id;
            if (!foreign && namespace != 'symbol' && !english.containsKey(wordId)) {
              problems.add(KitProblem(KitProblemCode.missingEnglish,
                  '$locale: "$wordId" has no English word'));
            }
          default:
            problems.add(KitProblem(KitProblemCode.unknownWordId,
                '$locale: "$wordId" is in no known namespace'));
        }
        if (foreign) {
          problems.add(KitProblem(KitProblemCode.foreignWordId,
              '$locale: "$wordId" is not under the kit "$id"'));
        }
      }
    }
    return problems;
  }
}
```

In `lib/jet_cad_2d_kit.dart`, the exports become:

```dart
export 'src/kit/bundled_library.dart';
export 'src/kit/plan_kit.dart';
export 'src/kit/symbol_library_source.dart';
export 'src/model/model.dart';
```

- [ ] **Step 6: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/kit test/model test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 7: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`): M-S2 (`return data.buffer.asUint8List();`) → S2 red; M-S3 (hoist the load: `final future = (bundle ?? rootBundle).load(assetKey); return () async { final data = await future; ... };`) → S3 red; M-S4 (`bundle!`) → S4 red; M-K3a (delete the id check) → K3 red; M-K3b (`version.isEmpty`) → K3 red; M-K4 (`case 'symbol':` alone, the others to `default`) → K4 red; M-K4b (`case 'category': break;`, as before the amendment) → K4 red (the category cases); M-K6 (delete the `else if` branch) → K6 red.

- [ ] **Step 8: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0. The purity test P1 stays green: `lib/src/kit/` is reached from neither `lib/authoring.dart` nor `lib/src/model/`.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/jet_cad_2d_kit.dart packages/jet_cad_2d_kit/lib/src/kit/symbol_library_source.dart packages/jet_cad_2d_kit/lib/src/kit/bundled_library.dart packages/jet_cad_2d_kit/lib/src/kit/plan_kit.dart packages/jet_cad_2d_kit/test/kit/sources_test.dart packages/jet_cad_2d_kit/test/kit/plan_kit_test.dart
git commit -m "$(cat <<'EOF'
feat(kit): SymbolLibrarySource, bundledLibrary and PlanKit (K5)

A source is a label and a reader of a library's bytes; bundledLibrary
reads an asset bundle, rootBundle by default, when the reader runs.
PlanKit carries a kit's id, version, sources and words, and validate
reports a bad id, an empty version, a word under another kit's id or in
no namespace, and a code-side word without English.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

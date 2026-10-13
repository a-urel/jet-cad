### Task 9: The geometry snapshot, the conformance test and the sample kit (K7)

**Files:**
- Create: `lib/src/authoring/snapshot.dart`, `lib/src/authoring/conformance.dart`
- Modify: `lib/authoring.dart` (two exports)
- Create: `test/fixtures/sample_kit/sample_kit.dart`, `test/fixtures/sample_kit/generate.dart`
- Generate and commit: `test/fixtures/sample_kit/sample.jetlib`, `test/fixtures/sample_kit/sample_snapshot.json`
- Test: `test/authoring/snapshot_test.dart`, `test/authoring/conformance_test.dart`

**Interfaces:**
- Consumes: `Catalog`, `CatalogSymbol`, `CatalogShape` family, `CatalogUnit`, `encodeLibrary` (Task 7); `chairAt`, `chairsAround`, `stoolAt`, `rect`, `inset` (Task 8); `KitNames`, `KitProblem`, `KitProblemCode`, `kitOfKey`, `SymbolLibrary.decode`, `SymbolLibraryError`, `UnitKinds`, `UnitLabelling` (Tasks 2-5).
- Produces (exported from `package:jet_cad_2d_kit/authoring.dart`):
  - `SplayTreeMap<String, String> geometrySnapshot(Catalog catalog)` — `key@version` → canonical JSON text.
  - `SplayTreeMap<String, String> parseSnapshot(String text)` (throws `FormatException`); `String encodeSnapshot(Map<String, String> snapshot)`; `SplayTreeMap<String, String> updateSnapshot(Map<String, String> committed, Map<String, String> current)`.
  - `List<KitProblem> conformance({required Catalog catalog, required Uint8List committedLibrary, required String committedSnapshot, required KitNames names, required List<String> locales, Map<String, Set<String>> sameAsEnglish = const {}})`.
- Test fixture: `sampleSymbols`, `sampleCatalog`, `sampleNames`, `sampleLocales`, `sampleSameAsEnglish` in `test/fixtures/sample_kit/sample_kit.dart`.

Plan decision: the snapshot file is a JSON object, one `"key@N": {entry}` per line, keys sorted, each entry the canonical object (keys sorted, Dart's shortest round-trip numbers, `-0.0` written `0.0`); `parseSnapshot` re-encodes each entry compactly, so the comparison is of canonical texts, not of file formatting (spec Risks).
Plan decision: `locales` lists the kit's non-English locales and `'en'` in it is an `ArgumentError` (English is always required, by stored text or words); a locale that has words but is not declared is a problem (`localeUndeclared`: K4 says a declared locale is complete, so a partial one must not hide undeclared).
Plan decision: `sameAsEnglish` is per locale (`{'de': {'category:sample/Bar'}}`): `Bar` is right in German, not necessarily in every locale.
Plan decision: a catalog `key@N` missing from the committed snapshot is a problem (`snapshotMissing`): the generator adds every new entry, so a missing one means the generator did not run and a new `key@N`'s geometry would go unpinned.
Plan decision: a locale's symbol word is compared with the English name of the key's newest version (words are by key, names by version).
Plan decision: checks 3 and 6 (keys under the kit, lower case) run on the catalog first and end the check when they find anything, and a catalog that does not build is one `catalogInvalid` problem: the later checks need a built library.

- [ ] **Step 1: The snapshot test.** Create `test/authoring/snapshot_test.dart`:

```dart
// Spec K7: the geometry snapshot, its canonical text, its file, and the
// merge the generator runs (M, the spec's own: let updateSnapshot overwrite
// an existing entry; N7 goes red).
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

const CatalogSymbol every = CatalogSymbol(
  key: 'sample.x.y',
  version: 3,
  name: 'X',
  category: 'C',
  unit: CatalogUnit(
      kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
  base: (120.5, -40),
  shapes: [
    CatalogLine((10, 20), (30, 40)),
    CatalogPolyline([(1, 2), (3, 4), (5, 6)], closed: true),
    CatalogCircle((7, 8), 9),
    CatalogArc((1, 1), 2, 0.5, -1.25),
  ],
);

CatalogSymbol dot(String key, {(double, double) base = (300, 200)}) =>
    CatalogSymbol(
      key: key,
      name: key,
      category: 'C',
      base: base,
      shapes: [CatalogCircle(base, 150)],
    );

void main() {
  test('N1 the canonical entry: base, shapes, unit, keys sorted', () {
    // M-N1a: leave out "closed". M-N1b: leave out the unit.
    expect(geometrySnapshot(const Catalog(kit: 'sample', symbols: [every])), {
      'sample.x.y@3': '{"base":[120.5,-40.0],"shapes":['
          '{"from":[10.0,20.0],"kind":"line","to":[30.0,40.0]},'
          '{"closed":true,"kind":"polyline","points":[[1.0,2.0],[3.0,4.0],[5.0,6.0]]},'
          '{"center":[7.0,8.0],"kind":"circle","radius":9.0},'
          '{"center":[1.0,1.0],"kind":"arc","radius":2.0,"start":0.5,"sweep":-1.25}'
          '],"unit":{"capacity":1,"kind":"seat","labelling":"assigned"}}',
    });
  });

  test('N2 -0.0 is written 0.0; a symbol with no unit writes null', () {
    final s = geometrySnapshot(
        Catalog(kit: 'sample', symbols: [dot('sample.a.b', base: (-0.0, 5))]));
    // M-N2: write numbers as they are; "-0.0" appears.
    expect(s['sample.a.b@1'],
        '{"base":[0.0,5.0],"shapes":[{"center":[0.0,5.0],"kind":"circle",'
        '"radius":150.0}],"unit":null}');
  });

  test('N3 entries are sorted by key@version, whatever the catalog order', () {
    final s = geometrySnapshot(Catalog(
        kit: 'sample', symbols: [dot('sample.z.b'), dot('sample.a.b')]));
    expect(s.keys.toList(), ['sample.a.b@1', 'sample.z.b@1']);
  });

  test('N4 the file: one entry per line, sorted, and it reads back', () {
    final s = geometrySnapshot(Catalog(
        kit: 'sample', symbols: [dot('sample.z.b'), dot('sample.a.b')]));
    final text = encodeSnapshot(s);
    expect(
        text,
        '{\n'
        '  "sample.a.b@1": ${s['sample.a.b@1']},\n'
        '  "sample.z.b@1": ${s['sample.z.b@1']}\n'
        '}\n');
    expect(parseSnapshot(text), s);
    expect(encodeSnapshot(const {}), '{}\n');
    expect(parseSnapshot('{}\n'), isEmpty);
  });

  test('N5 parsing compares canonical texts, not the file layout', () {
    expect(
        parseSnapshot('{ "a.b.c@1" : { "base" : [ 1.0, 2.0 ], "shapes" : [],'
            ' "unit" : null } }'),
        {'a.b.c@1': '{"base":[1.0,2.0],"shapes":[],"unit":null}'});
  });

  test('N6 what is not a snapshot is a FormatException', () {
    expect(() => parseSnapshot('not json'), throwsFormatException);
    expect(() => parseSnapshot('[1]'), throwsFormatException);
    expect(() => parseSnapshot('{"a.b.c@1": 3}'), throwsFormatException);
  });

  test('N7 updateSnapshot adds new entries and never rewrites one', () {
    final merged = updateSnapshot(
      {'a.b.c@1': 'committed', 'c.d.e@1': 'retired'},
      {'a.b.c@1': 'changed', 'b.c.d@1': 'new'},
    );
    // M-N7 (the spec's own): `{...committed, ...current}` lets the changed
    // geometry overwrite the committed entry.
    expect(merged, {
      'a.b.c@1': 'committed',
      'b.c.d@1': 'new',
      'c.d.e@1': 'retired',
    });
    expect(merged.keys.toList(), ['a.b.c@1', 'b.c.d@1', 'c.d.e@1']);
  });
}
```

- [ ] **Step 2: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/snapshot_test.dart`. Expected: compilation errors (`Undefined name 'geometrySnapshot'`).

- [ ] **Step 3: The snapshot.** Create `lib/src/authoring/snapshot.dart`:

```dart
// The geometry snapshot (spec K7): per key@version, a canonical JSON text of
// its base point, shapes and unit. A kit commits it; the conformance test
// holds every published key@N to it, and the generator only ever adds to it.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:collection';
import 'dart:convert';

import 'catalog.dart';

/// Each symbol of [catalog] by `key@version`, sorted, as a canonical JSON
/// text: keys sorted, numbers in Dart's shortest round-trip form, -0 as 0.
SplayTreeMap<String, String> geometrySnapshot(Catalog catalog) =>
    SplayTreeMap.of({
      for (final s in catalog.symbols) s.id: jsonEncode(_entry(s)),
    });

Map<String, Object?> _entry(CatalogSymbol s) => {
      'base': _point(s.base),
      'shapes': [for (final shape in s.shapes) _shape(shape)],
      'unit': switch (s.unit) {
        null => null,
        final CatalogUnit u => {
            'capacity': u.capacity,
            'kind': u.kind,
            'labelling': u.labelling.name,
          },
      },
    };

Map<String, Object?> _shape(CatalogShape shape) => switch (shape) {
      CatalogLine(:final from, :final to) => {
          'from': _point(from),
          'kind': 'line',
          'to': _point(to),
        },
      CatalogPolyline(:final points, :final closed) => {
          'closed': closed,
          'kind': 'polyline',
          'points': [for (final p in points) _point(p)],
        },
      CatalogCircle(:final center, :final radius) => {
          'center': _point(center),
          'kind': 'circle',
          'radius': _number(radius),
        },
      CatalogArc(:final center, :final radius, :final start, :final sweep) => {
          'center': _point(center),
          'kind': 'arc',
          'radius': _number(radius),
          'start': _number(start),
          'sweep': _number(sweep),
        },
    };

List<double> _point(CatalogPoint p) => [_number(p.$1), _number(p.$2)];

/// -0.0 is the same geometry as 0.0, and is written so.
double _number(double v) => v == 0 ? 0.0 : v;

/// A committed snapshot's text, each entry re-encoded canonically. Throws
/// [FormatException] when [text] is not a JSON object of objects.
SplayTreeMap<String, String> parseSnapshot(String text) {
  final Object? json = jsonDecode(text);
  if (json is! Map<String, Object?>) {
    throw const FormatException('a geometry snapshot is a JSON object');
  }
  final snapshot = SplayTreeMap<String, String>();
  for (final MapEntry(:key, :value) in json.entries) {
    if (value is! Map) {
      throw FormatException('the snapshot entry "$key" is not an object');
    }
    snapshot[key] = jsonEncode(value);
  }
  return snapshot;
}

/// [snapshot] as its file: one entry per line, sorted by key.
String encodeSnapshot(Map<String, String> snapshot) {
  final keys = snapshot.keys.toList()..sort();
  if (keys.isEmpty) return '{}\n';
  final lines = [for (final k in keys) '  ${jsonEncode(k)}: ${snapshot[k]}'];
  return '{\n${lines.join(',\n')}\n}\n';
}

/// The generator's merge: every entry of [committed] as it is, plus the
/// entries of [current] it lacks. Never rewrites an existing entry, so a
/// changed geometry shows as a failing conformance test, never as a quietly
/// regenerated file.
SplayTreeMap<String, String> updateSnapshot(
        Map<String, String> committed, Map<String, String> current) =>
    SplayTreeMap.of({...current, ...committed});
```

In `lib/authoring.dart`, add `export 'src/authoring/snapshot.dart';` (after `shapes.dart`). Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/snapshot_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 4: The sample kit.** Create `test/fixtures/sample_kit/sample_kit.dart`:

```dart
// The sample kit (spec K7, "Tests"): a stand-in for the architecture and
// restaurant kits of sub-projects 3 and 4. Every shape kind, both unit
// kinds and labellings, attachment kinds and a family, the shape helpers,
// two declared locales, everything off the origin.
import 'dart:math' as math;

import 'package:jet_cad_2d_kit/authoring.dart';

const String tables = 'Tables';
const String bar = 'Bar';
const String bedroom = 'Bedroom';

final List<CatalogSymbol> sampleSymbols = [
  CatalogSymbol(
    key: 'sample.table.round-four',
    name: 'Round table, 4 seats',
    category: tables,
    tags: const ['table', 'round', 'four'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 4),
    base: (2000, 1500),
    shapes: [
      const CatalogCircle((2000, 1500), 450),
      ...chairsAround(2000, 1500, 450, 4),
    ],
  ),
  CatalogSymbol(
    key: 'sample.table.rect-two',
    version: 2,
    name: 'Rectangular table, 2 seats',
    category: tables,
    tags: const ['table', 'rectangular', 'two'],
    unit: const CatalogUnit(kind: UnitKinds.table, capacity: 2),
    base: (1400, 1100),
    shapes: [
      rect(1000, 800, 800, 600),
      inset(1000, 800, 800, 600, 50),
      ...chairAt(1400, 675, math.pi / 2),
      ...chairAt(1400, 1525, -math.pi / 2),
    ],
  ),
  CatalogSymbol(
    key: 'sample.stool.bar',
    name: 'Bar stool',
    category: bar,
    tags: const ['stool', 'bar', 'seat'],
    unit: const CatalogUnit(
        kind: UnitKinds.seat, capacity: 1, labelling: UnitLabelling.assigned),
    base: (640, 410),
    shapes: [
      ...stoolAt(640, 410),
      const CatalogArc((640, 410), 230, 0.4, 2.3),
    ],
  ),
  CatalogSymbol(
    key: 'sample.bed.double',
    name: 'Double bed',
    category: bedroom,
    tags: const ['bed', 'double', 'sleeping'],
    attachTo: const ['wall-face'],
    family: 'bed-double',
    base: (900, 1050),
    shapes: [
      rect(100, 50, 1600, 2000),
      const CatalogLine((100, 1350), (1700, 1350)),
      rect(200, 1750, 650, 240),
      rect(950, 1750, 650, 240),
    ],
  ),
];

final Catalog sampleCatalog = Catalog(kit: 'sample', symbols: sampleSymbols);

const List<String> sampleLocales = ['de', 'tr'];

/// "Bar" is the right word for a bar in German and in Turkish.
const Map<String, Set<String>> sampleSameAsEnglish = {
  'de': {'category:sample/Bar'},
  'tr': {'category:sample/Bar'},
};

const KitNames sampleNames = KitNames({
  'de': {
    'symbol:sample.table.round-four': 'Runder Tisch, 4 Plätze',
    'symbol:sample.table.rect-two': 'Rechteckiger Tisch, 2 Plätze',
    'symbol:sample.stool.bar': 'Barhocker',
    'symbol:sample.bed.double': 'Doppelbett',
    'category:sample/Tables': 'Tische',
    'category:sample/Bar': 'Bar',
    'category:sample/Bedroom': 'Schlafzimmer',
  },
  'tr': {
    'symbol:sample.table.round-four': 'Yuvarlak masa, 4 kişilik',
    'symbol:sample.table.rect-two': 'Dikdörtgen masa, 2 kişilik',
    'symbol:sample.stool.bar': 'Bar taburesi',
    'symbol:sample.bed.double': 'Çift kişilik yatak',
    'category:sample/Tables': 'Masalar',
    'category:sample/Bar': 'Bar',
    'category:sample/Bedroom': 'Yatak odası',
  },
});
```

Create `test/fixtures/sample_kit/generate.dart`:

```dart
// The sample kit's generator, as a kit's own runs (spec K7): writes the
// library and adds the snapshot entries of new key@Ns, never rewriting an
// existing one.
//
//   cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart
import 'dart:io';

import 'package:jet_cad_2d_kit/authoring.dart';

import 'sample_kit.dart';

void main() {
  final dir = File.fromUri(Platform.script).parent.path;
  File('$dir/sample.jetlib').writeAsBytesSync(encodeLibrary(sampleCatalog));
  final snapshot = File('$dir/sample_snapshot.json');
  final committed = snapshot.existsSync()
      ? parseSnapshot(snapshot.readAsStringSync())
      : <String, String>{};
  snapshot.writeAsStringSync(encodeSnapshot(
      updateSnapshot(committed, geometrySnapshot(sampleCatalog))));
  stdout.writeln('sample kit: ${sampleCatalog.symbols.length} symbols written');
}
```

- [ ] **Step 5: The conformance test.** Create `test/authoring/conformance_test.dart`:

```dart
// Spec K7: the conformance test. The sample kit conforms; each failing kit
// changes one thing of it (and regenerates what a kit's generator would),
// so it can only go red through its own problem.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/authoring.dart';

import '../fixtures/sample_kit/sample_kit.dart';

const String dir = 'test/fixtures/sample_kit';

Uint8List committedLibrary() => File('$dir/sample.jetlib').readAsBytesSync();

String committedSnapshot() =>
    File('$dir/sample_snapshot.json').readAsStringSync();

List<KitProblem> problems({
  Catalog? catalog,
  Uint8List? library,
  String? snapshot,
  KitNames names = sampleNames,
  List<String> locales = sampleLocales,
  Map<String, Set<String>> sameAsEnglish = sampleSameAsEnglish,
}) =>
    conformance(
      catalog: catalog ?? sampleCatalog,
      committedLibrary: library ?? committedLibrary(),
      committedSnapshot: snapshot ?? committedSnapshot(),
      names: names,
      locales: locales,
      sameAsEnglish: sameAsEnglish,
    );

List<KitProblemCode> codes(List<KitProblem> problems) =>
    [for (final p in problems) p.code];

CatalogSymbol symbolOf(String id) =>
    sampleSymbols.firstWhere((s) => s.id == id);

CatalogSymbol copyOf(CatalogSymbol s,
        {String? key,
        int? version,
        String? name,
        List<String>? tags,
        List<String>? attachTo,
        String? family,
        CatalogUnit? unit,
        List<CatalogShape>? shapes}) =>
    CatalogSymbol(
      key: key ?? s.key,
      version: version ?? s.version,
      name: name ?? s.name,
      category: s.category,
      tags: tags ?? s.tags,
      attachTo: attachTo ?? s.attachTo,
      family: family ?? s.family,
      unit: unit ?? s.unit,
      base: s.base,
      shapes: shapes ?? s.shapes,
    );

/// The sample catalog with [symbol] in place of the one of its id.
Catalog replacing(CatalogSymbol symbol) => Catalog(kit: 'sample', symbols: [
      for (final s in sampleSymbols) s.id == symbol.id ? symbol : s,
    ]);

/// [names] with [edits] applied to [locale]: a null value removes the word.
KitNames editing(KitNames names, String locale, Map<String, String?> edits) {
  final words = {...?names.words[locale]};
  for (final MapEntry(key: id, value: word) in edits.entries) {
    if (word == null) {
      words.remove(id);
    } else {
      words[id] = word;
    }
  }
  return KitNames({...names.words, locale: words});
}

/// The library and the snapshot a kit's generator would write for [catalog]
/// over the committed snapshot.
({Uint8List library, String snapshot}) generated(Catalog catalog) => (
      library: encodeLibrary(catalog),
      snapshot: encodeSnapshot(updateSnapshot(
          parseSnapshot(committedSnapshot()), geometrySnapshot(catalog))),
    );

void main() {
  test('F0 the sample kit conforms', () {
    expect(problems(), isEmpty);
  });

  test('F0b premise: the committed files are the sample kit', () {
    final library = SymbolLibrary.decode(committedLibrary());
    expect(library.kits, ['sample']);
    expect([for (final e in library.entries) e.id], [
      'sample.table.round-four@1',
      'sample.table.rect-two@2',
      'sample.stool.bar@1',
      'sample.bed.double@1',
    ]);
    expect(parseSnapshot(committedSnapshot()).keys.toList(), [
      'sample.bed.double@1',
      'sample.stool.bar@1',
      'sample.table.rect-two@2',
      'sample.table.round-four@1',
    ]);
  });

  test('F1 built differs from committed: a renamed symbol', () {
    final renamed = replacing(
        copyOf(symbolOf('sample.bed.double@1'), name: 'Double bed, 160'));
    // M-F1: drop the byte comparison.
    expect(codes(problems(catalog: renamed)), [KitProblemCode.builtDiffers]);
  });

  test('F2 the committed library does not validate', () {
    expect(
        codes(problems(library: Uint8List.fromList(utf8.encode('{}')))),
        [KitProblemCode.builtDiffers, KitProblemCode.libraryInvalid]);
  });

  test("F3 the committed library is another kit's", () {
    final other = encodeLibrary(const Catalog(kit: 'other', symbols: [
      CatalogSymbol(
        key: 'other.table.round',
        name: 'Round table',
        category: 'Tables',
        base: (700, 700),
        shapes: [CatalogCircle((700, 700), 400)],
      ),
    ]));
    // M-F3: drop the kit comparison.
    expect(codes(problems(library: other)),
        [KitProblemCode.builtDiffers, KitProblemCode.libraryKitMismatch]);
  });

  test("F4 a key under another kit's id", () {
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.stool.bar@1'), key: 'other.stool.bar'),
    ]);
    // M-F4: drop the kit-of-key check (the catalog then fails to build).
    final found = problems(catalog: catalog);
    expect(codes(found), [KitProblemCode.keyOutsideKit]);
    expect(found.single.message, contains('other.stool.bar@1'));
  });

  test('F5 a moved vertex of a committed key@1', () {
    final bed = symbolOf('sample.bed.double@1');
    final moved = replacing(copyOf(bed, shapes: [
      bed.shapes[0],
      const CatalogLine((100, 1351), (1700, 1351)),
      ...bed.shapes.skip(2),
    ]));
    // M-F5: compare the snapshot's keys only.
    final found = problems(catalog: moved, library: encodeLibrary(moved));
    expect(codes(found), [KitProblemCode.snapshotChanged]);
    expect(found.single.message, contains('sample.bed.double@1'));
    expect(found.single.message, contains('1351.0'));
  });

  test('F6 a changed capacity', () {
    final more = replacing(copyOf(symbolOf('sample.table.round-four@1'),
        unit: const CatalogUnit(kind: UnitKinds.table, capacity: 5)));
    expect(codes(problems(catalog: more, library: encodeLibrary(more))),
        [KitProblemCode.snapshotChanged]);
  });

  test('F7 the same change at a new version conforms', () {
    // Review Focus 5: one key at two versions.
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.table.round-four@1'),
          version: 2,
          unit: const CatalogUnit(kind: UnitKinds.table, capacity: 5)),
    ]);
    final g = generated(catalog);
    expect(
        problems(catalog: catalog, library: g.library, snapshot: g.snapshot),
        isEmpty);
    expect(parseSnapshot(g.snapshot).keys,
        containsAll(['sample.table.round-four@1', 'sample.table.round-four@2']));
  });

  test('F8 a removed key', () {
    final fewer = Catalog(kit: 'sample', symbols: [
      for (final s in sampleSymbols)
        if (s.key != 'sample.stool.bar') s,
    ]);
    var names = editing(sampleNames, 'de', {'symbol:sample.stool.bar': null});
    names = editing(names, 'tr', {'symbol:sample.stool.bar': null});
    // The Bar category goes with its only symbol.
    names = editing(names, 'de', {'category:sample/Bar': null});
    names = editing(names, 'tr', {'category:sample/Bar': null});
    // M-F8: skip committed entries the catalog lacks.
    final found =
        problems(catalog: fewer, library: encodeLibrary(fewer), names: names);
    expect(codes(found), [KitProblemCode.keyRemoved]);
    expect(found.single.message, contains('sample.stool.bar@1'));
  });

  test('F9 a key@N missing from the committed snapshot', () {
    final snapshot = parseSnapshot(committedSnapshot())
      ..remove('sample.bed.double@1');
    expect(codes(problems(snapshot: encodeSnapshot(snapshot))),
        [KitProblemCode.snapshotMissing]);
  });

  test('F10 an unreadable snapshot', () {
    expect(codes(problems(snapshot: 'not json')),
        [KitProblemCode.snapshotUnreadable]);
  });

  test('F11 a missing Turkish word; a declared locale with no words', () {
    // An English word for the key too, so a lookup that falls back to
    // English (M-F11) finds one and reports something else.
    final found = problems(
        names: editing(
            editing(sampleNames, 'tr', {'symbol:sample.bed.double': null}),
            'en',
            {'symbol:sample.bed.double': 'Double bed'}));
    expect(codes(found), [KitProblemCode.wordMissing]);
    expect(found.single.message, contains('tr'));
    expect(found.single.message, contains('symbol:sample.bed.double'));
    final onlyGerman = KitNames({'de': sampleNames.words['de']!});
    expect(codes(problems(names: onlyGerman)),
        List.filled(7, KitProblemCode.wordMissing));
  });

  test('F12 a word equal to its English, unless the kit allows it', () {
    // M-F12a: drop the equality check.
    expect(
        codes(problems(
            names: editing(
                sampleNames, 'tr', {'symbol:sample.stool.bar': 'Bar stool'}))),
        [KitProblemCode.wordUntranslated]);
    // M-F12b: ignore the allow-list; F0 goes red too.
    expect(codes(problems(sameAsEnglish: const {})),
        [KitProblemCode.wordUntranslated, KitProblemCode.wordUntranslated]);
  });

  test('F13 a word for a key or a category the catalog lacks', () {
    for (final (locale, id) in [
      ('tr', 'symbol:sample.table.square'),
      ('de', 'category:sample/Kitchen'),
      // A category under another kit's id is not this kit's word.
      ('tr', 'category:other/Tables'),
      ('en', 'symbol:sample.gone.away'),
    ]) {
      // M-F13: check the declared locales only; the "en" case passes.
      expect(codes(problems(names: editing(sampleNames, locale, {id: 'x'}))),
          [KitProblemCode.wordOrphan],
          reason: '$locale $id');
    }
  });

  test('F14 a locale with words that is not declared', () {
    expect(
        codes(problems(
            names: editing(
                sampleNames, 'fr', {'symbol:sample.bed.double': 'Lit double'}))),
        [KitProblemCode.localeUndeclared]);
  });

  test('F15 lower case for keys, tags, target kinds, families and kinds', () {
    final round = symbolOf('sample.table.round-four@1');
    final bed = symbolOf('sample.bed.double@1');
    for (final changed in [
      copyOf(round, tags: const ['table', 'Round']),
      copyOf(round, key: 'sample.Table.round-four'),
      copyOf(round, unit: const CatalogUnit(kind: 'Table', capacity: 4)),
      copyOf(bed, family: 'Bed-double'),
      copyOf(bed, attachTo: const ['Wall-face']),
    ]) {
      final catalog = changed.key == round.key || changed.key == bed.key
          ? replacing(changed)
          : Catalog(kit: 'sample', symbols: [...sampleSymbols, changed]);
      // M-F15: drop one of the five checks; its case goes red.
      expect(codes(problems(catalog: catalog)), [KitProblemCode.notLowerCase],
          reason: changed.id);
    }
  });

  test('F16 a catalog that does not build', () {
    final twoSegments = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(symbolOf('sample.stool.bar@1'), key: 'sample.stool'),
    ]);
    expect(codes(problems(catalog: twoSegments)),
        [KitProblemCode.catalogInvalid]);
    final twice = Catalog(
        kit: 'sample', symbols: [...sampleSymbols, sampleSymbols.first]);
    final found = problems(catalog: twice);
    expect(codes(found), [KitProblemCode.catalogInvalid]);
    expect(found.single.message, contains('rule 6'));
  });

  test("F17 English is not a declared locale: it is always required", () {
    expect(() => problems(locales: const ['en', 'tr']), throwsArgumentError);
  });

  test('F18 an empty kit conforms', () {
    // Review Focus 4.
    const empty = Catalog(kit: 'sample', symbols: []);
    expect(
        conformance(
          catalog: empty,
          committedLibrary: encodeLibrary(empty),
          committedSnapshot: '{}\n',
          names: KitNames.empty,
          locales: const ['tr'],
        ),
        isEmpty);
  });

  test("F19 a word is compared with the key's newest English", () {
    // Review Focus 5. M-F19: compare with the first version's name.
    final stool = symbolOf('sample.stool.bar@1');
    final catalog = Catalog(kit: 'sample', symbols: [
      ...sampleSymbols,
      copyOf(stool, version: 2, name: 'High bar stool'),
    ]);
    final g = generated(catalog);
    List<KitProblemCode> withTurkish(String word) => codes(problems(
        catalog: catalog,
        library: g.library,
        snapshot: g.snapshot,
        names: editing(sampleNames, 'tr', {'symbol:sample.stool.bar': word})));
    expect(withTurkish('High bar stool'), [KitProblemCode.wordUntranslated]);
    expect(withTurkish('Bar stool'), isEmpty);
  });
}
```

Note F15's `copyOf(round, key: 'sample.Table.round-four')` has an id other than the round table's, so `replacing` would not replace it; the conditional adds it beside the sample symbols instead (its words are irrelevant: the check ends at the catalog problems).

- [ ] **Step 6: Run it to see it fail.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring/conformance_test.dart`. Expected: compilation error (`Undefined name 'conformance'`).

- [ ] **Step 7: The conformance test.** Create `lib/src/authoring/conformance.dart`:

```dart
// The conformance test (spec K7, umbrella A16): a kit's own test calls it
// and expects an empty list. It holds the kit to its committed library, its
// committed geometry snapshot and its words.
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart' show listEquals;

import '../model/kit_ids.dart';
import '../model/kit_names.dart';
import '../model/kit_problem.dart';
import '../model/symbol_library.dart';
import 'builder.dart';
import 'catalog.dart';
import 'snapshot.dart';

/// The problems of a kit: its [catalog], its [committedLibrary] bytes, its
/// [committedSnapshot] text, its [names] and its declared non-English
/// [locales]. [sameAsEnglish] lists, per locale, the word ids whose right
/// word is the English one. Empty when the kit conforms.
///
/// Throws [ArgumentError] when [locales] lists English: English is always
/// required, by stored text or by words.
List<KitProblem> conformance({
  required Catalog catalog,
  required Uint8List committedLibrary,
  required String committedSnapshot,
  required KitNames names,
  required List<String> locales,
  Map<String, Set<String>> sameAsEnglish = const {},
}) {
  if (locales.contains(KitNames.english)) {
    throw ArgumentError.value(locales, 'locales',
        "lists the kit's other locales; English is always required");
  }
  final problems = _catalogProblems(catalog);
  if (problems.isNotEmpty) return problems;
  final Uint8List built;
  try {
    built = encodeLibrary(catalog);
  } catch (e) {
    return [
      KitProblem(KitProblemCode.catalogInvalid, 'the catalog does not build: $e'),
    ];
  }
  if (!listEquals(built, committedLibrary)) {
    problems.add(const KitProblem(KitProblemCode.builtDiffers,
        "the committed library is not the catalog's: run the kit's generator"));
  }
  try {
    final library = SymbolLibrary.decode(committedLibrary);
    if (library.kits.single != catalog.kit) {
      problems.add(KitProblem(
          KitProblemCode.libraryKitMismatch,
          'the committed library holds the kit "${library.kits.single}", not '
          '"${catalog.kit}"'));
    }
  } on SymbolLibraryError catch (e) {
    problems.add(KitProblem(KitProblemCode.libraryInvalid,
        'the committed library is refused, rule ${e.rule}: ${e.message}'));
  }
  problems
    ..addAll(_snapshotProblems(catalog, committedSnapshot))
    ..addAll(_wordProblems(catalog, names, locales, sameAsEnglish));
  return problems;
}

/// Checks 3 and 6, on the catalog itself: keys under the kit, lower case.
List<KitProblem> _catalogProblems(Catalog catalog) {
  final problems = <KitProblem>[];
  void lower(CatalogSymbol s, String what, String value) {
    if (value != value.toLowerCase()) {
      problems.add(KitProblem(KitProblemCode.notLowerCase,
          '${s.id}: the $what "$value" is not lower case'));
    }
  }

  for (final s in catalog.symbols) {
    lower(s, 'key', s.key);
    for (final tag in s.tags) {
      lower(s, 'tag', tag);
    }
    for (final kind in s.attachTo) {
      lower(s, 'target kind', kind);
    }
    final family = s.family;
    if (family != null) lower(s, 'family', family);
    final unit = s.unit;
    if (unit != null) lower(s, 'unit kind', unit.kind);
    if (kitOfKey(s.key) != catalog.kit) {
      problems.add(KitProblem(KitProblemCode.keyOutsideKit,
          '${s.id} is not under the kit "${catalog.kit}"'));
    }
  }
  return problems;
}

/// Check 4: every committed entry is in the current snapshot and equal to
/// it; every current entry is committed.
List<KitProblem> _snapshotProblems(Catalog catalog, String text) {
  final Map<String, String> committed;
  try {
    committed = parseSnapshot(text);
  } on FormatException catch (e) {
    return [
      KitProblem(KitProblemCode.snapshotUnreadable,
          'the committed snapshot is not readable: ${e.message}'),
    ];
  }
  final current = geometrySnapshot(catalog);
  final problems = <KitProblem>[];
  for (final MapEntry(key: id, value: was) in committed.entries) {
    final now = current[id];
    if (now == null) {
      problems.add(KitProblem(KitProblemCode.keyRemoved,
          '$id is committed but not in the catalog: a key is never removed'));
    } else if (now != was) {
      problems.add(KitProblem(
          KitProblemCode.snapshotChanged,
          '$id changed its geometry or its unit; a published key@N never '
          'does: add the change at a new version.\n'
          '  committed: $was\n'
          '  current:   $now'));
    }
  }
  for (final id in current.keys) {
    if (!committed.containsKey(id)) {
      problems.add(KitProblem(KitProblemCode.snapshotMissing,
          "$id is not in the committed snapshot: run the kit's generator"));
    }
  }
  return problems;
}

/// Check 5: every declared locale complete, no word the catalog lacks, no
/// undeclared locale.
List<KitProblem> _wordProblems(Catalog catalog, KitNames names,
    List<String> locales, Map<String, Set<String>> sameAsEnglish) {
  // The English of each word id: a key's newest version's name, a
  // category's own text.
  final newest = <String, int>{};
  final english = <String, String>{};
  for (final s in catalog.symbols) {
    if (s.version >= (newest[s.key] ?? 0)) {
      newest[s.key] = s.version;
      english[KitNames.symbolWord(s.key)] = s.name;
    }
  }
  for (final s in catalog.symbols) {
    english[KitNames.categoryWord(catalog.kit, s.category)] = s.category;
  }

  final problems = <KitProblem>[];
  for (final locale in names.words.keys) {
    if (locale != KitNames.english && !locales.contains(locale)) {
      problems.add(KitProblem(KitProblemCode.localeUndeclared,
          '$locale has words but is not declared: a declared locale is complete'));
    }
  }
  for (final MapEntry(key: locale, value: words) in names.words.entries) {
    for (final id in words.keys) {
      final ours = id.startsWith('symbol:') || id.startsWith('category:');
      if (ours && !english.containsKey(id)) {
        problems.add(KitProblem(KitProblemCode.wordOrphan,
            '$locale: "$id" names nothing in the catalog'));
      }
    }
  }
  for (final locale in locales) {
    final words = names.words[locale] ?? const <String, String>{};
    final allowed = sameAsEnglish[locale] ?? const <String>{};
    for (final MapEntry(key: id, value: en) in english.entries) {
      final word = words[id];
      if (word == null) {
        problems.add(
            KitProblem(KitProblemCode.wordMissing, '$locale: no word for "$id"'));
      } else if (word == en && !allowed.contains(id)) {
        problems.add(KitProblem(
            KitProblemCode.wordUntranslated,
            '$locale: "$id" is its English, "$en"; list it in sameAsEnglish '
            'if that is the right word'));
      }
    }
  }
  return problems;
}
```

In `lib/authoring.dart`, the exports become:

```dart
export 'src/authoring/builder.dart';
export 'src/authoring/catalog.dart';
export 'src/authoring/conformance.dart';
export 'src/authoring/shapes.dart';
export 'src/authoring/snapshot.dart';
export 'src/model/model.dart';
```

- [ ] **Step 8: Generate the sample kit's committed files.** Run: `cd packages/jet_cad_2d_kit && dart run test/fixtures/sample_kit/generate.dart`. Expected output: `sample kit: 4 symbols written`. Then `head -c 300 test/fixtures/sample_kit/sample_snapshot.json` (expect `{` and the line of `"sample.bed.double@1": {"base":[900.0,1050.0],...`). Stage the two generated files by explicit path (`git add packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample.jetlib packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample_snapshot.json`, from the root), run the generator a second time, and `git diff --quiet -- test/fixtures/sample_kit/sample.jetlib test/fixtures/sample_kit/sample_snapshot.json` must exit 0 (the generator is idempotent). No copy aside.

- [ ] **Step 9: Run the tests.** Run: `cd packages/jet_cad_2d_kit && flutter test test/authoring test/invariants`. Expected: `All tests passed!`.

- [ ] **Step 10: Mutation check** (on committed files; revert each with `git checkout -- <file>` and check `git diff --quiet`; the generated files are never edited by hand):
  - M-N7 (the spec's own): `SplayTreeMap.of({...committed, ...current})` → N7 red.
  - M-N1a: drop `'closed': closed,` → N1 red. M-N2: `_number` returns `v` → N2 red.
  - M-F1: delete the `listEquals` byte comparison → F1 red (and F2, F3).
  - M-F3: delete the kit comparison → F3 red.
  - M-F4: delete the `kitOfKey` check → F4 red (the catalog then fails to build: `catalogInvalid`).
  - M-F5: `else if (false)` in place of `else if (now != was)` → F5, F6 red.
  - M-F8: delete the `now == null` branch → F8 red.
  - M-F11: `final word = names.word(locale, id);` (falls back to English) → F11 red.
  - M-F12a: delete the `else if (word == en ...)` branch → F12 red; M-F12b: `final allowed = const <String>{};` → F0 and F12 red.
  - M-F13: loop over `locales` instead of `names.words` in the orphan check → F13 red (the `en` case).
  - M-F15: delete the `lower(s, 'family', family)` call → F15 red (the family case: without the check the catalog still builds, but not as a case of `notLowerCase`: K2's constructors refuse an upper-case family, so the result is `catalogInvalid`, and the expected code is missing). Conformance check 6 (lower case) is shadowed by K2's constructors, which refuse upper case when the catalog builds; the check is kept as defence in depth.
  - M-F19: `if (!newest.containsKey(s.key))` in place of the version comparison → F19 red.

- [ ] **Step 11: The gate.** `cd packages/jet_cad_2d_kit && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — all exit 0. P1 now reaches `conformance.dart` and `snapshot.dart` and finds them pure.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/authoring.dart packages/jet_cad_2d_kit/lib/src/authoring/snapshot.dart packages/jet_cad_2d_kit/lib/src/authoring/conformance.dart packages/jet_cad_2d_kit/test/authoring/snapshot_test.dart packages/jet_cad_2d_kit/test/authoring/conformance_test.dart packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample_kit.dart packages/jet_cad_2d_kit/test/fixtures/sample_kit/generate.dart packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample.jetlib packages/jet_cad_2d_kit/test/fixtures/sample_kit/sample_snapshot.json
git commit -m "$(cat <<'EOF'
feat(kit): the geometry snapshot and the conformance test (K7)

geometrySnapshot writes each key@N's base, shapes and unit as canonical
JSON; updateSnapshot only adds entries, so a changed geometry fails the
test instead of regenerating. conformance holds a kit to its committed
library and snapshot, its keys to its id, its words to completeness.
A sample kit under test/fixtures runs the whole path and conforms; one
failing kit per problem shows each check.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

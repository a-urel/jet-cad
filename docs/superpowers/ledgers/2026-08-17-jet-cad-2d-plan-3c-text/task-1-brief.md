## Task 1: Codec, schema 4, and the defensive scalar read

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart` (`toJson`, `fromJson`)
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart`
- Create: `packages/jet_cad_2d/lib/src/document/text_scalars.dart`
- Create: `packages/jet_cad_2d/test/codec/schema_v3_fixture_test.dart`
- Modify: `packages/jet_cad_2d/test/testing/generate_document_test.dart` (re-baseline the two fingerprints)

**Interfaces:**
- Consumes: Task 0's record fields.
- Produces: `double scalarOr(GeometryPayload payload, int index, double fallback)`; `kSchemaVersion == 4`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/codec/schema_v3_fixture_test.dart
const _v3Document = '''
{"schemaVersion":3,"header":{},"tables":{"layers":[],"linetypes":[],
"textStyles":[],"patterns":[]},"tree":{"nodes":[]},"entities":[
{"record":{"handle":"0x1","owner":"0x0","kind":"text","layer":"0x10",
"linetype":"0x20","linetypeScale":1.0,"color":-1,"lineweight":-3,
"transparency":-1,"flags":0},
"geometry":{"coords":[10.0,20.0],"scalars":[100.0]}}],
"components":{},"rawData":{}}
''';

test('a version-3 document loads under the version-4 build', () {
  final doc = decodeDocument(_v3Document);
  final slot = doc.entities.liveSlots.single;
  expect(doc.entities.textAt(slot), '');
  expect(doc.entities.tagAt(slot), '');
  expect(doc.entities.textStyleAt(slot), ReservedHandles.standardTextStyle);
  expect(doc.entities.textAttrsAt(slot), 0);
  // One scalar, not four. Reading scalars[1] must not throw.
  final payload = doc.geometry.read(doc.entities.geomIndexAt(slot));
  expect(scalarOr(payload, 1, 0.0), 0.0);
  expect(scalarOr(payload, 0, 0.0), 100.0);
});

test('a version-3 document survives a round-trip unpadded', () {
  final once = encodeDocument(decodeDocument(_v3Document));
  final twice = encodeDocument(decodeDocument(once));
  expect(twice, once);
  // The payload is not rewritten on load: padding it would change geometry
  // the file never contained.
  expect(once.contains('"scalars":[100.0]'), isTrue);
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/codec/schema_v3_fixture_test.dart`
Expected: FAIL — `scalarOr` is undefined.

- [ ] **Step 3: Write the helper**

```dart
// lib/src/document/text_scalars.dart
import '../store/geometry_store.dart';

/// Reads a scalar that a document written before Plan 3c does not carry.
///
/// A text entity written at schema 3 holds exactly one scalar — its height —
/// so `scalars[1..3]` is a `RangeError` on every such document. The payload is
/// **not** padded on load: padding would write geometry the file did not
/// contain and would make `save(load(save(d))) == save(d)` compare a padded
/// payload against an unpadded one.
double scalarOr(GeometryPayload payload, int index, double fallback) =>
    index < payload.scalars.length ? payload.scalars[index] : fallback;
```

- [ ] **Step 4: Extend the codec**

In `EntityRecord.toJson`, after `'flags': flags,`:

```dart
        'text': text,
        'tag': tag,
        'textStyle': textStyle.toJson(),
        'textAttrs': textAttrs,
```

In `fromJson`, absent-key defaults — these four lines *are* the v3→v4 migration, because `json_codec.dart:103` rejects only versions **above** the current one:

```dart
      text: json['text'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      textStyle: json['textStyle'] == null
          ? ReservedHandles.standardTextStyle
          : Handle.fromJson(json['textStyle']),
      textAttrs: json['textAttrs'] as int? ?? 0,
```

Bump `kSchemaVersion` to `4` and extend its doc comment with one line naming what changed.

- [ ] **Step 5: Re-baseline the corpus fingerprints**

The four new keys move both FNV-1a constants in `generate_document_test.dart:49-52`, and that test's own comment calls them "the whole guard" on corpus extensions. Re-baseline them **here**, in the codec commit, so the guard is voided and restored before Task 7 changes the corpus.

Run: `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart`
Read the two actual values out of the failure, replace the constants, and add one line to the comment: `# re-baselined in Plan 3c Task 1: the four text keys changed the serialisation.`

- [ ] **Step 6: Run the suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including the codec determinism, idempotence, round-trip and preserve-unknown tests.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib packages/jet_cad_2d/test
git commit -m "feat(jet_cad_2d): carry text fields through the codec at schema 4"
```

---


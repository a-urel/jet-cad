## Task 4: a v5 document resolves bit-identically under a v6 build

**Files:**
- Modify: `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart` — add one group

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: nothing. This task is proof, not mechanism.

**Why the fixture shape is named rather than left to judgement.** M10 changes
`fromJson`'s absent-`linetype` default from `byBlockLinetype` to
`byLayerLinetype`. That changes a *resolved style* only when the document
contains a BYBLOCK-linetype entity, inside a definition, placed through an
INSERT whose effective layer's linetype differs from the inherited context's.
Relying on the golden suite to catch it assumes some existing golden happens to
contain that shape, which nobody has verified. The fixture below contains it
explicitly, so M10 is killed by design rather than by luck.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d/test/codec/instance_style_codec_test.dart`:

```dart
  group('a v5 document resolves bit-identically under a v6 build', () {
    /// A v5 document: a v6 encoding with the four new instance keys stripped
    /// and the version declared back down.
    ///
    /// **Derived, not hand-written.** Hand-writing the whole document shape
    /// would put a second, drifting copy of the codec's JSON contract in a
    /// test file, and a fixture that silently fails to parse into anything
    /// proves less than nothing about migration. Encoding a real document and
    /// removing exactly the four keys a pre-3f.1 writer never wrote produces
    /// precisely what that writer produced, and stays correct when the rest of
    /// the shape changes.
    ///
    /// The document's shape is chosen so M10 has somewhere to land: entity 201
    /// is BYBLOCK-linetype, it lives inside definition 200, and instance 300
    /// sits on layer 100 whose linetype (71) differs from documentRoot's
    /// `continuousLinetype`. Under the correct BYBLOCK default the entity
    /// resolves to `continuousLinetype`; under M10's BYLAYER default it
    /// resolves to `Handle(71)`.
    Map<String, Object?> v5Document() {
      final doc = DraftDocument.empty();
      doc.tables.layers.add(const LayerRecord(
        handle: Handle(100),
        name: 'STRUCT',
        color: IndexedColor(5),
        linetype: Handle(71),
        lineweight: 191,
        transparency: 88,
        visible: true,
        locked: false,
      ));
      doc.tree.addDefinition(Definition(
          handle: const Handle(200),
          name: 'BOLT',
          basePoint: Vector2.zero(),
          children: const []));
      doc.commands.execute(AddEntityCommand(
        record: const EntityRecord(
          handle: Handle(201),
          owner: Handle(200),
          kind: EntityKind.line,
          layer: ReservedHandles.layerZero,
          linetype: ReservedHandles.byBlockLinetype,
          linetypeScale: 2.0,
          geomIndex: 0,
          color: ByBlockColor(),
          lineweight: kByBlock,
          transparency: kByBlock,
          flags: 0,
        ),
        payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 1, 1]),
          scalars: Float64List(0),
        ),
      ));
      doc.commands.execute(AddNodeCommand(InstanceNode(
        handle: const Handle(300),
        parent: doc.rootHandle,
        transform: Transform2.translation(31, 17),
        definition: const Handle(200),
        layer: const Handle(100),
      )));

      final json = DraftDocumentCodec.encode(doc);
      // Exactly the four keys a v5 writer did not write.
      for (final node in json['nodes']! as List<Object?>) {
        final map = node! as Map<String, Object?>;
        if (map['type'] != 'instance') continue;
        map.remove('lineweight');
        map.remove('transparency');
        map.remove('linetype');
        map.remove('linetypeScale');
      }
      json['schemaVersion'] = 5;
      return json;
    }

    test('every field of the resolved style matches the pre-3f.1 answer', () {
      final doc = DraftDocumentCodec.decode(v5Document());
      final resolver = DocumentStyleResolver(doc);
      final ctx = resolver.contextFor(const Handle(300),
          StyleContext.documentRoot);
      final style =
          resolver.styleFor(doc.entities.slotOf(const Handle(201))!, ctx);

      // The four answers a pre-3f.1 build produced for this document, written
      // as literals. Recomputing them from the current resolver would be a
      // tautology -- the code under test on both sides of the comparison.
      //
      // lineweight: the INSERT defaults to BYBLOCK, so the entity's BYBLOCK
      // reaches documentRoot's 25 -- NOT layer STRUCT's 191.
      expect(style.lineweightHundredths, 25);
      // transparency: same route to documentRoot's 0, so alpha is 255 --
      // NOT 255 - 88.
      expect(style.argb >> 24, 255);
      // linetype: BYBLOCK all the way to documentRoot's continuousLinetype.
      // This is the assertion M10 breaks.
      expect(style.linetype, ReservedHandles.continuousLinetype);
      // linetypeScale: the entity's own 2.0 times an INSERT that defaults to
      // the identity.
      expect(style.linetypeScale, 2.0);
    });

    test('a v6 build refuses nothing it wrote and everything from the future',
        () {
      // The bump's whole purpose is the reader. A v5 payload loads; a v7 one
      // is refused by version rather than by a FormatException deep inside a
      // field parse.
      expect(() => DraftDocumentCodec.decode(v5Document()), returnsNormally);
      final future = v5Document()..['schemaVersion'] = 7;
      expect(() => DraftDocumentCodec.decode(future),
          throwsA(isA<SchemaVersionError>()));
    });
  });
```

- [ ] **Step 2: Run it**

```sh
cd packages/jet_cad_2d && CI=true dart test test/codec/instance_style_codec_test.dart
```

Expected: both new tests PASS on the first run. **This is a regression guard,
not a red-green cycle** — Tasks 1–3 were built so that this is already true,
and a failure here means one of their defaults is not the no-op it claims to
be. If it fails, the defect is in Task 1's `fromJson` or Task 2's `contextFor`,
not in this test.

- [ ] **Step 3: Fire M10 again, this time for its resolution consequence**

`cp lib/src/document/node.dart /tmp/node.dart.bak`, change `fromJson`'s absent-
`linetype` default to `ReservedHandles.byLayerLinetype`, and run:

```sh
CI=true dart test test/codec/instance_style_codec_test.dart
```

Expected: `every field of the resolved style matches the pre-3f.1 answer` goes
red on `expect(style.linetype, ReservedHandles.continuousLinetype)`, reading
`Handle(71)`. Restore from the copy.

- [ ] **Step 4: Confirm criterion 11 — no golden moved**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test
git status --short packages/jet_cad_2d_flutter/test/golden
```

Expected: the suite green, and `git status` reports **nothing** under
`test/golden` — no PNG regenerated, none modified. Paste both outputs into the
task report.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d/test/codec/instance_style_codec_test.dart
git commit -m "test: a v5 document resolves bit-identically under v6

The migration's whole claim is that the four new defaults are no-ops. This
pins it against a v5 payload written as JSON rather than built through the
API -- built through the API it would carry v6 defaults and prove nothing.

The fixture shape is deliberate: a BYBLOCK-linetype entity inside a
definition, placed through an INSERT whose layer's linetype differs from
documentRoot's. Without that shape the mutant that defaults absent
linetypes to BYLAYER changes no resolved style and survives."
```

---


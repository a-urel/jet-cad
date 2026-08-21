## Task 7: Codec — schema 5, and the load-time rebuild

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/codec/schema_version.dart:10`
- Modify: `packages/jet_cad_2d/lib/src/codec/json_codec.dart`
- Modify: `packages/jet_cad_2d/test/codec/json_codec_test.dart`

**Interfaces:**
- Produces: `kSchemaVersion = 5`. `JsonCodec.load` leaves `doc.fills` fully populated — every link, every triangulation.

**Why the bump.** `json_codec.dart:103` rejects `version > kSchemaVersion`, so a v4 build must refuse a document containing `kind: "fill"` rather than choke inside `EntityKind.values.byName`. Nothing about the *shape* of the JSON changes — a fill is an entity and the existing entity serialisation already carries it.

**Why the rebuild is here.** `FillIndex` is derived state with one source of truth, and the frame path must never compute. A loaded document's fills are triangulated before its first frame.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a document with a region round-trips byte-identically', () {
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final first = jsonEncode(JsonCodec.save(doc));
    final reloaded = JsonCodec.load(jsonDecode(first) as Map<String, Object?>);
    expect(jsonEncode(JsonCodec.save(reloaded)), first);
  });

  test('load leaves the fill index populated, not empty', () {
    // The frame path reads and never computes. A load that left this empty
    // would ear-clip on the first paint of every visible fill.
    final doc = DraftDocument.empty();
    final cmd = AddRegionCommand.allocate(
      seed: doc.handleSeed,
      owner: doc.rootHandle,
      boundaryKind: EntityKind.polyline,
      boundaryPayload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
          scalars: Float64List(0)),
      layer: ReservedHandles.layerZero,
      fillColor: const TrueColor(0x3366CC),
      boundaryColor: const TrueColor(0x000000),
    );
    doc.commands.execute(cmd);
    final reloaded =
        JsonCodec.load(jsonDecode(jsonEncode(JsonCodec.save(doc))) as Map<String, Object?>);
    expect(reloaded.fills.fillsOf(cmd.boundary.handle), [cmd.fill.handle]);
    expect(reloaded.fills.trianglesFor(cmd.boundary.handle), hasLength(6));
  });

  test('the schema version is 5, and a v6 document is refused', () {
    expect(kSchemaVersion, 5);
    expect(() => JsonCodec.load({'schemaVersion': 6}), throwsA(anything));
  });
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — `kSchemaVersion` is 4, and `reloaded.fills` is empty.

- [ ] **Step 3: Implement**

`schema_version.dart`:

```dart
/// 5: `EntityKind.fill`. The JSON shape is unchanged -- a fill is an ordinary
/// entity and `kind` is written by name -- but a v4 reader must refuse a
/// document containing one rather than fail inside `EntityKind.values.byName`,
/// and the version check at `json_codec.dart:103` is what makes it.
const int kSchemaVersion = 5;
```

In `json_codec.dart`, after entities are loaded and before `doc.invalidateDerived()`:

```dart
    _rebuildFills(doc, diagnostics);
```

```dart
/// Rebuilds the fill index from the loaded entities.
///
/// Derived state with one source of truth: the document stores a fill's
/// boundary handle and nothing else, and everything else about a fill --
/// its link and its boundary's triangulation -- is computed here, once,
/// before the first frame.
///
/// A fill whose boundary is missing or unfillable is **linked anyway and left
/// without triangles**. Dropping the link would silently discard the user's
/// data; `validate()` reports the condition and the painter counts the skip.
void _rebuildFills(DraftDocument doc, List<Diagnostic>? diagnostics) {
  doc.fills.clear();
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) != EntityKind.fill) continue;
    final fill = doc.entities.handleAt(slot);
    final boundary =
        boundaryHandleOf(doc.geometry.peek(doc.entities.geomIndexAt(slot)));
    doc.fills.link(fill, boundary);
    final boundarySlot = doc.entities.slotOf(boundary);
    if (boundarySlot == null) continue;
    if (doc.fills.trianglesFor(boundary) != null) continue;
    final triangles = triangulationFor(
        doc.entities.kindAt(boundarySlot),
        doc.geometry.peek(doc.entities.geomIndexAt(boundarySlot)));
    if (triangles != null && triangles.isNotEmpty) {
      doc.fills.putTriangles(boundary, triangles);
    }
  }
}
```

- [ ] **Step 4: Run and watch it pass**

Run: `cd packages/jet_cad_2d && dart test test/codec/json_codec_test.dart`

- [ ] **Step 5: Run the named mutations**

```sh
# T7a: do not rebuild on load -- the frame path would then compute
perl -0pi -e 's/    _rebuildFills\(doc, diagnostics\);//' lib/src/codec/json_codec.dart   # must KILL
# T7b: leave kSchemaVersion at 4
perl -0pi -e 's/const int kSchemaVersion = 5;/const int kSchemaVersion = 4;/' lib/src/codec/schema_version.dart  # must KILL
```

Use the `cp`/`trap` harness from Task 2 for both.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/codec packages/jet_cad_2d/test/codec
git commit -m "feat: schema 5, and the fill index rebuilt at load"
```

---


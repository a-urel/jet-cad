## Task 8: `validate()` learns five fill codes

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/validate.dart`
- Modify: `packages/jet_cad_2d/test/document/validate_test.dart`

**Interfaces:**
- Produces, on `ValidationCodes`:
```dart
  static const String fillBoundaryMissing = 'fill.boundary_missing';
  static const String fillBoundaryNotFillable = 'fill.boundary_not_fillable';
  static const String fillBoundaryNotClosed = 'fill.boundary_not_closed';
  static const String fillBoundaryForeignOwner = 'fill.boundary_foreign_owner';
  static const String fillDrawOrderInverted = 'fill.draw_order_inverted';
```

**`validate()` reports and never mutates.** In particular, a document carrying `fill.handle > boundary.handle` is **not** reordered, renumbered or refused. A loader that silently re-sorts to preserve "ascending handle is draw order" breaks that rule in the act of defending it: the drawing would then differ from the file. The document draws as written, and the diagnostic says it will look wrong.

- [ ] **Step 1: Write the failing tests**

One fixture document per code — a suite that only asserts "validate returns
something" cannot tell which check was deleted.

```dart
/// Builds a fill naming [boundary] directly, bypassing AddRegionCommand, which
/// is the only way to produce the malformed documents this test is about.
Handle rawFill(DraftDocument doc, Handle boundary,
    {Handle? owner, Handle? handle}) {
  final h = handle ?? doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x3366CC),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List(0),
        scalars: Float64List.fromList([boundary.value.toDouble()])),
  ));
  return h;
}

test('a fill naming nothing is reported', () {
  final doc = DraftDocument.empty();
  rawFill(doc, const Handle(9999));
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryMissing));
});

/// Adds a leaf of [kind] with [coords] and returns its handle. `rawFill` and
/// these three tests are the only way to build the malformed documents
/// `validate()` is about -- `AddRegionCommand` refuses every one of them.
Handle rawLeaf(DraftDocument doc, EntityKind kind, List<double> coords,
    {Handle? owner, List<double> scalars = const [], String text = ''}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: h,
      owner: owner ?? doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
      text: text,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
  return h;
}

test('a fill on a text entity is reported as not fillable', () {
  final doc = DraftDocument.empty();
  final textHandle =
      rawLeaf(doc, EntityKind.text, [0, 0], scalars: [2.5], text: 'ROOM 3');
  rawFill(doc, textHandle);
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryNotFillable));
});

test('a fill on an open polyline is reported as not closed', () {
  final doc = DraftDocument.empty();
  final open = rawLeaf(doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10]);
  rawFill(doc, open);
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryNotClosed));
});

test('a fill in a different owner than its boundary is reported', () {
  final doc = DraftDocument.empty();
  final group = doc.handleSeed.next();
  doc.commands.execute(AddNodeCommand(
      GroupNode(handle: group, parent: doc.rootHandle)));
  final boundary = rawLeaf(
      doc, EntityKind.polyline, [0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
      owner: group);
  rawFill(doc, boundary);   // owner defaults to the root
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillBoundaryForeignOwner));
});

test('an inverted pair is reported and nothing is changed', () {
  final doc = DraftDocument.empty();
  final boundary = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: boundary,
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
        scalars: Float64List(0)),
  ));
  final fill = rawFill(doc, boundary); // allocated after, so higher
  expect(fill.value, greaterThan(boundary.value));
  final before = jsonEncode(JsonCodec.save(doc));
  expect(doc.validate().map((d) => d.code),
      contains(ValidationCodes.fillDrawOrderInverted));
  expect(jsonEncode(JsonCodec.save(doc)), before,
      reason: 'validate reports and never mutates; a loader that re-sorted to '
          'defend the draw-order rule would make the drawing differ from the '
          'file');
});
```

- [ ] **Step 2: Run and watch each fail**

Expected: FAIL — the codes are not defined.

- [ ] **Step 3: Implement**

Add a sixth numbered block to `DocumentValidation.validate()`:

```dart
    // 6. Fills. Every check reports; none repairs.
    for (final slot in entities.liveSlots) {
      if (entities.kindAt(slot) != EntityKind.fill) continue;
      final fill = entities.handleAt(slot);
      final boundary =
          boundaryHandleOf(geometry.peek(entities.geomIndexAt(slot)));
      final boundarySlot = entities.slotOf(boundary);
      if (boundarySlot == null) {
        out.add(error(ValidationCodes.fillBoundaryMissing,
            'fill ${fill.toHex()} names ${boundary.toHex()}, which is not in '
            'this document', [fill, boundary]));
        continue;
      }
      final kind = entities.kindAt(boundarySlot);
      if (kind != EntityKind.polyline && kind != EntityKind.circle) {
        out.add(error(ValidationCodes.fillBoundaryNotFillable,
            'fill ${fill.toHex()} names a ${kind.name}, which has no interior',
            [fill, boundary]));
      } else if (kind == EntityKind.polyline &&
          triangulationFor(kind, geometry.peek(entities.geomIndexAt(boundarySlot))) ==
              null) {
        out.add(error(ValidationCodes.fillBoundaryNotClosed,
            'fill ${fill.toHex()} names an open polyline; closedness is the '
            'stored first point repeated as the last, compared exactly',
            [fill, boundary]));
      }
      if (entities.ownerAt(slot) != entities.ownerAt(boundarySlot)) {
        out.add(error(ValidationCodes.fillBoundaryForeignOwner,
            'fill ${fill.toHex()} and its boundary are in different owners, so '
            'the reference cannot resolve under an instance', [fill, boundary]));
      }
      if (fill.value > boundary.value) {
        out.add(error(ValidationCodes.fillDrawOrderInverted,
            'fill ${fill.toHex()} has a higher handle than its boundary '
            '${boundary.toHex()}, so it draws over its own outline',
            [fill, boundary]));
      }
    }
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutation**

Delete each of the five `out.add(...)` blocks in turn. Each deletion must fail
**its own** test and no other — that is what one fixture per code buys.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/validate.dart \
        packages/jet_cad_2d/test/document/validate_test.dart
git commit -m "feat: validate() reports five fill conditions and repairs none"
```

---


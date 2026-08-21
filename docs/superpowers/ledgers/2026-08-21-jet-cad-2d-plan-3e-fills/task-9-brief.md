## Task 9: `entityBounds` and every one of its call sites

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart` (`_reconcileEntity`, and the rebuild path)
- Modify: `packages/jet_cad_2d/lib/src/index/container_index.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart` (`extents`)
- Modify: `packages/jet_cad_2d/test/document/extents_test.dart`

**Interfaces:**
- Produces:
```dart
Aabb2 entityBounds({
  required EntityKind kind,
  required GeometryPayload payload,
  required TextMeasurer measurer,
  required TextStyleRecord textStyle,
  int textAttrs = 0,
  String text = '',
  EntityKind? boundaryKind,          // fill only
  GeometryPayload? boundaryPayload,  // fill only
});
```

**`entityBounds` does not resolve the handle, and the file says why in writing.** Its doc comment, about the text style it takes as a record rather than a handle:

> giving this function a document dependency so it could look one up would be worse: every caller already holds the document and can resolve the record once.

A boundary handle is the same lookup and gets the same answer. The **caller** resolves. Both new parameters are null for every kind but `fill`; a fill with neither resolved bounds to `Aabb2.empty()` and is counted by the painter, never guessed at.

**Find every call site first.** `grep -rn "entityBounds(" packages/jet_cad_2d/lib packages/jet_cad_2d/test packages/jet_cad_2d_flutter`. **One task owns the function and all of them** — update the function, miss a call site, and the index carries a wrong box silently. Each call site must state **`peek` or `read`** for the boundary payload: the index's hot paths use `peek` (three fewer allocations per candidate); commands, which keep what they read, use `read`.

- [ ] **Step 1: Write the failing test**

```dart
test('a fill bounds to its boundary, not to nothing', () {
  final square = GeometryPayload(
      coords: Float64List.fromList([0, 0, 10, 0, 10, 10, 0, 10, 0, 0]),
      scalars: Float64List(0));
  final fill = GeometryPayload(
      coords: Float64List(0), scalars: Float64List.fromList([40.0]));
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: fill,
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
    boundaryKind: EntityKind.polyline,
    boundaryPayload: square,
  );
  expect(box.min.x, 0.0);
  expect(box.max.x, 10.0);
  expect(box.max.y, 10.0);
});

test('a fill with no boundary resolved bounds to empty, not to a guess', () {
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: GeometryPayload(
        coords: Float64List(0), scalars: Float64List.fromList([40.0])),
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
  );
  expect(box.isEmpty, isTrue);
});

test('a fill on a circle boundary bounds to the circle', () {
  final circle = GeometryPayload(
      coords: Float64List.fromList([5, 5]),
      scalars: Float64List.fromList([3]));
  final box = entityBounds(
    kind: EntityKind.fill,
    payload: GeometryPayload(
        coords: Float64List(0), scalars: Float64List.fromList([40.0])),
    measurer: const InsertionPointMeasurer(),
    textStyle: const TextStyleRecord(),
    boundaryKind: EntityKind.circle,
    boundaryPayload: circle,
  );
  expect(box.min.x, 2.0);
  expect(box.max.y, 8.0);
});
```

And the one that catches a missed call site — through the **index**, not the
function:

```dart
test('an edited boundary moves its fill\'s indexed box', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);           // square at 0,0..10,10
  doc.commands.execute(cmd);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);

  doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList(
              [100, 100, 110, 100, 110, 110, 100, 110, 100, 100]),
          scalars: Float64List(0))));

  final slot = doc.entities.slotOf(cmd.fill.handle)!;
  final box = index.boxOfLeaf(slot) ?? index.dirty.boxOf(slot);
  expect(box!.min.x, 100.0,
      reason: 'the fill is derived from the boundary; if the reconcile misses '
          'it, the fill is culled and picked against an outline that moved');
});
```

- [ ] **Step 2: Run and watch it fail**

Expected: FAIL — `boundaryKind` is not a named parameter, and the index test
reports the old box.

- [ ] **Step 3: Implement**

In `extents.dart`, extend the doc comment and the signature, and replace Task 1's
inert case:

```dart
/// [boundaryKind] and [boundaryPayload] are the resolved boundary of an
/// [EntityKind.fill], and null for every other kind. They are *resolved by the
/// caller*, for the same reason [textStyle] is: giving this function a document
/// dependency so it could look a handle up would be worse, and every caller
/// already holds the document.
      case EntityKind.fill:
        // A fill has no geometry of its own -- it occupies exactly its
        // boundary. Unresolved, it bounds to nothing rather than to a guess;
        // the painter counts that as a skip and `validate()` names the cause.
        if (boundaryKind == null || boundaryPayload == null) {
          return Aabb2.empty();
        }
        return entityBounds(
          kind: boundaryKind,
          payload: boundaryPayload,
          measurer: measurer,
          textStyle: textStyle,
        );
```

At every call site, resolve first. The index's hot path:

```dart
    // `peek`, not `read`: this runs per candidate and `read` copies three
    // objects. Nothing here keeps the payload past the call.
    EntityKind? boundaryKind;
    GeometryPayload? boundaryPayload;
    if (record.kind == EntityKind.fill) {
      final b = document.entities
          .slotOf(boundaryHandleOf(document.geometry.peek(record.geomIndex)));
      if (b != null) {
        boundaryKind = document.entities.kindAt(b);
        boundaryPayload = document.geometry.peek(document.entities.geomIndexAt(b));
      }
    }
```

- [ ] **Step 4: Run the whole engine suite**

Run: `cd packages/jet_cad_2d && dart test`

- [ ] **Step 5: Run the named mutations**

```sh
# T9a: return Aabb2.empty() for a fill even when the boundary resolves
# T9b: skip the fill resolution at ONE call site (do each in turn)
# T9c: use `read` in the index's hot path (survives correctness, caught by
#      test/invariants/query_allocation_test.dart -- run that too)
```

T9b is the point of the task: with the resolution removed at the index call
site only, the unit tests stay green and **the indexed-box test goes red**. If
both stay green, the fixture is not going through the index and the task is not
done.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/extents.dart \
        packages/jet_cad_2d/lib/src/index packages/jet_cad_2d/test
git commit -m "feat: a fill bounds to its boundary, resolved by the caller"
```

---


## Task 1: `EntityKind.fill` and the four exhaustive switches

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/store/entity_store.dart:9`
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Test: `packages/jet_cad_2d/test/store/entity_store_test.dart`

**Interfaces:**
- Produces: `EntityKind.fill`, appended last. `Handle boundaryHandleOf(GeometryPayload)` in `entity_store.dart`, returning `Handle.none` when `scalars` is empty.

**Why appended:** `EntityRecord` serialises `kind.name` and reads it with `EntityKind.values.byName`, so JSON never depends on ordinal — but `EntityStore` stores `_kind[slot] = r.kind.index` in a `Uint8List`, which does. Appending costs nothing and settles both.

Adding the member breaks compilation at four `switch` sites in `lib/` plus one in the oracle. That is the safety net working; this task closes all five with the *inert* answer, so a fill is storable and draws nothing yet.

- [ ] **Step 1: Write the failing test**

In `packages/jet_cad_2d/test/store/entity_store_test.dart`:

```dart
test('fill is the last EntityKind, and its ordinal is stable', () {
  // The store writes `kind.index` into a Uint8List column. Inserting a member
  // rather than appending would silently renumber every stored kind.
  expect(EntityKind.values.last, EntityKind.fill);
  expect(EntityKind.fill.index, 7);
});

test('boundaryHandleOf reads the boundary from scalars, and none when absent',
    () {
  final withBoundary = GeometryPayload(
      coords: Float64List(0), scalars: Float64List.fromList([4919.0]));
  expect(boundaryHandleOf(withBoundary), const Handle(4919));

  final empty =
      GeometryPayload(coords: Float64List(0), scalars: Float64List(0));
  expect(boundaryHandleOf(empty), Handle.none);
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/store/entity_store_test.dart`
Expected: FAIL — `EntityKind.fill` is not defined.

- [ ] **Step 3: Add the member and the reader**

In `entity_store.dart`, line 9:

```dart
/// `fill` is appended, never inserted: [EntityStore] stores `kind.index` in a
/// `Uint8List` column, so an insertion renumbers every stored document's kinds
/// in memory. The JSON is safe either way -- it carries `kind.name`.
enum EntityKind { point, line, polyline, circle, arc, text, attrib, fill }
```

and, below `EntityRecord`:

```dart
/// The boundary a fill entity names, or [Handle.none] if its payload carries
/// none.
///
/// A fill stores no coordinates. Its whole geometry is one scalar: the handle
/// of the entity whose loop it fills. A handle is an `int` at most
/// `kMaxHandle` (0xFFFFFFFF), far under 2^53, so the round trip through
/// `double` is exact in both directions.
Handle boundaryHandleOf(GeometryPayload payload) =>
    payload.scalars.isEmpty ? Handle.none : Handle(payload.scalars[0].toInt());
```

- [ ] **Step 4: Close the four `lib/` switches with the inert answer**

`extents.dart` — a fill's own payload has no points, and this task does not yet resolve boundaries:

```dart
      case EntityKind.fill:
        // Task 9 gives this case the boundary's box. Until then a fill bounds
        // to nothing, which is what its own payload says.
        return Aabb2.empty();
```

`spatial_index.dart` — every `switch (kind)` in `_considerLeaf` and
`_considerSnapLeaf` gets:

```dart
      case EntityKind.fill:
        // A fill is drawn, not picked. See Task 10 -- this is the final
        // answer, not a placeholder.
        break;
```

`reference_walk.dart` and `draft_painter.dart` — the same shape:

```dart
      case EntityKind.fill:
        // Task 13 draws it.
        break;
```

`reference_query.dart` — the two `switch (record.kind)` statements get a
`case EntityKind.fill: break;` each, with the comment `a fill produces no hit
and no snap candidate`.

- [ ] **Step 5: Run the whole suite on both packages**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```
Expected: all green, and the two new tests pass.

- [ ] **Step 6: Run the named mutation**

```sh
cd packages/jet_cad_2d
cp lib/src/store/entity_store.dart /tmp/t1.dart
trap 'cp /tmp/t1.dart lib/src/store/entity_store.dart' EXIT
# MUTANT T1a: insert rather than append
perl -0pi -e 's/enum EntityKind \{ point, line, polyline, circle, arc, text, attrib, fill \}/enum EntityKind { fill, point, line, polyline, circle, arc, text, attrib }/' lib/src/store/entity_store.dart
dart test test/store/entity_store_test.dart   # must FAIL
cp /tmp/t1.dart lib/src/store/entity_store.dart
```

- [ ] **Step 7: Commit**

```bash
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "feat: EntityKind.fill, stored and inert"
```

---


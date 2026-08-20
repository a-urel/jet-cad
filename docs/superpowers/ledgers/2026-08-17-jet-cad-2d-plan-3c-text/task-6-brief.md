## Task 6: Text picks as `HitKind.fill`

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart:765-778`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Test: `packages/jet_cad_2d/test/index/pick_test.dart`

**Interfaces:**
- Consumes: Task 3's `textLocalBounds`/`textLocalTransform`, Task 4's bounds.
- Produces: text and attrib leaves report `HitKind.fill` when the query point is inside the laid-out box; the insertion point remains a `SnapKind.insertion` candidate and is no longer a pick candidate.

- [ ] **Step 1: Write the failing tests**

```dart
test('a pointer inside a text box hits it as a fill', () {
  // A label 'LONG ROOM NAME' at (0,0), height 200, left/baseline.
  final hit = HitPath();
  // Well inside the box and far from the insertion point.
  expect(index.pickInto(Vector2(400, 60), 1.0, const QueryFilter.picking(), hit),
      isTrue);
  expect(hit.kind, HitKind.fill);
  expect(hit.entity, textHandle);
});

test('a pointer near the insertion point is no longer a vertex hit', () {
  final hit = HitPath();
  index.pickInto(Vector2(-5, -5), 10.0, const QueryFilter.picking(), hit);
  expect(hit.kind, isNot(HitKind.vertex));
});

test('a point entity still picks as a vertex', () {
  // The switch case used to be shared; splitting it must not move `point`.
  final hit = HitPath();
  expect(index.pickInto(pointPos, 5.0, const QueryFilter.picking(), hit), isTrue);
  expect(hit.kind, HitKind.vertex);
});

test('the insertion point is still a snap candidate', () {
  final out = SnapResult();
  index.snapInto(Vector2(2, 2), 20.0, SnapMask.only(SnapKind.insertion), out);
  expect(out.found, isTrue);
  expect(out.kind, SnapKind.insertion);
});
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/index/pick_test.dart`
Expected: FAIL — the fill case returns nothing and the vertex case still fires.

- [ ] **Step 3: Split the shared case and test the box**

Replace the shared `point`/`text`/`attrib` case with `point` alone (unchanged),
plus a text case that transforms the query point into text-local space and tests
the box:

```dart
      case EntityKind.text:
      case EntityKind.attrib:
        // The laid-out box is the hit geometry (HitKind.fill); the insertion
        // point stays a snap candidate, not a pick candidate. Picking and
        // snapping are different questions.
        final record = document.entities.read(slot);
        final style = document.tables.textStyles[record.textStyle] ??
            document.tables.textStyles[ReservedHandles.standardTextStyle]!;
        final attrs =
            resolveTextAttributes(payload, record.textAttrs, style);
        final metrics =
            document.textMeasurer.measure(text: record.text, style: style);
        final local = textLocalTransform(attrs, metrics, payload.pointAt(0));
        // toLocal already maps world -> owner space; compose the text's own
        // inverse on top of it, then test the axis-aligned glyph box.
        final inv = local.inverted();
        final lx = inv.a * ownerX + inv.c * ownerY + inv.e;
        final ly = inv.b * ownerX + inv.d * ownerY + inv.f;
        final box = textLocalBounds(attrs, metrics);
        if (lx >= box.minX && lx <= box.maxX &&
            ly >= box.minY && ly <= box.maxY) {
          foundKind = HitKind.fill;
          foundX = world.x;
          foundY = world.y;
        }
```

The implementer must read the surrounding `_considerLeaf` to get the actual
local-coordinate variable names and the zero-allocation conventions — the six
raw transform coefficients are already in scope as fields there, and
`Transform2.inverted()` allocates, so cache the inverse per candidate the same
way the file caches other per-candidate state, or invert by hand into six
locals.

- [ ] **Step 4: Teach the brute-force reference the same rule**

`reference_query.dart` computes hits independently. Add the same box test there,
written from the metrics rather than copied from the index, so the differential
compares two implementations rather than one.

- [ ] **Step 5: Run pick, snap, differential and the allocation harness**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including `test/invariants/differential_test.dart` and
`test/invariants/query_allocation_test.dart`. If the allocation test fails, the
inverse or the metrics are allocating per candidate — fix that, do not relax the
test.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): pick text by its laid-out box as HitKind.fill"
```

---


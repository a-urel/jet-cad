## Task 10: Criterion 10 — an edit after a settle invalidates

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart`

**Interfaces:**
- Consumes: the shared `_baked` record from Task 8.

**Why this is a correctness gate and not a nicety.** `_invalidateTouched`
condemns tiles by iterating `_baked` in both directions. A sliced tile with no
record is invisible to both: edit an entity after a settle and the stale tile
keeps blitting over the corrected drawing, with `invalidationCount` reading
zero. **M5** is exactly that mutation.

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('an edit after a sliced settle condemns the sliced tiles',
      (t) async {
    final h = await pumpTiled(t, document: bandCrossingGrid);
    await settle(t, h);
    final tilesBefore = h.cache.liveTileCount;
    expect(tilesBefore, greaterThan(0),
        reason: 'not vacuous: there must be tiles to condemn');
    final invalidationsBefore = h.cache.invalidationCount;

    h.moveOneEntityOntoDisjointTiles();
    await t.pump();

    expect(h.cache.invalidationCount, greaterThan(invalidationsBefore),
        reason: 'sliced tiles carry the band record, so the edit reaches them');
    await settle(t, h);
    expect(differingPixels(await captureTiled(t, h), await captureLive(t, h)), 0,
        reason: 'and the drawing is correct afterwards, which is the half a '
            'counter alone cannot show');
  });
```

- [ ] **Step 2: Run it and watch it fail**

Expected: FAIL — `invalidationCount` unchanged, and the pixels differ.

- [ ] **Step 3: The implementation is Task 8's `_baked[key] = record;`**

If Task 8 landed it, this test passes as written and Step 2's failure must be
produced by firing M5 first. **Fire M5 before claiming this task**: delete
`_baked[key] = record;`, watch this test go red, restore, record the verbatim
output under **M5**.

- [ ] **Step 4: Run the package and commit**

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && dart format --output=none --set-exit-if-changed .
git add -A packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3i-mutation-log.md
git commit -m "test(tiles): an edit after a sliced settle must condemn the slices"
```

---


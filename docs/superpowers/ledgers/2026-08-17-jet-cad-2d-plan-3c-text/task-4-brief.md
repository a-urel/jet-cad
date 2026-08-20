## Task 4: `entityBounds` and all four call sites

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/extents.dart`
- Modify: `packages/jet_cad_2d/lib/src/document/draft_document.dart:226`
- Modify: `packages/jet_cad_2d/lib/src/index/container_index.dart:93`
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart:2358`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:108`
- Modify: test call sites — `test/invariants/corpus.dart:632`, `test/invariants/reference_query.dart:210` and `:805`, `test/document/extents_test.dart`, `test/index/snap_centre_index_test.dart:120` and `:353`
- Test: `packages/jet_cad_2d/test/index/text_overlay_test.dart` (create)

**Interfaces:**
- Consumes: Task 3's `resolveTextAttributes`, `textLocalTransform`, `textLocalBounds`.
- Produces: `Aabb2 entityBounds({required EntityKind kind, required GeometryPayload payload, required TextMeasurer measurer, required TextStyleRecord textStyle, String text = ''})` — note the parameter type change from `Handle` to `TextStyleRecord`.

- [ ] **Step 1: Write the failing test — the one that pins the incremental path**

```dart
// test/index/text_overlay_test.dart
test('an edited text has the same box in the overlay as after a rebuild', () {
  final doc = DraftDocument.empty(measurer: const MetricModelMeasurer());
  final style = doc.tables.textStyles.byName('STANDARD')!;
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
      EntityRecord(/* ... a text record at (1000, 2000), height 200 ... */),
      GeometryPayload(
          coords: Float64List.fromList([1000, 2000]),
          scalars: Float64List.fromList([200, 0, 0, 0]))));

  final index = SpatialIndex(doc);
  doc.commands.execute(SetEntityTextCommand(handle, 'A MUCH LONGER LABEL', ''));

  final incremental = index.rootIndex.boxOfLeaf(doc.entities.slotOf(handle)!);
  index.rebuildAll();
  final rebuilt = index.rootIndex.boxOfLeaf(doc.entities.slotOf(handle)!);

  // The dirty-overlay path at spatial_index.dart:2358 must resolve text the
  // same way the full build does. Hard-coding `text: ''` there leaves an
  // edited text in a degenerate box while a rebuilt one is correct — on the
  // path an editing session spends all its time in.
  expect(incremental.minX, closeTo(rebuilt.minX, 1e-9));
  expect(incremental.maxX, closeTo(rebuilt.maxX, 1e-9));
  expect(incremental.minY, closeTo(rebuilt.minY, 1e-9));
  expect(incremental.maxY, closeTo(rebuilt.maxY, 1e-9));
  expect(rebuilt.maxX - rebuilt.minX, greaterThan(0.0));
});
```

This test needs `SetEntityTextCommand`, which is Task 5. Write the test now and mark it `skip: 'Task 5 adds the command'`, then unskip it in Task 5 — or reorder locally and do Task 5 first. **Do not delete the test to make the tree green.**

- [ ] **Step 2: Change `entityBounds`' text case**

```dart
    case EntityKind.text:
    case EntityKind.attrib:
      final attrs = resolveTextAttributes(payload, textAttrs, textStyle);
      final metrics = measurer.measure(text: text, style: textStyle);
      final local = textLocalBounds(attrs, metrics);
      return local
          .transformedBy(textLocalTransform(attrs, metrics, payload.pointAt(0)));
```

Add `required TextStyleRecord textStyle` and `int textAttrs = 0` to the signature, replacing the `Handle textStyle` parameter.

- [ ] **Step 3: Update all four production call sites**

Each already holds the document, so each looks up the record once:

```dart
      final record = doc.entities.read(slot);          // or the existing local
      final leafBox = entityBounds(
        kind: record.kind,
        payload: payload,
        measurer: doc.textMeasurer,
        textStyle: doc.tables.textStyles[record.textStyle] ??
            doc.tables.textStyles[ReservedHandles.standardTextStyle]!,
        textAttrs: record.textAttrs,
        text: record.text,
      );
```

`spatial_index.dart:2358` is the one that matters most: it is the incremental
re-derive. `reference_walk.dart:108` is the differential oracle's own bounds
call and must use the same expression.

- [ ] **Step 4: Update the test call sites**

Run `grep -rn "entityBounds(" packages/*/test` and fix each — six sites across five files. Where a test passed `ReservedHandles.standardTextStyle`, pass the record from the document's table instead.

- [ ] **Step 5: Run everything**

Run: `cd packages/jet_cad_2d && dart test && dart analyze`
Run: `cd packages/jet_cad_2d_flutter && flutter test && flutter analyze`
Expected: PASS. Existing text expectations that asserted a degenerate box move here — that is the point, and each change is deliberate.

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d): bound text by its laid-out box at every call site"
```

---


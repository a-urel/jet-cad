### Task 1: The record learns a fourth kind

**Files:**
- Modify: `lib/src/gpu/instance_record.dart`
- Test: `test/gpu/instance_record_test.dart`

**Interfaces:**
- Consumes: `kFloatsPerInstance`, `InstanceFieldOffset`, `_writeColor`,
  `_writeDash` — all already in this file.
- Produces:
  ```dart
  const double kKindFill = 3;

  void writeFill(
    Float32List into,
    int index, {
    required double x0,
    required double y0,
    required double x1,
    required double y1,
    required double x2,
    required double y2,
    required int argb,
  });
  ```

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/instance_record_test.dart`:

```dart
  test('a fill record carries three corners, no width and no dash', () {
    // Pre-filled with garbage so a writer that leaves a slot untouched is
    // caught. A fresh Float32List is all zeros, and most of this record's
    // expected values are zero, so a zero-initialised buffer would let a
    // missing write pass -- the degenerate-fixture trap, at the record
    // level.
    final data = Float32List(kFloatsPerInstance)..fillRange(0, kFloatsPerInstance, 17.5);
    writeFill(data, 0,
        x0: 3.5, y0: -4.25, x1: 11.0, y1: 2.5, x2: -6.75, y2: 9.5,
        argb: 0x8033CC66);

    expect(data[InstanceFieldOffset.kind], kKindFill);
    expect(data[InstanceFieldOffset.halfWidth], 0.0,
        reason: 'a fill has no width and the shader must not expand it');
    expect(data[InstanceFieldOffset.x0], 3.5);
    expect(data[InstanceFieldOffset.y0], -4.25);
    expect(data[InstanceFieldOffset.x1], 11.0);
    expect(data[InstanceFieldOffset.y1], 2.5);
    expect(data[InstanceFieldOffset.x2], -6.75);
    expect(data[InstanceFieldOffset.y2], 9.5);
    expect(data[InstanceFieldOffset.r], closeTo(0x33 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.g], closeTo(0xCC / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.b], closeTo(0x66 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.a], closeTo(0x80 / 255.0, 1e-6));
    expect(data[InstanceFieldOffset.dashPeriod], 0.0);
    expect(data[InstanceFieldOffset.dashPhase], 0.0);
    expect(data[InstanceFieldOffset.dashFracStart], 0.0);
    expect(data[InstanceFieldOffset.dashFracEnd], 0.0);
  });

  test('the four kind tags are distinct and ordered for a < dispatch', () {
    // The shader dispatches `kind < 0.5`, `< 1.5`, `< 2.5`, else. These
    // values are not merely distinct: renumbering them without editing
    // cad_stroke.vert draws one kind as another, silently.
    expect(<double>[kKindStroke, kKindJoin, kKindPoint, kKindFill],
        <double>[0, 1, 2, 3]);
  });

  test('a fill at index 2 writes only its own record', () {
    final data = Float32List(kFloatsPerInstance * 4)
      ..fillRange(0, kFloatsPerInstance * 4, 17.5);
    writeFill(data, 2,
        x0: 1, y0: 2, x1: 3, y1: 4, x2: 5, y2: 6, argb: 0xFF000000);
    expect(data[kFloatsPerInstance * 1], 17.5,
        reason: 'the record before it is untouched');
    expect(data[kFloatsPerInstance * 3], 17.5,
        reason: 'the record after it is untouched');
    expect(data[kFloatsPerInstance * 2 + InstanceFieldOffset.kind], kKindFill);
  });
```

- [ ] **Step 2: Run them and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Expected: compile failure — `kKindFill` and `writeFill` are undefined.

- [ ] **Step 3: Add the constant and the writer**

In `instance_record.dart`, after `kKindPoint`'s doc block:

```dart
/// One triangle of a fill. `(x0, y0)`, `(x1, y1)` and `(x2, y2)` are its
/// three corners in collection space, and [InstanceFieldOffset.halfWidth] is
/// zero — a fill has no width, so unlike every other kind nothing here is
/// expanded in device pixels. The shader reads the three corners through the
/// `join_weight` roles `V`, `A` and `B`, and folds `M` onto `A` so the second
/// triangle of the six-vertex quad is degenerate (Plan D's Ruling D1).
///
/// **A fill is never dashed and never fades.** `DraftPainter._drawFill` opens
/// no dash bracket, and the colour is `style.argb` rather than
/// `_coveredArgb`'s — routing a fill through the sub-pixel alpha fade would
/// fade a filled room on a hairline layer (`vertices_draw_sink.dart:752-757`).
const double kKindFill = 3;
```

Update `kKindStroke`'s doc, which today says *"The values are 0, 1, 2"* — it
becomes:

```dart
/// **The values are 0, 1, 2, 3 and the order is load-bearing**, not merely
/// distinct: `cad_stroke.vert` dispatches with `kind < 0.5`, then
/// `kind < 1.5`, then `kind < 2.5`, because ES 100 has no integer attributes
/// and no `switch` on one. Renumbering these without editing that shader
/// silently draws every join as a stroke, or every fill as a point.
```

And append the writer at the end of the file:

```dart
/// Writes the fill-triangle record at [index]. [argb] is `0xAARRGGBB`.
///
/// **Takes no half-width and no dash arguments, by design.** A fill has no
/// width to expand (Ruling D2) and cannot be dashed (Ruling D4): the painter
/// reaches `fillPolygon` and `fillCircle` outside any `beginDash` bracket. All
/// five slots are still written explicitly — see [_writeDash]'s own doc for
/// why an explicit zero is not the same as a fresh buffer's zero.
void writeFill(
  Float32List into,
  int index, {
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double x2,
  required double y2,
  required int argb,
}) {
  final o = index * kFloatsPerInstance;
  into[o + InstanceFieldOffset.kind] = kKindFill;
  into[o + InstanceFieldOffset.halfWidth] = 0;
  into[o + InstanceFieldOffset.x0] = x0;
  into[o + InstanceFieldOffset.y0] = y0;
  into[o + InstanceFieldOffset.x1] = x1;
  into[o + InstanceFieldOffset.y1] = y1;
  into[o + InstanceFieldOffset.x2] = x2;
  into[o + InstanceFieldOffset.y2] = y2;
  _writeColor(into, o, argb);
  _writeDash(into, o, 0, 0, 0, 0);
}
```

- [ ] **Step 4: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/instance_record_test.dart
```
Expected: PASS.

- [ ] **Step 5: Full gate and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/instance_record.dart test/gpu/instance_record_test.dart
git commit -m "feat(gpu): the instance record learns a fill kind"
```

---


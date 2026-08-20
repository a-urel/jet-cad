## Task 8: The sink learns one text op

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/support/differential.dart`
- Test: `packages/jet_cad_2d_flutter/test/draw_sink_test.dart`

**Interfaces:**
- Consumes: nothing from Phase A.
- Produces: `void DrawSink.text(String text, Handle style, ResolvedStyle resolved)`; `TextOp(text, style, resolved)`; `flatten` emits `DrawnItem('text:$text', style, [origin, +x, +y])`.

- [ ] **Step 1: Write the failing test**

```dart
test('a text op records its string, style handle and resolved style', () {
  final sink = RecordingDrawSink()
    ..beginResidual(Transform2.translation(10, 20))
    ..text('WC', const Handle(7), _resolved)
    ..endResidual();
  expect(sink.ops[1], TextOp('WC', const Handle(7), _resolved));
});

test('flatten turns a text op into an origin and two unit images', () {
  final items = flatten(<DrawOp>[
    BeginResidualOp(Transform2(2, 0, 0, 2, 100, 200)),
    TextOp('WC', const Handle(7), _resolved),
    const EndResidualOp(),
  ]);
  expect(items.single.kind, 'text:WC');
  expect(items.single.points[0], _v(100, 200));
  expect(items.single.points[1], _v(102, 200));
  expect(items.single.points[2], _v(100, 202));
});
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draw_sink_test.dart`
Expected: FAIL — `text` is not a member of `RecordingDrawSink`.

- [ ] **Step 3: Add the op**

`DrawSink.text(String text, Handle style, ResolvedStyle resolved)`, drawn at the
**local origin** — the painter pushes `residual ∘ textLocal`, so no offset and
no second matrix are needed. `TextOp` with value equality over all three fields;
`RecordingDrawSink` appends it; `NullDrawSink` counts it.

`CanvasDrawSink.text` resolves the paragraph through Task 9's cache and calls
`canvas.drawParagraph(paragraph, Offset.zero)` after the existing
`_pushTransform()`. Until Task 9 lands, implement it as
`throw UnimplementedError('Task 9 supplies the paragraph cache')` and leave the
painter not calling it — the two tasks commit separately and neither leaves the
suite red.

- [ ] **Step 4: Flatten it**

```dart
      case TextOp(:final text, :final style, :final resolved):
        // Three points, not one: the origin plus the images of the local unit
        // vectors, so `kScreenTolerance` covers scale, rotation and shear with
        // the machinery already here. The string rides in `kind`, which
        // compares exactly.
        out.add(DrawnItem('text:$text', resolved, [
          residual.transformPoint(Vector2.zero()),
          residual.transformPoint(Vector2(1, 0)),
          residual.transformPoint(Vector2(0, 1)),
        ]));
```

- [ ] **Step 5: Run and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`
Expected: PASS.

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add a text op to the draw sink and the oracle"
```

---


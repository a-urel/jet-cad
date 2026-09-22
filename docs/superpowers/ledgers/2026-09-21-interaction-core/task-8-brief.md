### Task 8: `SelectionOverlay`

**Files:**
- Create: `lib/src/selection_overlay.dart`
- Test: `test/selection_overlay_test.dart`

**Interfaces:**

```dart
class SelectionOverlay extends CustomPainter {
  SelectionOverlay({
    required SelectionController selection, required ToolController tools,
    required CameraController camera, required OutlineCache outlines,
    Listenable? repaint,            // the caller passes Listenable.merge([selection, tools, camera])
    void Function()? onPaintForTest,
  });
}
```

`paint(canvas, size)`:

```dart
    onPaintForTest?.call();
    final cam = camera.value;
    final origin = rebaseOriginFor(cam.visibleWorld(size));
    final m = cam.worldToScreenMatrix;
    // worldToScreen ∘ translate(origin): column-major 4x4.
    _matrix[0] = m.a; _matrix[1] = m.b; _matrix[4] = m.c; _matrix[5] = m.d;
    _matrix[12] = m.a * origin.x + m.c * origin.y + m.e;
    _matrix[13] = m.b * origin.x + m.d * origin.y + m.f;
    _selected.strokeWidth = kSelectionStrokePixels / cam.scale;
    _hover.strokeWidth = kHoverStrokePixels / cam.scale;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_matrix);
    for (final key in selection.keys) {
      final path = outlines.pathFor(key, origin);
      if (path != null) canvas.drawPath(path, _selected);
    }
    final hover = selection.hover;
    if (hover != null && !selection.contains(hover)) {
      final path = outlines.pathFor(hover, origin);
      if (path != null) canvas.drawPath(path, _hover);
    }
    canvas.restore();
    tools.active.paintOverlay(canvas, cam, size);
```

with fields `final Float64List _matrix = Float64List(16)..[10] = 1.0..[15] = 1.0;`
and the two `Paint`s (`style = stroke`, colours from the constants).
`shouldRepaint(old) => false`.

- [ ] **Step 1: Failing tests** — all on the same pumped tree, no rebuild
  between mutation and assertion:

```dart
await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Center(child: SizedBox(
  width: 400, height: 300,
  child: Stack(children: [
    RepaintBoundary(child: DraftCanvas(document: doc, index: index, camera: camera, onPaintForTest: () => canvasPaints++)),
    Positioned.fill(child: RepaintBoundary(child: CustomPaint(
      painter: SelectionOverlay(..., repaint: Listenable.merge([selection, tools, camera]), onPaintForTest: () => overlayPaints++),
      size: Size.infinite))),
  ])))));
```

1. **Criterion 6 / M-02e′** — `'a selection change repaints the overlay and not the canvas'`:
   record both counters; `selection.replace([k])`; `await tester.pump()`;
   overlay +1, canvas unchanged.
2. **M-02m** — `'stroke width is 2 px at any zoom'`: paint the overlay
   directly into a `SpyCanvas` at camera scale 4 → the `drawPath` call's
   `strokeWidth == 0.5`.
3. **M-02ab** — `'the two Paints are reused across frames'`: paint into a
   `SpyCanvas` twice; the `Paint` objects in `args` are `identical` across
   the two `drawPath` calls.
4. **M-02ac** — `'hover on a selected key draws once'`: select k, hover k,
   paint into a `SpyCanvas` → one `drawPath`; hover another key → two.
5. **Criterion 14** — `'the outline coincides with the drawn line at 4.5e6'`:
   the M-02v line; paint into a `SpyCanvas`; take the recorded `transform`
   matrix and the recorded path's bounds; map the bounds' corners through the
   matrix; compare with `camera.value.worldToScreen` of the line's endpoints
   → within 0.01 px.
6. `'the tool's band is painted after the outlines, in screen space'`:
   with `SelectTool` in `dragging` (drive it with two `ToolPointerEvent`s),
   the `SpyCanvas` shows `drawRect` after `restore`.

- [ ] **Step 2: Implement, run, gate line, commit**

```sh
git add lib/src/selection_overlay.dart test/selection_overlay_test.dart
git commit -m "feat(overlay): SelectionOverlay over the rebased cache"
```

---


## Task 5: level of detail in the painter, and the knob on the widget

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart:36-43`, `:145-160`, `:252-258`, `:793-822`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:56-66`, `:145-152`, `:161-172`
- Test: `packages/jet_cad_2d_flutter/test/text_lod_test.dart` (create)

**Interfaces:**
- Consumes: nothing from Tasks 2-4 beyond a compiling tree.
- Produces:
  - `const double kMinTextCapPixels = 3.0;` in `draft_painter.dart`
  - `DraftPainter({..., double minTextCapPixels = kMinTextCapPixels})`
  - `int get culledTextCount` on `DraftPainter`
  - `DraftCanvas({..., double minTextCapPixels = kMinTextCapPixels})`

**The ordering is the whole point.** `_drawText` today calls `measure()` at `:807` and `TextLayout.resolve` at `:812`. The LOD test needs `resolve`'s output and must run before `measure`, so the method is reordered. A test placed after `measure` culls the draw and saves no layout.

- [ ] **Step 1: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/text_lod_test.dart`:

```dart
// `dart:typed_data` for Float64List, and `hide Aabb2` because vector_math ships
// its own Aabb2 and `jet_cad_2d` exports the one this codebase means. Every
// text-bearing test in this directory has exactly these two lines — see
// `text_paint_test.dart` and `draft_canvas_test.dart`.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

import 'support/fixtures.dart';

const TextStyleRecord _style =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');

/// One text entity of [height] world units at the world origin, and nothing
/// else, so the camera fit is decided by [world] rather than by the glyph box.
DraftDocument _doc(double height, Aabb2 world, FlutterTextMeasurer m) {
  final doc = DraftDocument.empty(measurer: m);
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: 'STAIR',
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([world.min.x, world.min.y]),
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return doc;
}

void main() {
  test('text below the threshold is culled and never measured', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    // 1000 world units across a 400 px viewport is 0.4 px per unit, so a
    // height-2 glyph is 0.8 px of cap height — under the 3.0 default.
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 1);
    expect(painter.textOpCount, 0);
    // The load-bearing half: culling after `measure` would leave this at 1 and
    // save nothing. It is why the LOD test sits before the measure call.
    expect(m.layoutCount, 0);
  });

  test('the same text at the same camera draws once LOD is off', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        minTextCapPixels: 0.0);
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    // The control arm. Without it the first test passes on a corpus with no
    // text at all.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('readable text at the same threshold is not culled', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    // 40 world units at 0.4 px per unit is 16 px of cap height.
    final doc = _doc(40.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('the threshold is exclusive at exactly kMinTextCapPixels', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    // 0.4 px per unit, so height 7.5 is exactly 3.0 px of cap height.
    final doc = _doc(7.5, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final sink = RecordingDrawSink();

    painter.paint(sink, ViewportTransform.fit(world, const Size(400, 300)),
        const Size(400, 300));

    // `<`, not `<=`: a glyph exactly at the threshold is drawn.
    expect(painter.culledTextCount, 0);
    expect(painter.textOpCount, 1);
  });

  test('culledTextCount is a per-frame figure, not a running total', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final view = ViewportTransform.fit(world, const Size(400, 300));

    painter.paint(RecordingDrawSink(), view, const Size(400, 300));
    painter.paint(RecordingDrawSink(), view, const Size(400, 300));

    expect(painter.culledTextCount, 1);
  });

  test('the threshold does not reach doc.extents', () {
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final world = Aabb2(Vector2.zero(), Vector2(1000, 750));
    final doc = _doc(2.0, world, m);
    final wide = doc.extents;
    doc.invalidateDerived();
    final again = doc.extents;
    // A document box that changed with zoom would be absurd; the painter's
    // threshold is a draw decision and lives nowhere near entityBounds.
    expect(again.min.x, wide.min.x);
    expect(again.min.y, wide.min.y);
    expect(again.max.x, wide.max.x);
    expect(again.max.y, wide.max.y);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart
```

Expected: compile error — `culledTextCount` and `minTextCapPixels` are not defined.

- [ ] **Step 3: Add the constant, the parameter and the counter**

In `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`, beside `kAnisotropyThreshold`:

```dart
/// Text whose on-screen cap height is below this many **logical** pixels is not
/// drawn, and not laid out either.
///
/// Below three pixels of cap height a glyph cannot resolve two strokes, so
/// nothing readable is lost. Logical rather than device pixels is deliberate:
/// on a 2x display the same text is six device pixels tall, so this culls
/// *less* than a device-pixel rule would — the safe direction, the same one
/// [kScreenClipInflate] takes.
///
/// **Two alternatives were considered and are not taken.** *Greeking* — drawing
/// a bar the width of the text instead of the glyphs, so a zoomed-out plan
/// keeps its visual weight — is cheap to draw (two batched triangles in
/// `VerticesDrawSink`) but needs `advanceWidth`, so either the layout happens
/// anyway and the saving is lost, or a font-free width model
/// (`text.length * ratio`, the shape `MetricModelMeasurer` uses) becomes a new
/// approximation to defend. *Two tiers* — greek in a middle band, nothing
/// beyond it — is closest to real CAD and the most control, at two constants,
/// two counters, two golden ladders, and the same font-free width model.
/// Neither is ruled out later; both were priced and deferred.
const double kMinTextCapPixels = 3.0;
```

Add the constructor parameter and field:

```dart
  DraftPainter({
    required this.document,
    required this.index,
    required this.resolver,
    this.debugDisableRebasing = false,
    this.drawText = true,
    this.minTextCapPixels = kMinTextCapPixels,
  });
```

```dart
  /// Cap height in logical pixels below which a text leaf is culled.
  ///
  /// **`0.0` disables level of detail**, which is what the exit gate's control
  /// arm needs: LOD-on and LOD-off must be compared on the same corpus at the
  /// same camera, or the two rows are two different documents.
  ///
  /// `final` for the reason [drawText] is: the painter is built once and a rig
  /// that flipped this after the fact would be measuring a rebuilt painter,
  /// which is a different frame.
  final double minTextCapPixels;
```

Add the counter beside `_skippedText`:

```dart
  int _culledText = 0;

  /// Text and attrib entities culled in the last frame for being too small to
  /// read — see [kMinTextCapPixels].
  ///
  /// **Separate from [skippedTextCount] on purpose.** That one means *empty
  /// string*; this one means *below the threshold*. Blended, the exit gate
  /// cannot tell which mechanism fired, which is the mistake Ruling 54 records
  /// for the paragraph cache's hit rate.
  int get culledTextCount => _culledText;
```

and reset it in `paint()` beside `_skippedText = 0;`:

```dart
    _culledText = 0;
```

- [ ] **Step 4: Reorder `_drawText` and insert the cull**

Replace the body of `_drawText` between the empty-string guard and the `sink` call with:

```dart
    final styleHandle = document.entities.textStyleAt(slot);
    final record = document.textStyleOf(styleHandle);
    // Resolved before the metrics are asked for, and that ordering is the whole
    // mechanism. `resolve` needs no metrics — height, rotation, width factor,
    // oblique angle and justification all come from the payload, the attribute
    // bits and the style record — while `measure` is the expensive call. A cull
    // placed after `measure` would skip the draw and save no layout at all.
    final layout = _textLayout
      ..resolve(payload, document.entities.textAttrsAt(slot), record);
    // `layout.height` is the effective DXF text height, which *is* the cap
    // height, in world units; `chain` carries camera, ancestors, instance,
    // placement and rebase. The product is the on-screen cap height in pixels,
    // with no measurement involved.
    //
    // `scaleMagnitude` is the geometric mean of the axis scales, so text
    // squashed in y under an anisotropic placement reads taller than it renders
    // and survives longer than it should. Same approximation the painter
    // already makes for curve stroke widths past [kAnisotropyThreshold], and it
    // errs toward drawing.
    if (layout.height * chain.scaleMagnitude < minTextCapPixels) {
      _culledText++;
      return;
    }
    final metrics = document.textMeasurer.measure(text: text, style: record);
    // The anchor is rebased like every other coordinate that reaches `chain`,
    // which already carries `translate(localOrigin)`. An unrebased anchor is
    // exactly right at the origin and one rebase origin wrong everywhere else —
    // the failure a fixture at (0, 0) cannot see.
    layout.composeTransform(metrics, payload.coords[0] - localOrigin.x,
        payload.coords[1] - localOrigin.y);
```

- [ ] **Step 5: Run the LOD tests**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart
```

Expected: PASS, six tests.

- [ ] **Step 6: Add the widget knob and its prop-update test**

In `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`, add to the constructor and the fields:

```dart
    this.minTextCapPixels = kMinTextCapPixels,
```

```dart
  /// Forwarded to [DraftPainter.minTextCapPixels]. `0.0` disables level of
  /// detail, which is what the exit gate's control arm needs.
  final double minTextCapPixels;
```

Forward it in `_attach()`'s `DraftPainter(...)` construction, and **add it to `didUpdateWidget`'s comparison list**:

```dart
        widget.minTextCapPixels != oldWidget.minTextCapPixels ||
```

Without that line a rebuild that changes the threshold keeps the old painter, so the LOD-off control arm silently measures the LOD-on build and looks like it worked.

Add to `draft_canvas_test.dart`:

```dart
  testWidgets('changing minTextCapPixels rebuilds the painter', (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);
    final key = GlobalKey<DraftCanvasState>();

    Widget at(double threshold) => Directionality(
        textDirection: TextDirection.ltr,
        child: DraftCanvas(
            key: key,
            document: doc,
            index: index,
            camera: camera,
            minTextCapPixels: threshold));

    await tester.pumpWidget(at(kMinTextCapPixels));
    expect(key.currentState!.painter.minTextCapPixels, kMinTextCapPixels);

    await tester.pumpWidget(at(0.0));
    // The painter's field is final, so a stale painter here means the control
    // arm measures the wrong build and reads as a working gate.
    expect(key.currentState!.painter.minTextCapPixels, 0.0);
  });
```

- [ ] **Step 7: Run the widget suite**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && flutter analyze
```

Expected: PASS. If any existing test now reads a lower `textOpCount`, that is Task 6's margin sweep finding work early — record it and leave it.

- [ ] **Step 8: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
        packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart \
        packages/jet_cad_2d_flutter/test/text_lod_test.dart \
        packages/jet_cad_2d_flutter/test/draft_canvas_test.dart
git commit -m "feat: cull text too small to read, before it is measured"
```

---


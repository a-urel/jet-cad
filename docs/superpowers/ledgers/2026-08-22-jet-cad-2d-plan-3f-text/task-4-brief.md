## Task 4: the document owns the measurer

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart:120-123`, `:135-140`, `:175-184`
- Modify: `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart:112`, `:180`, `:282`
- Modify: `packages/jet_cad_2d_flutter/test/render_backend_test.dart:9`, `:69`
- Modify: `packages/jet_cad_2d_flutter/test/frame_path_seam_test.dart:39`
- Modify: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart:22`
- Modify: `packages/jet_cad_2d_flutter/test/golden/fill_ladder_golden_test.dart:46`
- Modify: `apps/dev_harness_2d/lib/main.dart:140-160`, `:406-425`

**Interfaces:**
- Consumes: `FlutterTextMeasurer` from Task 2.
- Produces: `DraftCanvas` now throws `ArgumentError` at `_attach()` when `document.textMeasurer is! FlutterTextMeasurer`. `apps/dev_harness_2d/lib/main.dart` gains a library-level `final FlutterTextMeasurer harnessMeasurer`.

**The refusal is unconditional — it does not consult `drawText`.** `drawText: false` is a measurement flag, not a licence to carry a measurer that computes the wrong extents. A conditional guard would also force `CanvasDrawSink` to hold a throwaway measurer for its typed field, which is the second cache coming back.

- [ ] **Step 1: Write the failing tests**

Add to `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`:

```dart
  testWidgets('refuses a document whose measurer cannot lay out paragraphs',
      (tester) async {
    final doc = DraftDocument.empty();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: DraftCanvas(document: doc, index: index, camera: camera),
    ));

    // The whole point is that this used to draw nothing and say nothing.
    final error = tester.takeException();
    expect(error, isA<ArgumentError>());
    expect(error.toString(), contains('FlutterTextMeasurer'));
    expect(error.toString(), contains('DraftDocument.empty(measurer:'));
  });

  testWidgets('disposing one canvas leaves a sibling cache warm',
      (tester) async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(ViewportTransform.fit(
        Aabb2(Vector2.zero(), Vector2(100, 100)), const Size(400, 300)));
    addTearDown(camera.dispose);

    Widget canvases(int count) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                    width: 200,
                    height: 150,
                    child: DraftCanvas(
                        document: doc, index: index, camera: camera)),
            ],
          ),
        );

    await tester.pumpWidget(canvases(2));
    measurer.paragraphFor('WC', const Handle(7), _roboto, 0xFFFFFFFF);
    final live = measurer.liveParagraphCount;
    expect(live, 1);

    await tester.pumpWidget(canvases(1));
    await tester.pump();

    // A canvas that cleared on dispose would take its sibling's cache with it.
    expect(measurer.liveParagraphCount, live);
  });
```

with, near the top of the file:

```dart
const TextStyleRecord _roboto =
    TextStyleRecord(handle: Handle(7), name: 'Standard', fontFamily: 'Roboto');
```

- [ ] **Step 2: Run them to verify they fail**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_canvas_test.dart
```

Expected: the refusal test fails because `takeException()` returns `null` — nothing throws today. The split-view test fails because `dispose()` calls `clear()` and `liveParagraphCount` reads 0.

- [ ] **Step 3: Make the widget borrow, refuse, and stop disposing**

In `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`, delete the `_measurer` field at `:120-123` and replace it with nothing. In `_attach()`, immediately before the `sink = CanvasDrawSink(...)` line, insert:

```dart
    // The document owns the measurer; this widget borrows it. Refused
    // unconditionally rather than only when `drawText` is on: a document whose
    // boxes were computed from `TextMetrics.zero` is wrong whether or not
    // glyphs are drawn, and a conditional guard would force `CanvasDrawSink` to
    // hold a throwaway measurer for its typed field — the second cache coming
    // back. Before Plan 3f this widget built its own, handed it to the sink
    // only, and left the painter reading `document.textMeasurer`; a document
    // assembled the ordinary way therefore drew no text and reported nothing.
    final measurer = widget.document.textMeasurer;
    if (measurer is! FlutterTextMeasurer) {
      throw ArgumentError.value(
          measurer,
          'document.textMeasurer',
          'DraftCanvas requires a FlutterTextMeasurer. Build the measurer '
              'first and pass it to the document:\n\n'
              '    final measurer = FlutterTextMeasurer();\n'
              '    final doc = DraftDocument.empty(measurer: measurer);\n');
    }
```

and change the sink construction's `measurer:` argument to `measurer`.

In `dispose()`, replace the `_measurer.clear();` call and its comment with:

```dart
    // The measurer is **not** disposed here. The document owns it, two canvases
    // over one document share it, and clearing on dispose would wipe the
    // sibling's cache along with every native `Paragraph` in it. The
    // application that constructed the measurer calls `clear()` when it retires
    // the document — the ordinary Dart contract for a native-resource holder.
```

- [ ] **Step 4: Fix the nine documents**

Give each of these a real measurer with teardown:

`test/draft_canvas_test.dart:112` and `:180` —

```dart
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
```

`test/draft_canvas_test.dart:282` — swap the model measurer and disable LOD, because that test asserts `textOpCount == 1` and Task 5 makes the default cull:

```dart
    final textMeasurer = FlutterTextMeasurer();
    addTearDown(textMeasurer.clear);
    final textDoc = DraftDocument.empty(measurer: textMeasurer);
```

`test/render_backend_test.dart:9` and `:69` —

```dart
  final measurer = FlutterTextMeasurer();
  addTearDown(measurer.clear);
  final doc = generateDocument(40, dashedFraction: 0.5, measurer: measurer);
```

`test/frame_path_seam_test.dart:39`, `test/golden/dash_ladder_golden_test.dart:22` and `test/golden/fill_ladder_golden_test.dart:46` — the same `DraftDocument.empty(measurer: FlutterTextMeasurer())` shape, with `addTearDown` where the surrounding code is inside a test body and a top-level construction otherwise.

- [ ] **Step 5: Fix the harness, including its disposal**

In `apps/dev_harness_2d/lib/main.dart`, add a library-level field beside the other configuration constants:

```dart
/// The one measurer the harness document is built with, reachable from
/// `_HarnessState.dispose` so the native paragraphs it holds are released.
///
/// A field rather than an inline argument because `DraftCanvas` no longer
/// disposes the cache: the document owns it and the application releases it.
final FlutterTextMeasurer harnessMeasurer = FlutterTextMeasurer();
```

Replace the ternary at `:154-156` with:

```dart
    // Always a real measurer. The old `kTextCorpus ? FlutterTextMeasurer() :
    // const InsertionPointMeasurer()` was a workaround for this file's own
    // doc comment above — a zero-metric measurer makes every text transform
    // singular — applied at one call site while the cause stayed. `DraftCanvas`
    // now refuses a document without one, and what turns text off is
    // `labelFraction: 0` and `attributedInstanceFraction: 0`, which is the
    // correct axis.
    measurer: harnessMeasurer,
```

In `_HarnessState.dispose()`:

```dart
  @override
  void dispose() {
    index.dispose();
    camera.dispose();
    // `DraftCanvas` stops disposing the cache under Plan 3f, because two
    // canvases over one document share it. The application owns it instead.
    harnessMeasurer.clear();
    super.dispose();
  }
```

- [ ] **Step 6: Run everything**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze
cd ../../apps/dev_harness_2d && flutter analyze
```

Expected: all pass, **no golden PNG regenerated** — check with `git status`, which must show no `.png` under `test/golden`.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart \
        packages/jet_cad_2d_flutter/test apps/dev_harness_2d/lib/main.dart
git commit -m "feat: the document owns the text measurer and DraftCanvas borrows it"
```

---


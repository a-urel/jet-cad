## Task 8: `DraftCanvas` integration, and the table signal that reaches the frame

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
- Test: `packages/jet_cad_2d_flutter/test/tile_invalidation_test.dart` (criterion 7), `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`

**Interfaces:**
- Consumes: `TileCache`, `DocumentTables.changes`, `DocumentTables.mutationRevision`.
- Produces: `DraftCanvas({..., bool tiles = false, int tileDevicePixels = kTileDevicePixels})`.

- [ ] **Step 1: Write criterion 7 as a failing widget test**

Append to `test/tile_invalidation_test.dart`:

```dart
  testWidgets('criterion 7: a layer edit repaints and drops the generation',
      (tester) async {
    // **Two claims, and the second is the one an integer counter alone would
    // fail.** `TableSection.add` and friends emit no `DocChange`, and
    // `DraftCanvas` repaints only for `Listenable.merge([camera, _changes])`
    // where `_changes` is command-backed. A revision read inside `paint` would
    // invalidate correctly and never be reached, leaving stale pixels until an
    // unrelated camera move.
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    addLine(doc, doc.rootHandle, const Handle(1001), 20, 20, 260, 180);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(tileCamera());
    addTearDown(camera.dispose);

    var paints = 0;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(devicePixelRatio: kTileDpr),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: kTileViewport.width,
          height: kTileViewport.height,
          child: DraftCanvas(
            document: doc,
            index: index,
            camera: camera,
            tiles: true,
            tileDevicePixels: 64,
            onPaintForTest: () => paints++,
          ),
        ),
      ),
    ));
    await tester.pump();
    final paintsBefore = paints;

    doc.tables.layers.add(LayerRecord(
      handle: const Handle(900),
      name: 'WALLS',
      color: const DraftColor.indexed(3),
      linetype: ReservedHandles.continuousLinetype,
      lineweight: 50,
      transparency: 40,
    ));
    await tester.pump();

    expect(paints, greaterThan(paintsBefore),
        reason: 'a layer edit must cause a frame at all -- the half a counter '
            'inside paint could never reach');
  });
```

If `DraftCanvas` has no `onPaintForTest` hook, add one as a nullable `void Function()?` called at the top of `_DraftCustomPainter.paint`, documented as test-only. Counting frames is the only way to separate "invalidated correctly" from "was asked to".

- [ ] **Step 2: Wire it**

In `DraftCanvas`, add `tiles`, `tileDevicePixels` and `onPaintForTest`. In `_attach`:

```dart
    _tables = _TableListenableAdapter(widget.document.tables.changes);
    _tileCache = widget.tiles
        ? TileCache(tileDevicePixels: widget.tileDevicePixels)
        : null;
    _changes = DocChangeNotifier(widget.document,
        onChange: (change) => _tileCache?.applyChange(change, widget.document));
    // **The table adapter is here and not a nicety.** Without it a layer edit
    // causes no frame at all, so the cache's own invalidation -- correct as it
    // is -- is never reached and stale pixels sit there until the camera moves.
    _repaint = Listenable.merge([widget.camera, _changes, _tables]);
```

`_TableListenableAdapter` is a `ChangeNotifier` that subscribes to the engine's `TableListenable` and re-fires. It exists because `package:jet_cad_2d` has no Flutter dependency and declares its own two-method interface; this is where the two meet. Dispose it in `dispose()` and in `didUpdateWidget`'s teardown, beside `_changes`.

The cache also reads `document.tables.mutationRevision` once per frame and drops the generation when it moved, so a document mutated outside a `DraftCanvas` frame still invalidates. Add to `TileCache.paintFrame` a `required int tablesRevision` parameter; a change drops everything.

In `_DraftCustomPainter.paint`, the tiled branch:

```dart
  @override
  void paint(Canvas canvas, Size size) {
    onPaintForTest?.call();
    canvas.clipRect(Offset.zero & size);
    final cache = tileCache;
    if (cache != null) {
      cache.paintFrame(
        canvas: canvas,
        viewport: size,
        devicePixelRatio: devicePixelRatio,
        camera: camera.value,
        painter: painter,
        sink: sink,
        vertices: vertices,
        tablesRevision: document.tables.mutationRevision,
      );
      return;
    }
    // **The live path quantises too.** This is the rule, not a concession:
    // both paths use the same camera so the tiled frame is the live frame,
    // and a live path on the raw camera would make criterion 1 unmeetable.
    final quantised = quantiseCamera(camera.value, devicePixelRatio);
    sink.canvas = canvas;
    ...
  }
```

`didUpdateWidget` must also re-attach when `tiles` or `tileDevicePixels` changes, and `dispose` must call `_tileCache?.dispose()` — a `ui.Image` holds native memory past its Dart object.

- [ ] **Step 3: Run, then fire M8**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_invalidation_test.dart test/draft_canvas_test.dart
cp lib/src/draft_canvas.dart /tmp/draft_canvas.dart.bak
```

**M8** — drop `_tables` from the merge, keeping the revision read inside `paintFrame`. Criterion 7 must go red on the frame count while the cache's own logic stays correct. That asymmetry is the finding; record it.

- [ ] **Step 4: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart packages/jet_cad_2d_flutter/test
git commit -m "feat: the tiles flag, and a table edit that actually causes a frame

DraftCanvas repainted only for the camera and the command-backed change
notifier. Table mutations reach neither, so a revision counter read inside
paint would have been correct and never reached -- stale pixels until an
unrelated camera move. The engine's table Listenable is adapted here, which is
where a pure-Dart two-method interface meets Flutter's.

The live path quantises its camera too. That is the rule and not a concession:
both paths draw the same camera, so the tiled frame is the live frame."
```

---


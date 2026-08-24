## Task 6: Criteria 3 and 4 — text and translucency survive the texture round trip

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/support/tile_fixture.dart`, `packages/jet_cad_2d_flutter/test/tile_cache_test.dart`

**Interfaces:** consumes Task 5's `expectTiledEqualsLive`.

- [ ] **Step 1: Add two fixtures**

Append to `tile_fixture.dart`:

```dart
/// Labels large enough to clear `kMinTextCapPixels` and long enough to cross
/// tile boundaries.
///
/// Text is the one content type that does not reach the vertices sink: it
/// falls back to `CanvasDrawSink`, which flushes the batch first. A tile bake
/// therefore exercises a mid-picture flush, and criterion 3 is the only place
/// this plan sees it.
DraftDocument crossingLabels(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var row = 0; row < 6; row++) {
    // 14 world units of cap height at scale 1.4 is 19.6 logical pixels, well
    // clear of the 3.0 default, and `culledTextCount` is asserted rather than
    // assumed below.
    addText(doc, doc.rootHandle, Handle(handle++), 'SECTION-A$row', 20,
        30 + row * 40.0, 14);
  }
  return doc;
}

/// Overlapping translucent strokes, all inside one tile and also across one.
///
/// Transparency rides on the vertex colour, and a tile is baked to a
/// transparent-backed `Image` and composited with `srcOver`. Both halves have
/// to survive, and a blend-mode mistake shows up as a uniform shift rather
/// than as a missing shape -- which is why the criterion compares bytes and
/// not ink counts.
DraftDocument translucentOverlap(FlutterTextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);
  var handle = 1000;
  for (var i = 0; i < 10; i++) {
    final line = addLine(doc, doc.rootHandle, Handle(handle++), 20,
        30 + i * 6.0, 220, 150 - i * 6.0);
    // 60% transparent, so an overlap is visibly darker than a single stroke
    // and a lost alpha is a byte difference on thousands of pixels.
    setTransparency(doc, line, 60);
  }
  return doc;
}
```

`addText` and `setTransparency` come from `fixtures.dart`. If `setTransparency` does not exist there, write it in `fixtures.dart` as a `SetComponentCommand`-based helper and say so in the report — the transparency value must not be 0, which is the identity and would make criterion 4 degenerate.

- [ ] **Step 2: Write the two criteria**

Append to `test/tile_cache_test.dart`:

```dart
  test('criterion 3: text survives the tile round trip', () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: crossingLabels(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    // The fixture proves it drew text before any pixel is compared: a
    // level-of-detail cull would produce a smaller, self-consistent, wrong
    // picture that agreed with itself perfectly.
    expect(rig.painter.textOpCount, 6);
    expect(rig.painter.culledTextCount, 0);
    await expectTiledEqualsLive(rig);
  });

  test('criterion 4: overlapping translucent strokes composite identically',
      () async {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final rig = TileRig(
        tileDevicePixels: 64,
        tilesBakedPerFrame: 1000,
        document: translucentOverlap(measurer));
    addTearDown(rig.dispose);

    rig.paintOnce();
    await expectTiledEqualsLive(rig);
  });
```

- [ ] **Step 3: Run, then fire M14 and M11**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/tile_cache_test.dart
cp lib/src/tile_cache.dart /tmp/tile_cache.dart.bak
```

**M14** — skip text in a bake. In `_bake`, construct the draw with text off. The simplest faithful mutation is to set `painter`'s text off for the bake only; if `drawText` is `final`, mutate `_drawText`'s entry guard in `draft_painter.dart` instead and copy *that* file aside. Criterion 3 must go red with a large `uncoveredPixels` count.

**M11** — blit with `BlendMode.src`. Add `..blendMode = BlendMode.src` to `_blitPaint`. Criterion 4 must go red. Criterion 1 probably goes red too; note both, and note that M11 is *named* for criterion 4 because alpha is what it targets.

Restore from the copy after each.

- [ ] **Step 4: Green and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/test
git commit -m "test: criteria 3 and 4 -- text and alpha survive the texture

Text is the one content type that does not reach the vertices sink: it falls
back to CanvasDrawSink and flushes the batch first, so a tile bake exercises a
mid-picture flush that nothing else in this plan sees. The fixture asserts
textOpCount and culledTextCount before any pixel is compared, because a
level-of-detail cull produces a smaller picture that agrees with itself
perfectly.

Transparency is 60, not 0. Zero is the identity and would make the criterion
degenerate in exactly the way this repository's rule names."
```

---


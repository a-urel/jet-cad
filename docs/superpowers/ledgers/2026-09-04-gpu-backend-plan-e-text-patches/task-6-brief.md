### Task 6: The resident geometry carries patches, and the backend paints them

**Files:**
- Modify: `lib/src/gpu/resident_geometry.dart`
- Modify: `lib/src/gpu/gpu_draw_backend.dart`
- Test: `test/gpu/resident_geometry_test.dart`, `test/gpu/frame_info_test.dart`

**Interfaces:**
- Consumes: `TextPatch`, `ResidentTextRecord`, `patchTargetSizeFor`,
  `patchRegionFor`, `TextCompositor`, `PatchImage`, `labelBoundsLogical`,
  `buildFrameInfo`, `composeTransforms`, `dashScaleFor`.
- Produces:
  ```dart
  class ResidentPatch {           // @internal getters, as ResidentGeometry's own
    final int textIndex; final int instanceCount;
    final gpu.DeviceBuffer instances; final gpu.Texture target;
    final int targetWidth, targetHeight;
  }
  ResidentGeometry.create(Float32List instances, int instanceCount, {
      List<ResidentTextRecord> texts = const [], List<TextPatch> patches = const [],
      double devicePixelRatio = 1.0, int maxPatchWidth = 4096, int maxPatchHeight = 4096});
  List<ResidentTextRecord> get texts; List<ResidentPatch> get patches;
  int get byteLength;          // main buffer + every sub-buffer
  int get patchTargetBytes;    // sum of targetWidth * targetHeight * 4
  static int byteLengthFor(int instances, {int patchInstances = 0});
  GpuDrawBackend(ResidentGeometry geometry, ViewportTransform collectionCamera,
      {FlutterTextMeasurer? measurer, TextStyleRecord Function(Handle)? textStyleOf});
  ui.Image? render(ViewportTransform camera, Size viewport, double dpr);   // unchanged signature; now also renders patches
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr);
  int get patchesRendered; int get patchesClipped; int get patchesOffscreen;  // last frame
  ```

- [ ] **Step 1: The GPU-free tests**

Append to `test/gpu/resident_geometry_test.dart`:

```dart
  test('the byte length prices every sub-buffer beside the main buffer', () {
    // 1000 main instances + 37 patch instances, 64 bytes each.
    expect(ResidentGeometry.byteLengthFor(1000, patchInstances: 37),
        (1000 + 37) * 64);
  });

  test('create still returns null with no GPU, patches or not', () async {
    debugSetGpuFactory(() => throw StateError('no gpu'));
    final g = await ResidentGeometry.create(
        Float32List(kFloatsPerInstance), 1,
        texts: const [],
        patches: [
          TextPatch(
              textIndex: 0,
              instances: Float32List(kFloatsPerInstance),
              instanceCount: 1)
        ]);
    expect(g, isNull);
  });
```

Append to `test/gpu/frame_info_test.dart`:

```dart
  test('a patch FrameInfo maps the region origin to the NDC corner', () {
    // Region at device (120, 240), 80x40; collectionToDevice scale 2 +
    // (100, 200). Composed with translation(-120, -240) OUTSIDE, the
    // collection point that lands at device (120, 240) must land at NDC
    // (-1, +1): the top-left of an 80x40 target.
    const cam = Transform2(2, 0, 0, 2, 100, 200);
    final toPatch = composeTransforms(Transform2.translation(-120, -240), cam);
    final data = buildFrameInfo(toPatch, 80, 40, dashScale: 1.0);
    double at(int i) => data.getFloat32(i * 4, Endian.host);
    // collection (10, 20) -> device (120, 240) -> patch (0, 0) -> NDC (-1, 1)
    final x = at(0) * 10 + at(4) * 20 + at(12);
    final y = at(1) * 10 + at(5) * 20 + at(13);
    expect(x, closeTo(-1, 1e-6));
    expect(y, closeTo(1, 1e-6));
    expect(at(16), 40, reason: 'half_viewport is the REGION\'s, so the '
        'half-width expansion stays in device pixels');
    expect(at(17), 20);
  });
```

- [ ] **Step 2: `ResidentGeometry`**

Add the class and fields:

```dart
/// One covered label's GPU-side patch: its sub-buffer and its target.
///
/// Both allocated at upload and reused every frame -- the target at the
/// label's size at the band's ceiling (`patchTargetSizeFor`), so a zoom
/// inside the band never reallocates it.
class ResidentPatch {
  ResidentPatch._(this.textIndex, this.instanceCount, this._instances,
      this._target, this.targetWidth, this.targetHeight);

  final int textIndex;
  final int instanceCount;
  final gpu.DeviceBuffer _instances;
  final gpu.Texture _target;
  final int targetWidth;
  final int targetHeight;

  @internal
  gpu.DeviceBuffer get instances => _instances;
  @internal
  gpu.Texture get target => _target;
}
```

Extend `create` / `_upload` (the same try/catch, the same `null` on no GPU):

```dart
  static Future<ResidentGeometry?> create(
    Float32List instances,
    int instanceCount, {
    List<ResidentTextRecord> texts = const <ResidentTextRecord>[],
    List<TextPatch> patches = const <TextPatch>[],
    double devicePixelRatio = 1.0,
    int maxPatchWidth = 4096,
    int maxPatchHeight = 4096,
  }) async { ... }
```

In `_upload`, after the main buffers:

```dart
    final residentPatches = <ResidentPatch>[];
    for (final p in patches) {
      final (tw, th) = patchTargetSizeFor(texts[p.textIndex], devicePixelRatio,
          maxWidth: maxPatchWidth, maxHeight: maxPatchHeight);
      residentPatches.add(ResidentPatch._(
        p.textIndex,
        p.instanceCount,
        context.createDeviceBufferWithCopy(ByteData.sublistView(
            p.instances, 0, p.instanceCount * kFloatsPerInstance)),
        // A patch target must be shader-readable: the compositor draws it
        // through `asImage()`, which the web shim refuses on a texture
        // without `enableShaderReadUsage` (`web/texture.dart:358`). It is the
        // default on both backends; passed explicitly so it cannot drift.
        context.createTexture(gpu.StorageMode.devicePrivate, tw, th,
            enableShaderReadUsage: true),
        tw,
        th,
      ));
    }
```

`texts`, `patches` become fields; `byteLength` becomes
`byteLengthFor(instanceCount, patchInstances: sum of patch instanceCounts)`;
`patchTargetBytes` sums `targetWidth * targetHeight * 4`. Keep `byteLengthFor`'s
existing single-argument calls working with the named default.

**Why `maxPatchWidth/Height` default to 4096 and not the viewport:** `create`
does not know the viewport. The harness passes the viewport in device pixels
(Task 7); the default is a ceiling that keeps a mis-wired caller from asking
for a texture the driver refuses. Say so in the doc.

- [ ] **Step 3: `GpuDrawBackend`**

Constructor gains `measurer` and `textStyleOf` (optional; without them `paint`
draws the main image and no text, and says so in its doc — Ruling E2's shape
again). Fields:

```dart
  final TextCompositor? _compositor;   // null without a measurer
  final List<PatchImage> _patchImages = <PatchImage>[];
  int patchesRendered = 0, patchesClipped = 0, patchesOffscreen = 0;
```

In `render`, after the main pass's `pass.draw(...)` and **before**
`commandBuffer.submit()`, one more render pass per patch on the **same command
buffer**:

```dart
    _patchImages.clear();
    patchesRendered = 0;
    patchesClipped = 0;
    patchesOffscreen = 0;
    final dashScale = dashScaleFor(camera, _collectionInverse);
    for (final patch in geometry.patches) {
      final t = geometry.texts[patch.textIndex];
      final region = patchRegionFor(t, collectionToDevice, widthPx, heightPx,
          maxWidth: patch.targetWidth, maxHeight: patch.targetHeight);
      if (region == null) {
        patchesOffscreen++;
        continue;
      }
      // The region reached the target's size: either the live scale is past
      // the band's ceiling and Plan F's rebuild has not landed, or it sits
      // exactly at the ceiling. Drawn anyway, short if clamped; counted so
      // the harness can say how often. A diagnostic, not a decision.
      if (region.width == patch.targetWidth ||
          region.height == patch.targetHeight) {
        patchesClipped++;
      }
      final patchPass = commandBuffer.createRenderPass(gpu.RenderTarget.singleColor(
        gpu.ColorAttachment(
            texture: patch.target, clearValue: vm.Vector4(0, 0, 0, 0)),
      ));
      patchPass.bindPipeline(geometry.pipeline);
      patchPass.setPrimitiveType(gpu.PrimitiveType.triangle);
      patchPass.setCullMode(gpu.CullMode.none);
      patchPass.setColorBlendEnable(true);
      // Ruling E8: anchored at the target's origin. `Viewport`/`Scissor`
      // throw on a negative origin, and the region's on-screen position is
      // the compositor's business.
      patchPass.setViewport(gpu.Viewport(
          x: 0, y: 0, width: region.width, height: region.height));
      patchPass.setScissor(gpu.Scissor(
          x: 0, y: 0, width: region.width, height: region.height));
      patchPass.bindVertexBuffer(
          gpu.BufferView(geometry.corners,
              offsetInBytes: 0, lengthInBytes: geometry.corners.sizeInBytes),
          slot: 0);
      patchPass.bindVertexBuffer(
          gpu.BufferView(patch.instances,
              offsetInBytes: 0, lengthInBytes: patch.instances.sizeInBytes),
          slot: 1);
      final toPatch = composeTransforms(
          Transform2.translation(-region.x.toDouble(), -region.y.toDouble()),
          collectionToDevice);
      patchPass.bindUniform(
        geometry.vertexShader.getUniformSlot('FrameInfo'),
        geometry.uniforms.emplace(buildFrameInfo(
            toPatch, region.width, region.height,
            dashScale: dashScale)),
      );
      patchPass.draw(ResidentGeometry.cornerVertexCount,
          instanceCount: patch.instanceCount);
      patchesRendered++;
      _pendingRegions.add((patch, region));
    }

    commandBuffer.submit();
    frames++;

    // **`asImage()` only after `submit()`, on purpose.** On native the image
    // is a handle over the live texture (`flutter_gpu/texture.cc`'s
    // `Texture::AsImage`) and reads whatever the texture holds when the
    // picture rasterises, so the order would not matter there. On the web
    // shim `asImage()` SNAPSHOTS the texture now (`snapshotTextureSync`), so
    // taken before the submit it would show last frame's patch. One order
    // that is right on both backends -- the finding Codex made against
    // revision 5's first draft.
    for (final (patch, region) in _pendingRegions) {
      _patchImages.add(PatchImage(
        textIndex: patch.textIndex,
        image: patch.target.asImage(),
        src: Rect.fromLTWH(
            0, 0, region.width.toDouble(), region.height.toDouble()),
        dst: Rect.fromLTWH(region.x / dpr, region.y / dpr,
            region.width / dpr, region.height / dpr),
        layerBounds: labelBoundsLogical(
            geometry.texts[patch.textIndex], collectionToLogical),
      ));
    }
    _pendingRegions.clear();
    return target.asImage();
```

`_pendingRegions` is a `List<(ResidentPatch, PatchRegion)>` field, cleared
per frame — the existing `commandBuffer.submit(); frames++; return
target.asImage();` tail of `render` is replaced by the block above. `_patchImages`
is cleared at the top of the patch loop as shown.

**The uniform ring.** `geometry.uniforms` is a bump allocator reset once per
`render` (its own comment, `:150-186`). One `emplace` per pass, `1 + P` per
frame; the ring's blocks are large relative to 80 bytes, but if a run's
`FlutterError` reports a failed emplace at high patch counts, that is the
number to report and the sentence to write, not a reason to reset mid-frame.

Then `paint`:

```dart
  /// One frame onto [canvas]: `render`, then the compositor. This is the
  /// call site a widget uses (Plan F) and the harness uses (Task 7).
  void paint(Canvas canvas, ViewportTransform camera, Size viewport, double dpr) {
    final main = render(camera, viewport, dpr);
    final compositor = _compositor;
    if (compositor == null) {
      if (main != null) {
        canvas.drawImageRect(
            main,
            Rect.fromLTWH(0, 0, main.width.toDouble(), main.height.toDouble()),
            Rect.fromLTWH(0, 0, viewport.width, viewport.height),
            _imagePaint);
      }
      return;
    }
    final collectionToLogical =
        composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
    compositor.paint(canvas,
        main: main,
        viewport: viewport,
        collectionToLogical: collectionToLogical,
        texts: geometry.texts,
        patches: _patchImages);
  }
```

`collectionToLogical` is computed a third time here (once in `render`, once
in `dashScaleFor`, once here): per frame, not per entity, inside the
non-negotiable — the same sentence `render` already carries for its second
composition. Better: have `render` store the frame's `collectionToLogical` in
a field and read it here; do that, and drop the recomputation.

- [ ] **Step 4: Gate and commit**

`render` and `paint` cannot run in `flutter test`; the tests above cover
what can be. The harness run (Task 7) is where this code first executes.

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add lib/src/gpu/resident_geometry.dart lib/src/gpu/gpu_draw_backend.dart \
  test/gpu/resident_geometry_test.dart test/gpu/frame_info_test.dart
git commit -m "feat(gpu): patch targets and sub-buffers on the device, and a paint that composites them"
```

---


### Task 7: The live scale reaches the shader, in the same 80 bytes

**Files:**
- Modify: `lib/src/gpu/gpu_draw_backend.dart`
- Test: `test/gpu/frame_info_test.dart`

**Interfaces:**
- Produces: `buildFrameInfo(Transform2, int, int, {required double dashScale})`,
  writing `dashScale` at float index 18 of the same 80-byte block.
- Consumes: nothing new.

**The block does not grow, and that is arithmetic rather than luck.** std140
puts `mat4 mvp` at bytes 0–63 and `vec2 half_viewport` at 64–71; a trailing
`float` needs 4-byte alignment, so it sits at 72–75, and the struct's own
16-byte alignment rounds 76 up to **80** — exactly the size
`buildFrameInfo` already writes, with float indices 18 and 19 currently zero.
`dash_scale` takes index 18. **Do not add a `vec2` and leave one component
unread**: an entirely unread uniform member risks being optimised out of the
reflection, and this project has already lost a bisect to
*"Could not complete reflection on generated shader"*.

**What the number is.** Live **logical** pixels per collection unit. The
collection buffer is in the collection camera's logical screen space, and
`GpuDrawBackend.render` already computes the collection-to-live-logical
transform on its way to the device one — it is the inner `composeTransforms`
call. Its `scaleMagnitude` is the whole answer.

**Logical, not device, and the reason is `kDashCollapsePx`.** That constant is
compared against `cycle × scale` in `dashPolyline`, where the points are the
painter's screen-space points — logical pixels (`viewport_transform.dart`:
*"screen coordinates are logical pixels"*) — and against `period × pixelScale`
in `dashArc`, where `pixelScale` is `chain.scaleMagnitude`, also logical.
Handing the shader a device-space ratio would collapse patterns at
`dpr` times the wrong zoom: right at `dpr == 1`, wrong on every retina display,
which is the exact shape of the defect Plan A's device run found in the
half-width.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/frame_info_test.dart`:

```dart
  test('the block is still 80 bytes and dash_scale is at float 18', () {
    final data = buildFrameInfo(Transform2.identity(), 800, 600, dashScale: 2.5);
    expect(data.lengthInBytes, 80);
    expect(data.getFloat32(18 * 4, Endian.host), 2.5);
    expect(data.getFloat32(19 * 4, Endian.host), 0.0,
        reason: 'the tail stays zero; the block\'s size comes from the mat4\'s '
            'alignment, not from a member sitting there');
  });

  test('dash_scale does not disturb the mvp or the half viewport', () {
    final without = buildFrameInfo(someTransform, 800, 600, dashScale: 1.0);
    final with3 = buildFrameInfo(someTransform, 800, 600, dashScale: 3.0);
    for (var i = 0; i < 18; i++) {
      expect(with3.getFloat32(i * 4, Endian.host),
          without.getFloat32(i * 4, Endian.host),
          reason: 'float $i');
    }
  });

  test('the scale is logical, not device -- a dpr of 2 does not double it', () {
    // Built from the same camera pair at dpr 1 and dpr 2 through the
    // backend's own composition, the dash scale must read the same number.
    // A device-space ratio would read twice as large at dpr 2 and would
    // collapse every dash pattern at half the zoom it should.
    expect(dashScaleAt(dpr: 2.0), closeTo(dashScaleAt(dpr: 1.0), 1e-9));
  });
```

**The third test needs a seam to observe.** `render` cannot run without a GPU.
Extract the one line that computes the ratio into a top-level function beside
`composeTransforms` and test that:

```dart
/// Live logical pixels per collection unit — the factor the shader compares
/// a dash period against `kDashCollapsePx`.
///
/// **Logical, deliberately.** See this file's `buildFrameInfo` doc.
double dashScaleFor(ViewportTransform camera, Transform2 collectionInverse) =>
    composeTransforms(camera.worldToScreenMatrix, collectionInverse)
        .scaleMagnitude;
```

Now the test builds two cameras and calls it directly, and `render` calls it
too — one implementation, one witness.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/frame_info_test.dart
```

- [ ] **Step 3: Implement**

`buildFrameInfo` gains `{required double dashScale}` and writes
`f(18, dashScale)`. Make it **required**: a defaulted dash scale is a silent 0,
and a 0 collapses every pattern in the drawing to solid — a whole-drawing
defect behind a defaulted argument.

In `render`, name the intermediate rather than composing twice:

```dart
    final collectionToLogical =
        composeTransforms(camera.worldToScreenMatrix, _collectionInverse);
    final collectionToDevice =
        composeTransforms(Transform2.scale(dpr, dpr), collectionToLogical);
    pass.bindUniform(
      geometry.vertexShader.getUniformSlot('FrameInfo'),
      geometry.uniforms.emplace(buildFrameInfo(
          collectionToDevice, widthPx, heightPx,
          dashScale: collectionToLogical.scaleMagnitude)),
    );
```

**`scaleMagnitude` is read once per frame on a `Transform2` that already
exists** — one `sqrt` of a determinant, no allocation. That keeps this inside
the frame-path invariant.

- [ ] **Step 4: Run and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/gpu/gpu_draw_backend.dart packages/jet_cad_2d_flutter/test/gpu/frame_info_test.dart
git commit -m "feat(gpu): the live logical scale, for the collapse test only"
```

---


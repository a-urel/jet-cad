### Task 6: The compositor rejects off-viewport labels, and the frame path's per-patch objects become fields

**Files:**
- Modify: `lib/src/gpu/text_compositor.dart`
- Modify: `lib/src/gpu/text_patches.dart` (`PatchRegion` mutable, `patchRegionFor(out:)`)
- Modify: `lib/src/gpu/gpu_draw_backend.dart` (`buildFrameInfo(out:)`, the region pool, parallel pending lists)
- Test: `test/gpu/text_compositor_viewport_test.dart` (create); `test/gpu/text_patches_test.dart`, `test/gpu/frame_info_test.dart` (modify)

**Interfaces:**
- Consumes: `boundTransformedBox`, `patchRegionFor`, `buildFrameInfo`, `SpyCanvas`.
- Produces: `TextCompositor.labelsSkipped`; `PatchRegion` with mutable `x, y,
  width, height`; `patchRegionFor(..., {PatchRegion? out})`;
  `buildFrameInfo(..., {ByteData? out})`. Task 8's probe measures the effect.

- [ ] **Step 1: Write the failing compositor test**

`test/gpu/text_compositor_viewport_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../support/spy_canvas.dart';

const TextStyleRecord _roboto =
    TextStyleRecord(handle: Handle(11), name: 'Standard', fontFamily: 'Roboto');

/// A label whose collection-space box is [minX, minY]..[maxX, maxY], upright,
/// baseline at its box's bottom. Text, style and colour are the same for all
/// three; only the box moves.
ResidentTextRecord label(double minX, double minY, double maxX, double maxY) =>
    ResidentTextRecord(
        text: 'LABEL',
        style: const Handle(11),
        argb: 0xFF000000,
        a: 1,
        b: 0,
        c: 0,
        d: -1,
        e: minX,
        f: maxY,
        boxMinX: minX,
        boxMinY: minY,
        boxMaxX: maxX,
        boxMaxY: maxY,
        instanceIndex: 0);

void main() {
  test('labels outside the viewport are skipped; inside and straddling are drawn',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final compositor =
        TextCompositor(measurer: measurer, textStyleOf: (_) => _roboto);
    const viewport = Size(400, 300);
    // The outer transform is a pan of (-1000, 0): a label at x 1020..1100 in
    // collection space lands at 20..100 on screen (inside), one at 400..480
    // lands at -600..-520 (outside, left), one at 970..1030 straddles x = 0,
    // one at 1000..1080 / y 900..950 is below the viewport (outside).
    final outer = Transform2.translation(-1000, 0);
    final texts = <ResidentTextRecord>[
      label(1020, 100, 1100, 130),
      label(400, 100, 480, 130),
      label(970, 200, 1030, 230),
      label(1000, 900, 1080, 950),
    ];
    final spy = SpyCanvas();
    compositor.paint(spy,
        main: null,
        viewport: viewport,
        collectionToLogical: outer,
        texts: texts,
        patches: const <PatchImage>[]);
    // MUTATION (M-F11): invert the rejection -> 2 paragraphs skipped, 2 drawn
    // -- the wrong two, and `text_order_test.dart`'s composited differential
    // goes red with it.
    expect(spy.named('drawParagraph').length, 2,
        reason: 'the inside label and the straddling one');
    expect(compositor.labelsSkipped, 2);
    // Anti-vacuity: with a pan that brings every label on screen, all four
    // draw and nothing is skipped.
    final all = SpyCanvas();
    compositor.paint(all,
        main: null,
        viewport: const Size(2000, 2000),
        collectionToLogical: Transform2.identity(),
        texts: texts,
        patches: const <PatchImage>[]);
    expect(all.named('drawParagraph').length, 4);
    expect(compositor.labelsSkipped, 0);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/gpu/text_compositor_viewport_test.dart`
Expected: FAIL — `labelsSkipped` undefined (and four paragraphs drawn).

- [ ] **Step 3: The rejection**

In `lib/src/gpu/text_compositor.dart`, add to the class:

```dart
  /// Reused per plain label by the viewport test: [boundTransformedBox]'s
  /// caller-owned scratch, so rejecting an off-screen label allocates
  /// nothing.
  final Float64List _bound = Float64List(4);

  /// Plain labels the last [paint] did not draw because their box, under the
  /// outer transform, missed the viewport entirely. Diagnostics; reset per
  /// call. A patched label whose patch was off screen is not in `patches`,
  /// takes the plain branch, and is counted here too.
  int labelsSkipped = 0;
```

and in `paint`, `labelsSkipped = 0;` beside `_patchesComposited = 0;`, then
the plain branch becomes:

```dart
      if (patch == null) {
        final t = texts[i];
        boundTransformedBox(
            t.boxMinX, t.boxMinY, t.boxMaxX, t.boxMaxY, collectionToLogical, _bound);
        // Wholly off screen: nothing to draw. A box touching the edge is
        // drawn -- the paragraph clips itself.
        if (_bound[2] < 0 ||
            _bound[0] > viewport.width ||
            _bound[3] < 0 ||
            _bound[1] > viewport.height) {
          labelsSkipped++;
          continue;
        }
        _drawLabel(canvas, t, collectionToLogical);
        continue;
      }
```

Import `boundTransformedBox` is already in the file's `show` clause.

- [ ] **Step 4: Run; expect PASS. Then the two reuses, tests first**

Add to `test/gpu/frame_info_test.dart`:

```dart
  test('buildFrameInfo writes into `out` when given one of the right size', () {
    final m = Transform2(2, 0.5, -0.5, 2, 30, -40);
    final fresh = buildFrameInfo(m, 800, 600, dashScale: 1.7);
    final out = ByteData(80);
    final written = buildFrameInfo(m, 800, 600, dashScale: 1.7, out: out);
    expect(identical(written, out), isTrue);
    for (var i = 0; i < 80; i++) {
      expect(out.getUint8(i), fresh.getUint8(i), reason: 'byte $i');
    }
    // The wrong size is not trusted: a fresh block, not a partial write.
    final wrong = ByteData(64);
    expect(identical(buildFrameInfo(m, 800, 600, dashScale: 1.7, out: wrong),
        wrong), isFalse);
  });
```

Add to `test/gpu/text_patches_test.dart`:

```dart
  test('patchRegionFor writes into `out` and leaves it alone when off screen',
      () {
    final t = ResidentTextRecord(
        text: 'X', style: const Handle(11), argb: 0xFF000000,
        a: 1, b: 0, c: 0, d: -1, e: 0, f: 0,
        boxMinX: 10, boxMinY: 20, boxMaxX: 50, boxMaxY: 40, instanceIndex: 0);
    final out = PatchRegion(7, 7, 7, 7);
    final onScreen = patchRegionFor(t, Transform2.scale(2, 2), 800, 600,
        maxWidth: 4096, maxHeight: 4096, out: out);
    expect(identical(onScreen, out), isTrue);
    expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40));
    final offScreen = patchRegionFor(
        t, Transform2.translation(-1000, 0), 800, 600,
        maxWidth: 4096, maxHeight: 4096, out: out);
    expect(offScreen, isNull);
    expect((out.x, out.y, out.width, out.height), (20, 40, 80, 40),
        reason: 'an off-screen answer must not scribble on the pool entry');
  });
```

Every `const PatchRegion(` in the existing tests becomes `PatchRegion(`.

- [ ] **Step 5: The reuses**

`text_patches.dart` — `PatchRegion` becomes:

```dart
/// Where a patch draws on screen this frame: device pixels, on the viewport.
///
/// **Mutable, and pooled by `GpuDrawBackend`** (Ruling F10, Plan E's RF-1):
/// one instance per patch for the backend's life, written in place by
/// [patchRegionFor]'s `out` each frame. Rebuild-time callers and tests pass
/// no `out` and get a fresh one.
class PatchRegion {
  PatchRegion(this.x, this.y, this.width, this.height);
  int x, y, width, height;
}
```

and `patchRegionFor` gains `PatchRegion? out` and ends:

```dart
  if (x1 <= x0 || y1 <= y0) return null;
  final w = (x1 - x0).clamp(0, maxWidth);
  final h = (y1 - y0).clamp(0, maxHeight);
  if (out == null) return PatchRegion(x0, y0, w, h);
  out
    ..x = x0
    ..y = y0
    ..width = w
    ..height = h;
  return out;
```

`gpu_draw_backend.dart` — `buildFrameInfo` gains `ByteData? out` and opens
with:

```dart
  final data = out != null && out.lengthInBytes == 80 ? out : ByteData(80);
```

(every one of the twenty floats is written explicitly, `f(19, 0)` included,
so a reused block carries nothing over). Add a doc line: *"`out`, when given
and 80 bytes long, is written in place and returned -- the frame path's own
block; a fresh one otherwise."*

`GpuDrawBackend` replaces `_pendingRegions` and adds a pool:

```dart
  /// The frame's uniform block, written in place by `buildFrameInfo(out:)`
  /// once for the main pass and once per patch; `HostBuffer.emplace` copies
  /// the bytes, so one block serves every pass of a frame.
  final ByteData _frameInfo = ByteData(80);

  /// One `PatchRegion` per patch, for the backend's life -- grown to
  /// `geometry.patches.length` on the first frame that needs each slot and
  /// never past it, then written in place by `patchRegionFor(out:)`.
  final List<PatchRegion> _regionPool = <PatchRegion>[];

  /// Parallel lists, reused per frame: the patches this frame drew and the
  /// pool entry each drew into, drained into [_patchImages] after the last
  /// `submit()` (see [render]'s tail). Two lists rather than a list of
  /// records, so the drain allocates no record per patch.
  final List<ResidentPatch> _pendingPatches = <ResidentPatch>[];
  final List<PatchRegion> _pendingRegions = <PatchRegion>[];
```

In `render`: clear both pending lists at the top (where `_pendingRegions.clear()`
was); the two `emplace(buildFrameInfo(...))` calls pass `out: _frameInfo`; the
patch loop becomes indexed:

```dart
    for (var p = 0; p < geometry.patches.length; p++) {
      final patch = geometry.patches[p];
      final t = geometry.texts[patch.textIndex];
      while (_regionPool.length <= p) {
        _regionPool.add(PatchRegion(0, 0, 0, 0));
      }
      final region = patchRegionFor(t, collectionToDevice, widthPx, heightPx,
          maxWidth: patch.targetWidth,
          maxHeight: patch.targetHeight,
          scratch: _regionScratch,
          out: _regionPool[p]);
      if (region == null) {
        patchesOffscreen++;
        continue;
      }
      // ... unchanged through `patchesRendered++;` ...
      _pendingPatches.add(patch);
      _pendingRegions.add(region);
    }
```

and the drain iterates `for (var k = 0; k < _pendingPatches.length; k++)`
reading `_pendingPatches[k]` and `_pendingRegions[k]`. Update the class doc's
enumeration of per-patch allocations: `PatchRegion` and the uniform block
leave the list; `PatchImage`, three `Rect`s, the `asImage()` handle and the
layer stay (with `gpu.Viewport`, `vm.Vector4`, `gpu.BufferView`, the command
buffer and the render pass as the GPU shim's own per-pass objects, which Task
8's probe reports beside ours).

- [ ] **Step 6: Run all four files; expect PASS**

Run: `flutter test test/gpu/text_compositor_viewport_test.dart test/gpu/text_compositor_test.dart test/gpu/text_patches_test.dart test/gpu/frame_info_test.dart test/gpu/text_order_test.dart`

- [ ] **Step 7: Gates, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add lib/src/gpu/text_compositor.dart lib/src/gpu/text_patches.dart lib/src/gpu/gpu_draw_backend.dart test/gpu/text_compositor_viewport_test.dart test/gpu/text_patches_test.dart test/gpu/frame_info_test.dart
git commit -m "perf(gpu): the compositor skips off-viewport labels; PatchRegion and the uniform block are reused fields"
```

---


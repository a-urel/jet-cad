### Task 11: Sink against sink

The test that earns the two-backend decision. It compares **ink regions**, not
pixel colours: the rasterizer has no anti-aliasing and a CAD stroke is about a
pixel wide, so on the canvas side essentially every ink pixel is an edge pixel.
A per-pixel tolerance loose enough to admit that admits real geometry defects
with it.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart`
- Create: `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`

**Interfaces:**
- Consumes: `TriangleRasterizer`, `RenderBackend`, `DraftCanvas`.
- Produces: `expectBackendsAgree(...)`.

- [ ] **Step 1: Write the fixture and the comparison**

`packages/jet_cad_2d_flutter/test/support/sink_comparison.dart`:

```dart
// Do the two production backends draw the same drawing?
//
// Ink-region membership in both directions, not per-pixel colour. The
// rasterizer has no anti-aliasing and a CAD stroke is about one pixel wide, so
// on the canvas side essentially every ink pixel is an edge pixel: a per-pixel
// tolerance loose enough to admit that would admit a wrong corner too, and the
// number would be a bound on nothing.
//
// ## What this fixture deliberately avoids, and why
//
// `flutter_test` renders through **software Skia**, not Impeller. Two of the
// rules the vertices sink mirrors are Impeller's and do not exist on the
// canvas side here: the one-device-pixel stroke floor
// (`impeller/entity/geometry/geometry.h:19`) and the sub-pixel alpha fade
// (`geometry.cc:148`). `flutter_test` also defaults to a `devicePixelRatio` of
// 1, where the corpus's thinnest lineweight is 0.945 device pixels — squarely
// inside the regime the two engines treat differently.
//
// So the fixture pins the ratio and uses lineweights above the floor at it.
// **That buys agreement by excluding the sub-pixel rules from this
// comparison**, and they are then pinned by the six unit tests in
// `vertices_draw_sink_test.dart` and by nothing else. Said out loud because a
// reader would otherwise believe this test covers them.
//
// Text is excluded from the pixel comparison and asserted by flush count
// instead: a paragraph never enters the triangle buffer, so the vertices-side
// image has no glyphs while the canvas-side one does. The fixture still
// *carries* text, because text is what forces the mid-frame flush and the
// ordering that depends on it is half of what is being tested.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'triangle_rasterizer.dart';

const Size kComparisonSize = Size(400, 300);

/// The ratio the comparison runs at.
///
/// 1.0 is `flutter_test`'s default and the fixture's lineweights are chosen
/// against it; changing one without the other puts every thin stroke back into
/// the divergent regime.
const double kComparisonRatio = 1.0;

/// Pixels of the canvas image at or above this alpha count as its ink.
///
/// Below it is anti-aliasing spill, which the rasterizer has no way to
/// produce and which is a permitted divergence.
const int kInkAlphaFloor = 0xC0;

/// Rasterises [doc] through both backends and asserts they draw the same
/// drawing.
Future<void> expectBackendsAgree(
  WidgetTester tester,
  DraftDocument doc, {
  required Rect textMask,
}) async {
  // ... builds the widget once per backend, reads the canvas one back with
  // `RenderRepaintBoundary.toImage`, attaches the rasterizer to the vertices
  // one, then compares (see step 3).
}
```

- [ ] **Step 2: Write the failing test**

`packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'support/sink_comparison.dart';

void main() {
  testWidgets('the two backends draw the same drawing', (tester) async {
    // Every primitive, at lineweights above the floor at ratio 1, under
    // non-identity residuals -- the fixture that would be degenerate is the
    // one at the identity, and this repository names that as its dominant
    // failure mode.
    final doc = comparisonFixture();
    assertNoIdentityTransforms(doc);
    await expectBackendsAgree(tester, doc, textMask: comparisonTextMask(doc));
  });

  testWidgets('the comparison is not vacuous', (tester) async {
    // A membership assertion passes trivially against an empty image on
    // either side.
    final doc = comparisonFixture();
    final report = await measureBackendAgreement(tester, doc,
        textMask: comparisonTextMask(doc));
    expect(report.canvasInkPixels, greaterThan(500));
    expect(report.verticesInkPixels, greaterThan(500));
    expect(report.strayVerticesPixels, 0);
    expect(report.uncoveredCanvasPixels, 0);
  });
}
```

- [ ] **Step 3: Implement the comparison**

Fill in `expectBackendsAgree` and add `measureBackendAgreement`, which returns
the counts so the vacuity test can read them:

```dart
class AgreementReport {
  AgreementReport({
    required this.canvasInkPixels,
    required this.verticesInkPixels,
    required this.strayVerticesPixels,
    required this.uncoveredCanvasPixels,
  });

  /// Canvas pixels at or above [kInkAlphaFloor], outside the text mask.
  final int canvasInkPixels;
  final int verticesInkPixels;

  /// Vertices ink with no canvas ink within one pixel. Invented geometry.
  final int strayVerticesPixels;

  /// Canvas ink above the floor with no vertices ink within one pixel.
  /// Missing geometry.
  final int uncoveredCanvasPixels;
}
```

The comparison itself, after both images exist as `Uint32List`s:

```dart
  bool nearInk(List<bool> mask, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (mask[ny * w + nx]) return true;
      }
    }
    return false;
  }
```

Dilating by exactly one pixel in each direction is the whole tolerance: it
covers the half-pixel each rasteriser may place an edge differently, and it
does not cover a corner in the wrong place.

- [ ] **Step 4: Run the test and watch it fail, then pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/sink_comparison_test.dart
```

Expected first: a compile error, then real counts.

**If `strayVerticesPixels` or `uncoveredCanvasPixels` is non-zero, do not widen
the dilation.** Save both images to `/tmp` and look at them. A non-zero count
is a divergence, and the design document's table lists the five that are
permitted; anything else is a defect in Tasks 4, 5 or 6. Widening a tolerance
until a gate passes is the failure mode this plan's design document names twice.

- [ ] **Step 5: Record the observed numbers**

Put the measured `canvasInkPixels` / `verticesInkPixels` into the test's own
comment as a dated fact, so a later change that halves the ink is visible as a
number and not only as a pass.

- [ ] **Step 6: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter/test
git commit -m "test: the two backends draw the same drawing

Ink-region membership in both directions, dilated by exactly one pixel. Not
per-pixel colour: the rasterizer has no anti-aliasing and a CAD stroke is about
a pixel wide, so on the canvas side essentially every ink pixel is an edge
pixel and a tolerance loose enough to admit that admits a wrong corner too.

flutter_test is software Skia, so Impeller's stroke floor and alpha fade do not
exist on the canvas side of this comparison. The fixture pins devicePixelRatio
and stays above the floor, and the test says out loud what that costs: those
two rules are pinned by unit test and by nothing else."
```

---

# Phase C — measurement


## Task 1: The frame-global audit, and `DraftPainter`'s injectable rebase origin

**Why first:** the spec's D1 says tiling turns *every* frame-global quantity into a per-tile one unless it is pinned. Nothing later in this plan is safe until the list of such quantities is written down.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `DraftPainter({..., Vector2? debugRebaseOrigin, void Function(Handle)? debugOnVisit})`. Task 5 injects the origin; Task 8 uses the visit callback.

- [ ] **Step 1: Audit and record the frame-global quantities**

Read `DraftPainter.paint` (`draft_painter.dart:296-350`) and write down every value it derives from *this call's* `camera` and `viewport` rather than from a field. Put the list in the commit message. The four the spec expects are:

| quantity | line | frame-global? |
|---|---|---|
| `rebaseOriginFor(world)` → `origin` | `:307-308` | **yes** — snaps to a power-of-two grid from the view span |
| `_screenOrigin = camera.worldToScreen(origin)` | `:310` | derived from the above |
| `_screenSpaceClip` / `_rebasedClip` (inflated by `kScreenClipInflate`) | `:311-322` | **no** — must be the tile's own rect, which is what the bake camera gives it |
| `minTextCapPixels` level-of-detail threshold | field, `:102` | already a field, so already frame-global |

If the audit finds a fifth, say so in the report; the plan's later tasks assume these four.

- [ ] **Step 2: Write the failing test**

Create `packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart`:

```dart
// Rebasing is frame-global by construction: `rebaseOriginFor` snaps the view
// centre to a power-of-two grid whose step comes from the view *span*
// (`camera_controller.dart:18-33`). Plan 3g bakes tiles through per-tile
// cameras, and a per-tile span would give each tile its own step and its own
// origin — different `float32` residuals from the live frame, against a
// criterion that allows zero differing pixels.
//
// This pins that the override exists and that it wins. Mutant M17 deletes it.

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

import 'support/fixtures.dart';

void main() {
  test('an injected rebase origin overrides the one the view span would give',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // Far from the origin, so the rebase origin is a large number and a wrong
    // one is visible in the emitted coordinates rather than lost in rounding.
    // 4.5e6 is the magnitude `viewport_transform.dart`'s header names.
    addLine(doc, doc.rootHandle, const Handle(1001), 4.5e6, 4.5e6, 4.5e6 + 400,
        4.5e6 + 300);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    const viewport = Size(400, 300);
    final camera = ViewportTransform(
        worldToScreenMatrix:
            Transform2(1, 0, 0, -1, -4.5e6, 4.5e6 + viewport.height));

    Float64List firstPolyline(DraftPainter painter) {
      final sink = RecordingDrawSink();
      painter.paint(sink, camera, viewport);
      final op = sink.ops.whereType<PolylineOp>().first;
      return Float64List.fromList(op.points);
    }

    final derived = firstPolyline(DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc)));

    // A deliberately different origin: the same grid, one step over. The
    // emitted points are rebased against it, so every x moves by exactly the
    // difference and nothing else changes.
    final defaultOrigin = rebaseOriginFor(camera.visibleWorld(viewport));
    final shifted = Vector2(defaultOrigin.x + 4096, defaultOrigin.y);
    final overridden = firstPolyline(DraftPainter(
        document: doc,
        index: index,
        resolver: DocumentStyleResolver(doc),
        debugRebaseOrigin: shifted));

    expect(overridden.length, derived.length);
    for (var i = 0; i < derived.length; i += 2) {
      expect(overridden[i], derived[i] - 4096,
          reason: 'x rebased against the injected origin');
      expect(overridden[i + 1], derived[i + 1], reason: 'y untouched');
    }
  });

  test('debugOnVisit reports every leaf drawn and every container descended',
      () {
    final measurer = FlutterTextMeasurer();
    addTearDown(measurer.clear);
    final doc = DraftDocument.empty(measurer: measurer);
    // One root leaf, one definition holding one leaf, one instance placing it.
    // A root-only fixture would let M16 survive — see anti-degenerate clause 4.
    addLine(doc, doc.rootHandle, const Handle(1001), 10, 10, 90, 90);
    addDefinition(doc, const Handle(210), 'PLATE');
    addLine(doc, const Handle(210), const Handle(1002), 0, 0, 40, 40);
    addInstance(doc, doc.rootHandle, const Handle(300), const Handle(210),
        Transform2(1, 0, 0, 1, 120, 20));
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);

    final seen = <Handle>[];
    final painter = DraftPainter(
      document: doc,
      index: index,
      resolver: DocumentStyleResolver(doc),
      debugOnVisit: seen.add,
    );
    painter.paint(RecordingDrawSink(), unitCamera(), const Size(400, 300));

    expect(seen, contains(const Handle(1001)), reason: 'the root leaf');
    expect(seen, contains(const Handle(1002)), reason: 'the definition leaf');
    expect(seen, contains(const Handle(300)),
        reason: 'the instance node itself — TransformNodeCommand reports only '
            'this handle, so a tile that never records it cannot find the '
            'pixels a drag left behind');
  });
}
```

`unitCamera()`, `addLine`, `addDefinition`, `addInstance` come from `test/support/fixtures.dart`. If any is missing, add it there in this task rather than inlining a local copy.

- [ ] **Step 3: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_painter_rebase_test.dart
```

Expected: compile failure — `DraftPainter` has no `debugRebaseOrigin` and no `debugOnVisit`.

- [ ] **Step 4: Add the two parameters**

In `draft_painter.dart`, add to the constructor and the fields:

```dart
  /// Overrides the rebase origin `paint` would derive from this call's visible
  /// world.
  ///
  /// **Rebasing is frame-global by construction.** `rebaseOriginFor` snaps the
  /// view centre to a power-of-two grid whose step comes from the view *span*
  /// (`camera_controller.dart:18-33`), precisely so a pan does not re-quantise
  /// every coordinate. Plan 3g bakes tiles through per-tile cameras; without
  /// this each tile would take its own span, its own exponent and its own
  /// origin, and its `float32` residuals would differ from the live frame's.
  ///
  /// Not `debugDisableRebasing`, which forces the origin to zero and destroys
  /// the precision rebasing exists for at 4.5e6.
  /// **Deliberately mutable.** `TileCache` sets it around each bake and clears
  /// it afterwards, so one painter serves the live frame and every tile in it.
  /// A `final` field would force a painter instance per tile, and a painter
  /// carries the scratch buffers `paint_allocation_test.dart` exists to keep
  /// still.
  Vector2? debugRebaseOrigin;

  /// Called with every leaf drawn and every container descended into.
  ///
  /// Plan 3g's tile invalidation records what a tile baked. **Both halves are
  /// needed**: `TransformNodeCommand` reports only the moved node's handle
  /// (`commands.dart:304`), and the leaves it moved keep their own, so a tile
  /// that recorded leaves alone cannot find a dragged instance's old pixels.
  ///
  /// Null on the production frame path, so it costs one null check per leaf and
  /// allocates nothing.
  /// Mutable for the same reason as [debugRebaseOrigin].
  void Function(Handle handle)? debugOnVisit;
```

In `paint`, replace the origin derivation:

```dart
    final origin = debugRebaseOrigin ??
        (debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world));
```

Note the precedence: an injected origin wins over `debugDisableRebasing`, because a caller that supplies one has already decided.

In `paint`'s leaf visitor, beside `_rootLeaves++`:

```dart
      debugOnVisit?.call(document.entities.handleAt(slot));
```

In `_drawContainer`'s leaf loop, beside `_defLeaves++` — use `document.entities.handleAt(slot)`, which the loop already computed as `leafHandle`:

```dart
      debugOnVisit?.call(Handle(leafHandle));
```

In `_drawInstance`, after the `is! InstanceNode` guard:

```dart
    debugOnVisit?.call(instance);
```

In `_descend`, after its `is! InstanceNode` guard:

```dart
    debugOnVisit?.call(handle);
```

- [ ] **Step 5: Run it and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test test/draft_painter_rebase_test.dart
```

- [ ] **Step 6: Fire mutant M17 by hand**

Copy the file aside first — **never `git checkout` to revert a mutation**:

```sh
cp lib/src/draft_painter.dart /tmp/draft_painter.dart.bak
```

Change the origin line to ignore the override:

```dart
    final origin = debugDisableRebasing ? Vector2.zero() : rebaseOriginFor(world);
```

Run the test; it must fail on the x assertion. Then:

```sh
cp /tmp/draft_painter.dart.bak lib/src/draft_painter.dart && rm /tmp/draft_painter.dart.bak
```

Record the transcript in the task report.

- [ ] **Step 7: Green the whole suite and commit**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/test/draft_painter_rebase_test.dart packages/jet_cad_2d_flutter/test/support/fixtures.dart
git commit -m "feat: the painter's rebase origin and visit list become injectable

Rebasing is frame-global by construction -- rebaseOriginFor snaps the view
centre to a power-of-two grid whose step comes from the view span, so a pan
does not re-quantise coordinates. Baking tiles through per-tile cameras would
give each tile its own span and its own origin, and float32 residuals that
differ from the live frame's against a criterion that allows zero differing
pixels.

debugOnVisit reports leaves and containers both. TransformNodeCommand reports
only the moved node's handle and its leaves keep theirs, so a tile recording
leaves alone cannot find a dragged instance's old pixels."
```

---


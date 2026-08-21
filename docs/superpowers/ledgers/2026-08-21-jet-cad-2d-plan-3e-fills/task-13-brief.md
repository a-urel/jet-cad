## Task 13: The painter draws fills, and counts the ones it skips

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart`
- Create: `packages/jet_cad_2d_flutter/test/fill_render_test.dart`

**Interfaces:**
- Produces: `int get skippedFillCount` on `DraftPainter`, reset per frame like `dashSpanCount`.

**The painter owns the skip, not the sinks.** `CanvasDrawSink` fills a path by non-zero winding, so a self-intersecting boundary would paint *something* there while `VerticesDrawSink` painted nothing — a divergence manufactured on exactly the case this plan refuses. So the painter checks for an unresolvable reference or an empty triangulation, skips, and counts. Neither sink is ever handed an empty fill.

**Where the fill goes in `_drawLeafComposed`.** A fill's geometry is its boundary's, and a boundary is a polyline or a circle. Polylines go through `_emitScreenSpace` (points carried into screen space, residual is a bare translation); circles keep the residual path. **A fill follows its boundary's route**, so a polygon fill's points are screen-space and its stroke-width question never arises, and a circle fill's residual is the same one its outline gets.

- [ ] **Step 1: Write the failing tests**

`packages/jet_cad_2d_flutter/test/fill_render_test.dart`:

```dart
test('a region draws the fill before its boundary', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);
  doc.commands.execute(cmd);
  final sink = RecordingDrawSink();
  paintOnce(doc, sink);
  final fillAt = sink.ops.indexWhere((o) => o is FillPolygonOp);
  final strokeAt = sink.ops.indexWhere((o) => o is PolylineOp);
  expect(fillAt, isNonNegative);
  expect(fillAt, lessThan(strokeAt),
      reason: 'draw order is ascending handle value and the fill holds the '
          'lower one; if this inverts, the fill paints over its own outline');
});

test('an unfillable boundary is skipped and counted, not handed to a sink', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);
  doc.commands.execute(cmd);
  // Edit the boundary into a bow tie: still closed, no longer simple.
  doc.commands.execute(SetEntityGeometryCommand(
      cmd.boundary.handle,
      GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
          scalars: Float64List(0))));
  final sink = RecordingDrawSink();
  final painter = paintOnce(doc, sink);
  expect(sink.ops.whereType<FillPolygonOp>(), isEmpty,
      reason: 'CanvasDrawSink fills a self-intersecting path by non-zero '
          'winding while VerticesDrawSink draws nothing -- handing either one '
          'this fill manufactures a divergence on the refused case');
  expect(painter.skippedFillCount, 1);
});

test('a circle boundary draws a fillCircle, never a triangulated polygon', () {
  // The scale-dependence rule, as a drawing property.
  final doc = DraftDocument.empty();
  doc.commands.execute(AddRegionCommand.allocate(
    seed: doc.handleSeed,
    owner: doc.rootHandle,
    boundaryKind: EntityKind.circle,
    boundaryPayload: GeometryPayload(
        coords: Float64List.fromList([0, 0]),
        scalars: Float64List.fromList([50])),
    layer: ReservedHandles.layerZero,
    fillColor: const TrueColor(0x3366CC),
    boundaryColor: const TrueColor(0x000000),
  ));
  final sink = RecordingDrawSink();
  paintOnce(doc, sink);
  expect(sink.ops.whereType<FillCircleOp>(), hasLength(1));
  expect(sink.ops.whereType<FillPolygonOp>(), isEmpty);
});

test('skippedFillCount is per frame, not a running total', () {
  // Plan 3c's Ruling 44: a counter that never resets prints a plausible number
  // beside two per-frame figures and reads as a working gate.
  final doc = DraftDocument.empty();
  doc.commands.execute(region(doc));
  doc.commands.execute(SetEntityGeometryCommand(
      doc.entities.handleAt(doc.entities.liveSlots.last),
      GeometryPayload(
          coords: Float64List.fromList([0, 0, 10, 10, 10, 0, 0, 10, 0, 0]),
          scalars: Float64List(0))));
  final painter = paintOnce(doc, RecordingDrawSink());
  paintAgain(painter, RecordingDrawSink());
  expect(painter.skippedFillCount, 1);
});

test('the painter walks fills and the reference walk agrees', () {
  // `expectPainterSupersetOfReference` in
  // `packages/jet_cad_2d_flutter/test/support/differential.dart` is the
  // existing oracle. It is a *superset* check by design, so it catches a
  // painter that forgets a fill and not one that draws an extra -- pair it
  // with the ordering test above, which is exact.
  final doc = DraftDocument.empty();
  doc.commands.execute(region(doc));
  expectPainterSupersetOfReference(doc);
});
```

- [ ] **Step 2: Run and watch them fail**

- [ ] **Step 3: Implement**

In `_drawLeafComposed`, before the kind switch:

```dart
      case EntityKind.fill:
        _drawFill(sink, camera, origin, placement, slot, style);
        return;
```

```dart
  /// Draws one fill, or skips it and says so.
  ///
  /// A fill has no geometry of its own: it occupies its boundary's loop and
  /// follows its boundary's route through this painter -- screen space for a
  /// polygon, the residual path for a circle -- so a filled shape and its own
  /// outline are transformed by the same code.
  ///
  /// **The skip lives here, not in a sink.** `CanvasDrawSink` fills a
  /// self-intersecting path by non-zero winding while `VerticesDrawSink`, given
  /// no triangles, draws nothing. Handing either of them an unfillable fill
  /// manufactures a backend divergence on exactly the case this plan refuses,
  /// so neither is ever handed one.
  void _drawFill(DrawSink sink, ViewportTransform camera, Vector2 origin,
      Transform2 placement, int slot, ResolvedStyle style) {
    final payload = document.geometry.peek(document.entities.geomIndexAt(slot));
    final boundary = boundaryHandleOf(payload);
    final boundarySlot = document.entities.slotOf(boundary);
    if (boundarySlot == null) {
      _skippedFills++;
      return;
    }
    final boundaryKind = document.entities.kindAt(boundarySlot);
    final boundaryPayload =
        document.geometry.peek(document.entities.geomIndexAt(boundarySlot));
    final toScreen = camera.worldToScreenMatrix.multiply(placement);

    if (boundaryKind == EntityKind.circle) {
      // Never triangulated ahead of time: a circle's tessellation is
      // scale-dependent, and the sink fans it at the step count its own stroke
      // uses.
      final localOrigin = _localOriginFor(placement, origin);
      final chain = camera.worldToScreenMatrix
          .multiply(placement)
          .multiply(Transform2.translation(localOrigin.x, localOrigin.y));
      sink.beginResidual(chain,
          debugHandle: document.entities.handleAt(slot));
      sink.fillCircle(boundaryPayload.coords[0] - localOrigin.x,
          boundaryPayload.coords[1] - localOrigin.y,
          boundaryPayload.scalars[0], style);
      sink.endResidual();
      return;
    }

    // Read, never compute: the triangulation was materialised by the command,
    // the codec or undo. A miss here means the boundary is unfillable.
    final triangles = document.fills.trianglesFor(boundary);
    if (triangles == null || triangles.isEmpty) {
      _skippedFills++;
      return;
    }

    final count = boundaryPayload.pointCount;
    _ensurePoints(count);
    for (var i = 0; i < count; i++) {
      final x = boundaryPayload.coords[i * 2];
      final y = boundaryPayload.coords[i * 2 + 1];
      _points[i * 2] =
          toScreen.a * x + toScreen.c * y + toScreen.e - _screenOrigin.x;
      _points[i * 2 + 1] =
          toScreen.b * x + toScreen.d * y + toScreen.f - _screenOrigin.y;
    }
    sink.beginResidual(Transform2.translation(_screenOrigin.x, _screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    sink.fillPolygon(_points, count, triangles, style);
    sink.endResidual();
  }
```

`_skippedFills` resets in the same place `_screenSpaceLeaves` does, and is
exposed as `int get skippedFillCount => _skippedFills;`.

`reference_walk.dart` gets the same shape, written independently — it resolves
the boundary and calls `fillPolygon`/`fillCircle` itself. **It must not share a
helper with the painter**: the oracle exists to disagree, and a shared helper
would have it share the assumption it is testing.

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T13a: draw the fill after the boundary          -> the ordering test reds
# T13b: hand an empty triangulation to the sink   -> the skip test reds
# T13c: never increment _skippedFills             -> the counter test reds
# T13d: do not reset _skippedFills per frame      -> the per-frame test reds
# T13e: triangulate a circle boundary instead of fanning it -> the circle test reds
# T13f: share _drawFill between painter and reference walk  -> no test reds;
#       this one is a REVIEW item, not a mutation. Recorded so nobody does it.
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart \
        packages/jet_cad_2d_flutter/lib/src/reference_walk.dart \
        packages/jet_cad_2d_flutter/test/fill_render_test.dart
git commit -m "feat: the painter draws fills, and counts the ones it skips"
```

---


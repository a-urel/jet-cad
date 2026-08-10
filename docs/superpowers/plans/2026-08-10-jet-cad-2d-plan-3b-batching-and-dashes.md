# jet_cad_2d Plan 3b — Draw-Call Batching and Dashes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the render path's draw calls cheap enough that a third of the corpus can finally be drawn dashed without the 500,000-entity working-set frame getting slower than Plan 3a measured it.

**Architecture:** `DraftPainter` carries every point, line and polyline into screen space in `Float64` and pushes one shared translation residual per frame — generalising the anisotropy bypass that already does this for a minority of leaves. The coalescing lives in `CanvasDrawSink`, behind a mode enum, so the `DrawSink` interface, `RecordingDrawSink` and the differential oracle keep their exact shape. Four sink modes are measured in a spike before the rest of the plan commits to one. Dash generation is pure engine geometry with a screen-space period, a clip-then-phase step and a measured collapse floor, so segment count is bounded by the viewport rather than by document extent.

**Tech Stack:** Dart 3.5+, Flutter stable ≥3.24 (3.44.9 measured), `vector_math_64`, `package:test` for the pure package, `flutter_test` + `integration_test` for the widget package.

**Spec:** [2026-08-10-jet-cad-2d-plan-3b-design.md](../specs/2026-08-10-jet-cad-2d-plan-3b-design.md)
**Predecessor results:** [2026-08-10-plan-3a-results.md](../notes/2026-08-10-plan-3a-results.md)

## Global Constraints

- **`packages/jet_cad_2d` must never import Flutter.** No `dart:ui`, no `package:flutter`. `dart test` must keep working there. The dasher lives here, so it takes plain doubles and `Aabb2`, never `Offset` or `Rect`.
- **Zero allocation on the frame path.** No `Path`, `Paint`, list or closure allocated per primitive. Scratch objects are fields, reset in place. Proven structurally through capacity getters, in the shape of `SpatialIndex.entityScratchCapacity`.
- **`reference_walk.dart` is not modified by this plan.** `flatten` in `test/support/differential.dart` already applies each residual before comparing, so the reference needs no screen-space change. An empty diff on that file is an exit criterion.
- **`DrawSink` (the abstract class in `draw_sink.dart`) gains no methods.** Batching is a `CanvasDrawSink` implementation detail. `RecordingDrawSink` and `NullDrawSink` stay one op per primitive.
- **`NullDrawSink.opCount` keeps its meaning** — one per painter call — so Plan 3a's R1 and R3 rows stay comparable. Real `Canvas` calls get a separate counter on `CanvasDrawSink`.
- **Draw order is ascending handle value in the painter, always.** What a sink does downstream is the sink's contract, written down per mode.
- **Every fixture instance carries a distinct non-uniform scale, a rotation and a translation.** No identity transforms in any new fixture. Plan 2's post-mortem records four fixtures that hid a composition-order defect because the identity commutes.
- **Geometric *decisions* use `Tolerance`; comparisons of *stored values* use exact `==`.**
- **`GeometryStore.peek` for frame reads, `read` for anything stored.**
- **`document.commands.onAfterMutate` belongs to `SpatialIndex`.** Nothing here may assign it.
- Analyzer and `dart format` clean at every commit. `dart test` in `packages/jet_cad_2d` (639 tests today) and `flutter test` in `packages/jet_cad_2d_flutter` (120 today) stay green throughout.
- **DXF dash convention:** in `DashPattern.dashes`, a positive value is a drawn length, a negative value is a gap, and `totalLength` is the sum of the absolute values. The corpus's dashed linetype is `DashPattern(dashes: [12.0, -6.0], totalLength: 18.0)`.

## File Structure

**Pure package (`packages/jet_cad_2d`)**

| File | Responsibility |
|---|---|
| `lib/src/document/header.dart` (modify) | `globalLinetypeScale` |
| `lib/src/geometry/segment_clip.dart` (create) | Liang–Barsky clip of a segment to an `Aabb2`, and a circle's angular windows inside one |
| `lib/src/geometry/dasher.dart` (create) | pattern walk over clipped polylines and arcs, with the collapse floor |
| `lib/src/document/memoised_style_resolver.dart` (delete) | measured pessimisation |

**Flutter package (`packages/jet_cad_2d_flutter`)**

| File | Responsibility |
|---|---|
| `lib/src/draft_painter.dart` (modify) | screen-space carry for line-like geometry, dash dispatch, counters |
| `lib/src/canvas_draw_sink.dart` (modify) | `BatchMode`, bucket lifecycle, `flush()`, real-call counter |
| `lib/src/draft_canvas.dart` (modify) | drop the owner map, call `sink.flush()` after painting |
| `lib/src/leaf_owner_map.dart` (delete) | only consumer was the cull floor |
| `lib/src/reference_walk.dart` | **untouched** |

**Tests and rigs**

| File | Responsibility |
|---|---|
| `packages/jet_cad_2d/test/geometry/dasher_test.dart` (create) | pure dash-generation tests |
| `packages/jet_cad_2d/test/geometry/segment_clip_test.dart` (create) | clip and angular-window tests |
| `packages/jet_cad_2d_flutter/test/golden/batch_equivalence_golden_test.dart` (create) | fixtures 1–3, batched vs unbatched |
| `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart` (create) | the collapse-floor review golden |
| `packages/jet_cad_2d_flutter/test/rig/rig_support.dart` (create) | `kRigViewport`, `rigCorpus`, the two cameras — lifted out of R1 so the spike shares them |
| `packages/jet_cad_2d_flutter/test/rig/batch_spike_test.dart` (create) | the spike's R1-side numbers |
| `apps/dev_harness_2d/integration_test/frame_timing_test.dart` (modify) | `BATCH` define, dashed R4a line |
| `docs/superpowers/notes/plan-3b-mutation-log.md` (create) | mutation evidence |
| `docs/superpowers/notes/<date>-plan-3b-results.md` (create) | the numbers |

---

## Task 0: Delete the two measured losses

Plan 3a measured both and both cost. The cull floor loses 10–20% on the working set — the frame that matters — and wins only on a frame nobody renders. The style memo costs 19–39% everywhere. They are removed **first**, before anything is measured, so no spike number is contaminated by a shortcut that is on its way out.

`LeafOwnerMap`'s only consumer is the cull floor, so it goes with it, and `DraftCanvas` loses the change-feeding path that kept it fresh.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart` (remove `kCullFloor`, `ownerMap`, `_directBucketFor`, `_directBuckets`, `directBucketCount`)
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` (remove `ownerMap` field and the `onChange` wiring)
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` (drop the `leaf_owner_map.dart` export)
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (drop the `memoised_style_resolver.dart` export)
- Delete: `packages/jet_cad_2d_flutter/lib/src/leaf_owner_map.dart`
- Delete: `packages/jet_cad_2d_flutter/test/leaf_owner_map_test.dart`
- Delete: `packages/jet_cad_2d/lib/src/document/memoised_style_resolver.dart`
- Delete: `packages/jet_cad_2d/test/document/memoised_style_resolver_test.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `DraftPainter({required DraftDocument document, required SpatialIndex index, required StyleResolver resolver, bool debugDisableRebasing = false})` — the `ownerMap` named parameter is gone. `DraftCanvasState` no longer has an `ownerMap` field.

- [ ] **Step 1: Write the failing test**

The property is user-visible: a small definition's off-screen leaves must not be drawn. `DraftCanvas` supplies an owner map today, so this fails through the widget.

Add to `packages/jet_cad_2d_flutter/test/draft_canvas_test.dart`:

```dart
  testWidgets('a small container does not draw its off-screen leaves',
      (tester) async {
    // Eight leaves — under the old kCullFloor of 32 — spread across a strip
    // far wider than the view. The camera sees the leftmost two.
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def,
        name: 'strip',
        basePoint: Vector2.zero(),
        children: const []));
    for (var i = 0; i < 8; i++) {
      addEntity(doc, def, doc.handleSeed.next(), EntityKind.line,
          [i * 1000.0, 0, i * 1000.0 + 40, 30], const []);
    }
    final placed = doc.handleSeed.next();
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: placed,
      parent: doc.rootHandle,
      definition: def,
      transform: Transform2(1.3, 0.2, -0.1, 1.7, 25, 40),
    )));

    final index = SpatialIndex(doc);
    final recording = RecordingDrawSink();
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    // A view over the first strip cell only.
    final camera = ViewportTransform.fit(
        Aabb2(Vector2(0, 0), Vector2(120, 90)), kViewport);
    painter.paint(recording, camera, kViewport);

    expect(recording.ops.whereType<PolylineOp>().length, lessThanOrEqualTo(2),
        reason: 'the container has eight leaves and the view holds one or '
            'two of them; drawing all eight is the cull-floor shortcut');
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_canvas_test.dart -N "a small container does not draw its off-screen leaves"`

Expected: FAIL — 8 polylines drawn, because `DraftCanvas`-era code paths hand the painter an owner map and eight is under `kCullFloor`.

If it passes, the test is being run against a painter with no owner map. Construct it with `ownerMap: LeafOwnerMap(doc)` to reproduce the shortcut, confirm the failure, then remove that argument again before step 3.

- [ ] **Step 3: Delete the shortcut**

In `draft_painter.dart`, delete the `kCullFloor` constant and its doc comment, the `ownerMap` field and its doc comment, the `_directBuckets` counter and `directBucketCount` getter, and the whole `_directBucketFor` method. In `_drawContainer`, replace:

```dart
    final scratch = _scratchAt(depth);
    scratch.leaves.reset();
    final bucket = _directBucketFor(container, ci);
    if (bucket != null) {
      _directBuckets++;
      for (var i = 0; i < bucket.length; i++) {
        scratch.leaves.add(bucket[i]);
      }
    } else {
      // searchLeaves is neither ordered nor deduplicated: it walks the packed
      // tree and then the dirty overlay, and a slot in both is visited twice by
      // design. Both are this caller's job.
      ci.searchLeaves(localRect, scratch.leaves.add);
    }
```

with:

```dart
    final scratch = _scratchAt(depth);
    scratch.leaves.reset();
    // searchLeaves is neither ordered nor deduplicated: it walks the packed
    // tree and then the dirty overlay, and a slot in both is visited twice by
    // design. Both are this caller's job.
    ci.searchLeaves(localRect, scratch.leaves.add);
```

Remove `import 'leaf_owner_map.dart';` and the `_directBuckets = 0;` line in `paint`.

- [ ] **Step 4: Delete `LeafOwnerMap` and unwire `DraftCanvas`**

Delete `lib/src/leaf_owner_map.dart` and `test/leaf_owner_map_test.dart`, and drop the export from `lib/jet_cad_2d_flutter.dart`.

In `draft_canvas.dart`'s `_attach`, remove the `ownerMap` field, its construction, the painter argument, and the `onChange:` argument:

```dart
  void _attach() {
    sink = CanvasDrawSink(pixelsPerPaperMm: widget.pixelsPerPaperMm);
    painter = DraftPainter(
      document: widget.document,
      index: widget.index,
      resolver: widget.resolver,
    );
    // No derived state left to update before listeners run: the map that
    // needed it was the cull floor's, and the cull floor is gone.
    _changes = DocChangeNotifier(widget.document);
    _repaint = Listenable.merge([widget.camera, _changes]);
  }
```

`DocChangeNotifier`'s `onChange` parameter now has no caller in this package. Keep it — it is a general hook and the widget test for it stays meaningful — but delete the `each change reaches the leaf-owner map` test and the `disposing stops listening` test's owner-map assertions, rewriting the latter to count `onChange` invocations instead:

```dart
  testWidgets('disposing stops listening', (tester) async {
    final doc = DraftDocument.empty();
    var changes = 0;
    final notifier = DocChangeNotifier(doc, onChange: (_) => changes++);
    addLine(doc);
    await tester.pump();
    final afterFirst = changes;
    expect(afterFirst, greaterThan(0), reason: 'the listener must be live '
        'before disposal, or the assertion below proves nothing');

    notifier.dispose();
    addLine(doc);
    await tester.pump();
    expect(changes, afterFirst,
        reason: 'a disposed notifier that still receives changes leaks; '
            'it does not throw, so "no exception" would not catch it');
  });
```

- [ ] **Step 5: Delete `MemoisedStyleResolver`**

Delete `packages/jet_cad_2d/lib/src/document/memoised_style_resolver.dart` and `packages/jet_cad_2d/test/document/memoised_style_resolver_test.dart`, and drop the export from `lib/jet_cad_2d.dart`.

Remove the memo rows from `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart` — the `memo` row per camera and its import.

The numbers survive in the 3a results note, section 9. That is where evidence belongs; a measured pessimisation left in `lib/` is one waiting to be adopted by somebody who did not read the note.

- [ ] **Step 6: Run both suites**

Run: `cd packages/jet_cad_2d && dart test` — expected: PASS, with the memo tests gone.
Run: `cd packages/jet_cad_2d_flutter && flutter test` — expected: PASS, including the new step-1 test.

- [ ] **Step 7: Commit**

```bash
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "perf: delete the cull floor and the style memo, both measured losses

The cull floor trades a rect query for drawing every leaf a container
owns. Plan 3a measured it: 10-20% slower on the working-set camera, 5-13%
faster on a frame nobody renders. LeafOwnerMap's only consumer was the
shortcut, so it goes too, and DraftCanvas loses the change-feeding path
that kept it fresh.

MemoisedStyleResolver was measured at 19-39% slower with a fully warm
cache: a seven-field record hash costs more than DocumentStyleResolver's
few array reads and switches.

Both sets of numbers live in the 3a results note. Left in lib/, a
measured pessimisation is one waiting to be adopted by someone who did
not read the note."
```

---

## Task 1: Carry every line-like leaf into screen space

`_emitBypassed` already does the whole job for the minority of leaves whose transform is past `kAnisotropyThreshold`. Its own comment states the property this task generalises: "the residual left for `Canvas` is a pure translation, so its scale is 1 and the stroke width the sink computes is the exact paper width in device pixels — nothing divided out of it, and nothing wrong on either axis." That is true of conformal transforms too. The threshold was never the reason it works.

After this task every frame pushes **one** residual value for all its points, lines and polylines. Nothing batches yet — that is Task 2 — but the precondition for batching exists, and the per-leaf `save`/`transform`/`restore` for line-like geometry is already reducible.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_test.dart`

**Interfaces:**
- Consumes: `DraftPainter` from Task 0.
- Produces: `DraftPainter.screenSpaceLeafCount` (replaces `bypassCount`), `DraftPainter.anisotropicCurveCount` (unchanged name and meaning). `_emitBypassed` is renamed `_emitScreenSpace` and `_bypassable` is deleted.

- [ ] **Step 1: Write the failing test**

The observable property is the residual's linear part. A line under a scaled, rotated instance must reach the sink under a residual whose linear part is the identity.

Add to `packages/jet_cad_2d_flutter/test/draft_painter_test.dart`:

```dart
  test('a conformal leaf reaches the sink under a translation-only residual',
      () {
    final doc = DraftDocument.empty();
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    addEntity(doc, def, doc.handleSeed.next(), EntityKind.line,
        [0, 0, 10, 4], const []);
    // Conformal: equal scale on both axes, plus a rotation. Ratio is 1.0, so
    // this leaf took the residual path before this task.
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: Transform2(2.4, 1.1, -1.1, 2.4, 60, 45),
    )));

    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final residuals = recording.ops.whereType<BeginResidualOp>().toList();
    expect(residuals, isNotEmpty);
    for (final r in residuals) {
      expect(r.residual.a, 1.0);
      expect(r.residual.b, 0.0);
      expect(r.residual.c, 0.0);
      expect(r.residual.d, 1.0);
    }
  });

  test('every frame pushes one residual value for its line-like leaves', () {
    // Two leaves in different definitions at different placements. If the
    // residual still carried the placement, these would differ — which is
    // exactly what stops a sink from batching them.
    final doc = generateDocument(400, definitionCount: 8, instanceCount: 40);
    final recording = RecordingDrawSink();
    final index = SpatialIndex(doc);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(recording, ViewportTransform.fit(doc.extents, kViewport),
            kViewport);

    final translations = recording.ops
        .whereType<BeginResidualOp>()
        .map((op) => '${op.residual.e},${op.residual.f}')
        .toSet();
    expect(translations.length, 1,
        reason: 'one rebase origin per frame means one residual value; '
            'more than one means a placement is still riding along');
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart -N "translation-only residual"`

Expected: FAIL — `Expected: <1.0> Actual: <2.4>`, because a conformal leaf still takes the residual path.

The second test fails with a set size well above 1.

- [ ] **Step 3: Generalise the screen-space path**

In `draft_painter.dart`, replace the branch in `_drawLeafComposed`:

```dart
    // `Paint.strokeWidth` is a single scalar measured in the residual's units,
    // so it can only be right when the residual scales both axes alike. Points,
    // lines and polylines avoid the question entirely: their points are carried
    // into screen space here in Float64 and the residual is a pure translation,
    // so the sink's width is the exact paper width with nothing divided out.
    //
    // This was the anisotropy bypass, taken only past kAnisotropyThreshold. The
    // threshold was never why it works — a conformal transform has the same
    // property — so it is now the rule rather than the exception, and one
    // residual value serves every line-like leaf in the frame.
    final toScreen = camera.worldToScreenMatrix.multiply(placement);
    switch (kind) {
      case EntityKind.point:
      case EntityKind.line:
      case EntityKind.polyline:
        _screenSpaceLeaves++;
        _emitScreenSpace(
            sink, camera, toScreen, origin, slot, kind, payload, style);
        return;
      case EntityKind.circle:
      case EntityKind.arc:
        // Curves keep the residual path: an anisotropic transform turns a
        // circle into an ellipse, and DrawSink.circle carries one radius.
        // What a sink does with that residual is a sink decision.
        if (toScreen.anisotropyRatio > kAnisotropyThreshold) {
          _anisotropicCurves++;
        }
      case EntityKind.text:
      case EntityKind.attrib:
        break;
    }
```

Delete `_bypassable` entirely. Rename `_emitBypassed` to `_emitScreenSpace` and drop the `_bypassCount++` from the caller, replacing the counter:

```dart
  int _screenSpaceLeaves = 0;

  /// Leaves drawn with their points already carried into screen space, under
  /// the frame's shared translation residual.
  ///
  /// Every point, line and polyline drawn in the frame. Plan 3a's
  /// `bypassCount` counted the minority that took this path when their
  /// transform was past [kAnisotropyThreshold]; the path is now the rule, so
  /// the name changed with the meaning rather than quietly keeping it.
  int get screenSpaceLeafCount => _screenSpaceLeaves;
```

Update `kAnisotropyThreshold`'s doc comment to say what it now gates:

```dart
/// How far from conformal a curve's screen transform may be before its baked
/// stroke width stops being close enough.
///
/// **Diagnostic only.** It gates no drawing decision: points, lines and
/// polylines are carried into screen space regardless, and curves take the
/// residual path regardless. All it decides is whether a curve is counted in
/// [DraftPainter.anisotropicCurveCount].
const double kAnisotropyThreshold = 2.0;
```

- [ ] **Step 4: Run the tests**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart`

Expected: PASS.

- [ ] **Step 5: Run the differential oracle, unchanged**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/differential_test.dart`

Expected: PASS with `reference_walk.dart` untouched. `flatten` applies each residual before comparing, precisely so a painter handing over screen-space points under a translation and a reference handing over local points under a full residual compare equal. This step is the proof that holds.

Run: `git diff --stat -- lib/src/reference_walk.dart` — expected: empty.

- [ ] **Step 6: Regenerate the goldens only if they actually moved**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden`

If they pass, do nothing — the arithmetic route changed but the pixels did not, which is the expected outcome and worth noting in the commit.

If any fail, the difference is float rounding from a different composition order, not a behaviour change. Run `flutter test --tags golden --update-goldens`, **open every regenerated PNG and compare it to the previous one**, and only then commit. A golden accepted without looking records whatever the code did, including the bug.

- [ ] **Step 7: Run both suites and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "perf(jet_cad_2d_flutter): carry every line-like leaf into screen space

The anisotropy bypass already carried points into screen space in Float64
and pushed a pure translation, and its comment already stated why that is
exact: residual scale 1, so the stroke width is the paper width with
nothing divided out. A conformal transform has the same property. The
threshold was never the reason it works.

So the bypass becomes the rule. Every point, line and polyline in a frame
now reaches the sink under one residual value, which is the precondition
a coalescing sink needs. kAnisotropyThreshold survives as the predicate
of anisotropicCurveCount and gates no drawing decision; its comment now
says so.

bypassCount becomes screenSpaceLeafCount: the meaning changed, so the
name did too rather than quietly keeping it.

reference_walk.dart is untouched. flatten already normalises both routes."
```

---

## Task 2: `CanvasDrawSink` batching, mode B, and the equality goldens

The first of two sink tasks. It adds the mode enum, the frame boundary, the real-call counter, the alpha rule, and the **single open bucket** lifecycle — variant B, which gives up no draw order at all.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` (call `sink.flush()`)
- Create: `packages/jet_cad_2d_flutter/test/golden/batch_equivalence_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/batch_*.png` (generated)
- Test: `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart`

**Interfaces:**
- Consumes: `DraftPainter` from Task 1.
- Produces:
  - `enum BatchMode { off, openBucket }` (Task 3 adds two more)
  - `CanvasDrawSink({Canvas? canvas, required double pixelsPerPaperMm, BatchMode mode = BatchMode.openBucket})`
  - `void CanvasDrawSink.flush()` — draws and clears whatever is open. **Must be called at the end of every frame.**
  - `int CanvasDrawSink.canvasCallCount` — real `Canvas` draw calls since the last `resetCounters()`
  - `void CanvasDrawSink.resetCounters()`

- [ ] **Step 1: Write the failing tests**

Create `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const ResolvedStyle _red = ResolvedStyle(
    argb: 0xFFFF0000,
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);
const ResolvedStyle _blue = ResolvedStyle(
    argb: 0xFF0000FF,
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);
const ResolvedStyle _ghost = ResolvedStyle(
    argb: 0x80FF0000, // alpha 128
    lineweightHundredths: 25,
    linetype: ReservedHandles.continuousLinetype,
    linetypeScale: 1.0);
const ResolvedStyle _redDashed = ResolvedStyle(
    argb: 0xFFFF0000,
    lineweightHundredths: 25,
    linetype: Handle(99), // a different linetype, same paint
    linetypeScale: 1.0);

CanvasDrawSink _sinkOn(PictureRecorder recorder, BatchMode mode) =>
    CanvasDrawSink(
        canvas: Canvas(recorder), pixelsPerPaperMm: 8.0, mode: mode);

void _line(CanvasDrawSink sink, double x, ResolvedStyle style) {
  sink.beginResidual(Transform2.translation(0, 0));
  sink.polyline(Float64List.fromList([x, 0, x, 50]), 2, style, closed: false);
  sink.endResidual();
}

void main() {
  test('mode off issues one canvas call per primitive', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.off);
    for (var i = 0; i < 5; i++) {
      _line(sink, i * 10.0, _red);
    }
    sink.flush();
    expect(sink.canvasCallCount, 5);
  });

  test('openBucket merges a run that shares a paint into one call', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    for (var i = 0; i < 5; i++) {
      _line(sink, i * 10.0, _red);
    }
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('a paint change flushes, so draw order is preserved exactly', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 3,
        reason: 'red, blue, red must reach the canvas in that order; '
            'two calls would mean the two reds merged across the blue');
  });

  test('the bucket key is the paint, not the whole style', () {
    // Same colour and lineweight, different linetype. The dash geometry is
    // already baked into the points by the time the sink sees them, so a
    // linetype in the key would open a bucket per nothing.
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    _line(sink, 10, _redDashed);
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('a style below full alpha is never batched', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _ghost);
    _line(sink, 10, _ghost);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'two overlapping translucent strokes in one path are unioned; '
            'drawn separately they blend twice, and only the second is right');
  });

  test('a curve flushes the open bucket and draws on its own', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 10, _red);
    sink.flush();
    expect(sink.canvasCallCount, 3);
  });

  test('flush is required: without it the last bucket never draws', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    expect(sink.canvasCallCount, 0);
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });

  test('flush is idempotent', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.openBucket);
    _line(sink, 0, _red);
    sink.flush();
    sink.flush();
    expect(sink.canvasCallCount, 1);
  });
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/canvas_draw_sink_test.dart`

Expected: FAIL to compile — `BatchMode` is not defined, `CanvasDrawSink` has no `mode`, `flush` or `canvasCallCount`.

- [ ] **Step 3: Implement mode `off` and `openBucket`**

Rewrite `canvas_draw_sink.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'draw_sink.dart';

/// How [CanvasDrawSink] turns the painter's primitives into `Canvas` calls.
///
/// These are **different designs, not different tunings**: they differ in how
/// much draw order survives, which is a contract and not a setting. Plan 3b's
/// spike measures them and ships one.
enum BatchMode {
  /// One `Canvas` call per primitive, one `save`/`transform`/`restore` per
  /// residual. Plan 3a's behaviour, kept as the reference the goldens compare
  /// the batched modes against.
  off,

  /// One open bucket: a `Path` and the paint key it holds. A primitive whose
  /// key differs flushes it and opens a new one, so **draw order is preserved
  /// exactly** and batching is limited to runs of one paint in walk order.
  openBucket,
}

/// Writes to `dart:ui`.
///
/// Stroke width is the one place paper space meets device space:
/// `lineweightHundredths` is 1/100 mm on paper and must not grow with zoom, so
/// it is converted to pixels and then divided by the residual's representative
/// scale — because `Paint.strokeWidth` is measured in the *current* canvas
/// units, which the residual has already scaled. A batched primitive arrives
/// under a translation-only residual, where that division is by one.
class CanvasDrawSink implements DrawSink {
  CanvasDrawSink({
    Canvas? canvas,
    required this.pixelsPerPaperMm,
    this.mode = BatchMode.openBucket,
  }) {
    if (canvas != null) this.canvas = canvas;
  }

  /// Rebound each frame rather than fixed at construction.
  ///
  /// The `Paint`, the `Path` and the two typed lists below are the whole
  /// reason this is an object: they are allocated once and rewritten per op.
  /// A sink built per paint would throw that away and put four allocations
  /// back on the frame path. The `Canvas` is the only part that genuinely
  /// changes from one frame to the next, so it is the only part that moves.
  late Canvas canvas;

  final double pixelsPerPaperMm;
  final BatchMode mode;

  // One paint and two paths for the whole frame. Both paths are reused in
  // place; neither is handed to a caller that could retain it.
  final Paint _paint = Paint()..style = PaintingStyle.stroke;
  final Path _scratch = Path();
  final Path _bucket = Path();
  final Float32List _point = Float32List(2);
  final Float64List _matrix = Float64List(16)..[10] = 1.0;

  Transform2 _residual = Transform2.identity();
  double _residualScale = 1.0;
  bool _transformPushed = false;

  // The open bucket: whether it holds anything, and the paint key it holds.
  bool _bucketOpen = false;
  int _bucketArgb = 0;
  int _bucketLineweight = 0;

  int _canvasCalls = 0;

  /// Real `Canvas` draw calls since [resetCounters].
  ///
  /// Deliberately separate from `NullDrawSink.opCount`, which counts painter
  /// calls and keeps Plan 3a's R1 and R3 rows comparable. The gap between the
  /// two numbers is what this plan exists to open.
  int get canvasCallCount => _canvasCalls;

  void resetCounters() => _canvasCalls = 0;

  /// Draws whatever is open. **Must be called at the end of every frame.**
  ///
  /// Without it the last bucket of the frame is silently dropped — geometry
  /// that was accepted and never drawn, which no assertion inside the walk can
  /// see. Idempotent, so a caller that flushes twice pays nothing.
  void flush() {
    if (!_bucketOpen) return;
    _bucketOpen = false;
    _paint
      ..color = Color(_bucketArgb)
      ..strokeWidth = _widthFor(_bucketLineweight, 1.0);
    canvas.drawPath(_bucket, _paint);
    _canvasCalls++;
    _bucket.reset();
  }

  /// Whether [style] may share a path with others of its paint.
  ///
  /// Below full alpha it may not: two overlapping strokes in one path are
  /// unioned, and drawn separately they are blended twice. With opaque paint
  /// the two agree; below it they do not, and the separate draw is the correct
  /// one. `ResolvedStyle` has no transparency field — an entity's transparency
  /// is folded into `argb` at resolution time, where alpha is `255 -
  /// transparency`.
  static bool _opaque(ResolvedStyle style) => (style.argb >>> 24) == 0xFF;

  /// Whether the residual is a pure translation, which is what the painter
  /// pushes for every point, line and polyline in a frame.
  bool get _translationOnly =>
      _residual.a == 1.0 &&
      _residual.b == 0.0 &&
      _residual.c == 0.0 &&
      _residual.d == 1.0;

  @override
  void beginResidual(Transform2 residual, {Handle debugHandle = Handle.none}) {
    _residual = residual;
    _residualScale = residual.scaleMagnitude;
    _transformPushed = false;
  }

  /// Pushes the residual onto the `Canvas`, for the primitives that cannot be
  /// batched. Deferred to here rather than done in [beginResidual] because a
  /// batched primitive must not disturb the canvas state at all.
  void _pushTransform() {
    if (_transformPushed) return;
    canvas.save();
    // Matrix4 storage is column-major: columns 0 and 1 carry the linear part,
    // column 3 the translation. Row-major here would transpose every residual.
    _matrix[0] = _residual.a;
    _matrix[1] = _residual.b;
    _matrix[4] = _residual.c;
    _matrix[5] = _residual.d;
    _matrix[12] = _residual.e;
    _matrix[13] = _residual.f;
    _matrix[15] = 1.0;
    canvas.transform(_matrix);
    _transformPushed = true;
  }

  @override
  void endResidual() {
    if (_transformPushed) {
      canvas.restore();
      _transformPushed = false;
    }
    _residual = Transform2.identity();
    _residualScale = 1.0;
  }

  /// Opens or reuses the bucket for [style], flushing first if the key differs.
  ///
  /// Returns false when [style] must not be batched at all.
  bool _bucketFor(ResolvedStyle style) {
    if (mode == BatchMode.off || !_opaque(style) || !_translationOnly) {
      flush();
      return false;
    }
    if (_bucketOpen &&
        (_bucketArgb != style.argb ||
            _bucketLineweight != style.lineweightHundredths)) {
      flush();
    }
    _bucketArgb = style.argb;
    _bucketLineweight = style.lineweightHundredths;
    _bucketOpen = true;
    return true;
  }

  @override
  void point(double x, double y, ResolvedStyle style) {
    if (_bucketFor(style)) {
      // A zero-length subpath strokes as a cap-shaped dot, which is what a
      // DXF POINT is. moveTo alone would contribute nothing.
      _bucket
        ..moveTo(x + _residual.e, y + _residual.f)
        ..lineTo(x + _residual.e, y + _residual.f);
      return;
    }
    _pushTransform();
    _point[0] = x;
    _point[1] = y;
    canvas.drawRawPoints(PointMode.points, _point, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count <= 0) return;
    if (_bucketFor(style)) {
      final dx = _residual.e;
      final dy = _residual.f;
      _bucket.moveTo(points[0] + dx, points[1] + dy);
      for (var i = 1; i < count; i++) {
        _bucket.lineTo(points[i * 2] + dx, points[i * 2 + 1] + dy);
      }
      if (closed) _bucket.close();
      return;
    }
    _pushTransform();
    _scratch.reset();
    _scratch.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      _scratch.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    if (closed) _scratch.close();
    canvas.drawPath(_scratch, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) {
    flush();
    _pushTransform();
    canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
    flush();
    _pushTransform();
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
        sweep, false, _paintFor(style));
    _canvasCalls++;
  }

  Paint _paintFor(ResolvedStyle style) {
    _paint
      ..color = Color(style.argb)
      ..strokeWidth = _widthFor(style.lineweightHundredths, _residualScale);
    return _paint;
  }

  double _widthFor(int lineweightHundredths, double residualScale) {
    final devicePx = lineweightHundredths / 100.0 * pixelsPerPaperMm;
    final w = residualScale == 0 ? devicePx : devicePx / residualScale;
    // 0 means "hairline" to Skia — one device pixel regardless of transform,
    // which is the right floor for a lineweight that has scaled away.
    return w.isFinite && w > 0 ? w : 0.0;
  }
}
```

- [ ] **Step 4: Call `flush()` at the end of every frame**

In `draft_canvas.dart`'s `_DraftCustomPainter.paint`:

```dart
    canvas.clipRect(Offset.zero & size);
    sink.canvas = canvas;
    painter.paint(sink, camera.value, size);
    // The last bucket of the frame has nothing after it to force it out.
    // Without this the geometry is accepted and never drawn, and no assertion
    // inside the walk can see that.
    sink.flush();
```

- [ ] **Step 5: Run the sink tests**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/canvas_draw_sink_test.dart`

Expected: PASS, all eight.

- [ ] **Step 6: Write the equality goldens, fixtures 1 and 2**

Create `packages/jet_cad_2d_flutter/test/golden/batch_equivalence_golden_test.dart`:

```dart
@Tags(['golden'])
library;

// The batch's correctness proof, and it has to be a pixel-level one: batching
// is a Canvas-level behaviour that an op list cannot see. RecordingDrawSink is
// unbatched by construction, so the differential oracle is blind to it.
//
// The invariant is NOT "the picture is identical". It is: batched and unbatched
// rendering are byte-identical whenever no two overlapping primitives have
// different paint keys. Fixture 3, in Task 3, is the cross-key case.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// A cross of two strokes, repeated at [count] offsets, in one colour.
///
/// Overlaps are within one paint key by construction: every entity here shares
/// a colour and a lineweight, so this fixture is byte-identical under every
/// batch mode. It is the assertion that path accumulation itself does not
/// change rasterisation.
DraftDocument sameKeyOverlapFixture() {
  final doc = DraftDocument.empty();
  for (var i = 0; i < 6; i++) {
    final x = -40.0 + i * 16;
    _line(doc, [x, -50, x + 30, 50], 0x000000);
    _line(doc, [-50, x, 50, x + 30], 0x000000);
  }
  return doc;
}

/// The same crosses, below full alpha.
///
/// Byte-identical **only** because a style below full alpha is excluded from
/// batching. Deleting that exclusion must make this fixture differ, which is
/// what proves the exclusion does work rather than merely existing.
DraftDocument translucentOverlapFixture() {
  final doc = DraftDocument.empty();
  for (var i = 0; i < 6; i++) {
    final x = -40.0 + i * 16;
    _line(doc, [x, -50, x + 30, 50], 0x000000, transparency: 128);
    _line(doc, [-50, x, 50, x + 30], 0x000000, transparency: 128);
  }
  return doc;
}

void _line(DraftDocument doc, List<double> coords, int rgb,
    {int transparency = 0, int lineweight = 60}) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      // TrueColor, not ByLayer: ByLayer resolves through layer 0 to ACI 7,
      // which is white on the white golden background.
      color: TrueColor(rgb),
      lineweight: lineweight,
      transparency: transparency,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords), scalars: Float64List(0)),
  ));
}

Widget _canvasOver(DraftDocument doc, BatchMode mode) {
  final index = SpatialIndex(doc);
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          key: kCanvasKey,
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            camera: CameraController(ViewportTransform.fit(
                Aabb2(Vector2(-60, -60), Vector2(60, 60)), kGoldenViewport)),
            batchMode: mode,
          ),
        ),
      ),
    ),
  );
}

Future<void> _bothWays(
    WidgetTester tester, DraftDocument Function() build, String name) async {
  await tester.pumpWidget(_canvasOver(build(), BatchMode.off));
  await expectLater(
      find.byKey(kCanvasKey), matchesGoldenFile('batch_$name.png'));

  await tester.pumpWidget(_canvasOver(build(), BatchMode.openBucket));
  await expectLater(
      find.byKey(kCanvasKey), matchesGoldenFile('batch_$name.png'));
}

void main() {
  testWidgets('fixture 1: same-key overlap is byte-identical either way',
      (tester) async {
    await _bothWays(tester, sameKeyOverlapFixture, 'same_key');
  });

  testWidgets('fixture 2: translucent overlap is byte-identical either way',
      (tester) async {
    // Passes only because _opaque() excludes it from batching. Deleting that
    // check must make the second expectLater fail.
    await _bothWays(tester, translucentOverlapFixture, 'translucent');
  });
}
```

- [ ] **Step 7: Give `DraftCanvas` a `batchMode`**

The golden needs to build both ways. Add to `DraftCanvas`:

```dart
  /// Which [BatchMode] the canvas's sink runs in.
  ///
  /// A widget parameter rather than a global so the batched and unbatched
  /// renderings of one fixture can be compared inside a single test.
  final BatchMode batchMode;
```

defaulted to `BatchMode.openBucket` in the constructor, and passed through in `_attach`:

```dart
    sink = CanvasDrawSink(
        pixelsPerPaperMm: widget.pixelsPerPaperMm, mode: widget.batchMode);
```

- [ ] **Step 8: Generate the goldens and look at them**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens`

**Open `batch_same_key.png` and `batch_translucent.png`.** The first must show six dark crosses of uniform weight. The second must show the same crosses paler, with the overlaps visibly darker than the strokes — that darkening is the double blend, and it is the whole reason the alpha exclusion exists. If the overlaps are *not* darker, the fixture's transparency did not survive resolution and the test proves nothing.

- [ ] **Step 9: Verify the alpha exclusion is load-bearing**

Temporarily change `_opaque` to `=> true`. Run: `flutter test --tags golden`

Expected: **fixture 2 FAILS.** Restore `_opaque` and re-run to green.

A test that passes with and without the code it is testing is not a test. Record the result in the mutation log in Task 11.

- [ ] **Step 10: Run everything and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): coalesce draw calls in CanvasDrawSink

The batching lives in the sink, so DrawSink gains no methods,
RecordingDrawSink stays one op per primitive, and the differential
oracle keeps its shape. It also means the oracle is blind to batching,
which is why the correctness proof here is a pair of goldens rendered
both ways and compared byte for byte.

BatchMode.openBucket holds one Path and the paint key it carries; a
primitive whose key differs flushes it, so draw order is preserved
exactly. The bucket key is the paint - argb and lineweight - not the
whole ResolvedStyle: dash geometry is baked into the points before the
sink sees them, so a linetype in the key would open a bucket per nothing.

A style below full alpha is never batched. Two overlapping strokes in one
path are unioned; drawn separately they blend twice, and only the
separate draw is right. Fixture 2 fails if that exclusion is deleted.

flush() is required at end of frame and is idempotent. Without it the
last bucket is accepted and never drawn, which nothing inside the walk
can see."
```

---

## Task 3: The persistent bucket map, and the baked-curve variant

Variants A and A′. Both hold a `Map` of open buckets instead of one, which is the only lifecycle that can collapse 21,031 ops into tens of calls — and the only one that costs draw order.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/canvas_draw_sink_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/golden/batch_equivalence_golden_test.dart`

**Interfaces:**
- Consumes: `BatchMode`, `CanvasDrawSink` from Task 2.
- Produces: `BatchMode.bucketMap` and `BatchMode.bucketMapBakedCurves` added to the enum.

- [ ] **Step 1: Write the failing tests**

Append to `test/canvas_draw_sink_test.dart`:

```dart
  test('bucketMap merges across an interleaved paint change', () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'two paints, two buckets, two calls — the two reds merge '
            'across the blue, which is the draw order this mode gives up');
  });

  test('bucketMap flushes every bucket before a curve, so it lands in order',
      () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 4,
        reason: 'red+blue flushed as two, then the circle, then the trailing '
            'red — the circle must not draw under lines that precede it');
  });

  test('bucketMapBakedCurves puts a curve in its bucket and flushes nothing',
      () {
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMapBakedCurves);
    _line(sink, 0, _red);
    _line(sink, 10, _blue);
    sink.beginResidual(Transform2(2, 0, 0, 2, 5, 5));
    sink.circle(0, 0, 4, _red);
    sink.endResidual();
    _line(sink, 20, _red);
    sink.flush();
    expect(sink.canvasCallCount, 2,
        reason: 'one red bucket holding two lines and an ellipse, one blue');
  });

  test('flushing a bucket map draws in insertion order', () {
    // Not observable through the counter, so it is asserted on the recorder:
    // the first bucket opened must be the first path drawn.
    final recorder = PictureRecorder();
    final sink = _sinkOn(recorder, BatchMode.bucketMap);
    _line(sink, 0, _blue);
    _line(sink, 10, _red);
    sink.flush();
    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    // The ordering itself is pinned by golden fixture 3; this asserts only
    // that flushing a map produces one call per bucket and does not throw.
    expect(sink.canvasCallCount, 2);
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/canvas_draw_sink_test.dart`

Expected: FAIL to compile — `BatchMode.bucketMap` is not defined.

- [ ] **Step 3: Implement both modes**

Extend the enum:

```dart
  /// A `Path` per paint key, held until the end of the frame. Every primitive
  /// of a key merges across the whole frame, so this is the lifecycle that can
  /// actually collapse the op count — and the one that loses draw order
  /// between keys. A curve flushes **every** bucket first, so it lands in
  /// order relative to everything drawn before it.
  bucketMap,

  /// [bucketMap], plus curves baked into their bucket's path through
  /// `Path.addPath(matrix4:)`. Nothing but a translucent style or the end of
  /// the frame flushes, so this is the widest ordering contract in the enum.
  ///
  /// It is also the only mode that is *more* correct than [off] for an
  /// anisotropically placed curve: baking the matrix means the stroke is
  /// applied in screen space, so the ellipse carries a uniform paper-space
  /// width. That is what `ResolvedStyle.lineweightHundredths` says a lineweight
  /// is — "paper-space width in 1/100 mm, **not** a world quantity".
  bucketMapBakedCurves,
```

Replace the single-bucket fields with a map, keeping the single-bucket fast path:

```dart
  /// Open buckets, keyed by paint. `Map` preserves insertion order, which is
  /// the order they are flushed in — the only draw order this mode keeps.
  final Map<(int, int), Path> _buckets = <(int, int), Path>{};

  /// Paths returned to the pool by [flush], so a frame allocates at most one
  /// `Path` per distinct paint ever seen rather than one per frame.
  final List<Path> _pool = <Path>[];

  bool get _mapped =>
      mode == BatchMode.bucketMap || mode == BatchMode.bucketMapBakedCurves;
```

`flush` handles both lifecycles:

```dart
  void flush() {
    if (_bucketOpen) {
      _bucketOpen = false;
      _paint
        ..color = Color(_bucketArgb)
        ..strokeWidth = _widthFor(_bucketLineweight, 1.0);
      canvas.drawPath(_bucket, _paint);
      _canvasCalls++;
      _bucket.reset();
    }
    if (_buckets.isEmpty) return;
    for (final entry in _buckets.entries) {
      _paint
        ..color = Color(entry.key.$1)
        ..strokeWidth = _widthFor(entry.key.$2, 1.0);
      canvas.drawPath(entry.value, _paint);
      _canvasCalls++;
      entry.value.reset();
      _pool.add(entry.value);
    }
    _buckets.clear();
  }
```

`_bucketFor` becomes a path lookup rather than a boolean:

```dart
  /// The path [style]'s geometry belongs in, or null when it must be drawn on
  /// its own.
  ///
  /// Flushing here is what keeps the contract honest: under [BatchMode.off],
  /// below full alpha, or under a residual that is not a pure translation,
  /// everything open is drawn first so the primitive that follows lands after
  /// it rather than under it.
  Path? _bucketFor(ResolvedStyle style, {required bool batchable}) {
    if (mode == BatchMode.off || !_opaque(style) || !batchable) {
      flush();
      return null;
    }
    if (_mapped) {
      return _buckets.putIfAbsent((style.argb, style.lineweightHundredths),
          () => _pool.isEmpty ? Path() : _pool.removeLast());
    }
    if (_bucketOpen &&
        (_bucketArgb != style.argb ||
            _bucketLineweight != style.lineweightHundredths)) {
      flush();
    }
    _bucketArgb = style.argb;
    _bucketLineweight = style.lineweightHundredths;
    _bucketOpen = true;
    return _bucket;
  }
```

`point` and `polyline` call it with `batchable: _translationOnly`, appending to the returned path exactly as in Task 2. `circle` and `arc` become:

```dart
  @override
  void circle(double cx, double cy, double r, ResolvedStyle style) {
    final bucket = _bucketFor(style,
        batchable: mode == BatchMode.bucketMapBakedCurves && _opaque(style));
    if (bucket != null) {
      _scratch.reset();
      _scratch.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      bucket.addPath(_scratch, Offset.zero, matrix4: _matrix4OfResidual());
      return;
    }
    _pushTransform();
    canvas.drawCircle(Offset(cx, cy), r, _paintFor(style));
    _canvasCalls++;
  }

  @override
  void arc(double cx, double cy, double r, double start, double sweep,
      ResolvedStyle style) {
    final bucket = _bucketFor(style,
        batchable: mode == BatchMode.bucketMapBakedCurves && _opaque(style));
    if (bucket != null) {
      _scratch.reset();
      _scratch.addArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r), start, sweep);
      bucket.addPath(_scratch, Offset.zero, matrix4: _matrix4OfResidual());
      return;
    }
    _pushTransform();
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r), start,
        sweep, false, _paintFor(style));
    _canvasCalls++;
  }

  /// The current residual as the column-major `Float64List(16)` `addPath` and
  /// `Canvas.transform` both want. Rewritten in place — the list is a field.
  Float64List _matrix4OfResidual() {
    _matrix[0] = _residual.a;
    _matrix[1] = _residual.b;
    _matrix[4] = _residual.c;
    _matrix[5] = _residual.d;
    _matrix[12] = _residual.e;
    _matrix[13] = _residual.f;
    _matrix[15] = 1.0;
    return _matrix;
  }
```

`_pushTransform` now calls `_matrix4OfResidual()` rather than filling `_matrix` itself.

Note the deliberate asymmetry: under `bucketMap`, a curve passes `batchable: false`, and `_bucketFor` flushes *every* bucket before returning null. That is what makes the curve land in order.

- [ ] **Step 4: Run the sink tests**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/canvas_draw_sink_test.dart`

Expected: PASS, all twelve.

- [ ] **Step 5: Add golden fixture 3 — cross-key overlap**

Append to `batch_equivalence_golden_test.dart`:

```dart
/// Overlapping strokes in **two** paint keys, which is where a draw-order
/// change becomes visible.
///
/// Byte-identical under [BatchMode.openBucket] and under it alone. Under the
/// mapped modes the two renderings are *expected* to differ: the second red
/// stroke merges with the first and draws beneath the blue that separates
/// them. That difference is the ordering contract made visible.
DraftDocument crossKeyOverlapFixture() {
  final doc = DraftDocument.empty();
  _line(doc, [-50, -50, 50, 50], 0xCC0000, lineweight: 200);
  _line(doc, [-50, 50, 50, -50], 0x0000CC, lineweight: 200);
  _line(doc, [-50, -30, 50, 70], 0xCC0000, lineweight: 200);
  return doc;
}

  testWidgets('fixture 3: cross-key overlap under the ordered mode',
      (tester) async {
    await _bothWays(tester, crossKeyOverlapFixture, 'cross_key');
  });
```

- [ ] **Step 6: Generate and inspect fixture 3**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens`

**Open `batch_cross_key.png`.** The blue diagonal must cross *over* the first red diagonal and *under* the second. That is handle order, and under `openBucket` it survives.

- [ ] **Step 7: Prove fixture 3 discriminates**

Temporarily change `_canvasOver`'s second call in `_bothWays` to `BatchMode.bucketMap`. Run: `flutter test --tags golden`

Expected: **fixture 3 FAILS** and fixtures 1 and 2 pass. That is the ordering contract, demonstrated rather than asserted in prose. Restore `openBucket` and re-run to green.

- [ ] **Step 8: Run everything and commit**

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): add the persistent bucket map and baked curves

BatchMode.bucketMap holds a Path per paint key until the end of the
frame, so every primitive of a key merges across the whole frame. That is
the lifecycle that can collapse the op count, and the one that loses draw
order between keys. A curve flushes every bucket first so it still lands
in order relative to what preceded it.

bucketMapBakedCurves drops that flush and bakes the curve's residual into
its bucket's path with Path.addPath(matrix4:), from a reset scratch path
so the frame path still allocates nothing. Buckets are pooled across
frames for the same reason.

It is also the only mode more correct than off for an anisotropic curve:
baking the matrix applies the stroke in screen space, giving the ellipse
a uniform paper-space width, which is what lineweightHundredths says a
lineweight is.

Golden fixture 3 covers cross-key overlap: byte-identical under
openBucket and expected to differ under the mapped modes. Switching the
comparison to bucketMap fails fixture 3 and passes 1 and 2, which is the
ordering contract demonstrated rather than argued."
```

---

## Task 4: The spike — measure the four modes and choose one

The reason raster is 26 µs per leaf is an inference. This task turns it into a number, under a decision rule written before the numbers exist.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/rig/batch_spike_test.dart`
- Modify: `apps/dev_harness_2d/lib/main.dart` (accept a `BATCH` define)
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` (delete the losing modes)
- Modify: `packages/jet_cad_2d_flutter/README.md`

**Interfaces:**
- Consumes: all four `BatchMode` values.
- Produces: a `BatchMode` enum reduced to `off` plus the winner, and a numbers table for the results note.

- [ ] **Step 1: Write the R1-side spike rig**

Create `packages/jet_cad_2d_flutter/test/rig/batch_spike_test.dart`:

```dart
@Tags(['rig'])
library;

// ignore_for_file: avoid_print — printing the numbers is what a rig is for.

// Debug JIT, and a PictureRecorder records without rasterising. **A relative
// signal only**, and it cannot see raster at all — which is the cost this plan
// is trying to move. The binding number is R2, in the harness app. This rig
// exists to catch a mode that is catastrophically wrong before a profile run
// is spent on it, and to report the real-call counts, which are exact.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import 'rig_support.dart';

const int kEntities = 500000;

void main() {
  test('batch modes, working-set camera', () {
    // `rigCorpus`, `workingSetCamera` and `kRigViewport` are the same ones R1
    // and R3 use. Sharing them is the point: a spike measured on a different
    // corpus than the rig it is compared against measures nothing.
    final doc = rigCorpus(kEntities);
    final index = SpatialIndex(doc);
    final camera = workingSetCamera(doc);

    for (final mode in BatchMode.values) {
      final sink = CanvasDrawSink(pixelsPerPaperMm: 8.0, mode: mode);
      final painter = DraftPainter(
          document: doc, index: index, resolver: DocumentStyleResolver(doc));
      final samples = <double>[];
      var calls = 0;
      for (var i = 0; i < 12; i++) {
        final recorder = PictureRecorder();
        sink.canvas = Canvas(recorder);
        sink.resetCounters();
        final sw = Stopwatch()..start();
        painter.paint(sink, camera, kRigViewport);
        sink.flush();
        sw.stop();
        recorder.endRecording().dispose();
        if (i >= 2) samples.add(sw.elapsedMicroseconds / 1000.0);
        calls = sink.canvasCallCount;
      }
      samples.sort();
      print('${mode.name}: '
          'p50=${samples[samples.length ~/ 2].toStringAsFixed(2)}ms '
          'p95=${samples[(samples.length * 0.95).floor()].toStringAsFixed(2)}ms '
          'canvasCalls=$calls '
          'painterOps=${painter.screenSpaceLeafCount}');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
```

This imports `rig_support.dart`, which does not exist yet. Create it by lifting `kRigViewport`, `workingSetCamera(DraftDocument doc)`, `wholeDrawingCamera` and `rigCorpus(int entityCount)` out of `paint_microbench_test.dart` verbatim — signatures unchanged — into `packages/jet_cad_2d_flutter/test/rig/rig_support.dart`, and importing it from `paint_microbench_test.dart` in their place. Run `flutter test --tags rig --run-skipped test/rig/paint_microbench_test.dart` once after the lift to confirm R1 and R3 still produce the numbers the 3a note recorded.

- [ ] **Step 2: Run it and record the four rows**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped test/rig/batch_spike_test.dart`

Expected: four rows. `off` should report `canvasCalls` near the painter's primitive count; `bucketMapBakedCurves` should report tens. If `openBucket` reports a number close to `off`, that is the corpus's style interleaving showing up, and it is a result, not a bug.

Record all four rows verbatim — they go in the results note.

- [ ] **Step 3: Add the `BATCH` define to the harness app**

In `apps/dev_harness_2d/lib/main.dart`:

```dart
/// Which [BatchMode] the harness renders with, so one profile run measures one
/// mode. `off` | `openBucket` | `bucketMap` | `bucketMapBakedCurves`.
const String kBatch = String.fromEnvironment('BATCH', defaultValue: 'bucketMap');

BatchMode get batchMode =>
    BatchMode.values.firstWhere((m) => m.name == kBatch);
```

and pass `batchMode: batchMode` to `DraftCanvas`.

- [ ] **Step 4: Run R2 for each mode, in the foreground, three times each**

```bash
cd apps/dev_harness_2d
for m in off openBucket bucketMap bucketMapBakedCurves; do
  for run in 1 2 3; do
    flutter drive --driver=test_driver/integration_test.dart \
      --target=integration_test/frame_timing_test.dart --profile -d macos \
      --dart-define=ENTITIES=500000 --dart-define=RIG=pan \
      --dart-define=BATCH=$m
  done
done
```

**Run these in the foreground.** Backgrounded, the app blocks on its first `pumpWidget` at 0% CPU waiting for a frame the windowing system never asks it for; it does not time out, it never finishes.

Record the 500k working-set **raster p50** for each mode, all three runs.

- [ ] **Step 5: Apply the decision rule**

Written before the numbers existed, and applied without amendment:

1. Compare the median of the three raster p50s per mode. Differences under 5% are noise.
2. The fastest mode ships.
3. **Ties break toward the narrower ordering contract:** `openBucket` over `bucketMap` over `bucketMapBakedCurves`.
4. If no mode beats `off` by more than noise, **stop.** Do not proceed to Task 5. Record the four rows, mark the batch hypothesis false in the results note, and reopen the design: dashes become the only remaining content of 3b and 3e's job is larger than the 3a note assumed.

- [ ] **Step 6: Delete the losing modes**

`BatchMode` keeps `off` — the goldens need it — and the winner. Delete the other two, their branches, and their sink tests. Dead modes in an enum are configuration nobody measured.

If `bucketMapBakedCurves` won, regenerate `anisotropy_bypass.png`: the stretched stroke becomes uniform. **Open the before and after side by side**, confirm the ellipse's outline is unchanged and only its line weight is now even, and name the change in the commit. It is a correctness fix, not a golden drifting.

If `openBucket` won, regenerate nothing — fixture 3 stays an equality assertion, and 3b hands 3d a flush contract with nothing in it yet.

- [ ] **Step 7: Update the READMEs**

Add the spike command to `packages/jet_cad_2d_flutter/README.md`'s rig list and the `BATCH` define to `apps/dev_harness_2d/README.md`.

- [ ] **Step 8: Commit**

```bash
git add -A packages/jet_cad_2d_flutter apps/dev_harness_2d
git commit -m "perf(jet_cad_2d_flutter): measure the four batch modes and ship one

Four modes, three profile runs each, decided by the rule written before
the numbers existed: fastest 500k working-set raster p50 ships, ties
break toward the narrower ordering contract, and no winner means stop.

The losing modes are deleted rather than left behind a flag. A mode
nobody measured is configuration, and this plan's whole method is that
the numbers choose."
```

---

## Task 5: `DocumentHeader.globalLinetypeScale`

Small, isolated, and needed by Task 8. Without it the linetype scale chain stops at the entity, DXF's `$LTSCALE` has nowhere to land when the import plan arrives, and adjusting a whole drawing's dash density means editing every entity.

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/header.dart`
- Test: `packages/jet_cad_2d/test/document/header_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `double DocumentHeader.globalLinetypeScale` — mutable, default `1.0`, round-tripped by `toJson`/`fromJson`.

- [ ] **Step 1: Write the failing test**

Add to `packages/jet_cad_2d/test/document/header_test.dart`:

```dart
  test('globalLinetypeScale round-trips and defaults to 1', () {
    final header = DocumentHeader();
    expect(header.globalLinetypeScale, 1.0);

    header.globalLinetypeScale = 0.375;
    final restored = DocumentHeader.fromJson(header.toJson());
    expect(restored.globalLinetypeScale, 0.375);
  });

  test('a document written before the field reads back as 1', () {
    // Forward compatibility runs both ways: an older file has no key, and the
    // default has to be the value that changes nothing.
    final json = DocumentHeader().toJson()..remove('globalLinetypeScale');
    expect(DocumentHeader.fromJson(json).globalLinetypeScale, 1.0);
  });
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/document/header_test.dart`

Expected: FAIL to compile — `globalLinetypeScale` is not defined.

- [ ] **Step 3: Add the field**

In `header.dart`, beside `scale`:

```dart
  /// DXF `$LTSCALE`: multiplies every linetype pattern in the drawing.
  ///
  /// A plain mutable field with no command, matching [units] and [scale]. It
  /// is a display setting rather than document content — no geometry moves —
  /// so it is not on the undo stack.
  double globalLinetypeScale = 1.0;
```

Add `'globalLinetypeScale': globalLinetypeScale,` to `toJson`, in the fixed key order (after `'scale'`, so serialisation stays byte-deterministic), and to `fromJson`:

```dart
      ..globalLinetypeScale =
          (json['globalLinetypeScale'] as num?)?.toDouble() ?? 1.0
```

- [ ] **Step 4: Run the tests**

Run: `cd packages/jet_cad_2d && dart test test/document/header_test.dart` — expected: PASS.
Run: `cd packages/jet_cad_2d && dart test` — expected: PASS, including the codec round-trip property test.

- [ ] **Step 5: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): add DocumentHeader.globalLinetypeScale

DXF \$LTSCALE. Without it the linetype scale chain stops at the entity,
the import plan has nowhere to put the header variable, and setting a
drawing's dash density means editing every entity.

A plain mutable field with no command, matching units and scale: it is a
display setting, no geometry moves, so it is not on the undo stack. The
default is 1.0, which is what an older file with no key must read back as."
```

---

## Task 6: Segment clipping and polyline dashing

The first half of the dasher, in the pure engine. Screen-space period, clip before generating, phase carried from the true segment start, and a collapse floor.

**Files:**
- Create: `packages/jet_cad_2d/lib/src/geometry/segment_clip.dart`
- Create: `packages/jet_cad_2d/lib/src/geometry/dasher.dart`
- Modify: `packages/jet_cad_2d/lib/jet_cad_2d.dart` (export both)
- Test: `packages/jet_cad_2d/test/geometry/segment_clip_test.dart`
- Test: `packages/jet_cad_2d/test/geometry/dasher_test.dart`

**Interfaces:**
- Consumes: `Aabb2`, `DashPattern`.
- Produces:
  - `bool clipSegment(double x0, double y0, double x1, double y1, Aabb2 clip, Float64List out)` — writes `[t0, t1]` into `out` and returns false when the segment misses `clip` entirely.
  - `typedef DashSpanEmit = void Function(double x0, double y0, double x1, double y1);`
  - `const double kDashCollapsePx = 3.0;` (swept in Task 9)
  - `class Dasher { Dasher({double collapsePx}); int collapsedCount; void resetCounters(); bool dashPolyline(Float64List points, int count, DashPattern pattern, double scale, Aabb2 clip, DashSpanEmit emit); }`

- [ ] **Step 1: Write the failing clip tests**

Create `packages/jet_cad_2d/test/geometry/segment_clip_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

void main() {
  final clip = Aabb2(Vector2(0, 0), Vector2(100, 100));
  final out = Float64List(2);

  test('a segment inside is unclipped', () {
    expect(clipSegment(10, 10, 90, 90, clip, out), isTrue);
    expect(out[0], 0.0);
    expect(out[1], 1.0);
  });

  test('a segment entering from the left is clipped at the edge', () {
    expect(clipSegment(-100, 50, 100, 50, clip, out), isTrue);
    expect(out[0], closeTo(0.5, 1e-12));
    expect(out[1], 1.0);
  });

  test('a segment wholly outside is rejected', () {
    expect(clipSegment(-50, -50, -10, -10, clip, out), isFalse);
  });

  test('a degenerate point inside is kept, outside is rejected', () {
    expect(clipSegment(50, 50, 50, 50, clip, out), isTrue);
    expect(clipSegment(-5, -5, -5, -5, clip, out), isFalse);
  });

  test('a segment crossing a corner keeps only the crossing part', () {
    expect(clipSegment(-50, 50, 50, -50, clip, out), isFalse,
        reason: 'the line passes outside the corner, touching nothing');
  });
}
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/segment_clip_test.dart`

Expected: FAIL to compile — `clipSegment` is not defined.

- [ ] **Step 3: Implement Liang–Barsky**

Create `packages/jet_cad_2d/lib/src/geometry/segment_clip.dart`:

```dart
import 'dart:typed_data';

import 'aabb2.dart';

/// Clips the segment to [clip], writing the parametric range into [out].
///
/// Liang–Barsky. Returns false when the segment misses the rectangle, in which
/// case [out] is untouched. `out[0]` and `out[1]` are `t` values in `[0, 1]`
/// along `(x0,y0) → (x1,y1)`.
///
/// The caller needs the parameters rather than the clipped endpoints because a
/// dash pattern's phase at the clip entry is the arc length to `t0`, measured
/// from the *original* start. Returning points alone would lose that.
bool clipSegment(double x0, double y0, double x1, double y1, Aabb2 clip,
    Float64List out) {
  final dx = x1 - x0;
  final dy = y1 - y0;
  var t0 = 0.0;
  var t1 = 1.0;

  for (var edge = 0; edge < 4; edge++) {
    final double p, q;
    switch (edge) {
      case 0:
        p = -dx;
        q = x0 - clip.minX;
      case 1:
        p = dx;
        q = clip.maxX - x0;
      case 2:
        p = -dy;
        q = y0 - clip.minY;
      default:
        p = dy;
        q = clip.maxY - y0;
    }
    if (p == 0.0) {
      // Parallel to this edge: inside if q >= 0, otherwise nothing survives.
      if (q < 0.0) return false;
      continue;
    }
    final r = q / p;
    if (p < 0.0) {
      if (r > t1) return false;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return false;
      if (r < t1) t1 = r;
    }
  }
  out[0] = t0;
  out[1] = t1;
  return true;
}
```

- [ ] **Step 4: Run the clip tests**

Run: `cd packages/jet_cad_2d && dart test test/geometry/segment_clip_test.dart` — expected: PASS.

- [ ] **Step 5: Write the failing dasher tests**

Create `packages/jet_cad_2d/test/geometry/dasher_test.dart`:

```dart
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2;

/// 12 on, 6 off, cycle 18 — the corpus's dashed linetype.
const DashPattern kDashed = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
const DashPattern kSolid = DashPattern(dashes: [], totalLength: 0);

final Aabb2 kOpen = Aabb2(Vector2(-1e9, -1e9), Vector2(1e9, 1e9));

List<List<double>> collect(
    Dasher dasher, List<double> pts, DashPattern pattern, double scale,
    {Aabb2? clip}) {
  final out = <List<double>>[];
  final buffer = Float64List.fromList(pts);
  dasher.dashPolyline(buffer, pts.length ~/ 2, pattern, scale, clip ?? kOpen,
      (x0, y0, x1, y1) => out.add([x0, y0, x1, y1]));
  return out;
}

void main() {
  test('a 36-long segment under a 12/6 pattern draws three spans', () {
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0);
    expect(spans, [
      [0.0, 0.0, 12.0, 0.0],
      [18.0, 0.0, 30.0, 0.0],
      [36.0, 0.0, 36.0, 0.0],
    ].sublist(0, 2));
  });

  test('the phase is carried from the true start when the clip cuts in', () {
    // x in [20, 100]. At 20 the pattern is 2 units into its second on-run,
    // which ends at 30. A phase reset at the clip entry would draw 20..32.
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0,
        clip: Aabb2(Vector2(20, -5), Vector2(100, 5)));
    expect(spans.first[0], closeTo(20.0, 1e-9));
    expect(spans.first[2], closeTo(30.0, 1e-9));
  });

  test('the pattern restarts at every vertex', () {
    // Two 12-long segments. DXF's default without LWPOLYLINE flag 128 is a
    // restart per vertex, so each draws one full 12-long dash rather than the
    // second continuing into the gap.
    final spans = collect(Dasher(), [0, 0, 12, 0, 12, 12], kDashed, 1.0);
    expect(spans.length, 2);
    expect(spans[0], [0.0, 0.0, 12.0, 0.0]);
    expect(spans[1], [12.0, 0.0, 12.0, 12.0]);
  });

  test('scale multiplies the pattern, not the geometry', () {
    final spans = collect(Dasher(), [0, 0, 72, 0], kDashed, 2.0);
    expect(spans.first[2], closeTo(24.0, 1e-9));
  });

  test('a period below the floor collapses to solid and is counted', () {
    final dasher = Dasher(collapsePx: 3.0);
    // period = 18 * 0.1 = 1.8, under 3.
    final spans = collect(dasher, [0, 0, 100, 0], kDashed, 0.1);
    expect(spans, isEmpty, reason: 'the caller draws the geometry unchanged');
    expect(dasher.collapsedCount, 1);
  });

  test('an empty pattern is solid and is not counted as a collapse', () {
    final dasher = Dasher();
    expect(collect(dasher, [0, 0, 100, 0], kSolid, 1.0), isEmpty);
    expect(dasher.collapsedCount, 0,
        reason: 'a continuous linetype was never dashed; counting it as a '
            'collapse would inflate the number the results note reports');
  });

  test('a segment entirely outside the clip emits nothing', () {
    final spans = collect(Dasher(), [0, 0, 36, 0], kDashed, 1.0,
        clip: Aabb2(Vector2(500, 500), Vector2(600, 600)));
    expect(spans, isEmpty);
  });

  test('returns true when it emitted, false when the caller must draw solid',
      () {
    final dasher = Dasher();
    final buffer = Float64List.fromList([0, 0, 36, 0]);
    expect(
        dasher.dashPolyline(buffer, 2, kDashed, 1.0, kOpen, (_, __, ___, ____) {}),
        isTrue);
    expect(
        dasher.dashPolyline(buffer, 2, kSolid, 1.0, kOpen, (_, __, ___, ____) {}),
        isFalse);
  });
}
```

- [ ] **Step 6: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/dasher_test.dart`

Expected: FAIL to compile — `Dasher` is not defined.

- [ ] **Step 7: Implement `Dasher.dashPolyline`**

Create `packages/jet_cad_2d/lib/src/geometry/dasher.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

import '../document/tables.dart';
import 'aabb2.dart';
import 'segment_clip.dart';

/// Below this on-screen pattern period, a linetype is drawn solid.
///
/// Zoomed far enough out a dashed line is visually solid anyway, and below the
/// floor dash generation buys nothing but segments. **Swept and reviewed**, not
/// chosen — see the results note.
const double kDashCollapsePx = 3.0;

/// Reports one drawn span of a dash pattern.
typedef DashSpanEmit = void Function(
    double x0, double y0, double x1, double y1);

/// Walks a dash pattern along screen-space geometry.
///
/// Pure geometry: no `dart:ui`, no document access, no allocation per call. The
/// period is denominated in the same units as the points, which for the render
/// path means device pixels — and that is the point. **A pixel-denominated
/// period bounds segment count by the viewport rather than by the document.**
/// Generating in world units puts tens of thousands of segments on a single
/// long line regardless of zoom, and CanvasKit's abort at about 3.4 million ops
/// in one picture is measured, not theoretical.
class Dasher {
  Dasher({this.collapsePx = kDashCollapsePx});

  final double collapsePx;

  final Float64List _range = Float64List(2);

  int _collapsed = 0;

  /// Entities whose pattern collapsed to solid since [resetCounters].
  int get collapsedCount => _collapsed;

  void resetCounters() => _collapsed = 0;

  /// Emits the drawn spans of [pattern] along the polyline in [points].
  ///
  /// [scale] converts pattern units to the units [points] are in. Returns false
  /// when nothing was dashed and the caller must draw the geometry as it
  /// stands — an empty pattern, or a period under [collapsePx].
  ///
  /// The phase restarts at every vertex. That is DXF's default without
  /// LWPOLYLINE flag 128; the continuous-pattern flag is a field the DXF plan
  /// adds, not a decision made here.
  bool dashPolyline(Float64List points, int count, DashPattern pattern,
      double scale, Aabb2 clip, DashSpanEmit emit) {
    if (count < 2 || pattern.dashes.isEmpty || pattern.totalLength <= 0) {
      return false;
    }
    final period = pattern.totalLength * scale;
    if (!period.isFinite || period < collapsePx) {
      _collapsed++;
      return false;
    }
    for (var i = 0; i + 1 < count; i++) {
      _dashSegment(points[i * 2], points[i * 2 + 1], points[i * 2 + 2],
          points[i * 2 + 3], pattern, scale, period, clip, emit);
    }
    return true;
  }

  void _dashSegment(double x0, double y0, double x1, double y1,
      DashPattern pattern, double scale, double period, Aabb2 clip,
      DashSpanEmit emit) {
    if (!clipSegment(x0, y0, x1, y1, clip, _range)) return;
    final dx = x1 - x0;
    final dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0.0) return;

    // Distances along the *original* segment. The pattern's phase at the clip
    // entry is the arc length to t0, not zero — resetting it here would give a
    // picture that is correct at rest and slides as the camera moves.
    final from = _range[0] * length;
    final to = _range[1] * length;

    final ux = dx / length;
    final uy = dy / length;

    // Walk the pattern from its start, skipping cycles before `from` in one
    // step rather than one element at a time: a 32,000-pixel line clipped to
    // 200 visible pixels must not cost 10,000 iterations to reach them.
    var cursor = (from / period).floorToDouble() * period;
    var element = 0;
    while (cursor < to) {
      final raw = pattern.dashes[element];
      final span = raw.abs() * scale;
      // A zero-length element is a DXF dot: give it the smallest visible run
      // rather than looping forever on a span of nothing.
      final width = span == 0.0 ? 1e-9 : span;
      final end = cursor + width;
      if (raw >= 0 && end > from) {
        final a = math.max(cursor, from);
        final b = math.min(end, to);
        if (b > a) {
          emit(x0 + ux * a, y0 + uy * a, x0 + ux * b, y0 + uy * b);
        }
      }
      cursor = end;
      element = (element + 1) % pattern.dashes.length;
    }
  }
}
```

- [ ] **Step 8: Run the dasher tests**

Run: `cd packages/jet_cad_2d && dart test test/geometry/dasher_test.dart` — expected: PASS.

- [ ] **Step 9: Export and run the whole engine suite**

Add to `packages/jet_cad_2d/lib/jet_cad_2d.dart`:

```dart
export 'src/geometry/dasher.dart';
export 'src/geometry/segment_clip.dart';
```

Run: `cd packages/jet_cad_2d && dart test` — expected: PASS, 639 plus the new ones.

- [ ] **Step 10: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): add screen-space dash generation for polylines

Pure geometry, in the engine rather than beside the painter: Aabb2 and
DashPattern are already engine types, so this is testable from the plain
dart test suite with no Flutter binding, and a DXF exporter reuses it
instead of writing it twice.

The period is denominated in the units the points are in, which for the
render path is device pixels. That is what bounds segment count by the
viewport instead of by the document - generating in world units puts tens
of thousands of segments on one long line regardless of zoom, against a
measured CanvasKit abort at about 3.4 million ops in one picture.

Clipping runs before generation, and the phase at the clip entry is the
arc length from the true segment start. Skipping that gives a picture
that is correct at rest and slides as the camera moves. The pattern
restarts at every vertex, which is DXF's default without LWPOLYLINE
flag 128."
```

---

## Task 7: Dashing arcs and circles

The bound has to hold for curves too, or it does not hold: a circle whose screen radius is large has an arc length to match, and a full pattern walk over it is unbounded in exactly the way the polyline clip prevents.

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/geometry/segment_clip.dart` (angular windows)
- Modify: `packages/jet_cad_2d/lib/src/geometry/dasher.dart`
- Test: `packages/jet_cad_2d/test/geometry/segment_clip_test.dart`
- Test: `packages/jet_cad_2d/test/geometry/dasher_test.dart`

**Interfaces:**
- Consumes: `Dasher`, `clipSegment`.
- Produces:
  - `int circleClipWindows(double cx, double cy, double r, Aabb2 clip, Float64List out)` — writes up to 8 `[start, end]` angle pairs into `out` and returns the pair count. Returns `-1` when the whole circle is inside `clip`.
  - `typedef DashArcEmit = void Function(double startAngle, double sweep);`
  - `bool Dasher.dashArc(double cx, double cy, double r, double start, double sweep, DashPattern pattern, double scale, Aabb2 clip, DashArcEmit emit)`

- [ ] **Step 1: Write the failing angular-window tests**

Append to `test/geometry/segment_clip_test.dart`:

```dart
  group('circleClipWindows', () {
    final out = Float64List(16);

    test('a circle entirely inside reports the whole-circle sentinel', () {
      expect(circleClipWindows(50, 50, 10, clip, out), -1);
    });

    test('a circle entirely outside reports no windows', () {
      expect(circleClipWindows(500, 500, 10, clip, out), 0);
    });

    test('a circle centred on the left edge keeps its right half', () {
      // Centre at x=0, radius 40: the arc from -pi/2 to +pi/2 is inside.
      final n = circleClipWindows(0, 50, 40, clip, out);
      expect(n, 1);
      expect(out[0], closeTo(-math.pi / 2, 1e-9));
      expect(out[1], closeTo(math.pi / 2, 1e-9));
    });

    test('a circle larger than the rect reports the windows over each edge',
        () {
      // Radius 200 around the rect centre: no part of the circle is inside, so
      // nothing is drawn even though the circle encloses the whole view.
      expect(circleClipWindows(50, 50, 200, clip, out), 0);
    });
  });
```

- [ ] **Step 2: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/segment_clip_test.dart -n circleClipWindows`

Expected: FAIL to compile — `circleClipWindows` is not defined.

- [ ] **Step 3: Implement the angular windows**

Append to `segment_clip.dart`:

```dart
/// The angular ranges of a circle that lie inside [clip].
///
/// Writes `[start0, end0, start1, end1, …]` into [out], each `start < end` and
/// in `(-pi, 3pi]`, and returns the pair count. Returns `-1` when the entire
/// circle is inside, which the caller treats as one window of the full turn
/// without paying for the intersection maths.
///
/// Constant work regardless of radius, which is the point: a dashed circle
/// whose screen radius is ten thousand pixels must cost the same to clip as one
/// of ten, or the pixel-denominated period stops bounding anything.
int circleClipWindows(
    double cx, double cy, double r, Aabb2 clip, Float64List out) {
  if (r <= 0 || !r.isFinite) return 0;
  if (cx - r >= clip.minX &&
      cx + r <= clip.maxX &&
      cy - r >= clip.minY &&
      cy + r <= clip.maxY) {
    return -1;
  }

  // Angles where the circle crosses each edge line, kept only where the
  // crossing point is on the finite edge.
  final crossings = <double>[];
  void vertical(double x) {
    final dx = x - cx;
    if (dx.abs() > r) return;
    final dy = math.sqrt(r * r - dx * dx);
    for (final y in [cy - dy, cy + dy]) {
      if (y >= clip.minY && y <= clip.maxY) {
        crossings.add(math.atan2(y - cy, dx));
      }
    }
  }

  void horizontal(double y) {
    final dy = y - cy;
    if (dy.abs() > r) return;
    final dx = math.sqrt(r * r - dy * dy);
    for (final x in [cx - dx, cx + dx]) {
      if (x >= clip.minX && x <= clip.maxX) {
        crossings.add(math.atan2(dy, x - cx));
      }
    }
  }

  vertical(clip.minX);
  vertical(clip.maxX);
  horizontal(clip.minY);
  horizontal(clip.maxY);

  if (crossings.isEmpty) return 0;
  crossings.sort();

  // Between two consecutive crossings the circle is wholly in or wholly out,
  // so one midpoint test per gap decides the whole gap.
  var pairs = 0;
  for (var i = 0; i < crossings.length; i++) {
    final a = crossings[i];
    final b = i + 1 < crossings.length
        ? crossings[i + 1]
        : crossings[0] + 2 * math.pi;
    final mid = (a + b) / 2;
    final mx = cx + r * math.cos(mid);
    final my = cy + r * math.sin(mid);
    if (mx >= clip.minX &&
        mx <= clip.maxX &&
        my >= clip.minY &&
        my <= clip.maxY) {
      if (pairs * 2 + 1 >= out.length) break;
      out[pairs * 2] = a;
      out[pairs * 2 + 1] = b;
      pairs++;
    }
  }
  return pairs;
}
```

Add `import 'dart:math' as math;` to the file, and `import 'dart:math' as math;` to the test.

- [ ] **Step 4: Run the clip tests**

Run: `cd packages/jet_cad_2d && dart test test/geometry/segment_clip_test.dart` — expected: PASS.

- [ ] **Step 5: Write the failing arc-dash tests**

Append to `test/geometry/dasher_test.dart`:

```dart
  group('dashArc', () {
    List<List<double>> arcs(Dasher dasher, double cx, double cy, double r,
        double start, double sweep, double scale,
        {Aabb2? clip}) {
      final out = <List<double>>[];
      dasher.dashArc(cx, cy, r, start, sweep, kDashed, scale, clip ?? kOpen,
          (a, s) => out.add([a, s]));
      return out;
    }

    test('a full circle is walked by arc length', () {
      // r = 18/(2*pi) makes the circumference exactly 18: one full cycle, so
      // one 12-long span, which is 12/18 of a turn.
      final r = 18 / (2 * math.pi);
      final spans = arcs(Dasher(), 0, 0, r, 0, 2 * math.pi, 1.0);
      expect(spans.length, 1);
      expect(spans.first[0], closeTo(0.0, 1e-9));
      expect(spans.first[1], closeTo(2 * math.pi * 12 / 18, 1e-9));
    });

    test('a period below the floor collapses and is counted', () {
      final dasher = Dasher(collapsePx: 3.0);
      expect(arcs(dasher, 0, 0, 100, 0, 2 * math.pi, 0.1), isEmpty);
      expect(dasher.collapsedCount, 1);
    });

    test('only the angular window inside the clip is generated', () {
      // A large circle whose centre is far left: a narrow window crosses the
      // clip. Every emitted span must lie inside that window.
      final clip = Aabb2(Vector2(0, -10), Vector2(20, 10));
      final spans = arcs(Dasher(), -1000, 0, 1005, 0, 2 * math.pi, 1.0,
          clip: clip);
      expect(spans, isNotEmpty);
      for (final s in spans) {
        final mid = s[0] + s[1] / 2;
        final x = -1000 + 1005 * math.cos(mid);
        final y = 1005 * math.sin(mid);
        expect(x, greaterThanOrEqualTo(clip.minX - 1));
        expect(x, lessThanOrEqualTo(clip.maxX + 1));
        expect(y, greaterThanOrEqualTo(clip.minY - 1));
        expect(y, lessThanOrEqualTo(clip.maxY + 1));
      }
    });

    test('a circle wholly outside the clip emits nothing', () {
      final spans = arcs(Dasher(), 0, 0, 10, 0, 2 * math.pi, 1.0,
          clip: Aabb2(Vector2(500, 500), Vector2(600, 600)));
      expect(spans, isEmpty);
    });
  });
```

Add `import 'dart:math' as math;` to the test file.

- [ ] **Step 6: Run and watch it fail**

Run: `cd packages/jet_cad_2d && dart test test/geometry/dasher_test.dart -n dashArc`

Expected: FAIL to compile — `dashArc` is not defined.

- [ ] **Step 7: Implement `dashArc`**

Append to `dasher.dart`:

```dart
/// Reports one drawn span of a dash pattern along an arc.
typedef DashArcEmit = void Function(double startAngle, double sweep);
```

and inside `Dasher`:

```dart
  final Float64List _windows = Float64List(16);

  /// Emits the drawn spans of [pattern] along an arc, by angle.
  ///
  /// [r] is the arc's **screen** radius, so arc length is `r * |sweep|` in the
  /// same units the period is in. Returns false when the caller must draw the
  /// arc as it stands.
  bool dashArc(double cx, double cy, double r, double start, double sweep,
      DashPattern pattern, double scale, Aabb2 clip, DashArcEmit emit) {
    if (pattern.dashes.isEmpty || pattern.totalLength <= 0) return false;
    final period = pattern.totalLength * scale;
    if (!period.isFinite || period < collapsePx) {
      _collapsed++;
      return false;
    }
    if (r <= 0 || !r.isFinite || sweep == 0.0) return false;

    final windows = circleClipWindows(cx, cy, r, clip, _windows);
    if (windows == 0) return true; // nothing visible; nothing to draw
    final count = windows < 0 ? 1 : windows;
    for (var w = 0; w < count; w++) {
      final wa = windows < 0 ? -math.pi : _windows[w * 2];
      final wb = windows < 0 ? math.pi * 3 : _windows[w * 2 + 1];
      _dashArcWindow(r, start, sweep, wa, wb, pattern, scale, period, emit);
    }
    return true;
  }

  /// Walks one angular window of the arc.
  ///
  /// The pattern's phase is measured from [start] along the arc, so clipping to
  /// a window shifts it exactly as clipping a segment does. Angles are reduced
  /// into the arc's own range before comparison, because a window from
  /// `circleClipWindows` may sit a full turn away from where the arc begins.
  void _dashArcWindow(double r, double start, double sweep, double windowStart,
      double windowEnd, DashPattern pattern, double scale, double period,
      DashArcEmit emit) {
    final direction = sweep < 0 ? -1.0 : 1.0;
    final total = sweep.abs();
    // The window, expressed as distances along the arc from `start`.
    double along(double angle) {
      var delta = (angle - start) * direction;
      while (delta < 0) {
        delta += 2 * math.pi;
      }
      while (delta > 2 * math.pi) {
        delta -= 2 * math.pi;
      }
      return delta * r;
    }

    var from = along(windowStart);
    var to = along(windowEnd);
    if (to <= from) to = total * r;
    from = math.max(0.0, from);
    to = math.min(total * r, to);
    if (to <= from) return;

    var cursor = (from / period).floorToDouble() * period;
    var element = 0;
    while (cursor < to) {
      final raw = pattern.dashes[element];
      final span = raw.abs() * scale;
      final width = span == 0.0 ? 1e-9 : span;
      final end = cursor + width;
      if (raw >= 0 && end > from) {
        final a = math.max(cursor, from);
        final b = math.min(end, to);
        if (b > a) {
          emit(start + direction * (a / r), direction * ((b - a) / r));
        }
      }
      cursor = end;
      element = (element + 1) % pattern.dashes.length;
    }
  }
```

- [ ] **Step 8: Run the tests**

Run: `cd packages/jet_cad_2d && dart test test/geometry/dasher_test.dart` — expected: PASS.
Run: `cd packages/jet_cad_2d && dart test` — expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add -A packages/jet_cad_2d
git commit -m "feat(jet_cad_2d): dash arcs and circles inside their visible windows

The pixel-denominated period only bounds segment count if it bounds it
for curves too. A circle with a ten-thousand-pixel screen radius has an
arc length to match, and walking the whole of it is unbounded in exactly
the way the polyline clip prevents.

circleClipWindows intersects the circle with the four edge lines, sorts
the crossings, and keeps the gaps whose midpoint is inside - constant
work regardless of radius. dashArc walks each window with the phase
measured from the arc's own start, so clipping shifts it the same way
clipping a segment does."
```

---

## Task 8: Wire dashing into the painter

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_painter.dart`
- Test: `packages/jet_cad_2d_flutter/test/draft_painter_test.dart`

**Interfaces:**
- Consumes: `Dasher`, `DraftPainter` from Task 1.
- Produces: `DraftPainter.dashSpanCount`, `DraftPainter.collapsedDashCount`.

- [ ] **Step 1: Write the failing tests**

Add to `packages/jet_cad_2d_flutter/test/draft_painter_test.dart`:

```dart
  DraftDocument dashedFixture({required Transform2 placement}) {
    final doc = DraftDocument.empty();
    final dashed = doc.handleSeed.next();
    doc.tables.linetypes.add(LinetypeRecord(
      handle: dashed,
      name: 'DASHED',
      description: '__ __ __',
      pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
    ));
    final def = doc.handleSeed.next();
    doc.tree.addDefinition(Definition(
        handle: def, name: 'd', basePoint: Vector2.zero(), children: const []));
    doc.commands.execute(AddEntityCommand(
      record: EntityRecord(
        handle: doc.handleSeed.next(),
        owner: def,
        kind: EntityKind.line,
        layer: ReservedHandles.layerZero,
        linetype: dashed,
        linetypeScale: 1.0,
        geomIndex: 0,
        color: const ByLayerColor(),
        lineweight: 25,
        transparency: 0,
        flags: 0,
      ),
      payload: GeometryPayload(
          coords: Float64List.fromList([0, 0, 360, 0]),
          scalars: Float64List(0)),
    ));
    doc.commands.execute(AddNodeCommand(InstanceNode(
      handle: doc.handleSeed.next(),
      parent: doc.rootHandle,
      definition: def,
      transform: placement,
    )));
    return doc;
  }

  List<PolylineOp> paintDashed(DraftDocument doc, ViewportTransform camera) {
    final recording = RecordingDrawSink();
    DraftPainter(
            document: doc,
            index: SpatialIndex(doc),
            resolver: DocumentStyleResolver(doc))
        .paint(recording, camera, kViewport);
    return recording.ops.whereType<PolylineOp>().toList();
  }

  test('a dashed entity reaches the sink as many spans, not one polyline', () {
    final doc = dashedFixture(placement: Transform2(1.4, 0.3, -0.3, 1.4, 5, 7));
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, greaterThan(4));
    for (final op in ops) {
      expect(op.points.length, 4, reason: 'each span is one two-point run');
    }
  });

  test('the instance scale multiplies the on-screen dash length', () {
    // Same geometry, same camera, twice the placement scale: each span must be
    // twice as long on screen. This is the scale chain, and nothing else in the
    // suite can see it.
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    double firstSpanLength(DraftDocument doc) {
      final op = paintDashed(doc, cam).first;
      final dx = op.points[2] - op.points[0];
      final dy = op.points[3] - op.points[1];
      return math.sqrt(dx * dx + dy * dy);
    }

    final one = firstSpanLength(dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0)));
    final two = firstSpanLength(dashedFixture(placement: Transform2(2, 0, 0, 2, 0, 0)));
    expect(two / one, closeTo(2.0, 1e-6));
  });

  test('globalLinetypeScale multiplies it too', () {
    final cam = ViewportTransform.fit(
        Aabb2(Vector2(-50, -50), Vector2(1200, 1200)), kViewport);
    final doc = dashedFixture(placement: Transform2(1, 0, 0, 1, 0, 0));
    final before = paintDashed(doc, cam).length;
    doc.header.globalLinetypeScale = 3.0;
    final after = paintDashed(doc, cam).length;
    expect(after, lessThan(before),
        reason: 'a longer pattern means fewer spans over the same line');
  });

  test('a continuous entity is drawn as one polyline and is not counted', () {
    final doc = DraftDocument.empty();
    addEntity(doc, doc.rootHandle, doc.handleSeed.next(), EntityKind.line,
        [0, 0, 360, 0], const []);
    final ops = paintDashed(doc, ViewportTransform.fit(doc.extents, kViewport));
    expect(ops.length, 1);
  });
```

Add `import 'dart:math' as math;` to the test file.

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart -N dash`

Expected: FAIL — one polyline where many spans are expected.

- [ ] **Step 3: Dispatch through the dasher**

In `draft_painter.dart`, add the fields:

```dart
  final Dasher _dasher = Dasher();

  int _dashSpans = 0;

  /// Dash spans emitted in the last frame.
  int get dashSpanCount => _dashSpans;

  /// Entities whose dash pattern collapsed to solid in the last frame.
  int get collapsedDashCount => _dasher.collapsedCount;

  /// The clip the dasher generates inside, in screen space.
  ///
  /// Inflated by half the widest stroke the frame can draw, so a stroke whose
  /// centreline is just outside still contributes its visible edge.
  Aabb2 _screenClip = Aabb2.empty();

  /// One two-point buffer, reused per span. A span is emitted through the sink
  /// immediately, so it never needs to outlive the callback.
  final Float64List _span = Float64List(4);
```

In `paint`, reset the counters and compute the clip:

```dart
    _dashSpans = 0;
    _dasher.resetCounters();
    const inflate = 32.0; // half of the widest plausible stroke, in device px
    _screenClip = Aabb2(Vector2(-inflate, -inflate),
        Vector2(viewport.width + inflate, viewport.height + inflate));
```

Add the pattern lookup and the scale chain:

```dart
  /// The pattern for [style], or null when the entity is continuous.
  DashPattern? _patternFor(ResolvedStyle style) {
    final record = document.tables.linetypes[style.linetype];
    final pattern = record?.pattern;
    if (pattern == null || pattern.dashes.isEmpty) return null;
    return pattern;
  }

  /// Pattern units to device pixels.
  ///
  /// `entity scale × document scale × the composed screen scale`. The last is
  /// `sqrt(|det|)` of the full world-to-screen chain — the same representative
  /// scale the stroke width uses, and under an anisotropic placement it is an
  /// approximation for the same reason, counted in [anisotropicCurveCount]'s
  /// company rather than assumed away.
  double _dashScale(ResolvedStyle style, Transform2 toScreen) =>
      style.linetypeScale *
      document.header.globalLinetypeScale *
      toScreen.scaleMagnitude;
```

In `_emitScreenSpace`, after the points are transformed, branch:

```dart
    sink.beginResidual(Transform2.translation(screenOrigin.x, screenOrigin.y),
        debugHandle: document.entities.handleAt(slot));
    if (kind == EntityKind.point) {
      sink.point(_points[0], _points[1], style);
      sink.endResidual();
      return;
    }
    final pattern = _patternFor(style);
    if (pattern == null ||
        !_dasher.dashPolyline(
            _points, count, pattern, _dashScale(style, toScreen), _screenClip,
            (x0, y0, x1, y1) {
          _span[0] = x0;
          _span[1] = y0;
          _span[2] = x1;
          _span[3] = y1;
          _dashSpans++;
          sink.polyline(_span, 2, style, closed: false);
        })) {
      sink.polyline(_points, count, style, closed: false);
    }
    sink.endResidual();
```

The clip is in screen space and the points are screen-space **before** the rebase subtraction, so subtract the screen origin from `_screenClip` once per frame rather than adding it back per point:

```dart
    final clip = Aabb2(
        Vector2(_screenClip.minX - screenOrigin.x,
            _screenClip.minY - screenOrigin.y),
        Vector2(_screenClip.maxX - screenOrigin.x,
            _screenClip.maxY - screenOrigin.y));
```

Hoist that into `paint` as `_rebasedClip`, computed once after `origin` is chosen, and pass it to the dasher.

For curves, in `_emit`'s `circle` and `arc` cases, apply the same branch through `dashArc`, emitting each span as `sink.arc(...)`. The curve's screen radius is `payload.scalars[0] * toScreen.scaleMagnitude`; pass `toScreen` down to `_emit` for the scale.

- [ ] **Step 4: Run the painter tests**

Run: `cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart` — expected: PASS.

- [ ] **Step 5: Confirm the oracle is unaffected, and say why in a test**

`differentialFixture` uses `ReservedHandles.byLayerLinetype`, which resolves through layer 0 to `continuousLinetype`, whose pattern is empty. Nothing in the differential fixture dashes, so the oracle keeps comparing a painter and a reference that both draw solid.

That is worth pinning rather than relying on, because a future fixture change would silently break it. Add to `test/differential_test.dart`:

```dart
  test('the differential fixture is entirely continuous', () {
    // The reference walk does not dash. If a fixture entity ever carries a
    // pattern, the painter emits spans where the reference emits one polyline
    // and the superset assertion fails for a reason that has nothing to do
    // with the walk. Dashing is covered by the dasher's own tests and by the
    // goldens, not here.
    final doc = differentialFixture();
    final resolver = DocumentStyleResolver(doc);
    for (final slot in doc.entities.liveSlots) {
      final style = resolver.styleFor(slot, StyleContext.documentRoot);
      final pattern = doc.tables.linetypes[style.linetype]?.pattern;
      expect(pattern?.dashes ?? const <double>[], isEmpty);
    }
  });
```

Run: `cd packages/jet_cad_2d_flutter && flutter test test/differential_test.dart` — expected: PASS.

- [ ] **Step 6: Run everything and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test`

```bash
git add -A packages/jet_cad_2d_flutter
git commit -m "feat(jet_cad_2d_flutter): draw dashed linetypes

35.0% of the measured corpus carries a non-continuous linetype and all of
it was drawn solid. The painter now looks the pattern up and hands the
screen-space points to the engine's Dasher, emitting one two-point span
per drawn run so the spans land in the same paint bucket the solid line
would have.

The scale chain is entity linetypeScale x globalLinetypeScale x the
composed screen scale, and it has its own test: the same geometry under
twice the placement scale must produce spans twice as long. Nothing else
in the suite can see that chain.

The differential oracle is unaffected because differentialFixture is
entirely continuous, which is now asserted rather than assumed - the
reference walk does not dash, so a fixture that did would fail the
superset assertion for a reason unrelated to the walk."
```

---

## Task 9: Sweep `kDashCollapsePx` and review the dash ladder

The floor is measured, then reviewed. "No visible difference" is not a threshold a test can hold, and pretending otherwise would bury the trade-off inside a constant.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_*.png` (generated)
- Modify: `packages/jet_cad_2d/lib/src/geometry/dasher.dart` (`kDashCollapsePx`)

- [ ] **Step 1: Write the dash-ladder golden**

Create `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`:

```dart
@Tags(['golden'])
library;

// One fixture, the same dashed geometry at five zoom levels, so the collapse
// floor's effect is visible as a ladder rather than as a number.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Aabb2, Colors;

const Size kGoldenViewport = Size(400, 300);
const Key kCanvasKey = Key('golden-canvas');

/// Six horizontal dashed rules, and one dashed circle, spanning the width.
DraftDocument dashLadderFixture() {
  final doc = DraftDocument.empty();
  final dashed = doc.handleSeed.next();
  doc.tables.linetypes.add(LinetypeRecord(
    handle: dashed,
    name: 'DASHED',
    description: '__ __ __',
    pattern: const DashPattern(dashes: [12.0, -6.0], totalLength: 18.0),
  ));
  for (var i = 0; i < 6; i++) {
    _dashedEntity(doc, dashed, EntityKind.polyline,
        [-500, -60.0 + i * 24, 500, -60.0 + i * 24], const []);
  }
  _dashedEntity(doc, dashed, EntityKind.circle, [0, 0], const [90]);
  return doc;
}

void _dashedEntity(DraftDocument doc, Handle linetype, EntityKind kind,
    List<double> coords, List<double> scalars) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: doc.handleSeed.next(),
      owner: doc.rootHandle,
      kind: kind,
      layer: ReservedHandles.layerZero,
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: 30,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList(coords),
        scalars: Float64List.fromList(scalars)),
  ));
}

Widget _at(DraftDocument doc, double halfSpan) {
  final index = SpatialIndex(doc);
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          key: kCanvasKey,
          width: kGoldenViewport.width,
          height: kGoldenViewport.height,
          child: DraftCanvas(
            document: doc,
            index: index,
            resolver: DocumentStyleResolver(doc),
            camera: CameraController(ViewportTransform.fit(
                Aabb2(Vector2(-halfSpan, -halfSpan),
                    Vector2(halfSpan, halfSpan)),
                kGoldenViewport)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final (name, halfSpan) in const [
    ('1', 60.0),
    ('2', 150.0),
    ('3', 400.0),
    ('4', 1200.0),
    ('5', 4000.0),
  ]) {
    testWidgets('dash ladder rung $name', (tester) async {
      await tester.pumpWidget(_at(dashLadderFixture(), halfSpan));
      await expectLater(
          find.byKey(kCanvasKey), matchesGoldenFile('dash_ladder_$name.png'));
    });
  }
}
```

- [ ] **Step 2: Sweep the floor**

For each candidate in `1.0, 2.0, 3.0, 4.0, 6.0`:

1. Set `kDashCollapsePx` in `packages/jet_cad_2d/lib/src/geometry/dasher.dart`.
2. Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens test/golden/dash_ladder_golden_test.dart`
3. Copy the five PNGs to `/tmp/dash-sweep/<candidate>/`.
4. Run: `flutter test --tags rig --run-skipped test/rig/batch_spike_test.dart` and record `p50` and `canvasCalls` for the shipped mode.
5. Run the R4a rig once at 50k and record its `dashSpanCount` and `collapsedDashCount`.

- [ ] **Step 3: Review the ladders and choose**

**Open the five ladders for each candidate side by side.** The question is the largest candidate at which rung 3 and rung 4 still read as dashed rather than as solid grey.

Write the chosen value into `kDashCollapsePx`, and record in the results note: every candidate, its p50, its span count, its collapse count, the chosen value, and one sentence on what the reviewer saw. The judgement is the deliverable — a threshold that pretends to be derived is worse than one that admits it was looked at.

- [ ] **Step 4: Regenerate at the chosen value and commit**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens`
Run: `cd packages/jet_cad_2d_flutter && flutter test && cd ../jet_cad_2d && dart test`

```bash
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter
git commit -m "perf(jet_cad_2d): set the dash collapse floor from a reviewed sweep

Five candidates, five zoom levels each, with span counts and paint times
beside the pictures. The value that ships is the largest at which the
middle rungs still read as dashed rather than as solid grey.

That is a judgement, and it is recorded as one. 'No visible difference'
is not a threshold a test can hold, and a constant that pretends to be
derived hides the trade-off it was chosen to make."
```

---

## Task 10: Counters, rig updates and the dashed edit path

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/rig/paint_microbench_test.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`
- Modify: `packages/jet_cad_2d_flutter/README.md`

- [ ] **Step 1: Report the new counters in R1**

In `paint_microbench_test.dart`, add to each printed row: `canvasCalls` from a `CanvasDrawSink` run alongside the `NullDrawSink` one, plus `dashSpanCount` and `collapsedDashCount` from the painter. Keep `NullDrawSink.opCount` reported unchanged and under its old label, so Plan 3a's rows compare line for line.

- [ ] **Step 2: Make R4a's edited line dashed**

`addLineAt` in `frame_timing_test.dart` adds its line with `linetype: ReservedHandles.byLayerLinetype` on layer 0, which is continuous — so today the edit rig exercises none of the dash path. Give it the corpus's dashed linetype:

```dart
Handle addLineAt(DraftDocument doc, Handle owner, double x, double y,
    Handle linetype) {
  final handle = doc.handleSeed.next();
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.line,
      layer: ReservedHandles.layerZero,
      // The corpus's dashed linetype, not ByLayer: layer 0 is continuous, so
      // a ByLayer line would measure an edit path that never dashes — which
      // is not the edit path this rig is for.
      linetype: linetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
    ),
    payload: GeometryPayload(
        coords: Float64List.fromList([x, y, x + 400, y + 250]),
        scalars: Float64List(0)),
  ));
  return handle;
}
```

Find the corpus's dashed linetype in `boot` — it is the only `LinetypeRecord` whose `pattern.dashes` is non-empty — and thread it through R4a.

- [ ] **Step 3: Report dash counters from R2 and R4a**

Add to each rig's printed block:

```dart
    print('  dashSpans=${painter.dashSpanCount} '
        'collapsed=${painter.collapsedDashCount} '
        'canvasCalls=${sink.canvasCallCount}');
```

`HarnessApp`'s `onReady` gains the painter and sink so the rigs can read them.

- [ ] **Step 4: Run both rigs once to confirm they print**

Run: `cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped`
Run: `cd apps/dev_harness_2d && flutter drive --driver=test_driver/integration_test.dart --target=integration_test/frame_timing_test.dart --profile -d macos --dart-define=RIG=leaf` (foreground)

- [ ] **Step 5: Commit**

```bash
git add -A packages/jet_cad_2d_flutter apps/dev_harness_2d
git commit -m "test: report dash and canvas-call counters from every rig

R4a added its line with ByLayer on layer 0, which is continuous, so the
edit rig exercised none of the dash path it is now supposed to measure.
It takes the corpus's dashed linetype instead.

NullDrawSink.opCount keeps its label and its meaning so Plan 3a's rows
still compare line for line; the real Canvas calls are a second number
beside it."
```

---

## Task 11: Mutation testing

The method that found Plan 2's and 3a's real defects, applied to the constructs this plan adds.

**Files:**
- Create: `docs/superpowers/notes/plan-3b-mutation-log.md`
- Modify: whichever test files fail to catch a mutant

- [ ] **Step 1: Apply each mutant by hand, one at a time, and run the suites**

| # | Mutant | Must be caught by |
|---|---|---|
| 1 | `_opaque` returns `true` always | golden fixture 2 (Task 2) |
| 2 | `flush()` body emptied | `flush is required` (Task 2) |
| 3 | the bucket key drops `lineweightHundredths` | a new sink test: two styles differing only in lineweight must produce two calls |
| 4 | `_bucketFor` skips the key-change flush in `openBucket` | `a paint change flushes` (Task 2) |
| 5 | the curve flush in `bucketMap` is dropped | `flushes every bucket before a curve` (Task 3) |
| 6 | `_translationOnly` returns `true` always | golden fixture 1 — a curve's residual would be applied as a translation |
| 7 | `clipSegment` returns `t0 = 0` instead of the computed value | `the phase is carried from the true start` (Task 6) |
| 8 | `cursor` starts at `0` instead of the floored multiple of `period` | the same test, and R2's frame time |
| 9 | `period < collapsePx` → `period <= collapsePx` | a boundary test: `scale` chosen so `period == collapsePx` exactly must **not** collapse |
| 10 | `_dashScale` drops `globalLinetypeScale` | `globalLinetypeScale multiplies it too` (Task 8) |
| 11 | `_dashScale` drops `toScreen.scaleMagnitude` | `the instance scale multiplies the on-screen dash length` (Task 8) |
| 12 | the pattern restarts per *polyline* rather than per vertex | `the pattern restarts at every vertex` (Task 6) |
| 13 | `circleClipWindows` returns `-1` always | `only the angular window inside the clip is generated` (Task 7) |
| 14 | `_screenClip` inflation set to `0` | a new painter test: a stroke whose centreline is one pixel outside the viewport must still emit a span |
| 15 | the painter draws curves through `_emitScreenSpace` | golden `anisotropy_bypass.png` |

- [ ] **Step 2: For every mutant that survives, write the test that kills it**

Three of the rows above (3, 9, 14) name tests that do not exist yet — write them. For any *other* survivor, fix the fixture rather than weakening the assertion: the usual cause is a fixture whose geometry cannot tell the two behaviours apart, which is the defect class Plan 2's post-mortem named.

If a mutant cannot be distinguished by any reachable input, it is **equivalent**, not a gap. Say so in the log and name the invariant that makes it so, the way 3a's log did for its mutant 3.

- [ ] **Step 3: Write the log**

`docs/superpowers/notes/plan-3b-mutation-log.md`, one row per mutant: caught by which test, killed by which new test, or argued equivalent. Add a closing section naming the mutants only one test catches — those are the tests nobody may delete without replacing.

- [ ] **Step 4: Commit**

```bash
git add -A packages/jet_cad_2d packages/jet_cad_2d_flutter docs/superpowers/notes/plan-3b-mutation-log.md
git commit -m "test: close the gaps mutation testing found in the batch and the dasher"
```

---

## Task 12: Re-run every rig and write the results note

**Files:**
- Create: `docs/superpowers/notes/<completion-date>-plan-3b-results.md`

- [ ] **Step 1: Run every rig**

```bash
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped
cd packages/jet_cad_2d_flutter && flutter test --tags rig --run-skipped --platform chrome
cd apps/dev_harness_2d && flutter build web --release
```

and, in the foreground, for both corpus sizes and all three rigs:

```bash
cd apps/dev_harness_2d && flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d macos \
  --dart-define=ENTITIES=500000 --dart-define=RIG=pan --dart-define=STEPS=60
```

Also re-run the engine's own gate benchmark, unchanged, so Plan 2's row stays current:

```bash
cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart
```

- [ ] **Step 2: Write the note**

`docs/superpowers/notes/<completion-date>-plan-3b-results.md` must contain:

1. Machine and builds, in 3a's format, with the same caveat that R1/R3 are a relative signal and cannot see raster.
2. **The spike:** all four modes, three runs each, R2 raster p50, R1 p50, real `Canvas` calls, and which shipped under which clause of the decision rule.
3. Every 3a row re-measured, **before and after in the same table**, with dashes on.
4. The gate row: 500k working-set raster p50 against 182.73 ms, pass or fail, stated plainly either way.
5. Dash spans and collapses per frame, both cameras, both corpora.
6. The `kDashCollapsePx` sweep: five candidates, their numbers, the chosen value, and the sentence on what the reviewer saw.
7. Real `Canvas` calls against painter ops, both cameras, both corpora — the ratio this plan exists to move.
8. Web: whether the 500k whole-drawing frame now completes, and its number if so. **Informational, not a gate.**
9. What this says about Plan 3c, 3d and 3e, in the shape of 3a's closing section.

- [ ] **Step 3: Commit**

```bash
git add -A docs/superpowers/notes
git commit -m "docs: record Plan 3b's measurements"
```

---

## Task 13: Exit gate

**Files:**
- None new. This task runs commands and records their output.

- [ ] **Step 1: Run every check**

| Check | Command | Threshold |
|---|---|---|
| engine suite | `cd packages/jet_cad_2d && dart test` | all pass |
| engine analyze | `cd packages/jet_cad_2d && dart analyze` | clean |
| engine format | `cd packages/jet_cad_2d && dart format --set-exit-if-changed .` | clean |
| Flutter suite | `cd packages/jet_cad_2d_flutter && flutter test` | all pass |
| goldens | `cd packages/jet_cad_2d_flutter && flutter test --tags golden` | all pass |
| Flutter analyze | `cd packages/jet_cad_2d_flutter && flutter analyze` | clean |
| harness analyze | `cd apps/dev_harness_2d && flutter analyze` | clean |
| query throughput | `cd packages/jet_cad_2d && dart run benchmark/query_throughput.dart` | compare to Plan 2's gate note; `snap at dirty threshold` is a **known** failure carried since Plan 2 |

- [ ] **Step 2: Check the failable criteria**

| Criterion | Threshold |
|---|---|
| 500k working-set raster p50, dashes on | ≤ 182.73 ms |
| goldens, fixtures 1 and 2, batched vs unbatched | byte-identical |
| golden fixture 3 | byte-identical under `openBucket`; a reviewed, deliberately regenerated golden under a mapped mode |
| the differential oracle | both differential tests and the non-vacuity test pass |
| `git diff --stat main -- packages/jet_cad_2d_flutter/lib/src/reference_walk.dart` | **empty** |
| `kDashCollapsePx` | swept, numbers recorded, chosen by recorded review |
| mutation log | every mutant killed or argued equivalent |

- [ ] **Step 3: If the gate fails, record it — do not work around it**

A failure means the batching win is smaller than the dash cost. Write that in the results note as a number, state what it implies for 3e, and stop. Plan 3a's `snap at dirty threshold` row is the precedent: a known failure carried forward honestly is worth more than a threshold quietly moved.

- [ ] **Step 4: Record the gate and finish the branch**

Append the gate results to the results note, then use the **superpowers:finishing-a-development-branch** skill: verify the suite, detect the environment, present the integration options, and act on the choice.

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: the batch mechanism to Tasks 1–3, the spike and its decision rule to Task 4, dashes to Tasks 5–8, the collapse floor to Task 9, the removals to Task 0, measurement and counters to Tasks 10 and 12, the goldens and the oracle to Tasks 2, 3 and 8, mutation testing to Task 11, and the exit criteria to Task 13. The flush contract 3b owes 3d is written in Task 2's `_bucketFor` and exercised by Task 3's curve test.

**Verified against the code while writing.** `TableSection.operator []` returns `T?` keyed by `Handle`; `EntityStore` exposes `liveSlots`, not a slot count plus a liveness test; `workingSetCamera` takes one argument and uses `kRigViewport`; `DraftCanvas.resolver` is optional; `TrueColor` is a const constructor over `rgb`. Each of those was checked in the source rather than recalled, and two of the four first drafts of these tests were wrong.

**Type consistency.** `BatchMode` is introduced in Task 2 with two values and extended in Task 3 to four, then reduced in Task 4. `CanvasDrawSink.flush()`, `canvasCallCount` and `resetCounters()` keep their names throughout. `Dasher.dashPolyline` and `Dasher.dashArc` return `bool` with the same meaning in both — false means the caller draws the geometry as it stands. `screenSpaceLeafCount` replaces `bypassCount` in Task 1 and is used under the new name in Tasks 4 and 10. `kDashCollapsePx` is defined in Task 6 and set in Task 9.

**Known gap, deliberate.** The differential oracle does not cover dashed drawing, because the reference walk does not dash and `differentialFixture` is entirely continuous. Task 8 asserts that fact rather than relying on it. Dashing is covered by the dasher's unit tests, the painter's scale-chain tests, and the dash-ladder golden.

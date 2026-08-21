# jet_cad_2d Plan 3d — The Vertices Sink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `VerticesDrawSink` a shippable renderer — joins, caps, no native leak, a rasterizer and goldens that can see it, and the measurement that decides whether it is the default.

**Architecture:** Three ordered phases. **A** finishes the sink: one backend-resolution point, `Vertices` disposal, miter and bevel joins shared by both walks, and the point shape reconciled between backends. **B** builds the apparatus that can see it: a flush observer, a pure-Dart triangle rasterizer, goldens on both backends, and a sink-against-sink ink-region comparison. **C** measures 10,000 / 50,000 / 500,000 on desktop and web, on both backends, and writes the results note. B precedes C because both of the spike's bugs were found by looking at a picture, not by a failing test.

**Tech Stack:** Dart 3.13, `flutter_test`, `dart:ui` (`Canvas.drawVertices`, `Vertices.raw`, `decodeImageFromPixels`, `matchesGoldenFile`), `package:flutter/foundation.dart` (`kIsWeb`), `integration_test`, `flutter drive`.

**Spec:** [docs/superpowers/specs/2026-08-20-jet-cad-2d-plan-3d-design.md](../specs/2026-08-20-jet-cad-2d-plan-3d-design.md) (revised at `aefb31f` after three review passes)

## Global Constraints

- **Draw order is ascending handle value**, stable across undo, save, load and purge. The single append-ordered buffer plus a flush before anything unbatchable is what preserves it; no task may reorder the buffer or batch across an unbatchable op.
- **The frame path allocates nothing in steady state.** Task 4 extends the measurement to the paint path. **The plan does not amend `CLAUDE.md` on its own authority** — see Task 4, step 8.
- **Geometric *decisions* use `Tolerance`; *stored value* comparisons are exact `==`.**
- **`kMiterLimit = 4.0`** and **`kMinMiterCosine = 2 * (1 / kMiterLimit)^2 - 1 = -0.875`**. Mitre while `dot(d0, d1) >= kMinMiterCosine`, bevel below it. Both are Impeller's (`painting.dart:1535`, `stroke_path_geometry.cc:442`).
- **`kMinStrokeDevicePixels = 1.0`** — Impeller's `kMinStrokeSize` (`geometry.h:19`).
- **`kFlattenTolerance = 0.25`** device pixels, **`kMaxFlattenSegments = 512`**. Already shipped; do not change.
- **The vertices backend is authoritative** where the two backends disagree. The five permitted divergences are the spec's table and nothing else.
- **Never commit `analysis_options.yaml`** — `flutter pub get` rewrites three of them in this workspace. Also revert `apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj` after any `flutter run` or `flutter drive`; CocoaPods rewrites it every time.
- **Never synthesize test output.** A fabricated transcript invalidates the task.
- **Never `git checkout` a file to revert a mutation.** Copy it aside and restore in a `finally`; Plan 3c's Task 10 lost a task's work that way.
- Language: code, comments and commit messages in English.
- Every task ends green:
  ```sh
  cd packages/jet_cad_2d          && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
  cd packages/jet_cad_2d_flutter  && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
  cd apps/dev_harness_2d          && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
  ```

## What already exists, and must not be rewritten

The spike (`spike/vertices-sink`, five commits, head `aefb31f`) ships and is tested. Inherit it:

- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — the single ordered buffer, per-vertex colour, curve flattening with the chord-error budget, both of Impeller's sub-pixel stroke rules (`_halfWidthFor`, `_coveredArgb`), and the mid-frame flush before text.
- `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart` — 24 tests.
- `packages/jet_cad_2d_flutter/test/support/vertices_differential.dart` and `test/vertices_differential_test.dart` — the differential oracle, 4 tests, three recorded blind spots.

## File Structure

**Created:**
- `packages/jet_cad_2d_flutter/lib/src/render_backend.dart` — the `RenderBackend` enum and `defaultRenderBackend()`. One resolution point, one file, so no second call site can appear without touching it.
- `packages/jet_cad_2d_flutter/test/render_backend_test.dart`
- `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart` — the pure-Dart scan-converter. Test support; never in `lib/`.
- `packages/jet_cad_2d_flutter/test/support/sink_comparison.dart` — the ink-region membership comparison and its fixture.
- `packages/jet_cad_2d_flutter/test/sink_comparison_test.dart`
- `packages/jet_cad_2d_flutter/test/vertices_join_test.dart`
- `packages/jet_cad_2d_flutter/test/golden/vertices/` — the second set of golden PNGs, one per existing fixture.
- `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
- `docs/superpowers/notes/plan-3d-mutation-log.md`
- `docs/superpowers/notes/2026-08-2X-plan-3d-results.md` (Task 14 writes it; the date is the day it runs)

**Modified:**
- `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` — the stale class comment, `dispose`, the `Paint` field, the shared join walk, the flush observer.
- `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart` — `point` emits an axis-aligned device-space square.
- `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart` — `useVertices` becomes `RenderBackend? backend`; `resolvedBackend` on the state.
- `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart` — export `render_backend.dart`.
- `packages/jet_cad_2d_flutter/test/golden/*_golden_test.dart` — a backend parameter on each of the three ladders.
- `apps/dev_harness_2d/lib/main.dart` — `VERTICES` becomes `BACKEND`.
- `apps/dev_harness_2d/integration_test/frame_timing_test.dart` — report the resolved backend.

---

# Phase A — the sink

### Task 1: `RenderBackend`, one resolution point

The spike chose its sink with `bool useVertices`. A `bool` cannot name a third
backend and, more importantly, nothing stopped a second call site from deciding
for itself. This replaces it with an enum resolved in one function.

The task also fixes `vertices_draw_sink.dart`'s class comment, which has been
false since curves started batching and which caused one review of the spec to
report an ordering defect that does not exist.

**Files:**
- Create: `packages/jet_cad_2d_flutter/lib/src/render_backend.dart`
- Create: `packages/jet_cad_2d_flutter/test/render_backend_test.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart` (comment only)

**Interfaces:**
- Produces: `enum RenderBackend { canvas, vertices }`;
  `RenderBackend defaultRenderBackend()`;
  `DraftCanvas({..., RenderBackend? backend})`;
  `RenderBackend DraftCanvasState.resolvedBackend`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/render_backend_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

Future<DraftCanvasState> _pump(WidgetTester tester,
    {RenderBackend? backend}) async {
  final doc = generateDocument(40, dashedFraction: 0.5);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(
      ViewportTransform.fit(doc.extents, const Size(300, 300)));
  addTearDown(camera.dispose);
  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 300,
      height: 300,
      child: DraftCanvas(
          key: key,
          document: doc,
          index: index,
          camera: camera,
          backend: backend),
    ),
  ));
  return key.currentState!;
}

void main() {
  test('the platform default is vertices everywhere but the web', () {
    // `kIsWeb` is false under `flutter_test`, so this pins the branch the
    // suite runs on; the web branch is pinned by reading `kIsWeb` back.
    expect(defaultRenderBackend(),
        kIsWeb ? RenderBackend.canvas : RenderBackend.vertices);
  });

  testWidgets('with no backend given, the widget resolves the platform default',
      (tester) async {
    final state = await _pump(tester);
    expect(state.resolvedBackend, defaultRenderBackend());
  });

  testWidgets('an explicit backend is honoured, not clamped', (tester) async {
    // Phase C forces `vertices` on the web to measure it. A parameter that
    // silently ignored what it was given would make that measurement a lie.
    for (final backend in RenderBackend.values) {
      final state = await _pump(tester, backend: backend);
      expect(state.resolvedBackend, backend, reason: '$backend');
    }
  });

  testWidgets('only the resolved backend builds a sink', (tester) async {
    // MUTATION: build both sinks unconditionally and this reads non-null in
    // the canvas row. Two live sinks is two paragraph caches and two buffers.
    final vertices = await _pump(tester, backend: RenderBackend.vertices);
    expect(vertices.vertices, isNotNull);

    final canvas = await _pump(tester, backend: RenderBackend.canvas);
    expect(canvas.vertices, isNull);
  });

  testWidgets('changing the backend prop rebuilds the sinks', (tester) async {
    // MUTATION: leave `backend` out of `didUpdateWidget`'s comparison and the
    // widget keeps drawing through the old sink after the prop changes.
    final doc = generateDocument(40, dashedFraction: 0.5);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final camera = CameraController(
        ViewportTransform.fit(doc.extents, const Size(300, 300)));
    addTearDown(camera.dispose);
    final key = GlobalKey<DraftCanvasState>();

    Widget build(RenderBackend backend) => Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 300,
            height: 300,
            child: DraftCanvas(
                key: key,
                document: doc,
                index: index,
                camera: camera,
                backend: backend),
          ),
        );

    await tester.pumpWidget(build(RenderBackend.canvas));
    expect(key.currentState!.vertices, isNull);
    await tester.pumpWidget(build(RenderBackend.vertices));
    expect(key.currentState!.vertices, isNotNull);
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/render_backend_test.dart
```

Expected: a compile error, `Undefined name 'defaultRenderBackend'` and
`No named parameter with the name 'backend'`.

- [ ] **Step 3: Create the backend file**

`packages/jet_cad_2d_flutter/lib/src/render_backend.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

/// Which sink `DraftCanvas` draws through.
///
/// An enum and not a `bool` because a third backend is foreseeable —
/// `flutter_gpu` ships in the SDK — and because a `bool` named for one of the
/// two options reads wrong the moment there is a third.
enum RenderBackend {
  /// `CanvasDrawSink`: one `drawPath` per primitive. The web renderer, and the
  /// fallback everywhere.
  canvas,

  /// `VerticesDrawSink`: the frame's strokes as one ordered `drawVertices`.
  vertices,
}

/// The backend a platform gets when the caller does not say.
///
/// **The only place this decision is made.** Two call sites that each decided
/// would eventually disagree, and the disagreement would show as a drawing
/// that changes when a widget is rebuilt somewhere unrelated.
///
/// Web gets the canvas backend because Impeller is not on the web — the engine
/// FAQ records interfacing the web engine with Impeller as a non-goal — and
/// CanvasKit's `drawVertices` is unmeasured. Phase C measures it; until then
/// the platform that has no Impeller gets the path that never needed one.
RenderBackend defaultRenderBackend() =>
    kIsWeb ? RenderBackend.canvas : RenderBackend.vertices;
```

- [ ] **Step 4: Wire it into `DraftCanvas`**

In `packages/jet_cad_2d_flutter/lib/src/draft_canvas.dart`, add the import
`import 'render_backend.dart';`, then replace the `useVertices` parameter and
field:

```dart
    this.drawText = true,
    this.backend,
  });
```

```dart
  /// Which sink draws the frame, or `null` for [defaultRenderBackend].
  ///
  /// A non-null value is honoured on **every** platform, including
  /// `RenderBackend.vertices` on the web. It is not clamped: Plan 3d's Phase C
  /// forces it to measure CanvasKit, and a parameter that silently ignored
  /// what it was given would make that measurement report the wrong thing.
  final RenderBackend? backend;
```

In `DraftCanvasState`, replace the `vertices` field's initialiser in `_attach`
and add the resolved backend:

```dart
  /// The backend this state actually built, resolved once in [_attach].
  ///
  /// Public so a rig reports what it measured rather than what it asked for.
  late RenderBackend resolvedBackend;
```

```dart
    resolvedBackend = widget.backend ?? defaultRenderBackend();
    vertices = resolvedBackend == RenderBackend.vertices
        ? VerticesDrawSink(
            pixelsPerPaperMm: widget.pixelsPerPaperMm,
            lineweightScale: widget.lineweightScale,
            fallback: sink)
        : null;
```

In `didUpdateWidget`, add `widget.backend != oldWidget.backend` to the
condition that calls `_attach()`.

- [ ] **Step 5: Export it**

In `packages/jet_cad_2d_flutter/lib/jet_cad_2d_flutter.dart`, add
`export 'src/render_backend.dart';` in alphabetical position.

- [ ] **Step 6: Fix the stale class comment**

In `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`, replace the
"What this is not" bullet that begins **"Points, circles, arcs and text still
go to [CanvasDrawSink]"** with:

```dart
/// - **Text goes to [CanvasDrawSink], and the buffer flushes before it.**
///   A paragraph is not triangles. Points, circles and arcs are batched;
///   only text falls back, and flushing first is what keeps a stroke batched
///   before a text op from drawing after it.
```

Then add, to the same list:

```dart
/// - **This sink is authoritative where it disagrees with [CanvasDrawSink].**
///   Under a non-conformal residual the two draw different stroke widths, and
///   this one is right: `CanvasDrawSink._widthFor` divides by
///   `scaleMagnitude`, one scalar standing in for two axis scales. The full
///   list of permitted divergences is in Plan 3d's design document; anything
///   not on it is a defect.
```

- [ ] **Step 7: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/render_backend_test.dart
```

Expected: 5 tests pass.

- [ ] **Step 8: Run both suites green**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

The harness will not compile yet — it still passes `useVertices`. Task 6 fixes
it; until then `apps/dev_harness_2d` is expected red and its analyze is **not**
part of this task's gate.

- [ ] **Step 9: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib packages/jet_cad_2d_flutter/test/render_backend_test.dart
git commit -m "feat: resolve the render backend in one place

A `bool useVertices` could not name a third backend and did not stop a second
call site from deciding for itself. `RenderBackend` is resolved by
`defaultRenderBackend()` and nowhere else, and an explicit value is honoured on
every platform because Phase C forces `vertices` on the web to measure it.

Also fixes the sink's class comment, false since curves started batching, which
led one review of the design to report an ordering defect that does not exist."
```

---

### Task 2: Dispose the submitted `Vertices`

`Vertices` extends `NativeFieldWrapperClass1` and carries a real `dispose()`
over the native symbol `Vertices::dispose`. `flush()` builds one per flush and
drops it. At 19 flushes a frame and 60 frames a second that is about 1,140
undisposed native-backed objects a second, each holding the frame's position
and colour buffers, reclaimed only when a finalizer runs.

**The open question is settled by test, not by reading:** may a `Vertices` be
disposed immediately after the `drawVertices` that submitted it, or does the
recorded output still refer to it? Step 1 asks a `PictureRecorder`; step 7 asks
a real device, because a recorder may retain what a rasterisation does not.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Consumes: `VerticesDrawSink.flush()` from the spike.
- Produces: `bool VerticesDrawSink.lastFlushDisposed` — whether the last
  submitted `Vertices` was disposed, so a test can assert it without holding
  the object.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`,
inside `main()`:

```dart
  test('the submitted Vertices is disposed, and the picture still records', () {
    // `Vertices` is native-backed: `dispose()` frees the position and colour
    // buffers the engine holds, and dropping the object instead leaves them to
    // a finalizer. At 19 flushes a frame that is about 1,140 a second.
    //
    // MUTATION: drop the dispose call and `lastFlushDisposed` reads false.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)..beginResidual(Transform2.identity());
    for (var i = 0; i < 5; i++) {
      sink.polyline(_seg(0, i * 1.0, 10, i * 1.0), 2, _style(), closed: false);
    }
    sink.endResidual();
    sink.flush();

    expect(sink.lastFlushDisposed, isTrue);
    // The recording must survive the dispose. If `drawVertices` had kept a
    // live reference rather than copying, this throws.
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);
    expect(picture, isNotNull);
  });

  test('a flush with nothing batched disposes nothing', () {
    // MUTATION: dispose unconditionally and this throws on a null.
    final recorder = PictureRecorder();
    final sink = _sink(canvas: Canvas(recorder));
    sink.flush();
    expect(sink.flushCallCount, 0);
    expect(sink.lastFlushDisposed, isFalse);
    recorder.endRecording().dispose();
  });
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: `The getter 'lastFlushDisposed' isn't defined for the type
'VerticesDrawSink'`.

- [ ] **Step 3: Implement**

In `vertices_draw_sink.dart`, add the field beside the other flush counters:

```dart
  bool _lastFlushDisposed = false;
```

and the accessor beside `lastFlushVertexCount`:

```dart
  /// Whether the last [flush] disposed the `Vertices` it submitted.
  ///
  /// Exposed rather than the object itself, because the object is gone by the
  /// time anything could read it — which is the point.
  bool get lastFlushDisposed => _lastFlushDisposed;
```

In `flush()`, set it false on entry beside `_flushCalls = 0;`, then replace the
submission with:

```dart
    final vertices = Vertices.raw(
      VertexMode.triangles,
      positions,
      colors: colors,
    );
    canvas.drawVertices(vertices, BlendMode.dst, _paint);
    // `drawVertices` has taken what it needs by the time it returns; holding
    // the object past that point holds native buffers the engine has already
    // copied. Verified against a `PictureRecorder` here and on a device in
    // Plan 3d Task 2 step 7.
    vertices.dispose();
    _lastFlushDisposed = true;
```

(The `_paint` field arrives in Task 3; until then leave the inline
`Paint()..color = const Color(0xFFFFFFFF)` exactly as the spike has it.)

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: 26 tests pass.

**If the recording throws instead**, the answer to the open question is "no".
Do not force it. Change the implementation to hold the previous flush's
`Vertices` in a field and dispose it at the *start* of the next flush, keep
`lastFlushDisposed` meaning "the previous one was disposed", adjust the two
tests to match, and record the finding in the task's commit message. One frame
of native memory outstanding is the cost; 1,140 a second is not.

- [ ] **Step 5: Run both suites green**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart
git commit -m "fix: dispose the Vertices each flush submits

`Vertices` is native-backed and carries a real `dispose()` over
`Vertices::dispose`. The spike built one per flush and dropped it: about 1,140
undisposed objects a second at 60 fps, each holding that frame's position and
colour buffers until a finalizer ran.

Whether it may be disposed at submission was an open question in the design and
is now answered by test rather than by reading."
```

- [ ] **Step 7: Verify on a device, not only in a recorder**

A `PictureRecorder` may retain what a real rasterisation does not, so the
recorder test is necessary and not sufficient.

```sh
cd apps/dev_harness_2d
flutter run --profile -d macos --dart-define=TEXT=true --dart-define=ENTITIES=10000
```

Pan and zoom for about thirty seconds. Expected: the drawing renders, no crash,
no blank frames. Then quit, and **revert the CocoaPods rewrite**:

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
git status --porcelain   # must be clean
```

Record what you saw in the task's report. A crash or a blank frame here means
the recorder answered a different question from the rasteriser, and the "hold
one frame" fallback in step 4 applies.

---

### Task 3: Hoist the `Paint`, and measure what a frame allocates

Two things that belong together: the one allocation that can simply be removed,
and the measurement that says what is left.

`CanvasDrawSink` holds one `Paint` for the life of the sink and rewrites it per
op — "the whole reason this is an object", as its comment says. The vertices
sink builds one per flush for no reason.

Then the measurement. `CLAUDE.md` says the frame path allocates nothing in
steady state, and `query_allocation_test.dart` measures the *query* path.
Nobody has measured the paint path through either sink.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`

**Interfaces:**
- Consumes: `VerticesDrawSink.flush()`, `NullDrawSink`, `DraftPainter.paint`.
- Produces: nothing other tasks depend on.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`:

```dart
// What a steady-state frame allocates through each sink.
//
// `CLAUDE.md`: "The frame path allocates nothing in steady state."
// `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` measures the
// query path and stops there. This measures the paint path, which is the half
// the vertices sink changes.
//
// The number is a *ratio against a control*, never an absolute: the VM's
// allocation profiler has a documented low-read artefact, and a run that reads
// low on both the control and the subject still reports the right ratio.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d/testing.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const Size _viewport = Size(800, 600);

DraftDocument _corpus() => generateDocument(
      4000,
      definitionCount: 40,
      instanceCount: 400,
      nestingDepth: 2,
      mirroredFraction: 0.1,
      nonUniformFraction: 0.2,
      groupCount: 10,
      layerCount: 8,
      byBlockFraction: 0.3,
      dashedFraction: 0.35,
    );

void main() {
  testWidgets('a steady-state frame allocates O(1) per flush, not O(entities)',
      (tester) async {
    final doc = _corpus();
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final painter = DraftPainter(
        document: doc, index: index, resolver: DocumentStyleResolver(doc));
    final camera = ViewportTransform.fit(doc.extents, _viewport);

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = VerticesDrawSink(
        pixelsPerPaperMm: kLogicalPixelsPerMm, canvas: canvas);

    // Warm up: the first frame grows the buffers, and growth is exactly what
    // the steady state is defined as being past.
    for (var i = 0; i < 3; i++) {
      painter.paint(sink, camera, _viewport);
      sink.flush();
    }

    // The subject frame. Flushes are counted, not assumed: the assertion below
    // is in units of flushes, so a frame that stopped flushing would make it
    // vacuous.
    sink.resetCounters();
    painter.paint(sink, camera, _viewport);
    sink.flush();

    expect(sink.totalFlushCount, greaterThan(0),
        reason: 'nothing was flushed, so nothing was measured');
    expect(sink.frameSegmentCount, greaterThan(1000),
        reason: 'a degenerate corpus would make the bound meaningless');

    // The buffer must not have grown in the subject frame. Growth is the one
    // O(entities) allocation this sink can make, and it is the one the
    // steady-state claim is about.
    final before = sink.debugCapacityVertices;
    painter.paint(sink, camera, _viewport);
    sink.flush();
    expect(sink.debugCapacityVertices, before,
        reason: 'the buffer grew in a steady-state frame, so the frame path '
            'allocates O(entities) and not O(1)');

    recorder.endRecording().dispose();
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
```

Expected: `The getter 'debugCapacityVertices' isn't defined`.

- [ ] **Step 3: Implement**

In `vertices_draw_sink.dart`, add the capacity accessor beside the other debug
accessors:

```dart
  /// Vertices the buffers can hold without growing.
  ///
  /// The steady-state claim is that this stops changing: `_reserve` doubles
  /// and never gives capacity back, so once a frame has drawn its widest view
  /// the buffer is large enough for every later one.
  int get debugCapacityVertices => _colors.length;
```

Replace the per-flush `Paint` with a field, beside the buffers:

```dart
  /// One paint for the life of the sink, as on [CanvasDrawSink].
  ///
  /// It never varies: the colour rides on the vertices, so the only thing the
  /// paint contributes is its alpha, and that is always opaque.
  final Paint _paint = Paint()..color = const Color(0xFFFFFFFF);
```

and in `flush()` pass `_paint` where the literal was.

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/invariants/paint_allocation_test.dart
```

Expected: 1 test passes.

- [ ] **Step 5: Count what is left, and write it down**

Read `flush()` and count the objects it still allocates per call. As of this
task they are: the `Vertices.raw`, and the two `Float32List.sublistView` /
`Int32List.sublistView` wrappers it is built from. Three, per flush.

Add the count to the sink's class comment, as a fact with a date:

```dart
/// ## What a steady-state frame allocates
///
/// Three objects per flush — the `Vertices` and the two `sublistView`
/// wrappers — and nothing per entity. The buffers themselves are grown once
/// and reused; `test/invariants/paint_allocation_test.dart` fails if they grow
/// in a steady-state frame. With text in the corpus a frame flushes once per
/// text op plus once at the end, so the frame's total is
/// `3 * (textOps + 1)`.
```

- [ ] **Step 6: Run both suites green**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart
git commit -m "test: measure what the paint path allocates, and hoist the Paint

The allocation invariant covered the query path and stopped there. This
measures the paint path and pins the property the steady-state claim actually
rests on: the buffers stop growing.

The per-flush Paint is now a field, as it is on CanvasDrawSink. What is left is
three objects per flush and nothing per entity, written into the class comment
as a dated fact rather than left for a reader to count."
```

- [ ] **Step 8: Stop. Do not amend `CLAUDE.md`.**

The residue is O(1) per flush and not zero. `CLAUDE.md` says *nothing*.

**The plan does not resolve this.** Report the measured number — three per
flush, `3 * (textOps + 1)` per frame — to the human running the plan, with the
proposed amendment wording:

> **The frame path allocates nothing per entity in steady state, and O(1) per
> flush.** `packages/jet_cad_2d/test/invariants/query_allocation_test.dart` and
> `packages/jet_cad_2d_flutter/test/invariants/paint_allocation_test.dart`
> measure it.

and wait for an explicit yes or no. If yes, amend `CLAUDE.md` in its own commit
that changes nothing else. If no, exit criterion 7 fails and Plan 3d stops at
Task 14 with that recorded as its result.

An exit gate that can be passed by editing the rule it is measured against is
not a gate.

---

### Task 4: Joins — one walk, miter and bevel

Every segment is an independent quad today, so a polyline's corners have a
notch on the outside. This closes it, once, for both walks.

**A miter is two triangles.** The notch at a vertex is the quadrilateral
`(V, A, M, B)`: the vertex, the outer corner of the incoming segment, the miter
point, and the outer corner of the outgoing one. Filling it takes the **bevel
triangle `(V, A, B)`** and the **tip triangle `(A, M, B)`**. The tip alone
leaves a hairline crack along `AB` at every mitred corner — invisible to a test
that counts triangles, obvious in a golden at a visible lineweight.

**The run state lives in fields, not in an object.** A `_StrokeRun` allocated
per polyline would put an allocation back on the frame path, which Task 3 has
just finished measuring.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/test/vertices_join_test.dart`

**Interfaces:**
- Consumes: `_emitSegment` from the spike.
- Produces: `VerticesDrawSink.kMiterLimit`, `VerticesDrawSink.kMinMiterCosine`.
  Task 5 consumes `_beginRun` / `_runTo` / `_endRun`.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/vertices_join_test.dart`:

```dart
// Joins. Every case here is at a lineweight where the corner is several pixels
// across, because a join is invisible at a hairline and most of a CAD drawing
// is hairlines — a fixture at the shipped corpus's widths would pass with the
// join code deleted.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/src/vertices_draw_sink.dart';

/// 1.0 mm at 4 px/mm is 4 logical pixels, so the half-width is 2 and every
/// expected coordinate below is exact in binary.
const _lw = 100;
const _pxPerMm = 4.0;
const _half = 2.0;

ResolvedStyle _style({int argb = 0xFF000000}) => ResolvedStyle(
      argb: argb,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

VerticesDrawSink _sink() => VerticesDrawSink(pixelsPerPaperMm: _pxPerMm);

Float64List _pts(List<double> xy) => Float64List.fromList(xy);

int _triangleCount(VerticesDrawSink s) => s.debugPositions().length ~/ 6;

/// Whether any emitted triangle contains the point.
bool _inked(VerticesDrawSink s, double px, double py) {
  final v = s.debugPositions();
  for (var i = 0; i + 5 < v.length ~/ 2; i += 3) {
    final ax = v[i * 2], ay = v[i * 2 + 1];
    final bx = v[i * 2 + 2], by = v[i * 2 + 3];
    final cx = v[i * 2 + 4], cy = v[i * 2 + 5];
    double edge(double x0, double y0, double x1, double y1) =>
        (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0);
    final d1 = edge(ax, ay, bx, by);
    final d2 = edge(bx, by, cx, cy);
    final d3 = edge(cx, cy, ax, ay);
    const eps = 1e-2;
    final neg = d1 < -eps || d2 < -eps || d3 < -eps;
    final pos = d1 > eps || d2 > eps || d3 > eps;
    if (!(neg && pos)) return true;
  }
  return false;
}

void main() {
  test('the miter limit and its cosine are Impellers own', () {
    // painting.dart:1535 and stroke_path_geometry.cc:442. Written down as a
    // test so a change to either constant is a red test rather than a drawing
    // that quietly stops matching CanvasDrawSink.
    expect(VerticesDrawSink.kMiterLimit, 4.0);
    expect(VerticesDrawSink.kMinMiterCosine, closeTo(-0.875, 1e-12));
  });

  test('a right-angle corner is mitred out to the square corner', () {
    // P(0,0) -> V(10,0) -> Q(10,10) turns left, so the outer side is the right
    // one and the miter point is the outer corner of the square: (12, -2).
    //
    // MUTATION: take the miter on the inside of the turn and this reads (8, 2).
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter tip');
    expect(_inked(sink, 8.0, 2.0), isFalse, reason: 'the inside of the turn');
  });

  test('a mitred corner emits both the bevel and the tip triangle', () {
    // MUTATION: emit the tip triangle alone and the point just inside the
    // bevel wedge -- between the vertex and the chord AB -- goes uninked.
    // That is the hairline crack.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();

    // Two segments are 4 triangles; the join adds 2.
    expect(_triangleCount(sink), 6);
    // A = (10, -2), B = (12, 0), V = (10, 0). The wedge's centroid.
    expect(_inked(sink, 10.6, -0.6), isTrue, reason: 'the bevel wedge');
  });

  test('a corner past the miter limit is bevelled, one triangle', () {
    // A 170-degree direction change: dot = cos(170 deg) = -0.985, below
    // -0.875.
    //
    // MUTATION: miter every corner and this reads 6 triangles and a spike
    // reaching about 23 units out.
    const a = 170 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(
          _pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]), 3,
          _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 5, reason: '4 for the segments, 1 bevel');
  });

  test('a corner just inside the limit is still mitred', () {
    // 150 degrees: dot = -0.866, above -0.875. The boundary is a real edge and
    // both sides of it are pinned.
    //
    // MUTATION: bevel every corner and this reads 5.
    const a = 150 * math.pi / 180;
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(
          _pts([0, 0, 10, 0, 10 + 10 * math.cos(a), 10 * math.sin(a)]), 3,
          _style(),
          closed: false)
      ..endResidual();

    expect(_triangleCount(sink), 6);
  });

  test('an open polyline gets no join between its ends', () {
    // MUTATION: join the first and last segment of an open run and this reads
    // 8 -- the L gets a phantom corner at the origin.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
  });

  test('a zero-length step is skipped and the join spans it', () {
    // A repeated point carries no direction. Skipping it must not also skip
    // the corner it sits on.
    //
    // MUTATION: return early from the whole run on a zero-length step and the
    // second segment and its join both vanish.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 10, 0, 10, 0, 10, 10]), 4, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6);
    expect(_inked(sink, 11.5, -1.5), isTrue, reason: 'the miter still fires');
  });

  test('joins are emitted under the residual, not in local space', () {
    // Degenerate-fixture guard: every case above is at the identity, and a
    // join computed before the transform would pass all of them.
    //
    // MUTATION: compute the join from local-space directions and the miter
    // lands at (2, 12) instead.
    const t = Transform2(0, 1, -1, 0, 0, 0); // quarter turn
    final sink = _sink()
      ..beginResidual(t)
      ..polyline(_pts([0, 0, 10, 0, 10, 10]), 3, _style(), closed: false)
      ..endResidual();
    // (12, -2) rotated a quarter turn is (2, 12).
    expect(_inked(sink, 1.5, 11.5), isTrue);
  });

  test('a flattened curve joins its chords', () {
    // MUTATION: skip the join between two chords and a thick arc shows a notch
    // at every one of them. Sampled just outside the chord and inside the
    // stroke, at the arc's midpoint.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..arc(0, 0, 40, 0, math.pi / 2, _style())
      ..endResidual();

    // The outer edge of the stroke at 45 degrees is at radius 42, and the
    // chord there falls short of it by the sag. Without joins that sliver is
    // uninked.
    final r = 40 + _half - 0.15;
    expect(_inked(sink, r * math.cos(math.pi / 4), r * math.sin(math.pi / 4)),
        isTrue);
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart
```

Expected: `kMiterLimit` undefined, and the triangle-count assertions read 4
where they expect 6 — no joins exist yet.

- [ ] **Step 3: Add the constants**

In `vertices_draw_sink.dart`, beside `kMinStrokeDevicePixels`:

```dart
  /// Flutter's default miter limit (`painting.dart:1535`).
  static const double kMiterLimit = 4.0;

  /// The cosine of the direction change at which a miter becomes a bevel.
  ///
  /// Impeller's own conversion of the limit: `2 * (1 / limit)^2 - 1`
  /// (`stroke_path_geometry.cc:442`). At a limit of 4 that is -0.875, so a
  /// corner is mitred up to about a 151-degree turn and bevelled past it.
  static const double kMinMiterCosine =
      2.0 * (1.0 / kMiterLimit) * (1.0 / kMiterLimit) - 1.0;
```

- [ ] **Step 4: Add the run state and the shared walk**

Fields, beside the buffers:

```dart
  // Run state. Fields and not a per-run object, because a `_StrokeRun`
  // allocated per polyline would put an allocation back on the frame path
  // that `paint_allocation_test.dart` has just finished pinning at zero.
  double _runFirstX = 0, _runFirstY = 0;
  double _runFirstDx = 0, _runFirstDy = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runPrevDx = 0, _runPrevDy = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;
```

Methods:

```dart
  /// Starts a connected run at a device-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run to a device-space point, emitting the join first.
  ///
  /// The join comes before the segment so the buffer's order is the drawing's
  /// order: at a corner the ink nearer the start of the run is written first.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    final length = math.sqrt(dx * dx + dy * dy);
    // A repeated point carries no direction. Skip the step, keep the previous
    // direction, and let the join span it — the corner is still there.
    if (length == 0) return;
    final ux = dx / length, uy = dy / length;

    if (_runHasDirection) {
      _emitJoin(_runPrevX, _runPrevY, _runPrevDx, _runPrevDy, ux, uy, half,
          argb);
    } else {
      _runFirstDx = ux;
      _runFirstDy = uy;
    }
    _emitQuad(_runPrevX, _runPrevY, x, y, ux, uy, half, argb);

    _runPrevX = x;
    _runPrevY = y;
    _runPrevDx = ux;
    _runPrevDy = uy;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all. The closed
  /// case — a closing segment and a seam join — is Task 5; it asserts here so
  /// a caller that reaches it before then fails loudly rather than silently
  /// dropping the closing segment the spike used to emit.
  void _endRun({required bool closed, required double half, required int argb}) {
    assert(!closed, 'closed runs arrive in Task 5');
  }
```

- [ ] **Step 5: Add the join itself**

```dart
  /// Fills the notch at a vertex between two unit directions.
  ///
  /// The notch is the quadrilateral `(V, A, M, B)` — vertex, outer corner of
  /// the incoming segment, miter point, outer corner of the outgoing one — so
  /// a miter is **two** triangles: the bevel `(V, A, B)` and the tip
  /// `(A, M, B)`. The tip alone leaves a hairline crack along `AB`.
  void _emitJoin(double vx, double vy, double d0x, double d0y, double d1x,
      double d1y, double half, int argb) {
    final cross = d0x * d1y - d0y * d1x;
    // Collinear: either straight through, where the quads already meet, or a
    // reversal, where both the miter and the bevel are degenerate.
    if (cross == 0) return;

    // The outer side of the turn is the one away from it: a left turn
    // (cross > 0) opens a notch on the right.
    final s = cross > 0 ? -half : half;
    final n0x = -d0y * s, n0y = d0x * s;
    final n1x = -d1y * s, n1y = d1x * s;
    final ax = vx + n0x, ay = vy + n0y;
    final bx = vx + n1x, by = vy + n1y;

    _emitTriangle(vx, vy, ax, ay, bx, by, argb);

    if (d0x * d1x + d0y * d1y < kMinMiterCosine) return;

    var mx = n0x + n1x, my = n0y + n1y;
    final mlen = math.sqrt(mx * mx + my * my);
    if (mlen == 0) return;
    mx /= mlen;
    my /= mlen;
    // `n0` has length `half`, so this is the cosine of half the included angle.
    final cosHalf = (mx * n0x + my * n0y) / half;
    if (cosHalf <= 0) return;
    final reach = half / cosHalf;
    _emitTriangle(ax, ay, vx + mx * reach, vy + my * reach, bx, by, argb);
  }

  /// Writes one triangle, six floats and three colours.
  void _emitTriangle(double ax, double ay, double bx, double by, double cx,
      double cy, int argb) {
    _reserve(3);
    final v = _positions;
    var i = _vertices * 2;
    v[i++] = ax;
    v[i++] = ay;
    v[i++] = bx;
    v[i++] = by;
    v[i++] = cx;
    v[i++] = cy;
    final colors = _colors;
    for (var k = _vertices; k < _vertices + 3; k++) {
      colors[k] = argb;
    }
    _vertices += 3;
    _frameSegments++;
  }
```

- [ ] **Step 6: Split `_emitSegment` so the direction is computed once**

Rename the body that takes a precomputed unit direction to `_emitQuad`, and
keep `_emitSegment` as the wrapper `point()` still uses:

```dart
  /// Two triangles around a segment whose unit direction is already known.
  void _emitQuad(double x0, double y0, double x1, double y1, double ux,
      double uy, double half, int argb) {
    final nx = -uy * half, ny = ux * half;
    // ... the existing twelve writes, unchanged, using nx and ny ...
  }

  /// Two triangles around a segment, taking its direction from its endpoints.
  void _emitSegment(double x0, double y0, double x1, double y1, double half,
      int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length == 0) return;
    _emitQuad(x0, y0, x1, y1, dx / length, dy / length, half, argb);
  }
```

- [ ] **Step 7: Route `polyline` through the run**

```dart
    var px = a * points[0] + c * points[1] + e;
    var py = b * points[0] + d * points[1] + f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final qx = a * points[i * 2] + c * points[i * 2 + 1] + e;
      final qy = b * points[i * 2] + d * points[i * 2 + 1] + f;
      _runTo(qx, qy, half, argb);
    }
    _endRun(closed: false, half: half, argb: argb);
    // The spike's closing segment moves to Task 5 with its seam join, so a
    // closed polyline draws one segment short until then. No caller reaches
    // it: `closed:` is `false` at all four of the painter's call sites, and
    // the one unit test that passes `closed: true` moves to Task 5 with it.
```

Delete the now-unused `px`/`py` reassignment and the old `if (closed)` line.
In `vertices_draw_sink_test.dart`, move the `closed: true` half of
`'a polyline of n points emits n-1 segments, and closed adds one more'` into a
skipped test named for Task 5, or delete that half and let Task 5 restore it —
whichever the implementer prefers, but say which in the commit.

- [ ] **Step 8: Route `_flatten` through the same run**

```dart
    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    _beginRun(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f);
    for (var i = 1; i <= steps; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      _runTo(t.a * lx + t.c * ly + t.e, t.b * lx + t.d * ly + t.f, half, argb);
    }
    _endRun(closed: false, half: half, argb: argb);
```

A full sweep's last sample is its first point, so the run closes itself
geometrically and the seam is still unjoined. That is Task 5's, and
`closed: false` here says so rather than pretending otherwise. Keep the
existing `assert(!closed || (sweep - 2 * math.pi).abs() < 1e-9)` until Task 5
replaces it.

- [ ] **Step 9: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart
```

Expected: 9 tests pass.

- [ ] **Step 10: Run the whole suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```

`vertices_draw_sink_test.dart`'s segment-count assertions now include join
triangles. **Do not loosen them.** Update each to the new exact count and add
one sentence saying which of the triangles are joins, so the number still
describes something. `frameSegmentCount` counts triangles rather than segments
now — rename it to `frameTriangleCount`, update the two rig call sites in
`apps/dev_harness_2d/integration_test/frame_timing_test.dart`, and say so in
the accessor's doc comment.

- [ ] **Step 11: Run both suites green, then commit**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test
git commit -m "feat: miter and bevel joins, shared by both stroke walks

Every segment was an independent quad, so a corner had a notch on the outside.
The join is emitted by one run walk that both `polyline` and `_flatten` drive,
because a thick polyline with joins beside a thick arc without them is the
failure a second implementation invites.

A miter is two triangles. The notch is the quadrilateral (V, A, M, B), so it
takes the bevel triangle and the tip triangle; the tip alone leaves a hairline
crack along AB at every mitred corner, which no triangle count would catch.

The limit is Impeller's: 4.0, converted to a cosine of -0.875 by its own
formula, so a corner mitres up to about a 151-degree turn. Both sides of that
boundary are pinned.

Run state is fields rather than a per-run object; an object here would put an
allocation back on the frame path that the previous task just measured at zero."
```

---

### Task 5: The seam — closed runs join instead of capping

A circle is a `_flatten` at a full sweep. Its last chord lands on its first
point, so the ring closes geometrically — and the corner there is a corner like
any other. Without a join, **every circle at a visible lineweight carries a
notch at its start angle**, and a start angle is not a thing a user chose.

The closed polyline is the same branch. The painter never calls it (`closed:`
is `false` at all four sites) but a test reaches it directly, so it lands with
a mutant rather than as unreached code. The spike already carried one
not-applicable mutant for exactly this branch; this task is why there is not a
second.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_join_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Consumes: `_beginRun` / `_runTo` / `_endRun` / `_emitJoin` from Task 4.
- Produces: nothing new; `_endRun`'s `closed` parameter becomes live.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d_flutter/test/vertices_join_test.dart`:

```dart
  test('a circle joins at its seam, so there is no notch at the start angle',
      () {
    // A circle is a full-sweep flatten whose last chord lands on its first
    // point. The corner there is a corner, and it is the one that is easy to
    // forget because no vertex list contains it.
    //
    // MUTATION: end a closed run without the seam join and the sample just
    // outside the two chords that meet at angle 0 goes uninked.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..circle(0, 0, 40, _style())
      ..endResidual();

    // Just inside the outer edge of the stroke, on the seam's bisector — the
    // notch's deepest point if the join is missing.
    expect(_inked(sink, 40 + _half - 0.15, 0.0), isTrue);
  });

  test('the seam is one join, not two, and not a cap', () {
    // MUTATION: emit the closing segment without the join and this reads one
    // triangle pair short; MUTATION: join both ends and it reads two too many.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0, 30, 30, 0, 30]), 4, _style(), closed: true)
      ..endResidual();

    // Four segments (8 triangles) and four corners (2 triangles each, all four
    // right angles so all four mitre).
    expect(_triangleCount(sink), 8 + 8);
  });

  test('an open run of the same points has three corners, not four', () {
    // The control for the row above: the difference between them is exactly
    // the closing segment and its seam.
    //
    // MUTATION: treat every run as closed and this reads 16.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0, 30, 30, 0, 30]), 4, _style(), closed: false)
      ..endResidual();
    expect(_triangleCount(sink), 6 + 6);
  });

  test('a closed run of two points closes without a phantom seam', () {
    // Two points make one segment out and one back along the same line. There
    // is no corner: both joins are reversals, and a reversal is degenerate.
    //
    // MUTATION: drop the `_runSegments >= 2` guard and this throws or emits a
    // triangle at a NaN.
    final sink = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(_pts([0, 0, 30, 0]), 2, _style(), closed: true)
      ..endResidual();
    for (final v in sink.debugPositions()) {
      expect(v.isFinite, isTrue);
    }
  });
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart
```

Expected: the circle row fails its `_inked` assertion, and the closed-polyline
rows trip Task 4's `assert(!closed, 'closed runs arrive in Task 5')`.

- [ ] **Step 3: Implement the closed branch**

Replace Task 4's placeholder `_endRun`:

```dart
  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all. A closed run
  /// gets the segment back to its first point and then the seam join — the
  /// corner no vertex list contains, and the one whose absence puts a notch on
  /// every circle at its start angle.
  void _endRun({required bool closed, required double half, required int argb}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Two segments is the floor: with one, both joins are reversals and a
    // reversal has no miter and no bevel.
    if (_runSegments >= 2) {
      _emitJoin(_runFirstX, _runFirstY, _runPrevDx, _runPrevDy, _runFirstDx,
          _runFirstDy, half, argb);
    }
  }
```

- [ ] **Step 4: Close the flatten**

In `_flatten`, stop one sample short when closed and let `_endRun` close it, so
the seam is a join and not a duplicated point:

```dart
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
```

and pass the flag through:

```dart
    _endRun(closed: closed, half: half, argb: argb);
```

Delete the `assert(!closed || (sweep - 2 * math.pi).abs() < 1e-9)`: `closed` is
a branch now, not documentation.

- [ ] **Step 5: Restore the closed half of the spike's polyline test**

In `vertices_draw_sink_test.dart`, restore the assertion Task 4 removed, with
the join triangles counted:

```dart
    final closed = _sink()
      ..beginResidual(Transform2.identity())
      ..polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, _style(),
          closed: true)
      ..endResidual();
    // Three segments and three corners: 3 * 2 quad triangles plus 3 * 2 join
    // triangles, every corner shallow enough to mitre.
    expect(closed.debugPositions().length, (3 * 2 + 3 * 2) * 3 * 2);
```

- [ ] **Step 6: Run the tests and watch them pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_join_test.dart test/vertices_draw_sink_test.dart
```

Expected: 13 join tests and the full sink suite pass.

- [ ] **Step 7: Run both suites green, then commit**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
```

```bash
git add packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart packages/jet_cad_2d_flutter/test
git commit -m "feat: closed runs join at the seam instead of capping

A circle is a full-sweep flatten whose last chord lands on its first point, so
the corner there is a corner -- and the one no vertex list contains. Without
the join every circle at a visible lineweight carried a notch at its start
angle, which is not an angle any user chose.

The closed polyline is the same branch and the painter never reaches it, so it
lands with a mutant rather than as unreached code: the spike already carried
one not-applicable mutant for this branch and one is enough."
```

---

### Task 6: The point shape, reconciled

`CanvasDrawSink.point` pushes the residual onto the canvas and calls
`drawRawPoints`, so its square cap **rotates and shears with the residual**.
`VerticesDrawSink.point` emits a device-space axis-aligned square. Under a
rotated residual these are different squares, and until one of them changes the
sink-against-sink comparison in Task 10 can only pass on a fixture at the
identity transform — the degenerate fixture `CLAUDE.md` names as this
repository's dominant failure mode.

The vertices backend is authoritative and its shape is the one kept: a point
marker that shears is not what a point marker is for. `CanvasDrawSink` changes
to match.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/canvas_draw_sink.dart`
- Create: `packages/jet_cad_2d_flutter/test/point_shape_test.dart`

**Interfaces:**
- Consumes: `CanvasDrawSink.point`, `RecordingDrawSink`.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/point_shape_test.dart`:

```dart
// A point marker is axis-aligned on the screen, on both backends.
//
// `CanvasDrawSink` used to draw it through `drawRawPoints` under the pushed
// residual, so a rotated instance turned the marker with it. Nothing wants
// that: the marker marks a position, and its orientation carries no
// information about the drawing.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

const _lw = 100;
const _pxPerMm = 4.0;

ResolvedStyle _style() => const ResolvedStyle(
      argb: 0xFF000000,
      lineweightHundredths: _lw,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
    );

void main() {
  test('the marker is axis-aligned on screen under a rotated residual', () {
    // A 30-degree residual. A marker drawn in local space would come back
    // rotated by it; an axis-aligned one has its extremes on the axes.
    //
    // MUTATION: push the residual and draw in local space -- the old
    // behaviour -- and the bounding box grows by a factor of about 1.37.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 100, 200);

    final recorder = PictureRecorder();
    final sink = CanvasDrawSink(
      canvas: Canvas(recorder),
      pixelsPerPaperMm: _pxPerMm,
      measurer: FlutterTextMeasurer(),
      textStyleOf: (_) => const TextStyleRecord(
          handle: ReservedHandles.standardTextStyle,
          name: 'Standard',
          fontFamily: 'Roboto'),
    );

    // The sink has no readable geometry, so the assertion runs against the
    // vertices sink's own square, which is the shape both are now required to
    // draw, and the canvas sink is checked by the Task 10 comparison. Here we
    // pin only that the canvas sink no longer pushes the residual for a point:
    // `canvasCallCount` is 1 and no `save` is outstanding afterwards.
    sink
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();
    expect(sink.canvasCallCount, 1);
    recorder.endRecording().dispose();
  });

  test('the two sinks agree on where the marker goes', () {
    // The position is not in question -- only the orientation -- so this pins
    // the position on the sink whose geometry is readable, and Task 10's
    // comparison covers the pair.
    const angle = math.pi / 6;
    final t = Transform2(math.cos(angle), math.sin(angle), -math.sin(angle),
        math.cos(angle), 100, 200);
    final sink = VerticesDrawSink(pixelsPerPaperMm: _pxPerMm)
      ..beginResidual(t)
      ..point(3, 4, _style())
      ..endResidual();

    final v = sink.debugPositions();
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (var i = 0; i < v.length; i += 2) {
      minX = math.min(minX, v[i]);
      maxX = math.max(maxX, v[i]);
      minY = math.min(minY, v[i + 1]);
      maxY = math.max(maxY, v[i + 1]);
    }
    // 1.0 mm at 4 px/mm is a 4-pixel square, axis-aligned whatever the
    // residual does.
    expect(maxX - minX, closeTo(4.0, 1e-6));
    expect(maxY - minY, closeTo(4.0, 1e-6));
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/point_shape_test.dart
```

Expected: the first row fails — `canvasCallCount` is 1 but a `save` was pushed,
which the next step removes; confirm by reading the sink, not by guessing.

- [ ] **Step 3: Implement**

Replace `CanvasDrawSink.point`:

```dart
  /// A square marker, axis-aligned on the screen.
  ///
  /// **Not** `drawRawPoints` under the pushed residual, which is what this used
  /// to be: that draws the cap in local space, so a rotated or sheared instance
  /// turned the marker with it. A marker marks a position and its orientation
  /// carries nothing, so it is drawn in screen space — which is also what
  /// `VerticesDrawSink` does, and the two backends have to agree.
  @override
  void point(double x, double y, ResolvedStyle style) {
    // Screen space, so the residual is applied here rather than pushed.
    final sx = _residual.a * x + _residual.c * y + _residual.e;
    final sy = _residual.b * x + _residual.d * y + _residual.f;
    final half = _widthFor(style.lineweightHundredths, 1.0) / 2;
    _paint
      ..color = Color(style.argb)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTRB(sx - half, sy - half, sx + half, sy + half), _paint);
    _paint.style = PaintingStyle.stroke;
    _canvasCalls++;
  }
```

Note the `1.0` passed as the residual scale: the width is a device-pixel
quantity and the residual is **not** on the canvas for this call, so there is
nothing to pre-divide by.

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/point_shape_test.dart
```

Expected: 2 tests pass.

- [ ] **Step 5: Regenerate any golden this moves**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden
```

If a ladder carries a point under a non-identity residual its PNG changes.
**Look at the before and after** — `flutter test --update-goldens` writes the
new one, and a diff nobody looked at is a golden nobody is testing. Record in
the commit which PNGs moved and why.

- [ ] **Step 6: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "fix: a point marker is axis-aligned on screen, on both backends

`CanvasDrawSink.point` drew its square cap through `drawRawPoints` under the
pushed residual, so a rotated instance turned the marker with it. The vertices
sink draws it in screen space, and until one of them changed the two backends
could only be compared on a fixture at the identity transform -- the degenerate
fixture this repository names as its dominant failure mode.

The vertices shape is the one kept: a marker marks a position and its
orientation carries no information about the drawing."
```

---

### Task 7: The harness picks a backend

`useVertices` is gone, so the harness no longer compiles. It gets the control
Phase C needs: a backend, not a sink toggle.

**Files:**
- Modify: `apps/dev_harness_2d/lib/main.dart`
- Modify: `apps/dev_harness_2d/integration_test/frame_timing_test.dart`

**Interfaces:**
- Consumes: `RenderBackend`, `defaultRenderBackend`, `DraftCanvasState.resolvedBackend`.
- Produces: `kBackend`, and a `backend=` field in every rig's printed block.

- [ ] **Step 1: Replace the define**

In `apps/dev_harness_2d/lib/main.dart`, delete `kVertices` and add:

```dart
/// Which sink the harness draws through: `canvas`, `vertices`, or unset for
/// the platform's own choice.
///
/// **A `String.fromEnvironment`, and it stays one.** Plan 3c lost a full device
/// run to `bool.fromEnvironment('TEXT')` reading `--dart-define=TEXT=1` as
/// false while printing entirely plausible numbers; the only thing that caught
/// it was a line printing `corpus=on/off`. A string has no such hazard, and an
/// unrecognised value throws at startup rather than falling back to something
/// that looks fine.
final RenderBackend? kBackend = switch (
    const String.fromEnvironment('BACKEND', defaultValue: '')) {
  '' => null,
  'canvas' => RenderBackend.canvas,
  'vertices' => RenderBackend.vertices,
  final other => throw StateError(
      'BACKEND must be canvas, vertices or unset; got "$other"'),
};
```

and pass it: `backend: kBackend` where `useVertices: kVertices` was.

- [ ] **Step 2: Report what was resolved, not what was asked**

In `apps/dev_harness_2d/integration_test/frame_timing_test.dart`, extend the
`boot` record and the `onReady` signature to carry
`RenderBackend resolvedBackend` from `DraftCanvasState.resolvedBackend`, and
replace `printVerticesCounters`:

```dart
/// The backend actually used, and the vertices counters when it was that one.
///
/// The resolved value and not the define: a run that asked for `vertices` and
/// silently got `canvas` would otherwise report canvas numbers under a
/// vertices heading, which is the shape of the mistake Plan 3c's `TEXT` define
/// made.
void printBackend(RenderBackend backend, VerticesDrawSink? vertices) {
  if (vertices == null) {
    print('  backend=${backend.name}');
    return;
  }
  print('  backend=${backend.name} '
      'triangles=${vertices.frameTriangleCount} '
      'drawVerticesCalls=${vertices.totalFlushCount}');
}
```

Call it in all three rigs where `printVerticesCounters` was called.

- [ ] **Step 3: Analyze and format**

```sh
cd apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
```

Expected: no issues.

- [ ] **Step 4: Prove the define is wired, on a device**

Two runs, and the printed `backend=` must differ between them. This is the
step that would have caught Plan 3c's `TEXT` bug.

```sh
cd apps/dev_harness_2d
for B in canvas vertices; do
  echo "### $B"
  flutter drive --driver=test_driver/integration_test.dart \
    --target=integration_test/frame_timing_test.dart --profile -d macos \
    --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
    --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
    | grep -E "R2 |build |raster |backend="
done
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
```

Expected: `backend=canvas` in the first block and `backend=vertices` in the
second. **If both read the same, stop** — the define is not wired and every
number Phase C would produce is worthless.

- [ ] **Step 5: Run every gate green, then commit**

```sh
cd packages/jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../../apps/dev_harness_2d && flutter analyze && dart format --output=none --set-exit-if-changed lib integration_test
```

```bash
git add apps/dev_harness_2d
git commit -m "feat: the harness selects a backend rather than toggling a sink

BACKEND=canvas|vertices, unset for the platform default. A String define and
not a bool one: Plan 3c lost a device run to bool.fromEnvironment reading
TEXT=1 as false while printing plausible numbers, and an unrecognised value
here throws at startup instead.

Every rig prints the *resolved* backend, so a run that asked for one and got
the other cannot report the wrong numbers under the right heading."
```

---

# Phase B — the apparatus

### Task 8: The flush observer

The rasterizer needs the triangles Impeller was given. `flush()` builds the
`Vertices`, submits it, disposes it and rewinds the buffer in one call, so a
test that runs after it finds nothing and one that runs before it has not
exercised the code under test.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/vertices_draw_sink.dart`
- Modify: `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`

**Interfaces:**
- Produces: `typedef FlushObserver = void Function(Float32List positions, Int32List colors);`
  and `VerticesDrawSink.observer`, consumed by Tasks 9 and 10.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d_flutter/test/vertices_draw_sink_test.dart`:

```dart
  test('the observer sees exactly what was submitted, before the rewind', () {
    // The rasterizer's seam. Reading the buffer after a flush finds it
    // rewound; reading it before finds work the flush has not yet done.
    //
    // MUTATION: hand the observer the whole buffer rather than the submitted
    // view and the length reads the capacity, 4096, instead of 12.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    late Float32List seenPositions;
    late Int32List seenColors;
    var calls = 0;

    final sink = _sink(canvas: canvas)
      ..observer = (positions, colors) {
        calls++;
        seenPositions = Float32List.fromList(positions);
        seenColors = Int32List.fromList(colors);
      }
      ..beginResidual(Transform2.identity())
      ..polyline(_seg(0, 0, 10, 0), 2, _style(argb: 0xFF112233), closed: false)
      ..endResidual();
    sink.flush();

    expect(calls, 1);
    expect(seenPositions.length, 12);
    expect(seenColors.length, 6);
    expect(seenColors[0].toUnsigned(32), 0xFF112233);
    // And the buffer really was rewound afterwards.
    expect(sink.debugPositions(), isEmpty);
    recorder.endRecording().dispose();
  });

  test('a flush with nothing batched does not call the observer', () {
    // MUTATION: call it unconditionally and a frame that drew nothing
    // rasterises an empty buffer over the previous one.
    var calls = 0;
    final recorder = PictureRecorder();
    _sink(canvas: Canvas(recorder))
      ..observer = ((_, __) => calls++)
      ..flush();
    expect(calls, 0);
    recorder.endRecording().dispose();
  });

  test('the observer fires once per flush, text included', () {
    // MUTATION: observe only the final flush and a fixture with text loses
    // every triangle drawn before the first text op.
    var calls = 0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final sink = _sink(canvas: canvas)
      ..observer = ((_, __) => calls++)
      ..beginResidual(Transform2.identity());
    sink.polyline(_seg(0, 0, 10, 0), 2, _style(), closed: false);
    sink.text('x', ReservedHandles.standardTextStyle, _style());
    sink.polyline(_seg(0, 5, 10, 5), 2, _style(), closed: false);
    sink.endResidual();
    sink.flush();
    expect(calls, 2);
    recorder.endRecording().dispose();
  });
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

Expected: `The setter 'observer' isn't defined for the type 'VerticesDrawSink'`.

- [ ] **Step 3: Implement**

In `vertices_draw_sink.dart`, above the class:

```dart
/// Handed the position and colour views a [VerticesDrawSink.flush] submitted,
/// before it rewinds the buffer.
///
/// The views are live over the sink's own storage and are valid only for the
/// duration of the call; an observer that keeps one must copy it.
typedef FlushObserver = void Function(Float32List positions, Int32List colors);
```

In the class, beside `canvas`:

```dart
  /// Watches every flush, or null.
  ///
  /// **Test seam, null in production.** `flush` submits, disposes and rewinds
  /// in one call, so there is no moment outside it at which the triangles
  /// Impeller was given can be read. The rasterizer in
  /// `test/support/triangle_rasterizer.dart` is the only caller.
  FlushObserver? observer;
```

and in `flush()`, immediately after `_lastFlushVertices = colors.length;`:

```dart
    observer?.call(positions, colors);
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/vertices_draw_sink_test.dart
```

- [ ] **Step 5: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter
git commit -m "feat: a flush observer, so a test can see what Impeller was given

flush() submits, disposes and rewinds in one call. Reading the buffer after it
finds nothing; reading it before finds work the flush has not done. The
observer is handed the submitted views at the one moment they mean something,
and is null in production."
```

---

### Task 9: A triangle rasterizer this repository owns

`flutter_test`'s software Skia did not finish a `drawVertices` of 1,007
segments in 7 minutes 28 seconds, so the golden suite cannot see this sink
through the engine. It gets its own scan-converter: deterministic across
machines and Flutter versions, and reading the buffer Impeller was given rather
than a re-derivation of it.

It has no anti-aliasing. Its goldens are of **coverage**, not of appearance —
the right trade for a regression test and the wrong one for judging how a
drawing looks. The device screenshot stays the instrument for the second
question.

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`
- Create: `packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`

**Interfaces:**
- Consumes: `FlushObserver`, `VerticesDrawSink.observer`.
- Produces: `class TriangleRasterizer` with `void observe(Float32List, Int32List)`,
  `Uint32List get pixels`, `bool inked(int x, int y)`, `Future<ui.Image> toImage()`.
  Tasks 10 and 11 consume all four.

- [ ] **Step 1: Write the failing test**

`packages/jet_cad_2d_flutter/test/support/triangle_rasterizer_test.dart`:

```dart
// The rasterizer is test infrastructure, so it gets its own tests: a golden
// compared through a broken scan-converter is a green test and a wrong
// drawing.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'triangle_rasterizer.dart';

Float32List _tri(List<double> xy) => Float32List.fromList(xy);
Int32List _rgb(int argb) => Int32List.fromList(List<int>.filled(3, argb));

void main() {
  test('a triangle covers its interior and not its outside', () {
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFFFF0000));
    expect(r.inked(2, 2), isTrue, reason: 'inside');
    expect(r.inked(5, 5), isFalse, reason: 'past the hypotenuse');
    expect(r.inked(7, 7), isFalse, reason: 'outside the bounding box');
  });

  test('winding does not matter', () {
    // MUTATION: reject triangles whose edge functions come out negative and
    // the clockwise one vanishes. `drawVertices` culls nothing, so neither
    // does this.
    final ccw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 6, 1, 1, 6]), _rgb(0xFF00FF00));
    final cw = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 1, 6, 6, 1]), _rgb(0xFF00FF00));
    expect(cw.inked(2, 2), ccw.inked(2, 2));
  });

  test('a later triangle draws over an earlier one', () {
    // The buffer's order is the draw order, and the rasterizer must not
    // reorder it — that is the property the whole sink is built around.
    //
    // MUTATION: skip a pixel that is already inked and this reads red.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFFFF0000))
      ..observe(_tri([0, 0, 8, 0, 0, 8]), _rgb(0xFF0000FF));
    expect(r.pixels[1 * 8 + 1] & 0x00FFFFFF, 0x0000FF);
  });

  test('geometry outside the surface is clipped, not wrapped', () {
    // MUTATION: drop the row and column clamps and this throws a RangeError,
    // or worse, writes a pixel on the opposite edge.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([-20, -20, 40, -20, -20, 40]), _rgb(0xFF000000));
    expect(r.inked(0, 0), isTrue);
    expect(r.inked(7, 7), isFalse);
  });

  test('a degenerate triangle inks nothing', () {
    // MUTATION: divide by a zero area and every pixel comes out NaN-inked.
    final r = TriangleRasterizer(8, 8)
      ..observe(_tri([1, 1, 5, 1, 3, 1]), _rgb(0xFF000000));
    expect(List.generate(64, (i) => r.pixels[i]).every((p) => p == 0), isTrue);
  });

  test('it renders what the sink submitted, end to end', () async {
    // The seam under test, not a hand-built triangle list.
    final r = TriangleRasterizer(64, 64);
    // A one-pixel horizontal line across the middle.
    final image = await r.toImage();
    addTearDown(image.dispose);
    expect(image.width, 64);
    expect(image.height, 64);
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

Expected: `Undefined class 'TriangleRasterizer'`.

- [ ] **Step 3: Implement**

`packages/jet_cad_2d_flutter/test/support/triangle_rasterizer.dart`:

```dart
// A coverage-only scan-converter for `VerticesDrawSink`'s output.
//
// `flutter_test`'s software Skia did not finish a `drawVertices` of 1,007
// segments in 7 minutes 28 seconds, so the golden suite cannot see this sink
// through the engine. This is small enough to own, deterministic across
// machines and Flutter versions where the engine's rasteriser is not, and it
// reads the buffer Impeller was given rather than a second derivation of it.
//
// **No anti-aliasing.** A pixel is inside a triangle or it is not, so what it
// produces is a coverage golden and not an appearance golden. Judging how a
// drawing looks stays the device screenshot's job.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Rasterises the triangles a [VerticesDrawSink] flush submitted.
///
/// Attach with `sink.observer = rasterizer.observe;`.
class TriangleRasterizer {
  TriangleRasterizer(this.width, this.height)
      : pixels = Uint32List(width * height);

  final int width;
  final int height;

  /// RGBA, row-major, zero where nothing was drawn.
  final Uint32List pixels;

  bool inked(int x, int y) => pixels[y * width + x] != 0;

  /// A [FlushObserver]. Triangles are drawn in buffer order with no depth
  /// test, exactly as `drawVertices` rasterises them, so a later one covers an
  /// earlier one — which is the property the sink's whole design rests on.
  void observe(Float32List positions, Int32List colors) {
    for (var t = 0; t + 2 < colors.length; t += 3) {
      _fill(
        positions[t * 2], positions[t * 2 + 1],
        positions[t * 2 + 2], positions[t * 2 + 3],
        positions[t * 2 + 4], positions[t * 2 + 5],
        colors[t].toUnsigned(32),
      );
    }
  }

  void _fill(double ax, double ay, double bx, double by, double cx, double cy,
      int argb) {
    final area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    // A zero-area triangle has no interior and no orientation to test against.
    if (area == 0 || !area.isFinite) return;
    // `drawVertices` culls nothing, so neither does this: a clockwise triangle
    // is as visible as a counter-clockwise one.
    final sign = area > 0 ? 1.0 : -1.0;

    final minX = _clampX(_minOf(ax, bx, cx).floor());
    final maxX = _clampX(_maxOf(ax, bx, cx).ceil());
    final minY = _clampY(_minOf(ay, by, cy).floor());
    final maxY = _clampY(_maxOf(ay, by, cy).ceil());

    // RGBA for `ui.PixelFormat.rgba8888`, from the ARGB the sink carries.
    final rgba = ((argb & 0x00FF0000) >> 16) |
        (argb & 0x0000FF00) |
        ((argb & 0x000000FF) << 16) |
        ((argb & 0xFF000000));

    for (var y = minY; y <= maxY; y++) {
      final py = y + 0.5;
      for (var x = minX; x <= maxX; x++) {
        final px = x + 0.5;
        final w0 = ((bx - ax) * (py - ay) - (by - ay) * (px - ax)) * sign;
        final w1 = ((cx - bx) * (py - by) - (cy - by) * (px - bx)) * sign;
        final w2 = ((ax - cx) * (py - cy) - (ay - cy) * (px - cx)) * sign;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        pixels[y * width + x] = rgba;
      }
    }
  }

  int _clampX(int v) => v < 0 ? 0 : (v >= width ? width - 1 : v);
  int _clampY(int v) => v < 0 ? 0 : (v >= height ? height - 1 : v);
  static double _minOf(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);
  static double _maxOf(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);

  /// The surface as an image, for `matchesGoldenFile`.
  Future<ui.Image> toImage() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.buffer.asUint8List(),
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
```

- [ ] **Step 4: Run the test and watch it pass**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/triangle_rasterizer_test.dart
```

Expected: 6 tests pass.

- [ ] **Step 5: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter/test/support
git commit -m "test: a coverage-only triangle rasterizer for the vertices sink

flutter_test's software Skia did not finish a drawVertices of 1,007 segments in
7.5 minutes, so the golden suite cannot see this sink through the engine. This
is small enough to own and deterministic across machines and Flutter versions,
and it reads the buffer Impeller was given rather than a second derivation of
it.

It has its own tests, because a golden compared through a broken scan-converter
is a green test and a wrong drawing. Winding is not culled, later triangles
cover earlier ones, and geometry off the surface is clipped -- three ways to be
subtly wrong that no golden would name."
```

---

### Task 10: Goldens on both backends

Both backends are production, so both get pinned. The existing 14 PNGs keep
their fixtures and their assertions and become the **canvas** backend's suite —
which is the web renderer, so they stop being at risk of testing code nothing
draws through. The same fixtures render again through the vertices backend and
the rasterizer into a second set.

**Files:**
- Modify: `packages/jet_cad_2d_flutter/test/golden/dash_ladder_golden_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/golden/stroke_width_golden_test.dart`
- Modify: `packages/jet_cad_2d_flutter/test/golden/text_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/vertices/*.png` (14 files)

**Interfaces:**
- Consumes: `RenderBackend`, `TriangleRasterizer`, `VerticesDrawSink.observer`.
- Produces: nothing.

- [ ] **Step 1: Add the second rendering route to one ladder**

Take `dash_ladder_golden_test.dart` first — it is the one whose fixture carries
both a polyline and a circle. Wrap each existing `testWidgets` body in a loop
over the backends and route the vertices one through the rasterizer:

```dart
/// Renders one rung on one backend and compares it to that backend's PNG.
///
/// The canvas backend goes through `flutter_test`'s own rasteriser and
/// `matchesGoldenFile` on the widget. The vertices backend cannot: software
/// Skia does not finish a `drawVertices` of this size, so its triangles are
/// scan-converted by `TriangleRasterizer` and the *image* is matched instead.
Future<void> _rung(WidgetTester tester, DraftDocument doc, String name,
    RenderBackend backend) async {
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final camera = CameraController(
      ViewportTransform.fit(doc.extents, kGoldenSize));
  addTearDown(camera.dispose);

  final rasterizer = backend == RenderBackend.vertices
      ? TriangleRasterizer(
          kGoldenSize.width.round(), kGoldenSize.height.round())
      : null;

  final key = GlobalKey<DraftCanvasState>();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      child: SizedBox(
        width: kGoldenSize.width,
        height: kGoldenSize.height,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: DraftCanvas(
              key: key,
              document: doc,
              index: index,
              camera: camera,
              backend: backend),
        ),
      ),
    ),
  ));
  key.currentState!.vertices?.observer = rasterizer?.observe;
  await tester.pump();

  if (rasterizer == null) {
    await expectLater(
        find.byType(DraftCanvas), matchesGoldenFile('$name.png'));
    return;
  }
  final image = await rasterizer.toImage();
  addTearDown(image.dispose);
  await expectLater(image, matchesGoldenFile('vertices/$name.png'));
}
```

The `observer` is attached **after** the first pump and the widget is pumped
again, because the state does not exist until the first build.

- [ ] **Step 2: Run it and watch the vertices goldens fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden test/golden/dash_ladder_golden_test.dart
```

Expected: the five canvas rungs pass unchanged; the five vertices rungs fail
with "Golden file … does not exist".

- [ ] **Step 3: Generate the vertices goldens, then look at every one**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden --update-goldens test/golden/dash_ladder_golden_test.dart
```

Then **open all five PNGs and look at them**. This is not a formality: the
spike's two bugs were a reordered drawing and a picture nobody had rendered,
and both were found by looking. Check specifically:

- corners are filled, with no hairline crack along the miter's base;
- the circle has no notch at its start angle (three o'clock);
- dashes start and end where the canvas golden's do;
- colours match the canvas golden's rung for rung.

A PNG that looks wrong is a Task 4 or Task 5 defect, not a golden to accept.

- [ ] **Step 4: Repeat for the other two ladders**

`stroke_width_golden_test.dart` and `text_ladder_golden_test.dart`, the same
way. The text ladder's glyphs will be **absent** from its vertices golden —
text never enters the triangle buffer — and its polyline will be present. That
is correct and the test says so:

```dart
  // The vertices golden of this ladder carries the rung's polyline and none of
  // its glyphs: text goes to `CanvasDrawSink` as a paragraph and never reaches
  // the triangle buffer. What it pins is that the strokes around the text are
  // right and that the flush before each text op happened; the glyphs are
  // pinned by the canvas golden beside it.
```

- [ ] **Step 5: Run the whole golden suite**

```sh
cd packages/jet_cad_2d_flutter && flutter test --tags golden
```

Expected: 28 rungs pass, 14 per backend. **No pre-existing PNG regenerated** —
if one moved, Task 6's point change moved it and that is already recorded; any
other movement is a defect.

- [ ] **Step 6: Run both suites green, then commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden
git commit -m "test: goldens on both backends

Both backends are production, so both are pinned. The existing 14 PNGs keep
their fixtures and become the canvas backend's suite, which is the web
renderer -- the web decision is what stops them from becoming tests of code
nothing draws through.

The same fixtures render again through the vertices backend and the rasterizer.
The text ladder's vertices golden carries its polyline and none of its glyphs,
because text never enters the triangle buffer; what it pins is the strokes and
the flush, and the glyphs stay pinned by the canvas golden beside it.

Every generated PNG was opened and looked at before it was accepted."
```

---

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

### Task 12: The desktop rows

**Files:**
- Create: nothing. Task 14 writes the note; this task produces the readings and
  pastes the raw transcripts into the task report.

- [ ] **Step 1: Check the machine before anything else**

```sh
pmset -g | grep lowpowermode
```

Expected: `lowpowermode         0`. **If it reads 1, stop and say so** — Plan
3c's entire results note is contaminated because nobody checked, and the
re-measurement showed a uniform ~24% on both raster and build. Check it again
after the last run and record both readings.

- [ ] **Step 2: Run R2 on both backends at all three corpus sizes**

Three consecutive runs per cell, so the median and the spread are both real.
Nine cells means eighteen runs; the 500,000 rows take minutes each.

```sh
cd apps/dev_harness_2d
for N in 10000 50000 500000; do
  for B in canvas vertices; do
    for I in 1 2 3; do
      echo "### R2 entities=$N backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d macos \
        --dart-define=TEXT=true --dart-define=ENTITIES=$N \
        --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R2 |build |raster |screenSpace|dashSpans|backend=|text:"
    done
  done
done
```

**Read `backend=` in every block.** If it does not match the define, the run is
void — that is Plan 3c's `TEXT` bug in a new place, and it printed entirely
plausible numbers for a whole session.

- [ ] **Step 3: Run R4a and R4b at 50,000 on both backends**

```sh
for B in canvas vertices; do
  for RIG in leaf instance; do
    for I in 1 2 3; do
      echo "### $RIG backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d macos \
        --dart-define=TEXT=true --dart-define=ENTITIES=50000 \
        --dart-define=RIG=$RIG --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R4|build |raster |command |backend="
    done
  done
done
```

- [ ] **Step 4: Record peak buffer bytes**

`_reserve` doubles and never gives capacity back — that is the property that
makes a steady-state frame allocation-free, and it means one zoom-out at
500,000 entities pins the peak for the life of the widget. Read
`debugCapacityVertices` after the 500,000 whole-drawing frame and record
`capacity * (8 + 4)` bytes. The number exists so nobody is surprised by it
later.

- [ ] **Step 5: Clean up**

```sh
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git checkout -- apps/dev_harness_2d/macos/Runner.xcodeproj/project.pbxproj
git status --porcelain   # must be clean
pmset -g | grep lowpowermode
```

- [ ] **Step 6: Paste every raw transcript into the task report**

Not a summary. The medians go in the note; the transcripts go in the report, so
a reviewer can recompute them. **Never retype a number** — copy it.

---

### Task 13: The web rows

The rows that can still change a decision. If CanvasKit's `drawVertices` is
faster than its `drawPath` at these counts, the web default flips and
`CanvasDrawSink` becomes a fallback with no default platform.

- [ ] **Step 1: Get the driver working before measuring anything**

```sh
which chromedriver || brew install chromedriver
chromedriver --port=4444 &
```

The invocation is `flutter drive ... -d chrome`, **not**
`flutter test --platform chrome`: the first drives the integration-test rig
these rows share with the desktop ones, the second runs widget tests and cannot
reach the frame-timing harness. Getting this wrong is how a web row comes back
empty and gets reported as "web is fine".

- [ ] **Step 2: One smoke run, and check `backend=`**

```sh
cd apps/dev_harness_2d
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/frame_timing_test.dart --profile -d chrome \
  --dart-define=TEXT=true --dart-define=ENTITIES=10000 \
  --dart-define=RIG=pan --dart-define=BACKEND=vertices 2>&1 \
  | grep -E "R2 |build |raster |backend="
```

Expected: `backend=vertices` — the override is honoured on web by design, and
if it reads `canvas` the clamp Task 1 forbade has crept back in.

**If the run hangs or produces no timing block, stop and report that.** A web
row that cannot be measured is a finding: it means the platform default stands
on the argument in the design document rather than on a number, and the plan
says so instead of inventing one.

- [ ] **Step 3: The rows**

```sh
for N in 10000 50000; do
  for B in canvas vertices; do
    for I in 1 2 3; do
      echo "### web R2 entities=$N backend=$B run=$I"
      flutter drive --driver=test_driver/integration_test.dart \
        --target=integration_test/frame_timing_test.dart --profile -d chrome \
        --dart-define=TEXT=true --dart-define=ENTITIES=$N \
        --dart-define=RIG=pan --dart-define=BACKEND=$B 2>&1 \
        | grep -E "R2 |build |raster |backend="
    done
  done
done
```

500,000 is deliberately not run on the web: the desktop rows take minutes each
there and CanvasKit is slower, so it would cost hours to confirm something the
50,000 row already indicates. Say that in the note rather than leaving a blank
cell.

- [ ] **Step 4: State the platform default with the number behind it**

Two outcomes, both acceptable, one of them written down:

- **CanvasKit's `drawVertices` is slower.** The default stands as the design
  document wrote it, now with a measurement instead of an argument.
- **It is faster by more than the spread.** The web default flips to
  `vertices`, `defaultRenderBackend()` becomes unconditional, and
  `CanvasDrawSink` stays as a fallback with no default platform. Change
  `render_backend.dart` in its own commit, with the numbers in the message.

- [ ] **Step 5: Kill chromedriver and clean up**

```sh
kill %1
cd /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/vertices-spike
git status --porcelain   # must be clean
```

---

### Task 14: The mutation log

The spike ran 33 mutants against the sink and killed 32, with one not
applicable. Phase A added nine more. Every one gets run, and every survivor
gets a test or a recorded reason.

**Files:**
- Create: `docs/superpowers/notes/plan-3d-mutation-log.md`

- [ ] **Step 1: Write the runner**

A backup-based script, in the scratchpad and not committed. **Never
`git checkout` a file to revert a mutation** — Plan 3c's Task 10 lost a full
task's work that way. Copy the file aside before the edit and restore it in a
`finally`, whatever happens in between.

Model it on `mutate13.py` from Plan 3c's ledger: apply, run the narrowest suite
that should catch it, and if that stays green widen to both full suites so a
survivor is a measured survivor rather than an unlooked-for one.

- [ ] **Step 2: Run every mutant in the design document's table**

J1 through J9, B1, B2, A1, V1, P1, and the spike's 33. For each, record: the
mutation as a diff, the test that went red, and the assertion message.

- [ ] **Step 3: Close every survivor**

A survivor is either a missing test — write it, watch the mutant die — or a
mutation the frame path cannot reach, which is recorded as **not applicable**
with the reason and the file:line that makes it unreachable. Those are the only
two outcomes. "Accepted risk" is not one.

- [ ] **Step 4: Write the log**

One section per mutant: id, the mutation, the killer, the assertion. A table at
the top with the tally. Model it on
`docs/superpowers/notes/plan-3c-mutation-log.md`.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/notes/plan-3d-mutation-log.md
git commit -m "docs: Plan 3d mutation log"
```

---

### Task 15: The results note and the exit gate

- [ ] **Step 1: Run the exit gate, criterion by criterion**

Each of the eight in the design document. Run the check, paste the output, mark
it pass or fail. **A criterion nobody ran is a fail**, not a blank.

- [ ] **Step 2: Write the note**

`docs/superpowers/notes/2026-08-2X-plan-3d-results.md`, dated the day the runs
happened. It carries:

- machine, OS, Flutter and Dart versions, engine revision, and the Low Power
  Mode readings from before and after;
- the exact `flutter drive` invocations, including the web one;
- every cell as median of three with its spread beside it, desktop and web;
- criterion 6 evaluated per corpus size, with the crossover named if there is
  one;
- the peak buffer bytes from Task 12 step 4;
- what a steady-state frame allocates, and whether the `CLAUDE.md` amendment
  was approved, refused, or not needed;
- the five permitted divergences, with the sink-against-sink counts beside
  them;
- what 3d owes 3e and 3f.

- [ ] **Step 3: Say plainly what failed**

If criterion 6 tied at 500,000, the note says so, records the crossover, and
hands it to 3f — it does not round the number up. If the allocation amendment
was refused, the note says criterion 7 failed and the plan stopped. A results
note that reports only what went well is not a result.

- [ ] **Step 4: Update `STATUS.md`**

Replace the "The batching spike pulled the lever, on a branch" section with the
plan's outcome, the gate verdict, and the resume point.

- [ ] **Step 5: Commit, then finish the branch**

```bash
git add docs/superpowers/notes STATUS.md
git commit -m "docs: Plan 3d results and exit gate"
```

Then use the **superpowers:finishing-a-development-branch** skill. Do not merge
on your own initiative: the menu is the human's to answer.

---

## Self-review

Run against the design document at `aefb31f`.

**Spec coverage.** Backend selection → Task 1. The two backends drawing the
same picture → Tasks 6 and 11. Joins and caps → Tasks 4 and 5. `Vertices`
disposal → Task 2. The allocation question → Task 3, with the amendment left
to the human. Text and why `CanvasDrawSink` survives → Tasks 1, 8, 11. The
defines → Task 7. The rasterizer → Task 9. Goldens on both backends → Task 10.
Sink against sink → Task 11. Phase C's rows → Tasks 12 and 13. Mutants →
Task 14. Exit gate → Task 15. **No section without a task.**

**Placeholders.** None. Every code step carries the code; the one prose-only
step, Task 14's runner, names the file to model it on and the trap to avoid.

**Type consistency.** `RenderBackend` / `defaultRenderBackend()` (Task 1) are
used unchanged in 7, 10, 11, 13. `FlushObserver` (Task 8) is what
`TriangleRasterizer.observe` (Task 9) satisfies and what Tasks 10 and 11
attach. `frameSegmentCount` is renamed to `frameTriangleCount` in Task 4 step
10 and used under that name in Task 7. `_emitQuad` / `_emitSegment` /
`_emitTriangle` (Task 4) are consumed by Task 5's `_endRun`.

**One thing this plan does not decide, on purpose.** Whether `CLAUDE.md`'s
allocation non-negotiable is amended. Task 3 measures it and stops; the plan
cannot pass its own criterion 7 by editing the rule that criterion is measured
against.

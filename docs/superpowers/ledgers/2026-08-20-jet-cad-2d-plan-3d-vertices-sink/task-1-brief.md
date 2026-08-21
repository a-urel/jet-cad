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


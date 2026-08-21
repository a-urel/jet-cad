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


### Task 4: Joins — the run state machine and the seam

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: `writeJoin` (Task 2), `_coveredArgb` (Task 3).
- Produces: `GeometryCollector.polyline` emits, per run,
  `join(v_i)` **before** `segment(v_i, v_{i+1})` for every interior vertex, and
  on a closed run the closing segment followed by the seam join **last**.

**The order is the requirement, not an implementation detail.** The reference's
`_runTo` doc: *"The join comes before the segment so the buffer's order is the
drawing's order: at a corner the ink nearer the start of the run is written
first."* And `_endRun` emits the seam join after the closing `_runTo`. One
draw call means buffer order *is* draw order, so a reordering here is a
reordering of the picture.

**The bevel/miter/collinear decision is NOT made here.** It is made in the
shader, in device pixels, from the same arithmetic `_emitJoin` uses. The
collector emits a join instance at **every** interior vertex where both
neighbours exist; a collinear corner reaches the shader and collapses to two
zero-area triangles.

> **Ruling B4 — one implementation of the wedge decision, and it lives in the
> shader.** Deciding collinearity in the collector would put the test in
> `double`, in *collection* space, against a reference that tests it in
> `double` in *device* space — two different spaces and two different
> roundings, disagreeing on exactly the corners that are nearly straight. The
> shader's `float32` device-space test is the one that matches what the
> reference actually does. **The cost is one degenerate instance per collinear
> vertex**, which Task 11 measures on the 10,000-entity corpus and reports
> against the 8 MB budget. **Cost if wrong:** the buffer is larger than it
> needs to be on drawings with many collinear vertices, and the fix is a
> collector-side test added later with the divergence measured first.

- [ ] **Step 1: Write the failing tests**

Append to `test/gpu/geometry_collector_test.dart`:

```dart
  /// Reads the kind tag of instance [i].
  double _kindAt(GeometryCollector c, int i) =>
      c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind];

  test('an open three-point run is join-before-segment, and nothing else', () {
    // Three points, one corner. The reference emits: segment(0,1),
    // join(1), segment(1,2) -- in that order, with the join written before
    // the segment it precedes. Butt caps mean there is nothing at either
    // end (Ruling B2), so the count is exactly 3.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 3,
        reason: 'segment, join, segment -- no caps, no trailing join');
    expect(<double>[_kindAt(c, 0), _kindAt(c, 1), _kindAt(c, 2)],
        <double>[kKindStroke, kKindJoin, kKindStroke],
        reason: 'the join is written BEFORE the segment that follows it');
  });

  test('the join carries the corner and both its neighbours', () {
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 30]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x0], 40, reason: 'the vertex');
    expect(j[InstanceFieldOffset.y0], 0);
    expect(j[InstanceFieldOffset.x1], 0, reason: 'the previous point');
    expect(j[InstanceFieldOffset.y1], 0);
    expect(j[InstanceFieldOffset.x2], 40, reason: 'the next point');
    expect(j[InstanceFieldOffset.y2], 30);
  });

  test('a closed run emits the closing segment and then the seam join', () {
    // A triangle: three points, closed. Segments 0-1, 1-2, 2-0 with a join
    // at vertices 1 and 2, then the seam join at vertex 0 -- LAST, after the
    // closing segment. Six instances, and the last one is the seam.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 60, 0, 30, 50]),
        3,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: true);
    expect(c.instanceCount, 6);
    expect(
        List<double>.generate(6, (i) => _kindAt(c, i)),
        <double>[
          kKindStroke, // 0 -> 1
          kKindJoin, //   at 1
          kKindStroke, // 1 -> 2
          kKindJoin, //   at 2
          kKindStroke, // 2 -> 0, the closing segment
          kKindJoin, //   the seam, at 0, LAST
        ]);
    final seam = c.data.sublist(5 * kFloatsPerInstance);
    expect(seam[InstanceFieldOffset.x0], 0, reason: 'the seam is at the first point');
    expect(seam[InstanceFieldOffset.y0], 0);
    expect(seam[InstanceFieldOffset.x1], 30, reason: 'incoming from the last point');
    expect(seam[InstanceFieldOffset.y1], 50);
    expect(seam[InstanceFieldOffset.x2], 60, reason: 'outgoing to the second point');
    expect(seam[InstanceFieldOffset.y2], 0);
  });

  test('a repeated point is spanned by the join, not turned into one', () {
    // The reference's `_runTo` skips a zero-length step and KEEPS the
    // previous direction, so a duplicated vertex produces the same corner a
    // clean polyline would. A collector that reset its direction on the
    // repeat would emit a join between two identical points and draw
    // nothing there.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 0, 40, 0, 40, 30]),
        4,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 3, reason: 'the repeat adds no instance');
    final j = c.data.sublist(kFloatsPerInstance, 2 * kFloatsPerInstance);
    expect(j[InstanceFieldOffset.x1], 0,
        reason: 'the incoming neighbour is still the first point');
    expect(j[InstanceFieldOffset.y1], 0);
  });

  test('a two-point run has no join at all', () {
    // The degenerate case a join implementation gets wrong in the other
    // direction: emitting a join at the start or the end of an open run.
    final c = GeometryCollector(
        pixelsPerPaperMm: kLogicalPixelsPerMm, devicePixelRatio: 2.0);
    c.polyline(
        Float64List.fromList(<double>[0, 0, 40, 30]),
        2,
        const ResolvedStyle(argb: 0xFF000000, lineweightHundredths: 25),
        closed: false);
    expect(c.instanceCount, 1);
    expect(_kindAt(c, 0), kKindStroke);
  });
```

- [ ] **Step 2: Run and watch them fail**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: the five new tests fail on instance counts (1, 2, 3 instead of 3, 3,
6, 3, 1) — the collector emits segments only.

- [ ] **Step 3: Implement the run state machine**

Add to `GeometryCollector`'s fields:

```dart
  // The run state machine, mirroring `VerticesDrawSink._beginRun` /
  // `_runTo` / `_endRun`. It is duplicated rather than shared because these
  // two classes are independent implementations of one `DrawSink` contract,
  // cross-checked against each other by the differential gates -- the same
  // reason `kMinStrokeDevicePixels` is a separate copy.
  //
  // Points, not directions: `_runBack` is the point BEFORE `_runPrev`, so a
  // join is written as its three points and the shader normalises after the
  // mvp. See `writeJoin`'s doc for why directions could not be stored here.
  double _runFirstX = 0, _runFirstY = 0;
  double _runSecondX = 0, _runSecondY = 0;
  double _runPrevX = 0, _runPrevY = 0;
  double _runBackX = 0, _runBackY = 0;
  bool _runHasDirection = false;
  int _runSegments = 0;
```

and the three methods:

```dart
  /// Starts a connected run at a collection-space point.
  void _beginRun(double x, double y) {
    _runFirstX = x;
    _runFirstY = y;
    _runSecondX = x;
    _runSecondY = y;
    _runPrevX = x;
    _runPrevY = y;
    _runBackX = x;
    _runBackY = y;
    _runHasDirection = false;
    _runSegments = 0;
  }

  /// Extends the run, emitting the join **before** the segment.
  ///
  /// The zero-length test is `length == 0` on the square root, not
  /// `x == _runPrevX && y == _runPrevY`, because that is the reference's test
  /// (`vertices_draw_sink.dart`, `_runTo`) and the two are not the same
  /// predicate: for a displacement near the underflow boundary `dx * dx`
  /// rounds to zero while `dx` itself is non-zero, so the equality form keeps
  /// a step the reference drops. Matching the formula rather than the
  /// intention is what keeps the two arms' instance lists identical.
  void _runTo(double x, double y, double half, int argb) {
    final dx = x - _runPrevX, dy = y - _runPrevY;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;

    if (_runHasDirection) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else {
      _runSecondX = x;
      _runSecondY = y;
    }
    _emit(_runPrevX, _runPrevY, x, y, half, argb);

    _runBackX = _runPrevX;
    _runBackY = _runPrevY;
    _runPrevX = x;
    _runPrevY = y;
    _runHasDirection = true;
    _runSegments++;
  }

  /// Ends the run.
  ///
  /// An open run gets butt caps, which is to say nothing at all — the
  /// reference's own words, and the reason this plan emits no cap geometry.
  /// A closed run gets the segment back to its first point and then the seam
  /// join, the corner no vertex list contains and the one whose absence puts
  /// a notch on every circle at its start angle.
  void _endRun({required bool closed, required double half, required int argb}) {
    if (!closed || !_runHasDirection) return;
    _runTo(_runFirstX, _runFirstY, half, argb);
    // Guarded for the same reason the reference guards it: today's callers
    // cannot reach here with one segment, but that is a fact about the
    // callers, not a promise the join arithmetic makes.
    if (_runSegments >= 2) {
      _emitJoin(_runFirstX, _runFirstY, _runBackX, _runBackY, _runSecondX,
          _runSecondY, half, argb);
    }
  }

  void _emitJoin(double vx, double vy, double prevX, double prevY, double nextX,
      double nextY, double half, int argb) {
    // No collinearity test here, deliberately: the bevel/miter/collinear
    // decision belongs to the shader, in device pixels, where the reference
    // makes it too. See this plan's Ruling B4.
    _reserve(_instances + 1);
    writeJoin(_buffer, _instances,
        vx: vx,
        vy: vy,
        prevX: prevX,
        prevY: prevY,
        nextX: nextX,
        nextY: nextY,
        halfWidth: half,
        argb: argb);
    _instances++;
  }
```

Add `import 'dart:math' as math;` at the top of the file.

Rewrite `_emit`'s guard to the same formula, replacing the exact-equality test:

```dart
  void _emit(
      double x0, double y0, double x1, double y1, double half, int argb) {
    // The reference's own test (`vertices_draw_sink.dart`, `_emitSegment`): a
    // zero-length segment has no direction to take a normal from. Matching
    // the formula, not the intention -- see `_runTo`.
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    _reserve(_instances + 1);
    writeStroke(_buffer, _instances,
        x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
    _instances++;
  }
```

and rewrite `polyline` to drive the run:

```dart
  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final t = _residual;
    _beginRun(t.a * points[0] + t.c * points[1] + t.e,
        t.b * points[0] + t.d * points[1] + t.f);
    for (var i = 1; i < count; i++) {
      _runTo(t.a * points[i * 2] + t.c * points[i * 2 + 1] + t.e,
          t.b * points[i * 2] + t.d * points[i * 2 + 1] + t.f, half, argb);
    }
    _endRun(closed: closed, half: half, argb: argb);
  }
```

- [ ] **Step 4: Run the tests**

```bash
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```

Expected: all pass.

- [ ] **Step 5: Fire two mutations**

```bash
cd packages/jet_cad_2d_flutter
cp lib/src/gpu/geometry_collector.dart /tmp/gc.bak

# M-B2: emit the join AFTER its segment (swap the two statements in `_runTo`).
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart

# M-B3: skip the seam join (delete the `if (_runSegments >= 2)` block).
flutter test test/gpu/geometry_collector_test.dart
cp /tmp/gc.bak lib/src/gpu/geometry_collector.dart
```

Expected: M-B2 red on the kind-sequence assertions; M-B3 red on the closed-run
count and the seam's coordinates. Paste both failures.

- [ ] **Step 6: Gate and commit**

```bash
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
echo "exit=$?"
git add packages/jet_cad_2d_flutter
git commit -m "feat(gpu): the collector emits joins, in the reference's order"
```

The full suite may now show the differential test (Task 8 of Plan A) failing on
instance counts, since the collector emits joins the oracle does not rebuild.
**Do not weaken that test.** Task 9 rewrites it against a join-aware oracle. If
it goes red here, report the exact failure and mark the task
`DONE_WITH_CONCERNS` rather than editing the assertion.

---


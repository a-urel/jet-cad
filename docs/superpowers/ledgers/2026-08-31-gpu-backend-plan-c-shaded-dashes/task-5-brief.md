### Task 5: The collector shades a dashed polyline

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: Task 1's bracket, Task 4's writers.
- Produces: the collector's dash state and its emission rule, which Task 6
  extends to curves and Task 8's oracle reproduces.

**The emission rule, stated once.** For a dashed primitive with *D* drawn
elements in its cycle, the collector emits **exactly *D* instances per
geometric primitive** (or exactly **one** when *D* is zero), consecutively, in
ascending cycle position. Instance *k* carries:

| field | value |
|---|---|
| `dashPeriod` | `periodLocal × factor`, negated when `k == 0` |
| `dashPhase` | `(phaseLocal mod periodLocal) × factor` |
| `dashFracStart` | `cumulative(k) / cycle` |
| `dashFracEnd` | `(cumulative(k) + |dashes[k]|) / cycle` |

where `periodLocal = cycle × patternToLocal`, and **`factor` is the primitive's
own local-to-collection length ratio**, not the residual's `scaleMagnitude`:

```
factor = (the primitive's length in collection space)
       / (the primitive's length in the space the pattern is measured in)
```

For a polyline segment both lengths are the segment's, so `factor` is 1
whenever the residual is a translation — which is every call the painter makes
— and is exactly right when it is not. **Computing it rather than assuming 1 is
what makes an anisotropic residual correct per segment instead of correct on
average**, which is the same approximation `draft_painter.dart`'s own
`anisotropicCurveCount` exists to count.

**Ruling C3 in code: `_suppressJoins`.** A dashed run emits no joins. The
reference gives every span its own `polyline` op and therefore its own run, so
it has no join geometry on a dashed polyline anywhere.

- [ ] **Step 1: Write the failing tests**

In `test/gpu/geometry_collector_test.dart`:

```dart
  const dashed = DashPattern(dashes: [12.0, -6.0], totalLength: 18.0);
  const dashDot = DashPattern(dashes: [12.0, -3.0, 0.5, -3.0], totalLength: 18.5);
  const allGap = DashPattern(dashes: [-4.0], totalLength: 4.0);
  const style = ResolvedStyle(
      argb: 0xFF112233,
      lineweightHundredths: 25,
      linetype: Handle(900),
      linetypeScale: 1.0);

  test('a dashed polyline emits one instance per segment per drawn element, '
      'and no joins at all', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, style,
        closed: false);
    c.endDash();
    c.endResidual();

    // Two segments, one drawn element, no joins.
    expect(c.instanceCount, 2);
    for (var i = 0; i < 2; i++) {
      expect(c.data[i * kFloatsPerInstance + InstanceFieldOffset.kind],
          kKindStroke,
          reason: 'a dashed run has no joins: the reference gives every span '
              'its own polyline op and therefore its own run');
    }
  });

  test('the same polyline undashed keeps its join -- so the assertion above '
      'is about dashes, not about the fixture', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(10, 20));
    c.polyline(Float64List.fromList([0, 0, 10, 0, 10, 10]), 3, style,
        closed: false);
    c.endResidual();
    expect(c.instanceCount, 3); // segment, join, segment
  });

  test('a two-element pattern doubles the instances and the two elements '
      'tile the cycle without overlapping', () {
    final c = /* as above, but beginDash(dashDot, 2.0) and one segment */;
    expect(c.instanceCount, 2);
    final e0Start = c.data[InstanceFieldOffset.dashFracStart];
    final e0End = c.data[InstanceFieldOffset.dashFracEnd];
    final e1Start =
        c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracStart];
    final e1End = c.data[kFloatsPerInstance + InstanceFieldOffset.dashFracEnd];
    expect(e0Start, 0.0);
    expect(e0End, closeTo(12.0 / 18.5, 1e-6));
    expect(e1Start, closeTo(15.0 / 18.5, 1e-6));
    expect(e1End, closeTo(15.5 / 18.5, 1e-6));
    expect(e0End, lessThan(e1Start), reason: 'the gap between them is a gap');
  });

  test('the period is the cycle times the scale, in collection units', () {
    // cycle 18, patternToLocal 2.0, residual a translation -> factor 1.
    final c = /* one dashed segment, beginDash(dashed, 2.0) */;
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(36.0, 1e-6));
  });

  test('a scaled residual scales the period, because the pattern is measured '
      'in the space the points are in', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 3.0));
    c.beginDash(dashed, 2.0);
    c.polyline(Float64List.fromList([0, 0, 10, 0]), 2, style, closed: false);
    c.endDash();
    c.endResidual();
    expect(c.data[InstanceFieldOffset.dashPeriod].abs(), closeTo(108.0, 1e-4),
        reason: '18 x 2.0 x 3.0');
  });

  test('exactly one instance per primitive is the collapse representative', () {
    final c = /* one dashed segment with dashDot, so D == 2 */;
    final periods = <double>[
      c.data[InstanceFieldOffset.dashPeriod],
      c.data[kFloatsPerInstance + InstanceFieldOffset.dashPeriod],
    ];
    expect(periods.where((p) => p < 0), hasLength(1),
        reason: 'two representatives would draw the collapsed line twice, '
            'and with blending on that is darker, not merely wasteful');
    expect(periods.first, lessThan(0), reason: 'the first drawn element');
  });

  test('a pattern with no drawn element still emits one instance, so the '
      'collapse case has something to draw', () {
    final c = /* one segment, beginDash(allGap, 2.0) */;
    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], lessThan(0));
    expect(c.data[InstanceFieldOffset.dashFracStart],
        c.data[InstanceFieldOffset.dashFracEnd],
        reason: 'an empty extent draws nothing until the pattern collapses, '
            'and the reference draws the whole line solid when it does');
  });

  test('endDash restores solid emission', () {
    final c = /* beginDash, one polyline, endDash, a second polyline */;
    // The second polyline is a plain two-segment run: two segments, one join.
    expect(c.instanceCount, 1 + 3);
  });

  test('a zero-cycle pattern is solid, matching dashPolyline returning false', () {
    const degenerate = DashPattern(dashes: [0.0], totalLength: 0.0);
    final c = /* beginDash(degenerate, 2.0), one segment */;
    expect(c.instanceCount, 1);
    expect(c.data[InstanceFieldOffset.dashPeriod], 0.0);
  });

  test('the phase of every polyline segment is zero -- the pattern restarts '
      'at each vertex, which is dasher.dart:94-96', () {
    final c = /* a three-segment dashed polyline */;
    for (var i = 0; i < c.instanceCount; i++) {
      expect(c.data[i * kFloatsPerInstance + InstanceFieldOffset.dashPhase], 0.0);
    }
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: instance counts are the solid ones and every dash field reads 0 —
`beginDash` is still the empty stub Task 1 left.

- [ ] **Step 3: Add the bracket state**

```dart
  // --- the dash bracket ---------------------------------------------------
  //
  // Set by `beginDash`, cleared by `endDash`. Kept as fields rather than
  // threaded through `_runTo` for the same reason `DraftPainter` keeps
  // `_spanSink` and `_spanStyle` as fields: the alternative is a closure or a
  // widened signature on the hot path, and this class's contract is that a
  // rebuild allocates per document, not per primitive.
  bool _dashActive = false;
  double _dashPeriodLocal = 0;
  double _dashCycle = 0;

  /// The drawn elements' extents, as fractions of the cycle. Two parallel
  /// lists rather than a list of pairs: a pair object per element per
  /// `beginDash` is an allocation per dashed entity per rebuild.
  final List<double> _dashFracStart = <double>[];
  final List<double> _dashFracEnd = <double>[];

  /// Per-primitive values, set immediately before the `_emit` / `_emitJoin`
  /// call that consumes them. Same idiom, same reason.
  double _pendingSegPeriod = 0, _pendingSegPhase = 0;
  double _pendingJoinPeriod = 0, _pendingJoinPhase = 0;
  bool _suppressJoins = false;

  @override
  bool get shadesDashes => true;

  @override
  void beginDash(DashPattern pattern, double patternToLocal) {
    _dashFracStart.clear();
    _dashFracEnd.clear();
    // The cycle is summed from the array, never read from
    // `pattern.totalLength` -- `dasher.dart` says why in as many words, and
    // this class must agree with the dasher about where a cycle ends or the
    // two draw different pictures from the same pattern.
    var cycle = 0.0;
    for (final d in pattern.dashes) {
      cycle += d.abs();
    }
    if (!cycle.isFinite || cycle <= 0.0 || !patternToLocal.isFinite) {
      // `dashPolyline` returns false here and the caller draws solid. This is
      // the same decision, reached by the same test.
      _dashActive = false;
      return;
    }
    _dashCycle = cycle;
    _dashPeriodLocal = cycle * patternToLocal;
    var at = 0.0;
    for (final d in pattern.dashes) {
      final w = d.abs();
      if (d >= 0) {
        _dashFracStart.add(at / cycle);
        _dashFracEnd.add((at + w) / cycle);
      }
      at += w;
    }
    _dashActive = true;
  }

  @override
  void endDash() {
    _dashActive = false;
    _suppressJoins = false;
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
  }
```

**A note the implementer must keep in the code**: `beginDash` uses `|d|` for
the extents where `dasher.dart` substitutes `1e-9` for a zero-length element
(`dasher.dart:169`). The divergence is `1e-9` pattern units per zero element,
which against a period the collapse rule floors at 3 device pixels is at most
`3 × 10^-10` px — below any representable difference. **Say that in the
comment**; a reader who spots the mismatch must find the arithmetic there
rather than "fixing" it.

- [ ] **Step 4: Make `_emit` and `_emitJoin` emit the element fan**

```dart
  /// Writes this primitive's instances: one, if it is solid; one per drawn
  /// pattern element, if it is dashed; exactly one, if it is dashed with a
  /// pattern that draws nothing.
  ///
  /// **The first instance carries a negative period.** That marks it as the
  /// primitive's collapse representative -- the one the shader draws solid
  /// when the live period falls under `kDashCollapsePx`, while its
  /// siblings collapse to a degenerate vertex. Without the mark, all of them
  /// draw solid and a collapsed translucent line is drawn D times over
  /// itself.
  void _emit(double x0, double y0, double x1, double y1, double half, int argb) {
    final dx = x1 - x0, dy = y1 - y0;
    if (math.sqrt(dx * dx + dy * dy) == 0) return;
    final period = _pendingSegPeriod;
    if (period == 0.0) {
      _reserve(_instances + 1);
      writeStroke(_buffer, _instances,
          x0: x0, y0: y0, x1: x1, y1: y1, halfWidth: half, argb: argb);
      _instances++;
      return;
    }
    final n = _dashFracStart.isEmpty ? 1 : _dashFracStart.length;
    _reserve(_instances + n);
    for (var k = 0; k < n; k++) {
      writeStroke(_buffer, _instances,
          x0: x0,
          y0: y0,
          x1: x1,
          y1: y1,
          halfWidth: half,
          argb: argb,
          dashPeriod: k == 0 ? -period : period,
          dashPhase: _pendingSegPhase,
          dashFracStart: k < _dashFracStart.length ? _dashFracStart[k] : 0.0,
          dashFracEnd: k < _dashFracEnd.length ? _dashFracEnd[k] : 0.0);
      _instances++;
    }
  }
```

`_emitJoin` takes the identical shape against `_pendingJoinPeriod` /
`_pendingJoinPhase`, keeping its existing `debugCollinearJoins` accounting —
**count the corner once, not once per element**, or that diagnostic starts
reporting *D* times the corners the drawing has.

- [ ] **Step 5: Suppress joins on a dashed run**

In `_runTo`, guard the join call:

```dart
    if (_runHasDirection && !_suppressJoins) {
      _emitJoin(_runPrevX, _runPrevY, _runBackX, _runBackY, x, y, half, argb);
    } else if (!_runHasDirection) {
      _runSecondX = x;
      _runSecondY = y;
    }
```

**Read that carefully — the `else` branch is not a stylistic rewrite.** The
original is `if (_runHasDirection) { join } else { record the second point }`,
and `_runSecondX/Y` must still be recorded on the first step even when joins
are suppressed, because `_endRun` uses it for the seam. Writing this as
`if (A && !B) {...} else {...}` would record the second point on *every*
suppressed step and corrupt the seam. The shape above is the correct one.

And in `_endRun`, guard the seam join with `!_suppressJoins` too — Task 6
derives why.

- [ ] **Step 6: Give `polyline` the dashed path**

```dart
  @override
  void polyline(Float64List points, int count, ResolvedStyle style,
      {required bool closed}) {
    if (count < 2) return;
    final half = _halfWidthFor(style.lineweightHundredths);
    final argb = _coveredArgb(style.argb, style.lineweightHundredths);
    final t = _residual;
    _suppressJoins = _dashActive;
    var px = t.a * points[0] + t.c * points[1] + t.e;
    var py = t.b * points[0] + t.d * points[1] + t.f;
    _beginRun(px, py);
    for (var i = 1; i < count; i++) {
      final lx = points[i * 2], ly = points[i * 2 + 1];
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive) {
        // The phase restarts at every vertex (`dasher.dart:94-96`), so a
        // polyline's segments all carry phase 0. The period is scaled by
        // THIS segment's own local-to-collection length ratio rather than by
        // the residual's scale magnitude: under an anisotropic residual the
        // two disagree, and only the first one is right for this segment.
        final llx = lx - points[i * 2 - 2], lly = ly - points[i * 2 - 1];
        final localLen = math.sqrt(llx * llx + lly * lly);
        final cdx = nx - px, cdy = ny - py;
        final collectionLen = math.sqrt(cdx * cdx + cdy * cdy);
        _pendingSegPeriod =
            localLen > 0 ? _dashPeriodLocal * (collectionLen / localLen) : 0.0;
        _pendingSegPhase = 0.0;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    _endRun(closed: closed, half: half, argb: argb);
    _suppressJoins = false;
    _pendingSegPeriod = 0;
  }
```

**Watch the `_pendingSegPeriod = 0` at the end.** A pending value that
survives the primitive is a value the next solid primitive silently inherits.
The final `endDash` clears it too; both are needed, because `polyline` can be
called twice inside one bracket.

- [ ] **Step 7: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart && flutter test
```
Expected: the new tests pass; everything else is unchanged, because
`_dashActive` is false for every existing caller.

- [ ] **Step 8: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): a dashed polyline collects as elements, not as spans"
```

---


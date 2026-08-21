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


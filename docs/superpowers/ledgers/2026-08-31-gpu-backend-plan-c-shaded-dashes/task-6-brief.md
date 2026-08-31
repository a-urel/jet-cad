### Task 6: The collector shades a dashed circle and arc

**Files:**
- Modify: `lib/src/gpu/geometry_collector.dart`
- Test: `test/gpu/geometry_collector_test.dart`

**Interfaces:**
- Consumes: Task 5's state and emission rule.
- Produces: the arc phase law, which Task 8's oracle reproduces.

**Ruling C3, third clause — derived here rather than assumed.** A dashed
closed run gets **no seam join**. The reference emits each arc span as its own
`arc()` op (`draft_painter.dart:311-314`), so a dashed circle is a sequence of
*open* runs and there is no closed run anywhere in it — the seam join, which
exists only on a closed run, is not drawn. Suppressing it on a dashed run is
therefore the reference's behaviour, not an omission. **A dashed circle is
notched at its start angle in both arms, and the solid circle's seam test
remains the gate that the notch is fixed when the linetype is continuous.**

**The phase law.** `dasher.dart` measures the pattern along the arc in
**local** units — `_walkArcRange` converts a distance to an angle by dividing
by `r` (`dasher.dart:346`), and `dashArc` is passed `scale = linetypeScale ×
globalLinetypeScale` with no screen term. So:

```
phaseLocal(i)  = r * |step| * i          // arc length from `start` to vertex i
period(i)      = periodLocal * factor(i)
factor(i)      = |chord i in collection space| / (r * |step|)
phase(i)       = (phaseLocal(i) mod periodLocal) * factor(i)
```

**`factor` divides by the local ARC length, not the local chord length.** The
reference measures the pattern along the arc; the shaded arm measures it along
the chord the shader draws. Dividing by the arc length makes the two agree at
every chord *endpoint* exactly, and leaves a bounded disagreement inside a
chord — at most `arc − chord` over one chord, which for a chord flattened to
`kFlattenTolerance = 0.25` px of sagitta is under a tenth of a pixel of phase
at the collection scale. **That is the honest form of Ruling C4** and the
comment in the code must say it.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a dashed arc carries a running phase, and consecutive chords advance '
      'it by one chord of arc length', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.translation(5, 7));
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, 40, 0, 1.2, style);
    c.endDash();
    c.endResidual();

    // Read the phases off the stroke instances in order.
    final phases = <double>[/* every kKindStroke instance's dashPhase */];
    expect(phases.first, 0.0);
    // Each step advances by r * |sweep| / steps, reduced mod the period.
    final period = /* the first instance's |dashPeriod| */;
    for (var i = 1; i < phases.length; i++) {
      final delta = (phases[i] - phases[i - 1] + period) % period;
      expect(delta, closeTo(expectedChordArc, 1e-3),
          reason: 'a constant advance is what "running" means; a phase that '
              'restarts per chord is dasher.dart\'s polyline rule applied '
              'to a curve, which is the spec\'s own named mutation');
    }
  });

  test('a dashed circle emits no seam join', () {
    final c = /* beginDash(dashed, 0.5); circle(0, 0, 40, style); endDash() */;
    final solid = /* the same circle with no bracket */;
    // The solid circle's join count is chords; the dashed one's is chords - 1
    // (interior joins only, no seam).
    expect(joinCount(c), joinCount(solid) - 1);
  });

  test('a solid circle still has its seam join -- the assertion above is '
      'about dashes', () {
    // Guards against "no joins at all" passing the test above.
    final solid = /* circle, no bracket */;
    expect(joinCount(solid), greaterThan(0));
  });

  test('the chord count does not change when a dash bracket is open', () {
    // Flattening is a scale decision, not a linetype one. A dashed arc that
    // chorded differently from a solid one would put the two arms' geometry
    // in different places for a reason that has nothing to do with the
    // pattern.
    expect(strokeCount(dashedArc) ~/ drawnElements, strokeCount(solidArc));
  });

  test('an anisotropic residual scales each chord\'s period by that chord\'s '
      'own ratio, not by one number for the whole arc', () {
    final c = GeometryCollector(pixelsPerPaperMm: 3.78, devicePixelRatio: 2.0);
    c.beginResidual(Transform2.scale(3.0, 1.0)); // a circle becomes an ellipse
    c.beginDash(dashed, 0.5);
    c.arc(0, 0, 40, 0, math.pi, style);
    c.endDash();
    c.endResidual();
    final periods = <double>[/* every stroke instance's |dashPeriod| */];
    expect(periods.reduce(math.max) / periods.reduce(math.min),
        closeTo(3.0, 0.1),
        reason: 'a chord along x is stretched 3x and a chord along y is not; '
            'one period for the whole arc would read 1.0 here and would be '
            'the scaleMagnitude approximation this fixture exists to reject');
  });

  test('the phase is reduced into [0, period) at collection', () {
    // A long arc accumulates many periods; leaving them in the record spends
    // float32 precision the fragment stage needs for `fract`.
    final c = /* a long dashed arc */;
    for (final phase in allPhases) {
      expect(phase, greaterThanOrEqualTo(0.0));
      expect(phase, lessThan(matchingPeriod));
    }
  });
```

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/gpu/geometry_collector_test.dart
```
Expected: every phase reads 0 — `_flatten` sets no pending dash values.

- [ ] **Step 3: Thread the phase through `_flatten`**

Inside `_flatten`, after `steps` and `step` are computed:

```dart
    _suppressJoins = false; // arcs keep their interior joins -- Ruling C3
    final arcStep = r * step.abs(); // local arc length per chord
    var lx = cx + r * math.cos(start);
    var ly = cy + r * math.sin(start);
    var px = t.a * lx + t.c * ly + t.e;
    var py = t.b * lx + t.d * ly + t.f;
    _beginRun(px, py);
    final last = closed ? steps - 1 : steps;
    for (var i = 1; i <= last; i++) {
      final angle = start + step * i;
      lx = cx + r * math.cos(angle);
      ly = cy + r * math.sin(angle);
      final nx = t.a * lx + t.c * ly + t.e;
      final ny = t.b * lx + t.d * ly + t.f;
      if (_dashActive && arcStep > 0) {
        final cdx = nx - px, cdy = ny - py;
        // The pattern is measured along the ARC and drawn along the CHORD.
        // Dividing the chord's collection length by the chord's LOCAL ARC
        // length makes the two agree exactly at every chord endpoint and
        // leaves the disagreement inside one chord, bounded by (arc - chord)
        // -- under a tenth of a pixel at this flattener's 0.25 px sagitta.
        // Ruling C4 records this rather than removing it: removing it means
        // re-chording per span, which is chording at one camera, which is
        // what this plan exists to stop doing.
        final factor = math.sqrt(cdx * cdx + cdy * cdy) / arcStep;
        _pendingSegPeriod = _dashPeriodLocal * factor;
        _pendingSegPhase = (arcStep * (i - 1)) % _dashPeriodLocal * factor;
        // The join at the vertex this step arrives from sits at the START of
        // this chord, so it takes this chord's phase and this chord's factor.
        _pendingJoinPeriod = _pendingSegPeriod;
        _pendingJoinPhase = _pendingSegPhase;
      }
      _runTo(nx, ny, half, argb);
      px = nx;
      py = ny;
    }
    if (_dashActive) _suppressJoins = true; // no seam join -- Ruling C3
    _endRun(closed: closed, half: half, argb: argb);
    _suppressJoins = false;
    _pendingSegPeriod = 0;
    _pendingSegPhase = 0;
    _pendingJoinPeriod = 0;
    _pendingJoinPhase = 0;
```

**Read the `_pendingSegPhase` line's precedence.** Dart's `%` and `*` bind
left to right at the same precedence, so
`(arcStep * (i - 1)) % _dashPeriodLocal * factor` is
`(((arcStep * (i - 1)) % _dashPeriodLocal) * factor)` — the reduction happens
before the scaling, which is what the phase law requires. **Parenthesise it
anyway.** A precedence argument in a comment is a defect waiting for a reader
who does not check.

**And read the `_endRun` ordering.** The closing chord that `_endRun` emits for
a closed run carries the *last* pending values, which are the final chord's —
correct, since the closing chord is the arc's last one. Setting
`_suppressJoins = true` before `_endRun` suppresses the seam join without
suppressing that closing chord's own emission, because `_emit` does not consult
`_suppressJoins` at all.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test
```

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/gpu/geometry_collector.dart packages/jet_cad_2d_flutter/test/gpu/geometry_collector_test.dart
git commit -m "feat(gpu): a dashed arc carries a running phase, per chord"
```

---


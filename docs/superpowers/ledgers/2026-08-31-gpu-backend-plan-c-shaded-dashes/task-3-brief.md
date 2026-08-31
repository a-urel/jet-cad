### Task 3: `shadedDashFixture()` — the corpus, and why it is not the old one

**Files:**
- Modify: `test/support/fixtures.dart`
- Test: `test/support/fixtures_test.dart` (create if absent)

**Interfaces:**
- Produces: `DraftDocument shadedDashFixture({double linetypeScale})` and the
  handles it uses, which later tasks name.

**Ruling C5 is the whole reason this is a new function.** Put the reason in
the doc comment, in the file, where the next reader will be: the
painter-versus-`reference_walk` oracle in `test/differential_test.dart` runs on
`differentialFixture`, and `reference_walk.dart` does not dash. A dashed entity
there makes that oracle red for a reason that has nothing to do with dashes.

- [ ] **Step 1: Write the fixture**

Append to `test/support/fixtures.dart`:

```dart
/// The corpus for shaded dashes.
///
/// **Separate from [differentialFixture] on purpose, and the reason is not
/// tidiness.** `test/differential_test.dart` compares [DraftPainter] against
/// `reference_walk.dart`, and the reference walk does not dash at all -- it
/// emits raw `polyline` and `arc` ops. A dashed entity in
/// [differentialFixture] would make the painter emit spans and the reference
/// walk emit whole polylines, reddening this project's oldest correctness
/// gate over a difference that is not a defect. The cost of the split is
/// that every gate which should see dashes needs a dashed arm written for it
/// explicitly; Plan C's results note lists the gates that have one.
///
/// **Nothing here sits at the identity, the origin, or a uniform scale.**
/// Every placement carries a rotation and a distinct non-uniform scale --
/// `CLAUDE.md`'s named dominant failure mode is the degenerate fixture, and a
/// dashed arc under an anisotropic placement is exactly the case Ruling C4
/// bounds.
///
/// Handles, so a test can name what it is looking at:
///
/// | handle | what |
/// |---|---|
/// | 900 | the `DASHED` linetype, `[12, -6]` -- one drawn element |
/// | 901 | the `DASHDOT` linetype, `[12, -3, 0.5, -3]` -- two drawn elements |
/// | 902 | the `ALLGAP` linetype, `[-4]` -- **no** drawn element |
/// | 910 | a five-vertex dashed polyline, three interior corners |
/// | 911 | a dashed circle -- a closed run, so the seam join is in play |
/// | 912 | a dashed arc under the non-uniform instance |
/// | 913 | a `DASHDOT` line, so `D == 2` has a witness |
/// | 914 | an `ALLGAP` line, so the collapse representative has a witness |
/// | 915 | a **solid** line crossing 910, so dash gaps have something behind them |
/// | 916 | a hairline dashed line (`lineweight: 1`), so `_coveredArgb` meets a dash |
DraftDocument shadedDashFixture({double linetypeScale = 1.0}) {
  // ... construction ...
}
```

**Construction requirements, each with its reason — the implementer chooses
the exact coordinates:**

1. **Register three linetypes** at handles 900, 901, 902 with the patterns in
   the table. `DashPattern(dashes: [...], totalLength: <the sum of the
   absolute values>)`. The totals must be *consistent* with the dashes here;
   `dasher.dart` deliberately ignores `totalLength` and this fixture must not
   be the place that hides a disagreement.
2. **Entity 910 is a five-point polyline with three interior vertices**, at
   least one of them a sharp turn (interior angle under 90°) and one nearly
   straight (turn under 5°). Ruling C3 says a dashed run emits no joins;
   a fixture whose corners are all shallow cannot tell a missing join from a
   collinear one.
3. **The whole document must span enough length that every pattern repeats at
   least four times** at the camera the tests use. A fixture where the pattern
   fits once is a fixture where `fract` is never exercised past its first
   cycle. Assert this in Step 2 rather than eyeballing it.
4. **Entity 916 carries `lineweight: 1`**, which is below one device pixel at
   `dpr` 1 and therefore routes through `_coveredArgb`. Plan B's final review
   found `lineweightScale` sitting at the identity in every instrument; a
   dashed hairline is a second, independent place that factor has to be right.
5. **Set `doc.header.globalLinetypeScale` to something other than 1.0** — use
   `1.7`. It is a multiplicand in `_dashScale` and a fixture that leaves it at
   1 cannot tell it from a dropped term.
6. The `linetypeScale` parameter multiplies entity 913's `linetypeScale` field
   only, so a test can vary one entity's rate without rebuilding the corpus.

- [ ] **Step 2: Write the fixture's own guard test**

The fixture is an instrument, so it gets a test that fails when it goes
degenerate. In `test/support/fixtures_test.dart`:

```dart
  test('shadedDashFixture is not degenerate in any of the four ways that '
      'would make a dash test pass vacuously', () {
    final doc = shadedDashFixture();

    // 1. globalLinetypeScale is a real multiplicand.
    expect(doc.header.globalLinetypeScale, isNot(1.0));

    // 2. Every placement is non-uniform and rotated.
    for (final node in /* the fixture's instance and group nodes */) {
      final t = node.transform;
      expect(t.a * t.d - t.b * t.c, isNot(0.0));
      expect((t.a.abs() - t.d.abs()).abs(), greaterThan(0.05),
          reason: 'a uniform scale cannot distinguish Ruling C4 divergence '
              'from agreement');
      expect(t.b, isNot(0.0), reason: 'unrotated');
    }

    // 3. The pattern repeats. Painted at the test camera, the longest dashed
    //    entity must be at least four periods long.
    // ... measure it through DraftPainter into a shading RecordingDrawSink,
    //     divide the polyline's screen length by cycle * patternToLocal ...
    expect(repeats, greaterThan(4.0));

    // 4. The three patterns have three different drawn-element counts.
    expect(<int>{drawnElements(900), drawnElements(901), drawnElements(902)},
        <int>{1, 2, 0});
  });
```

- [ ] **Step 3: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: green once the fixture satisfies its own guard. **If assertion 3
fails, lengthen the geometry — do not lower the threshold.**

- [ ] **Step 4: Prove the split was necessary**

This is the step that makes Ruling C5 evidence instead of assertion. Add the
dashed polyline to `differentialFixture` **temporarily**, run
`flutter test test/differential_test.dart`, record what it printed, then
**revert with `git checkout -- test/support/fixtures.dart`** (this file is
committed and unmodified at this point, so the ban on `git checkout --` for
mutation reverts does not apply — the ban is about reverting *uncommitted work*).
Paste the failure into the task report. If it does **not** fail, say so: the
ruling then rests on a premise that did not hold and Task 12 must record that.

- [ ] **Step 5: Commit**

```sh
git add packages/jet_cad_2d_flutter/test/support/fixtures.dart packages/jet_cad_2d_flutter/test/support/fixtures_test.dart
git commit -m "test(fixtures): a dashed corpus, separate from the walk oracle's"
```

---


### Task 2: The painter routes undashed geometry to a shading sink

**Files:**
- Modify: `lib/src/draft_painter.dart`
- Test: `test/draft_painter_test.dart`

**Interfaces:**
- Consumes: Task 1's `shadesDashes`, `beginDash`, `endDash`, `BeginDashOp`.
- Produces: nothing new. This task is a branch at three call sites.

**The three sites, and nothing else.** `_patternFor(style)` is consulted in
exactly three places today: the polyline path in `_emitScreenSpace`, and the
`circle` and `arc` cases in the residual path. Each grows the same branch,
between the `pattern == null` early return and the `_dasher` call.

- [ ] **Step 1: Write the failing test**

Append to `test/draft_painter_test.dart`. It reuses that file's own local
`dashedFixture` helper, which already registers a `DASHED` linetype with
`DashPattern(dashes: [12.0, -6.0], totalLength: 18.0)`:

```dart
  test('a shading sink is handed the undashed polyline inside a bracket, '
      'and the bracket carries the painter\'s own dash scale', () {
    final doc = dashedFixture(
        placement: Transform2.translation(3, 2).multiply(Transform2.scale(2, 2)));
    final sink = RecordingDrawSink(shadesDashes: true);
    final camera = ViewportTransform.fit(worldOf(doc), kViewport);
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    DraftPainter(
            document: doc, index: index, resolver: DocumentStyleResolver(doc))
        .paint(sink, camera, kViewport);

    final begins = sink.ops.whereType<BeginDashOp>().toList();
    expect(begins, hasLength(1),
        reason: 'one dashed leaf, one bracket -- not one per span');
    expect(sink.ops.whereType<EndDashOp>(), hasLength(1));

    // The undashed geometry, whole: two points, not a span list.
    final lines = sink.ops.whereType<PolylineOp>().toList();
    expect(lines, hasLength(1));
    expect(lines.single.points, hasLength(4));

    // The scale is the painter's own `_dashScale`: linetypeScale ×
    // globalLinetypeScale × toScreen.scaleMagnitude. Asserted as an
    // arithmetic identity against the camera, not as a copied literal --
    // a literal would survive the factor being dropped.
    final expected = 1.0 *
        doc.header.globalLinetypeScale *
        (camera.worldToScreenMatrix.scaleMagnitude * 2.0 /* placement */);
    expect(begins.single.patternToLocal, closeTo(expected, 1e-9));
  });

  test('a non-shading sink still gets spans, and no bracket', () {
    final doc = dashedFixture(placement: Transform2.translation(3, 2));
    final sink = RecordingDrawSink(); // shadesDashes: false
    // ... paint as above ...
    expect(sink.ops.whereType<BeginDashOp>(), isEmpty);
    expect(sink.ops.whereType<PolylineOp>().length, greaterThan(1),
        reason: 'the dasher cut this line into spans, as it always has');
  });

  test('a shading sink sees no dash-span counters move', () {
    // `dashSpanCount` and `collapsedDashCount` describe the dasher's work,
    // and a shading sink means the dasher never ran. Zero here is the
    // correct reading, not a broken counter -- Task 12's results note says
    // so where the harness prints them.
    final painter = /* painted into a shading sink over dashedFixture */;
    expect(painter.dashSpanCount, 0);
    expect(painter.collapsedDashCount, 0);
  });
```

**Implementer note:** the file's existing dashed tests build their camera and
painter a particular way — copy that construction rather than inventing one,
and replace the `/* ... */` placeholders above with it. The assertions are the
requirement; the scaffolding is the file's own.

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart
```
Expected: the first test fails on `begins` being empty — the painter still
dashes into every sink.

- [ ] **Step 3: Branch the polyline site**

In `_emitScreenSpace`, immediately after the `if (pattern == null) { ... }`
block and **before** `_spanSink = sink;`:

```dart
    if (sink.shadesDashes) {
      // The sink evaluates the pattern itself, per fragment, at the live
      // camera. Handing it spans instead would freeze the dash count at
      // whatever camera this walk ran under -- which for the resident
      // backend is a camera the viewer is not looking through.
      sink.beginDash(pattern, _dashScale(style, toScreen));
      sink.polyline(_points, count, style, closed: false);
      sink.endDash();
      sink.endResidual();
      return;
    }
```

- [ ] **Step 4: Branch the two curve sites**

In the `EntityKind.circle` case, after its own `pattern == null` early return:

```dart
        if (sink.shadesDashes) {
          // Local units, not screen: the coordinates below stay in the
          // leaf's own space and the residual carries the scale, so the
          // factor must not include `chain.scaleMagnitude` -- the same
          // reason `dashArc` is passed this value and `pixelScale`
          // separately.
          sink.beginDash(pattern,
              style.linetypeScale * document.header.globalLinetypeScale);
          sink.circle(coords[0] - ox, coords[1] - oy, r, style);
          sink.endDash();
          return;
        }
```

And the identical shape in `EntityKind.arc`, calling
`sink.arc(coords[0] - ox, coords[1] - oy, r, start, sweep, style)`.

**Do not factor these three into one helper.** They differ in the scale they
pass and in the op they emit, and the two curve cases differ from each other
in their arguments; a helper would take four parameters to save six lines and
would put the one value this task is about — the scale — behind an indirection.

- [ ] **Step 5: Run the tests**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/draft_painter_test.dart && flutter test
```
Expected: green, including every existing dashed test — they all use
non-shading sinks and take the unchanged route.

- [ ] **Step 6: Commit**

```sh
git add packages/jet_cad_2d_flutter/lib/src/draft_painter.dart packages/jet_cad_2d_flutter/test/draft_painter_test.dart
git commit -m "feat(painter): a dash-shading sink gets the pattern, not the spans"
```

---


## Task 6: the oracle derives its own cull, and every painter site gets a margin

**Files:**
- Modify: `packages/jet_cad_2d_flutter/lib/src/reference_walk.dart:29-42`, `:154-175`
- Modify: `packages/jet_cad_2d_flutter/test/support/fixtures.dart:154`, `:167`
- Modify: `packages/jet_cad_2d_flutter/test/differential_test.dart:63`
- Audit and, where needed, modify: every file constructing a `DraftPainter`

**Interfaces:**
- Consumes: `kMinTextCapPixels`, `DraftPainter.minTextCapPixels` from Task 5.
- Produces: `referenceWalk(DraftDocument, DrawSink, ViewportTransform, Size, StyleResolver, {double minTextCapPixels = kMinTextCapPixels})`; `paintToRecording(DraftDocument, [ViewportTransform?], {double minTextCapPixels})`; `referenceToRecording(DraftDocument, [ViewportTransform?], {double minTextCapPixels})`.

**The walk computes the cull itself.** It must not ask the painter what it decided — sharing the decision would have the oracle share the assumption it exists to test. This is the correction Plan 3e made at `24cfd23` for fill triangulation, applied here before it can go wrong.

**LOD arrives by default value, so it has no compiler-visible call site.** Seventeen files construct a `DraftPainter` and every one of them silently gains culling. This task sweeps all of them.

- [ ] **Step 1: Write the failing differential test**

Add to `packages/jet_cad_2d_flutter/test/text_lod_test.dart`:

```dart
  test('painter and oracle cull the same text under a non-identity placement',
      () {
    // Deliberately not at the identity and not at the origin: the painter and
    // the walk reach `chain` by different routes, and a fixture at the identity
    // transform cannot tell a shared decision from two agreeing ones.
    final m = FlutterTextMeasurer();
    addTearDown(m.clear);
    final doc = textLodDifferentialDocument(m);
    final world = doc.extents;
    final view = ViewportTransform.fit(world, kViewport);

    final painted = paintToRecording(doc, view);
    final walked = referenceToRecording(doc, view);

    expect(painted.length, walked.length);
    for (var i = 0; i < painted.length; i++) {
      expect(painted[i], walked[i], reason: 'op $i');
    }
    // Non-vacuity: if nothing were culled this would pass with LOD deleted.
    final all = paintToRecording(doc, view, minTextCapPixels: 0.0);
    expect(all.length, greaterThan(painted.length));
  });
```

with a fixture in `test/support/fixtures.dart` that places text at three heights inside a scaled, rotated, off-origin instance so the two routes to `chain` differ:

```dart
/// Adds one text entity, which [addEntity] cannot: text carries `text`,
/// `textStyle` and `textAttrs` on the record rather than in the payload.
Handle addText(
  DraftDocument doc,
  Handle owner,
  Handle handle,
  String text,
  double x,
  double y,
  double height,
) {
  doc.commands.execute(AddEntityCommand(
    record: EntityRecord(
      handle: handle,
      owner: owner,
      kind: EntityKind.text,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.byLayerLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const ByLayerColor(),
      lineweight: 25,
      transparency: 0,
      flags: 0,
      text: text,
      textStyle: ReservedHandles.standardTextStyle,
      textAttrs: packTextAttrs(),
    ),
    payload: GeometryPayload(
      coords: Float64List.fromList([x, y]),
      // height, rotation, widthFactor, obliqueAngle.
      scalars: Float64List.fromList([height, 0, 1, 0]),
    ),
  ));
  return handle;
}

/// A drawing whose text straddles [kMinTextCapPixels] at the fitted camera,
/// placed under a scaled and rotated instance well away from the origin.
///
/// Every property here is load-bearing. At the identity transform the painter's
/// `chain` and the walk's `chain` are the same matrix by accident rather than
/// by agreement, so a walk that read the painter's decision would pass. Away
/// from the origin the rebase term differs between the two. And three heights
/// straddling the threshold are what make the comparison about culling rather
/// than about drawing.
///
/// The arithmetic the heights come from: the root line spans 16,000 x 12,000
/// world units into [kViewport]'s 800 x 600, so the fit is about 0.05 px per
/// world unit; the instance scales by 0.35; so on-screen cap height is roughly
/// `height * 0.0175`, and 3.0 px falls at a height of about 171.
DraftDocument textLodDifferentialDocument(TextMeasurer measurer) {
  final doc = DraftDocument.empty(measurer: measurer);

  // The drawing's real extent, so the camera fit is decided by this and not by
  // whichever glyph box happens to be widest.
  addEntity(doc, doc.rootHandle, const Handle(890), EntityKind.line,
      [0, 0, 16000, 12000], const []);

  const labels = Handle(900);
  // Not `const`: `Vector2.zero()` is not a const constructor, which is why
  // `differentialFixture` spells it this way too.
  doc.tree.addDefinition(Definition(
      handle: labels,
      name: 'labels',
      basePoint: Vector2.zero(),
      children: const []));

  // Definition-local coordinates, so nothing here is at the world origin once
  // the instance places it.
  addText(doc, labels, const Handle(901), 'TINY', 0, 0, 40);
  addText(doc, labels, const Handle(902), 'EDGE', 0, 900, 172);
  addText(doc, labels, const Handle(903), 'LARGE', 0, 2400, 800);

  // Rotated, uniformly scaled, and far from the origin. Uniform scale keeps
  // `scaleMagnitude` exactly 0.35 so the arithmetic above is checkable; the
  // rotation and the translation are what make the painter's and the walk's
  // routes to `chain` genuinely different rather than accidentally equal.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(12000, 9000)
        .multiply(Transform2.rotation(0.4))
        .multiply(Transform2.scale(0.35, 0.35)),
    definition: labels,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(3),
  )));

  return doc;
}
```

**The three heights are a starting point derived from the arithmetic above, not a measurement.** `ViewportTransform.fit` may add margin, which moves the fit scale. Before Step 2, print the actual on-screen cap height for all three — `layout.height * chain.scaleMagnitude`, or equivalently `height * 0.35 * fitScale` — and **state all three numbers in the task report**. `TINY` must land clearly below 3.0, `LARGE` clearly above, and `EDGE` within about 10% of 3.0. If the fit does not produce that, **the heights move, not the threshold**: a fixture tuned by changing `kMinTextCapPixels` is a fixture that tests nothing.

- [ ] **Step 2: Run it to verify it fails**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test test/text_lod_test.dart --plain-name "painter and oracle"
```

Expected: FAIL — `painted.length` is less than `walked.length`, because the painter culls and the walk does not.

- [ ] **Step 3: Thread the threshold and derive the cull in the walk**

In `reference_walk.dart`, change the signature:

```dart
void referenceWalk(
  DraftDocument doc,
  DrawSink sink,
  ViewportTransform camera,
  Size viewport,
  StyleResolver resolver, {
  double minTextCapPixels = kMinTextCapPixels,
}) {
```

carry it into `_ReferenceWalk`, and inside the text branch, immediately after the empty-string guard:

```dart
      final attrs = resolveTextAttributes(
          payload, doc.entities.textAttrsAt(slot), record);
      // The same rule the painter applies, computed here rather than asked for.
      // An oracle that read the painter's decision would share the assumption
      // it exists to test — the correction Plan 3e made at 24cfd23 for fill
      // triangulation. The walk reaches `chain` by its own route, so this is a
      // genuinely independent number.
      if (attrs.height * chain.scaleMagnitude < minTextCapPixels) return;
      final metrics = doc.textMeasurer.measure(text: text, style: record);
```

moving the existing `resolveTextAttributes` call above the metrics call.

- [ ] **Step 4: Thread it through both recording helpers**

In `test/support/fixtures.dart`:

```dart
List<DrawOp> paintToRecording(DraftDocument doc,
    [ViewportTransform? camera,
    double minTextCapPixels = kMinTextCapPixels]) {
  final index = SpatialIndex(doc);
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  DraftPainter(
          document: doc,
          index: index,
          resolver: DocumentStyleResolver(doc),
          minTextCapPixels: minTextCapPixels)
      .paint(sink, view, kViewport);
  index.dispose();
  return sink.ops;
}

List<DrawOp> referenceToRecording(DraftDocument doc,
    [ViewportTransform? camera,
    double minTextCapPixels = kMinTextCapPixels]) {
  final view = camera ?? ViewportTransform.fit(doc.extents, kViewport);
  final sink = RecordingDrawSink();
  referenceWalk(doc, sink, view, kViewport, DocumentStyleResolver(doc),
      minTextCapPixels: minTextCapPixels);
  return sink.ops;
}
```

**Both sides, not just the oracle.** Matched on/off control arms need both steerable, and the fixture above has to drive painter and oracle to the same number on purpose.

- [ ] **Step 5: Sweep every `DraftPainter` construction site**

Run:

```bash
grep -rn "DraftPainter(" packages/jet_cad_2d_flutter/test packages/jet_cad_2d_flutter/lib apps/dev_harness_2d
```

Expected: seventeen files. For each, determine whether it draws text:

```bash
for f in $(grep -rl "DraftPainter(" packages/jet_cad_2d_flutter/test); do \
  n=$(grep -c "EntityKind.text\|EntityKind.attrib\|labelFraction\|attributedInstanceFraction" $f); \
  [ "$n" -gt 0 ] && echo "$n  $f"; done | sort -rn
```

Expected, before this task's own additions: `test/text_paint_test.dart`, `test/rig/paint_microbench_test.dart`, `test/support/sink_comparison.dart`, `test/draft_painter_root_test.dart`, `test/draft_canvas_test.dart`.

**For each text-bearing site, record in the report the smallest text cap height in pixels at the camera it uses, against the 3.0 threshold** — the way `text_ladder`'s 7.3x margin is recorded in the spec. A site whose margin is thin gets `minTextCapPixels: 0` **explicitly**, so a later threshold change cannot silently empty it. A site whose margin is wide is left on the default and its number is written down.

- [ ] **Step 6: Run everything**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test && CI=true flutter test --tags golden && flutter analyze
```

Expected: PASS, no golden PNG regenerated.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d_flutter/lib/src/reference_walk.dart \
        packages/jet_cad_2d_flutter/test
git commit -m "test: the reference walk derives its own cull, and every painter site has a margin"
```

---


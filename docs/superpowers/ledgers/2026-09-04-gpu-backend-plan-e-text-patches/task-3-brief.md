### Task 3: The corpus — labels the spec names, and a guard that each overlap is real

**Files:**
- Modify: `test/support/fixtures.dart` (add `textOverlapFixture`)
- Modify: `test/support/fixtures_test.dart`

**Interfaces:**
- Consumes: `addEntity`, `addText`, `AddRegionCommand`, `AddNodeCommand`,
  `InstanceNode`, `DraftDocument.empty(measurer:)`.
- Produces: `DraftDocument textOverlapFixture(TextMeasurer measurer, {int
  grazeLineweight = 400})` with the handle table below;
  `kTextOverlapLabelHeight = 600.0`; `Future<int> strokeInkInsideLabel(doc,
  stroke, label)`.

**The spec's corpus, for text** (revision 5, "Testing"): *text overlapped by
a stroke of higher handle, and by a translucent fill of higher handle; text a
stroke of higher handle passes within its width of but whose centerline misses
the glyphs; text overlapped by a stroke of lower handle only; the overlapped
label at four scales inside the band, including its lower edge; text near the
culling threshold; text under a mirrored / non-uniform instance.* The four
scales are the gate's business (Task 5); the rest is this document.

| handle | what | why |
|---|---|---|
| 900 | a thick solid stroke, lineweight 120, crossing the middle of label 901 | **lower** handle: must stay UNDER the label; a classifier admitting earlier instances draws it over |
| 901 | label `'COVERED'`, height 600 | the patched label: 903 and 905 reach it |
| 903 | a thick solid stroke, lineweight 120, crossing the middle of label 901 | **higher** handle: must draw OVER the label — the spec's headline mutation |
| 904/905 | a translucent fill (transparency 128) and its polygon boundary, x 4300..7000, over the right half of label 901 (which spans x ~3000..5500) | `srcATop` vs `srcOver` — a double blend shows outside the glyphs |
| 911 | label `'UNDER'`, height 600 | overlapped by 910 only |
| 910 | a thick stroke crossing label 911, **lower** handle | the label nothing later reaches: zero patches, drawn as a plain paragraph |
| 921 | label `'GRAZED'`, height 600 | |
| 922 | a stroke of lineweight 400 whose centerline runs just above label 921's box, within its width of the glyphs | the centerline-vs-reach mutation |
| 931 | label `'TINY'`, height 140 | near `kMinTextCapPixels` at the fitted camera: culled or not, both arms must agree |
| 990 | the placement instance: rotated 0.3 rad, **mirrored** (`scale(-0.9, 1.1)`), off-origin | an identity placement hides a transposed box corner |

All entities live in one definition (`Handle(890)`) placed by instance 990,
so every label sits under a non-uniform, mirrored, rotated residual. The
definition's floor is a 30,000 × 20,000 unit rectangle (handle 899, a thin
line across its diagonal) so the fitted camera at 800 × 600 logical is about
0.026 px/unit and a 600-unit label is ~16 px tall — comfortably above
`kMinTextCapPixels` (3) at every band scale from 0.5 to 2.0, while `'TINY'`
at 140 units is ~3.6 px at scale 1 and crosses the threshold inside the band.

- [ ] **Step 1: Write the guard tests first**

Append to `test/support/fixtures_test.dart`:

```dart
  group('textOverlapFixture', () {
    late DraftDocument doc;
    setUp(() => doc = textOverlapFixture(FlutterTextMeasurer()));

    test('has the handles the table names, and the strokes are thick', () {
      for (final h in [900, 901, 903, 904, 905, 910, 911, 921, 922, 931]) {
        expect(doc.entities.slotOf(Handle(h)), isNotNull, reason: 'handle $h');
      }
      int lineweightOf(int h) =>
          doc.entities.lineweightAt(doc.entities.slotOf(Handle(h))!);
      expect(lineweightOf(903), 120);
      expect(lineweightOf(922), 400);
    });

    test('the placement is mirrored, rotated and non-uniform', () {
      // `DocumentTree.operator []` is the lookup by handle (`tree.dart:12`).
      final t = (doc.tree[const Handle(990)]! as InstanceNode).transform;
      expect(t.determinant, lessThan(0), reason: 'mirrored');
      expect(t.b, isNot(0.0), reason: 'rotated');
      expect(t.anisotropyRatio, isNot(closeTo(1.0, 1e-6)),
          reason: 'non-uniform');
    });

    test('stroke 903 actually crosses label 901 at the fitted camera', () {
      // The overlap is measured, not assumed: the label alone is painted
      // through the reference and its ink read back; then the stroke alone;
      // the two must share at least 200 device pixels. `strokeInkInsideLabel`
      // is the same instrument Task 5's gate reads.
      expect(strokeInkInsideLabel(doc, const Handle(903), const Handle(901)),
          greaterThan(200));
      expect(strokeInkInsideLabel(doc, const Handle(900), const Handle(901)),
          greaterThan(200));
    });

    test("stroke 922's centerline misses label 921 but its width reaches it",
        () async {
      expect(
          await strokeInkInsideLabel(doc, const Handle(922), const Handle(921)),
          greaterThan(50));
      // The same corpus rebuilt with 922 at hairline width: there is no
      // modify-lineweight command in this package, so the fixture takes the
      // lineweight as a parameter and the test builds it twice.
      final hairline =
          textOverlapFixture(FlutterTextMeasurer(), grazeLineweight: 1);
      expect(
          await strokeInkInsideLabel(
              hairline, const Handle(922), const Handle(921)),
          0,
          reason: 'at hairline width the same centerline touches no glyph');
    });
  });
```

`doc.entities.slotOf` and `lineweightAt` are `EntityStore`'s own accessors
(`packages/jet_cad_2d/lib/src/store/entity_store.dart`); `DocumentTree`'s
`operator []` is `tree.dart:12`. The two `strokeInkInsideLabel` tests are `async` — the
helper returns a `Future<int>` (Step 4) — so mark the first of them `async`
and `await` both calls as well.

`strokeInkInsideLabel` goes in `fixtures.dart` beside `strokeInkInsideFill`
(Plan D) and is built the same way: a `PictureRecorder`, a `CanvasDrawSink`
over a real `FlutterTextMeasurer`, `DraftPainter.paint` of a document holding
**only** the label (every other entity removed with `RemoveEntityCommand`),
`toImage`, read alpha; the same for the stroke alone; count pixels where
both alphas exceed 128. Because it is Skia on both, this is the
one helper in this plan that can read *text* ink.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: compile error — `textOverlapFixture` undefined.

- [ ] **Step 3: Write the fixture**

Append to `test/support/fixtures.dart`:

```dart
/// A label's height in this corpus, in definition units. ~16 logical px at
/// the fitted 800x600 camera; see `textOverlapFixture`.
const double kTextOverlapLabelHeight = 600.0;

/// A corpus for Plan E: three labels and what does or does not cover them.
/// See the plan's Task 3 table for every handle and the mutation it exists
/// for. Everything sits under instance 990 -- rotated, MIRRORED and
/// non-uniformly scaled, far from the origin.
DraftDocument textOverlapFixture(TextMeasurer measurer,
    {int grazeLineweight = 400}) {
  final doc = DraftDocument.empty(measurer: measurer);

  const content = Handle(890);
  doc.tree.addDefinition(Definition(
      handle: content,
      name: 'labelled-floor',
      basePoint: Vector2.zero(),
      children: const []));

  // The floor's extent, so the fit is decided by this and not by a label.
  addEntity(doc, content, const Handle(899), EntityKind.line,
      [0, 0, 30000, 20000], const [], lineweight: 1);

  // --- COVERED: under 900, over 903 and the translucent fill 904 ---------
  addEntity(doc, content, const Handle(900), EntityKind.line,
      [3000, 5300, 9000, 5300], const [], lineweight: 120);
  addText(doc, content, const Handle(901), 'COVERED', 3000, 5000,
      kTextOverlapLabelHeight);
  addEntity(doc, content, const Handle(903), EntityKind.line,
      [3000, 5250, 9000, 5250], const [], lineweight: 120);
  doc.commands.execute(AddRegionCommand(
    fill: const EntityRecord(
      handle: Handle(904),
      owner: content,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0xCC3311),
      lineweight: kLineweightDefault,
      transparency: 128,
      flags: 0,
    ),
    boundary: const EntityRecord(
      handle: Handle(905),
      owner: content,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[
        4300, 4800, // COVERED at height 600 spans x ~3000..5500; the fill
        7000, 4800, // covers its right half and runs past it
        7000, 5800, //
        4300, 5800, //
        4300, 4800, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
  ));

  // --- UNDER: a lower-handle stroke only -- no patch ---------------------
  addEntity(doc, content, const Handle(910), EntityKind.line,
      [3000, 9300, 9000, 9300], const [], lineweight: 120);
  addText(doc, content, const Handle(911), 'UNDER', 3000, 9000,
      kTextOverlapLabelHeight);

  // --- GRAZED: centerline above the box, width reaches into it -----------
  addText(doc, content, const Handle(921), 'GRAZED', 12000, 5000,
      kTextOverlapLabelHeight);
  // The box top is at 5000 + ascent; ascent for a 600 high label is about
  // 600 * (ascent / capHeight) -- the guard test measures the overlap
  // rather than deriving it, so this y only needs to be near the box's top.
  addEntity(doc, content, const Handle(922), EntityKind.line,
      [12000, 5700, 18000, 5700], const [], lineweight: grazeLineweight);

  // --- TINY: near the culling threshold ---------------------------------
  addText(doc, content, const Handle(931), 'TINY', 12000, 9000, 140);

  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(990),
    parent: doc.rootHandle,
    transform: Transform2.translation(400000, -250000)
        .multiply(Transform2.rotation(0.3))
        .multiply(Transform2.scale(-0.9, 1.1)),
    definition: content,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(7),
  )));

  return doc;
}
```

If `AddRegionCommand` refuses a fill whose boundary is added by the same
command in this shape, follow `fillFixture` (`fixtures.dart:722-800`) exactly —
it is the working example in this file.

**`kLineweightDefault`, `TrueColor`, `IndexedColor`, `ReservedHandles`** are
whatever `fillFixture` imports; copy its import block.

- [ ] **Step 4: `strokeInkInsideLabel`**

Model on `strokeInkInsideFill` in the same file. Signature:

```dart
/// Device pixels where [stroke]'s ink and [label]'s glyph ink both exceed
/// alpha 128, each painted ALONE through the reference (`CanvasDrawSink`
/// over a real `FlutterTextMeasurer`) at the fitted 800x600 camera, dpr 1.
/// The one helper in the GPU suite that can see text ink, because it reads
/// Skia's output rather than `TriangleRasterizer`'s.
Future<int> strokeInkInsideLabel(DraftDocument doc, Handle stroke, Handle label);
```

It must remove every entity except the one it paints (so the floor line 899
and the placement 990 stay — 990 is a node, not an entity — and 899 is a
hairline that adds one pixel-wide line; subtract nothing, it is thin enough
to sit under the 200-pixel floor). Use `Picture.toImage(800, 600)` and
`toByteData(format: ImageByteFormat.rawRgba)`; alpha is byte `i * 4 + 3`.
`toImage` is async, hence the `Future<int>`.

- [ ] **Step 5: Run, gate, commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
git add test/support/fixtures.dart test/support/fixtures_test.dart
git commit -m "test(gpu): a corpus of labels and what covers them"
```

**If the guard's overlap numbers come out under the floors,** move the
stroke's y or the label's x — the numbers in this task are the plan's
estimate, and Plan D's Task 4 recorded exactly this kind of correction
(`lineweightHundredths: 60` → `120`). Record the correction in the ledger.

---


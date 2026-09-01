### Task 4: The corpus grows two fills, and a guard that they are not degenerate

**Files:**
- Modify: `test/support/fixtures.dart`
- Modify: `test/support/fixtures_test.dart`
- Test: `test/support/fixtures_test.dart`

**Interfaces:**
- Produces: `DraftDocument fillFixture()`, a document whose handles are
  documented below and are relied on by Tasks 7 and 8.

**The corpus the spec asks for**, verbatim: *"an opaque fill overlapping
strokes of both lower and higher handle"*, and *"a translucent fill"*. Both
clauses are load-bearing:

- **Both sides of the handle order.** A fill that only overlaps strokes of
  *lower* handle draws over them in emission order; permuting the buffer
  changes nothing visible, because the fill was on top either way. Only a
  stroke of *higher* handle — drawn after the fill, so visible over it —
  makes the permutation change a pixel.
- **A hairline layer** for the opaque fill, so Ruling D3's mutation has a
  fixture.

**Handles, fixed here so later tasks name them rather than counting:**

| handle | what |
|---|---|
| 900 | a thick stroke **under** the fill (lower handle) |
| 901 | the fill entity, opaque, on a hairline layer |
| 902 | its boundary polygon |
| 903 | a thick stroke **over** the fill (higher handle), crossing it |
| 904 | the translucent fill entity |
| 905 | its boundary circle |

- [ ] **Step 1: Write the failing guard tests**

Append to `test/support/fixtures_test.dart`:

```dart
  group('fillFixture', () {
    test('is not degenerate in any of the four ways that would hide a defect',
        () {
      final doc = fillFixture();

      // 1. A fill exists and is indexed, so the painter can reach it.
      final fillSlot = doc.entities.slotOf(const Handle(901))!;
      expect(doc.entities.kindAt(fillSlot), EntityKind.fill);
      expect(doc.fills.trianglesFor(const Handle(902)), isNotNull,
          reason: 'an unfillable boundary is skipped by the painter and the '
              'corpus would silently draw no fill at all');

      // 2. Strokes on BOTH sides of the fill in handle order. Without the
      //    higher one, permuting the buffer changes no pixel and the
      //    criterion-4 test in Task 7 passes vacuously.
      expect(const Handle(900).value, lessThan(const Handle(901).value));
      expect(const Handle(903).value, greaterThan(const Handle(901).value));

      // 3. The translucent fill is actually translucent -- neither opaque
      //    nor invisible.
      final translucentSlot = doc.entities.slotOf(const Handle(904))!;
      final translucent = doc.entities.transparencyAt(translucentSlot);
      expect(translucent, greaterThan(0));
      expect(translucent, lessThan(255));

      // 4. No identity transform: the fill sits under a rotated, non-uniform
      //    instance well away from the origin. An axis-aligned fill at the
      //    origin hides a transposed matrix element -- Plan 2's post-mortem.
      final node = doc.tree.nodeOf(const Handle(910))! as InstanceNode;
      expect(node.transform.a, isNot(closeTo(node.transform.d, 1e-9)));
      expect(node.transform.b, isNot(0.0));
      expect(node.transform.e.abs(), greaterThan(1.0));
    });

    test('the fill and the higher-handle stroke actually overlap on screen',
        () {
      // A corpus whose "overlapping" shapes miss each other proves nothing.
      // Painted through the reference sink, the stroke's ink must land
      // inside the fill's bounding box.
      final doc = fillFixture();
      final fillBox = doc.extents;
      expect(fillBox.min.x, lessThan(fillBox.max.x));
      final overlap = strokeInkInsideFill(doc);
      expect(overlap, greaterThan(200),
          reason: 'fewer than 200 shared device pixels and the order gate '
              'cannot see a permutation');
    });
  });
```

`strokeInkInsideFill` is a helper this task adds to `fixtures.dart` — it
paints the corpus through `VerticesDrawSink` twice, once with handle 903
present and once with it removed, and returns the number of pixels that
differ inside the fill's screen box.

**Check `EntityIndex`'s accessor names against the source before writing the
guard.** The sample above reads `transparencyAt(slot)`; if this document
model spells it differently, use the real name — the assertion is that the
value is strictly between 0 and 255, not that any particular getter exists.

- [ ] **Step 2: Run and watch them fail**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: compile failure — `fillFixture` is undefined.

- [ ] **Step 3: Build the fixture**

In `test/support/fixtures.dart`:

```dart
/// A corpus for Plan D: two fills, and strokes on both sides of one of them
/// in handle order.
///
/// **Every element is here because a named mutation needs it:**
///  - handle 900 is a thick stroke the fill covers, so a fill that failed to
///    draw leaves it visible;
///  - handle 901 is an opaque fill on a **hairline layer**, so a fill routed
///    through `_coveredArgb` fades (M-D5) where a correct one does not;
///  - handle 903 is a thick stroke of HIGHER handle crossing the fill, so it
///    is drawn *after* the fill and stays visible over it. Permuting the
///    buffer to draw all fills last hides it -- which is spec criterion 4,
///    and the reason this corpus exists at all;
///  - handle 904 is a translucent fill over a circle boundary, so the fan
///    path (`fillCircle`) is exercised and the colour comparison has a
///    non-opaque value to disagree about;
///  - the whole thing sits under instance 910, rotated and non-uniformly
///    scaled, far from the origin: an identity transform commutes and hides
///    composition-order defects (Plan 2's post-mortem).
DraftDocument fillFixture() {
  final doc = DraftDocument.empty();

  const content = Handle(890);
  doc.tree.addDefinition(Definition(
      handle: content,
      name: 'filled-room',
      basePoint: Vector2.zero(),
      children: const []));

  // 900: under the fill.
  addEntity(doc, content, const Handle(900), EntityKind.line,
      [1, 1, 19, 13], const [], lineweight: 60);

  // 901 / 902: the opaque fill and its boundary, on a hairline layer.
  final hairline = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
    handle: hairline,
    name: 'hairline',
    color: const TrueColor(0x333333),
    linetype: ReservedHandles.continuousLinetype,
    lineweight: 1,
  )));
  doc.commands.execute(AddRegionCommand(
    fill: EntityRecord(
      handle: const Handle(901),
      owner: content,
      kind: EntityKind.fill,
      layer: hairline,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x2E7D32),
      lineweight: 1,
      transparency: 0,
      flags: 0,
    ),
    boundary: EntityRecord(
      handle: const Handle(902),
      owner: content,
      kind: EntityKind.polyline,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[
        2, 2, //
        17, 3, //
        16, 12, //
        3, 11, //
        2, 2, // closing duplicate
      ]),
      scalars: Float64List(0),
    ),
  ));

  // 903: over the fill, and crossing it.
  addEntity(doc, content, const Handle(903), EntityKind.line,
      [3, 12, 17, 2], const [], lineweight: 60);

  // 904 / 905: the translucent fill, over a circle boundary.
  doc.commands.execute(AddRegionCommand(
    fill: EntityRecord(
      handle: const Handle(904),
      owner: content,
      kind: EntityKind.fill,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0xC62828),
      lineweight: kLineweightDefault,
      transparency: 128,
      flags: 0,
    ),
    boundary: EntityRecord(
      handle: const Handle(905),
      owner: content,
      kind: EntityKind.circle,
      layer: ReservedHandles.layerZero,
      linetype: ReservedHandles.continuousLinetype,
      linetypeScale: 1.0,
      geomIndex: 0,
      color: const TrueColor(0x000000),
      lineweight: kLineweightDefault,
      transparency: 0,
      flags: 0,
    ),
    boundaryPayload: GeometryPayload(
      coords: Float64List.fromList(<double>[24, 7]),
      scalars: Float64List.fromList(<double>[5.5]),
    ),
  ));

  // The placement: rotated, non-uniformly scaled, far from the origin.
  doc.commands.execute(AddNodeCommand(InstanceNode(
    handle: const Handle(910),
    parent: doc.rootHandle,
    transform: Transform2.translation(37.5, 22.25)
        .multiply(Transform2.rotation(0.44))
        .multiply(Transform2.scale(1.8, 1.15)),
    definition: content,
    layer: ReservedHandles.layerZero,
    color: const IndexedColor(7),
  )));

  return doc;
}
```

**A polygon boundary needs a triangulation**, and `AddRegionCommand`
materialises one — assert it in Step 1's guard rather than assuming it. If
`doc.fills.trianglesFor(const Handle(902))` comes back null, put one in by
hand with `doc.fills.putTriangles`, as `fill_render_test.dart:132` does, and
say so in the fixture's doc.

- [ ] **Step 4: Run**

```sh
cd packages/jet_cad_2d_flutter && flutter test test/support/fixtures_test.dart
```
Expected: PASS.

- [ ] **Step 5: Both gates and commit**

```sh
cd packages/jet_cad_2d_flutter && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .
cd ../jet_cad_2d && dart test && dart analyze && dart format --output=none --set-exit-if-changed .
git status --short
git add packages/jet_cad_2d_flutter/test/support/fixtures.dart packages/jet_cad_2d_flutter/test/support/fixtures_test.dart
git commit -m "test(gpu): a fill corpus with strokes on both sides of the fill"
```

---


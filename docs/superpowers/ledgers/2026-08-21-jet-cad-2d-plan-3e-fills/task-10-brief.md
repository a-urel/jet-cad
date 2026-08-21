## Task 10: The index stays silent about fills

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/index/spatial_index.dart`
- Modify: `packages/jet_cad_2d/test/invariants/reference_query.dart`
- Modify: `packages/jet_cad_2d/test/index/pick_test.dart`, `snap_test.dart`

**Interfaces:**
- Produces: no new API. A fill contributes **no pick candidate and no snap candidate**, in both the real index and the oracle.

**This task deletes a requirement rather than adding a picker**, and that is the finding to carry: the spec's earlier claim that "a fill answers `HitKind.fill` on its own handle" was withdrawn under review because two independent facts make it unimplementable *and* undesirable.

1. `_considerLeaf` returns before any kind dispatch when `pointCount == 0`. A fill has no coordinates.
2. Even if it did not, it would always lose. Pick priority is kind, then ancestor, then **greater handle wins** — and a fill's handle is strictly lower than its boundary's by construction, while a closed polyline already answers `HitKind.fill` on its own interior.

So clicking inside a filled room selects the **boundary**, with `HitKind.fill`, exactly as it does today for an unfilled closed polyline. The region tool maps either half of the pair to the pair. That is the architecture spec's "the user never sees two entities" working as designed.

Two existing behaviours are **verified and left alone**, with the reasoning written down so a later reader does not "fix" them: `snapCentreOfLeaf` returns null for a fill and `NarrowPhaseSlack.ofLeaf` returns `none`, both through `if (kind != circle && kind != arc)` guards rather than a switch with a default. Both answers are right — a fill contributes no snap candidate because its boundary already contributes every vertex, and its box contains a narrow phase it does not have.

- [ ] **Step 1: Write the failing tests**

```dart
test('clicking inside a filled room selects the boundary, not the fill', () {
  final doc = DraftDocument.empty();
  final cmd = region(doc);           // square at 0,0..10,10
  doc.commands.execute(cmd);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final hit = HitPath();
  expect(index.pickInto(Vector2(5, 5), 0.5, hit), isTrue);
  expect(hit.entity, cmd.boundary.handle,
      reason: 'the fill carries the lower handle by construction and would '
          'lose the tie-break anyway; the region tool maps the boundary to '
          'the pair');
  expect(hit.kind, HitKind.fill);
});

test('a fill never wins a snap, so boundary vertices are not doubled', () {
  final doc = DraftDocument.empty();
  final withFill = region(doc);
  doc.commands.execute(withFill);
  final index = SpatialIndex(doc);
  addTearDown(index.dispose);
  final out = SnapResult();
  expect(index.snapInto(Vector2(0, 0), 1.0, const SnapMask.all(), out), isTrue);
  expect(out.entity, isNot(withFill.fill.handle),
      reason: 'the boundary already contributes every vertex; a second '
          'candidate on the same point would corrupt the snap tie-break');
});

test('the reference oracle agrees about a document containing fills', () {
  // `test/invariants/differential_test.dart` compares `pickInto` against
  // `referencePick` and `snapInto` against `referenceSnap`, both from
  // `reference_query.dart`. This adds a region to that file's corpus rather
  // than writing a second differential: the oracle must fail for a real
  // disagreement, never for a missing case in its own switch.
  //
  // In `test/invariants/corpus.dart`, add one region to the generated
  // document behind the same shape of flag the corpus already uses for text,
  // and run:
  //   dart test test/invariants/differential_test.dart
});
```

- [ ] **Step 2: Run and watch them fail**

Expected: the oracle test fails first — its `fill` case from Task 1 is a bare
`break` with no comment tying it to this decision.

- [ ] **Step 3: Implement**

Replace Task 1's placeholder comments with the final reasoning at each of the
four sites, and add the two comment blocks to `container_index.dart` above
`snapCentreOfLeaf` and `NarrowPhaseSlack.ofLeaf`:

```dart
// A fill reaches neither of these. Its `pointCount` is zero, so
// `_considerLeaf` and `_considerSnapLeaf` return before any kind dispatch,
// and that is the intended behaviour rather than an oversight: a fill is
// drawn, not picked. Its boundary already answers `HitKind.fill` on the same
// interior and already contributes every snap vertex. If a later change gives
// a fill coordinates of its own, these two guards start answering for it --
// and `none`/`null` remain the right answers for the same reasons.
```

- [ ] **Step 4: Run and watch them pass**

- [ ] **Step 5: Run the named mutations**

```sh
# T10a: give the oracle a fill hit that the index does not produce
#       -> the differential must go red
# T10b: make snapCentreOfLeaf answer for a fill
#       -> the doubled-vertex test must go red
```

- [ ] **Step 6: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "feat: a fill is drawn, not picked, in the index and the oracle"
```

---


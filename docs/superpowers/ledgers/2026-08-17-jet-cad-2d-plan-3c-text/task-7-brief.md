## Task 7: The corpus grows two text sources

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/testing/generate_document.dart`
- Test: `packages/jet_cad_2d/test/testing/generate_document_test.dart`

**Interfaces:**
- Consumes: Tasks 0-5.
- Produces: `generateDocument(..., double labelFraction = 0, double attributedInstanceFraction = 0)`.

- [ ] **Step 1: Write the failing tests**

```dart
test('both text fractions default to zero and change nothing', () {
  // The two fingerprints from Task 1's re-baseline still hold.
  expect(fingerprint(generateDocument(2000, definitionCount: 20)),
      <the Task 1 value>);
});

test('labelFraction produces repeating strings out of the root budget', () {
  final doc = generateDocument(2000, definitionCount: 20, labelFraction: 0.05);
  final labels = <String>{};
  var count = 0;
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.text) {
      count++;
      labels.add(doc.entities.textAt(slot));
    }
  }
  expect(count, greaterThan(50));
  // Repeating, not unique: this is the distribution the cache hits.
  expect(labels.length, lessThanOrEqualTo(20));
});

test('attributedInstanceFraction gives each chosen instance a unique attrib',
    () {
  final doc = generateDocument(2000,
      definitionCount: 20, instanceCount: 100, attributedInstanceFraction: 0.5);
  final values = <String>[];
  for (final slot in doc.entities.liveSlots) {
    if (doc.entities.kindAt(slot) == EntityKind.attrib) {
      values.add(doc.entities.textAt(slot));
      // Owned by the instance node, in instance-local coordinates.
      expect(doc.tree[doc.entities.ownerAt(slot)], isA<InstanceNode>());
    }
  }
  expect(values.length, 50);
  expect(values.toSet().length, values.length);
});
```

- [ ] **Step 2: Run and watch them fail**

Run: `cd packages/jet_cad_2d && dart test test/testing/generate_document_test.dart`
Expected: FAIL — no such named parameters.

- [ ] **Step 3: Implement both, drawing from the existing shared stream**

Both extensions draw from `extra` (`generate_document.dart:96`,
`math.Random(0x5EEDED)`) and **draw nothing while they are off**. There is one
such stream, not one per extension, so turning `labelFraction` on shifts every
`attributedInstanceFraction` draw: the two fractions are **not** independently
reproducible, and a fixture names both together or neither. Record that in the
doc comment.

Labels come **out of** the root entity budget (so the total leaf count does not
move); attributes are **additive** leaves owned by their instance node, with
coordinates in instance-local space — DXF stores them already placed, and
`container_index.dart:208-210` transforms them by the instance's composed
transform, so writing world coordinates here would double-apply it.

```dart
const List<String> _kLabelVocabulary = <String>[
  'WC', 'KITCHEN', 'BAR', 'STORE', 'OFFICE', 'ENTRY', 'HALL', 'STAIR',
  'LIFT', 'TERRACE', 'PANTRY', 'CLOAK', 'PLANT', 'RISER', 'LOBBY',
  'CORRIDOR', 'SERVICE', 'DECK', 'GARDEN', 'ROOF',
];
```

- [ ] **Step 4: Run the suite**

Run: `cd packages/jet_cad_2d && dart test`
Expected: PASS, including both fingerprints at defaults and the structural
assertions beside them — one layer, **three linetypes**, every entity `ByLayer`
on layer zero.

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d
git commit -m "test(jet_cad_2d): add off-by-default label and attribute corpus extensions"
```

---


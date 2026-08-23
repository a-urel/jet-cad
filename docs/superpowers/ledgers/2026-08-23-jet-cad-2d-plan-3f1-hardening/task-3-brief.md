## Task 3: `linetypeScale` composes multiplicatively

**Files:**
- Modify: `packages/jet_cad_2d/lib/src/document/style_resolver.dart` — the `linetypeScale:` line in `contextFor`, and the `linetypeScale:` line in `styleFor` (currently `:102`)
- Modify: `packages/jet_cad_2d/test/document/instance_style_test.dart` — add one group

**Interfaces:**
- Consumes: `InstanceNode.linetypeScale` from Task 1; `resolveThrough` from Task 2.
- Produces: `ResolvedStyle.linetypeScale` is now the product of the entity's own scale and every enclosing INSERT's. `DraftPainter` already multiplies that by `document.header.globalLinetypeScale` at `draft_painter.dart:615,769,803`, so the full DXF chain closes.

**Why this is a separate task from Task 2.** The other three fields answer
"which value wins" and substitute. This one answers "by how much" and
multiplies — a different rule, taken from DXF, and the only one of the four
that also changes `styleFor`. A reviewer can reject the multiplication without
rejecting the substitutions.

**The chosen numbers, and why these.** Entity `2.0` × inner INSERT `4.0` ×
outer INSERT `8.0` = **`64.0`**. Every factor is exact in binary, so the
assertion is `==` and not a tolerance. And `64.0` differs from every factor
(2, 4, 8), every pairwise product (8, 16, 32), the sum (14) and the maximum
(8) — so a mutant that drops one multiplication, replaces it with addition, or
takes a maximum lands on a different number in every case.

- [ ] **Step 1: Write the failing test**

Append to `packages/jet_cad_2d/test/document/instance_style_test.dart`, inside
`main()`:

```dart
  group('linetypeScale multiplies down the tree', () {
    test('entity 2.0 x inner 4.0 x outer 8.0 resolves to exactly 64.0', () {
      final doc = DraftDocument.empty();
      final inner = addDefinition(doc, const Handle(200), 'BOLT');
      final outer = addDefinition(doc, const Handle(210), 'PLATE');
      final child = addByBlockLine(doc, inner, const Handle(201),
          linetypeScale: 2.0);
      addInstance(doc, const Handle(300), outer, linetypeScale: 8.0);
      addInstance(doc, const Handle(310), inner,
          parent: const Handle(210), linetypeScale: 4.0);

      // Exact. Every factor is a power of two, so the product is
      // representable and `Tolerance` would only hide a wrong answer.
      expect(
          resolveThrough(doc, [const Handle(300), const Handle(310)], child)
              .linetypeScale,
          64.0);
    });

    test('an INSERT at 1.0 leaves its child alone', () {
      // The default's no-op property, asserted rather than assumed: this is
      // what makes every pre-3f.1 document resolve unchanged. The entity's own
      // scale is still 2.0, never 1.0 -- the identity on both sides would
      // prove nothing.
      final doc = DraftDocument.empty();
      final def = addDefinition(doc, const Handle(200), 'BOLT');
      final child =
          addByBlockLine(doc, def, const Handle(201), linetypeScale: 2.0);
      addInstance(doc, const Handle(300), def);

      expect(resolveThrough(doc, [const Handle(300)], child).linetypeScale,
          2.0);
    });
  });
```

- [ ] **Step 2: Run it and watch it fail**

```sh
cd packages/jet_cad_2d && CI=true dart test test/document/instance_style_test.dart --plain-name "linetypeScale multiplies"
```

Expected: the first test FAILS reading `2.0` instead of `64.0` — `styleFor`
returns the entity's own scale and ignores the context entirely. The second
test passes already, and that is the point: it cannot distinguish a connected
channel from a severed one, which is exactly how fifty-four fixtures at `1.0`
missed this defect. It is kept as the no-op guard, not as the proof.

- [ ] **Step 3: Connect both ends**

In `contextFor`, change the pass-through to a product:

```dart
      // Multiplies, never substitutes. DXF's rule for a nested entity's
      // effective linetype scale is a product, so nesting composes without a
      // special case for depth: entity x every enclosing INSERT x the header's
      // global scale, which `DraftPainter` applies at the far end.
      linetypeScale: inherited.linetypeScale * node.linetypeScale,
```

In `styleFor`, change the line that ignores the context:

```dart
      // Before Plan 3f.1 this read `document.entities.linetypeScaleAt(slot)`
      // alone. `StyleContext.linetypeScale` was constructed, copied, compared
      // and hashed, and no code path read it to produce a drawing — and no
      // test could tell, because every linetypeScale literal in the repository
      // was 1.0, the multiplicative identity.
      linetypeScale:
          ctx.linetypeScale * document.entities.linetypeScaleAt(slot),
```

- [ ] **Step 4: Run the test and the full engine suite**

```sh
cd packages/jet_cad_2d && CI=true dart test && dart analyze && dart format --output=none --set-exit-if-changed .
```

Expected: ten tests in `instance_style_test.dart` PASS, whole suite green. No
pre-existing test moves — `documentRoot.linetypeScale` is `1.0` and every
existing instance now defaults to `1.0`, so every existing product is the
identity.

- [ ] **Step 5: Fire mutants M4 and M5**

| mutant | edit | must redden |
|---|---|---|
| M4 | `styleFor` → `linetypeScale: document.entities.linetypeScaleAt(slot)` | `entity 2.0 x inner 4.0 x outer 8.0` (reads 2.0) |
| M5 | `contextFor` → `linetypeScale: node.linetypeScale` | same test (reads 8.0) |

Both must also leave `an INSERT at 1.0 leaves its child alone` green — that
test is the no-op guard and is expected to survive, which is why it is not
listed as any mutant's killer.

- [ ] **Step 6: Run the Flutter suite too**

```sh
cd packages/jet_cad_2d_flutter && CI=true flutter test
```

This is the first task whose change can move a *drawing*: dash spacing reads
`ResolvedStyle.linetypeScale`. Expected: green, including all 35 goldens, with
no PNG regenerated. **If a golden moves, stop** — the defaults are supposed to
make this a no-op, and a moved golden means a fixture somewhere carries a
non-identity instance scale that was previously being ignored.

- [ ] **Step 7: Commit**

```bash
git add packages/jet_cad_2d/lib/src/document/style_resolver.dart \
        packages/jet_cad_2d/test/document/instance_style_test.dart
git commit -m "fix: StyleContext.linetypeScale reaches the drawing

The field was constructed, copied by copyWith, compared by ==, hashed, and
threaded through contextFor -- and styleFor built its ResolvedStyle from
the entity's own scale alone, so no code path read the context's to produce
a drawing. Dash spacing consumes it at three sites in DraftPainter.

No test could see it. Every linetypeScale literal in the repository is 1.0
except one storage round-trip, and 1.0 is the multiplicative identity: a
severed channel and a connected one produce the same output when every
value flowing through is the identity.

Composes multiplicatively, per DXF: entity x every enclosing INSERT x the
header's global scale. Substitution would have been the wrong rule and
would have made nesting need a special case for depth."
```

---


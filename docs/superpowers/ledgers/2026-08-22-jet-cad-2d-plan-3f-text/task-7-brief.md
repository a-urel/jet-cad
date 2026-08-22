## Task 7: the LOD golden ladder

**Files:**
- Create: `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_golden_test.dart`
- Create: `packages/jet_cad_2d_flutter/test/golden/text_lod_ladder_{1,2,3}.png` and `vertices/text_lod_ladder_{1,2,3}.png`

**Interfaces:**
- Consumes: `kMinTextCapPixels`, `DraftCanvas.minTextCapPixels`.
- Produces: six PNGs.

**Ahem is sufficient here and the reason is stronger than "presence and absence".** `capHeight` is `kCapHeightRatio * kNominalTextPixels`, a constant, and the LOD test reads no metrics at all — so the cull decision is font-independent. This ladder is font-proof and needs no `FontLoader`. Say so in the file's header comment; a future reader will otherwise assume it was an oversight.

- [ ] **Step 1: Write the ladder**

Create the file following `dash_ladder_golden_test.dart`'s structure exactly — the same `kGoldenViewport`, the same `_framed` helper shape, the same two-backend loop, the same `matchesGoldenFile('vertices/...')` spelling for the second backend.

```dart
// Three rungs, one axis: the level-of-detail threshold. One drawing carrying
// three text heights, framed so the smallest is culled, the largest is not, and
// the middle sits near the boundary — so the ladder pins `kMinTextCapPixels`
// visually and goes red if the constant moves.
//
// **Ahem is enough, and that is not an oversight.** The other text ladder needs
// `fonts/Roboto-Regular.ttf` because it asserts things about glyph *shape*. The
// cull decision reads no metrics at all — `layout.height * chain.scaleMagnitude`
// against a constant — so nothing here depends on which font is loaded.

const Size kGoldenViewport = Size(400, 300);
```

Rung 1 renders at the default threshold. Rung 2 renders the same document at `minTextCapPixels: 0.0` — the control arm, showing every string. Rung 3 renders it at a threshold above every string's cap height, showing none.

- [ ] **Step 2: Generate the PNGs**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden --update-goldens test/golden/text_lod_ladder_golden_test.dart
```

- [ ] **Step 3: Look at all six**

Open each PNG and confirm by eye: rung 1 shows the large and middle strings and not the small one; rung 2 shows all three; rung 3 shows none. **A golden accepted without being looked at pins whatever the code did, including a bug.**

- [ ] **Step 4: Verify no other PNG moved**

Run:

```bash
cd packages/jet_cad_2d_flutter && CI=true flutter test --tags golden && git status --porcelain packages/jet_cad_2d_flutter/test/golden
```

Expected: 29 + 6 = 35 golden tests pass, and `git status` lists exactly the six new PNGs as untracked — **no existing PNG modified.**

- [ ] **Step 5: Commit**

```bash
git add packages/jet_cad_2d_flutter/test/golden
git commit -m "test: a golden ladder for the text level-of-detail threshold"
```

---


### Task 8: Mutation testing

**Files:**
- Create: `docs/superpowers/notes/plan-e-mutation-log.md`

For each mutation: `cp` the file to a backup, apply the edit, run the named
test, **paste the failing output verbatim**, restore from the backup, run
the test again green. A survivor is declared with a reason, never with a
threshold moved.

| id | mutation | must go red in |
|---|---|---|
| M-E1 | `classifyTextPatches` returns `[]` (spec: *draw all text in one pass*) | `text_order_test` "drawing all text in one pass" is the seam; the source mutation must ALSO fail the four-scale rows |
| M-E2 | the inner loop starts at `0` instead of `t.instanceIndex` (spec: *admit an instance emitted before the label*) | `text_patches_test` "an instance emitted BEFORE"; `text_order_test` at scale 1 (stroke 900 over COVERED) |
| M-E3 | `reachDevice = 0` for every kind (spec: *test the centerline*) | `text_patches_test` "centerline misses"; `text_order_test` (GRAZED) |
| M-E4 | `unitsPerDevicePixel = 1.0 / devicePixelRatio` (spec: *expand at the reference scale*) | `text_patches_test` "expanded at the band floor"; `text_order_test` at scale 0.5 |
| M-E5 | `_patchPaint.blendMode = BlendMode.srcOver` (spec: *`srcOver` instead of `srcATop`*) | `text_compositor_test` "translucent later fill"; `text_order_test` (fill 904) |
| M-E6 | `hits.add(i)` unconditionally (spec: *classify every label as a patch*) | `text_order_test` "the label nothing later reaches" (`patchCount 2` → 4) |
| M-E7 | join reach `half` instead of `half * kMiterLimit` (spec: *per-instance miter length*) | `text_patches_test` "a join's reach" |
| M-E8 | `points = 3` for a point (Ruling E4) | `text_patches_test` "a point's box" |
| M-E9 | `saveLayer` opened after `canvas.transform(_matrix)` (Copilot finding 4) — move the `saveLayer` call into `_drawLabel` after the transform | `text_compositor_test` "outer transform once" and the srcATop test (layer misplaced → patch clipped) |
| M-E10 | drop the baseline flip (`translate`/`scale(1,-1)`) in `_drawLabel` | `text_order_test` every row (the reference flips) |
| M-E11 | the box pad at the band ceiling: `kBandUpperScale` in place of `kBandLowerScale` in `text()` (Ruling E9) | `resident_text_test` "the pad is one device pixel at the band floor" |
| M-E12 | the compositor matches patches by position (`patches[i]`) instead of by `textIndex` | `text_compositor_test` "one cursor" |
| M-E13 | `patchRegionFor` clamps with `x0 = minX.floor()` unclamped (negative origin) | `text_patches_test` "partly off the top-left" |
| M-E14 | `sub.setRange` copies `hits[k]` in reverse (`hits.reversed`) | `text_patches_test` "keeps main-buffer order" |

Fourteen. **If M-E1 as a source edit and as the seam disagree** — the seam
goes red and the source edit does not — the seam is not measuring the
classifier and Task 5 has a defect; stop and ledger it.

- [ ] **Step 1: Run all fourteen, in a new file; commit the log**

```sh
git add docs/superpowers/notes/plan-e-mutation-log.md
git commit -m "docs: Plan E's mutation log"
```

---


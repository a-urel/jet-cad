## Task 13: The results note, the mutation log, and `STATUS.md`

**Files:**
- Create: `docs/superpowers/notes/2026-08-2X-plan-3g-results.md`, `docs/superpowers/notes/plan-3g-mutation-log.md`
- Modify: `STATUS.md`

- [ ] **Step 1: Write the mutation log**

One section per mutant, seventeen of them, each with the exact edit, the command run, and the **verbatim** transcript of the red run and of the restored green run. M3 gets a section too, recording that it **could not be fired** and why — G1's instrument concession — rather than being quietly dropped.

- [ ] **Step 2: Write the results note**

Thirteen criteria, each PASS / MISS / unevaluable with the number beside it. The sweep's three columns. The chosen `kTileDevicePixels` and `kTilesBakedPerFrame` with the measurement that chose them. The Low Power Mode reading. Every accepted gap restated with what is still owed:

- **G1** — the seam is proven complete geometrically and **not** proven free of antialiasing artefacts on device. Say it in those words. A green criterion 2 is not a settled seam.
- **G2** — no table record may gain a setter.
- **G3** — zoom stays where it is; that is Plan 3h.
- **G4** — the web whole-drawing abort's back-to-back re-run, still owed.

And the second-order measurement this plan owes 3h: `debugCapacityVertices` with tiles on against tiles off at 500,000 entities. Baking per tile flushes and rewinds between tiles, so the 96.00 MiB high-water mark `STATUS.md:1066` records should fall to a single tile's geometry. **If it does, the tile budget replaces that memory rather than adding to it**, and 3h's budget starts from the new number.

- [ ] **Step 3: Update `STATUS.md`**

Replace the Plan 3g block with what shipped: the exit gate, the chosen constants, what is owed, and Plan 3h's inheritance. Link both notes and the plan. Keep the spike note's link — it is the measurement of record for why this plan exists at all.

- [ ] **Step 4: Commit**

```sh
git add docs STATUS.md
git commit -m "docs: Plan 3g results, mutation log, and STATUS"
```

---

## Self-review of this plan

**Spec coverage.** D1 → Task 1. D2, D5 → Task 3. D3, D13 → Task 9. D4 is a rejection and needs no task. D6 → Task 11. D7 → Tasks 4–6 (the injectable tile size, used at 64 throughout). D8 → Task 4, gated in Task 5. D9 → Tasks 3 and 8. D10, D11 → Task 7. D12 → Tasks 2 and 8. D14 → Task 8. Criteria 1–4 → Tasks 5, 6. Criteria 5, 6, 9 → Task 7. Criterion 7 → Task 8. Criterion 8 → Task 9. Criteria 12, 13 → Task 10. Criteria 10, 11 → Task 12. G1–G4 → Task 13. **No spec section is unclaimed.**

**Mutant coverage.** M1, M2, M5, M12, M16 → Task 7. M3 → deferred, recorded in Task 13. M4, M9 → Task 9. M6 → Task 10. M7 → Task 12. M8 → Tasks 2 and 8. M10 → Task 3. M11, M14 → Task 6. M13 → Tasks 4 and 10. M15, M17 → Task 5. **Sixteen fired, one recorded as unfirable.**

**Anti-degenerate coverage.** Clause 1 → the 64 px tile everywhere and `crossingGrid`'s 90-logical-pixel lines. Clause 2 → `tileCamera()`, never `fit`. Clause 3 → asserted at `blitCount > 30`. Clauses 4 and 5 → `instancedFixture` and the dragged-instance test. Clauses 6 and 7 → Task 10's two eviction tests.

**Type consistency.** `TileCache.paintFrame` takes `CanvasDrawSink sink` (not `DrawSink`) throughout, and `tablesRevision` is added to its signature in Task 8 — Task 4's call sites in `tile_fixture.dart` must be updated there. `DraftPainter.debugRebaseOrigin` and `debugOnVisit` are mutable fields, not `final`, because `TileCache` sets them per bake.

**Known incompleteness, stated rather than hidden.** Tasks 9 and 10 give implementation *shape* and the exact tests, not line-by-line code for the composite and the LRU. Both are ordinary data-structure work whose contract is fully pinned by the tests above them, and writing speculative code for `Picture`/`Image` composition that the implementer will correct against the API is worth less than the tests that judge it. Every other task carries its code in full.

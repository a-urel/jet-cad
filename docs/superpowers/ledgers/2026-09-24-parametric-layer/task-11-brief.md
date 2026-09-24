### Task 11: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-24-plan-06-results.md`
- Modify: the spec, `roadmap/06-parametric-layer.md`,
  `roadmap/00-README.md`, `STATUS.md`

- [ ] **Step 1: Paste the four gate lines**, with exit codes and counts.
  The expected counts:
  - engine: 911 + 4 (X) + 10 (P) + 14 (N) + 9 (G) = **948**;
  - render layer: 923 + 2 (CN) = **925**, plus 1 skip and the five goldens;
  - harness: **82**;
  - app: 46 + 6 (BT) + 6 (BX) + 7 (SP) + 1 (SP5) = **66**;
  - both builds `✓ Built`.

  **Report what ran**, and explain any difference.
- [ ] **Step 2: The results note.** Include:
  - one row per exit criterion 1–14, each with its witness;
  - the mutation tally;
  - Rulings 06-1…06-13, and any added during execution;
  - the Review Focus items and their tests;
  - the debt, from spec D12 and the open questions:
    - the draw order of added children;
    - the O(n²) neighbour search;
    - the per-axis AABB reach;
  - **criterion 14 marked OWED.** The human looks after this branch is
    presented: on macOS, in Chrome and in Firefox from `build/web`. Each
    platform's list:
    1. B draws a box.
    2. A second box overlapping the first: one merged outline.
    3. Select a box. Width and Height appear; set the width, press Enter,
       and the outline follows. cmd+Z undoes it in one step.
    4. Move and rotate a box over another. The outlines re-merge, and one
       undo restores.
    5. Delete a box. The other regrows, and cmd+Z brings it back.
    6. Typing B or V in the fields does not switch tools.
- [ ] **Step 3: Spec amendments.** Add "Amended at execution (Plan 06)"
  paragraphs:
  - D3 and D10: Ruling 06-1, the catalog;
  - D4 step 4: Ruling 06-3, and 06-4;
  - the mutant table: Rulings 06-5, 06-6, 06-7, 06-8 and 06-10;
  - D1: Ruling 06-13 (`isRegistered`);
  - D13: Ruling 06-14, if it was made.
- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 05's shape:
  - the header;
  - a Plan 06 section;
  - the Resume paragraph;
  - `roadmap/06-parametric-layer.md`'s status line;
  - `roadmap/00-README.md`'s row.
- [ ] **Step 5: Commit, then archive the ledger** as the branch's last
  commit.

```bash
git add docs/superpowers/notes/2026-09-24-plan-06-results.md docs/superpowers/specs/2026-09-24-parametric-layer-design.md roadmap/06-parametric-layer.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 06 results, spec amendments, STATUS and roadmap

Exit gate 13 of 14; criterion 14 (the human's look) is OWED.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
mkdir -p docs/superpowers/ledgers/2026-09-24-parametric-layer
cp -R .superpowers/sdd/2026-09-24-parametric-layer/. docs/superpowers/ledgers/2026-09-24-parametric-layer/
git add docs/superpowers/ledgers/2026-09-24-parametric-layer
git commit -m "$(cat <<'EOF'
docs: archive the Plan 06 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Hand over to `superpowers:finishing-a-development-branch`. **The merge is
the human's decision.**

---

## Exit gate

| # | criterion | witness |
|---|---|---|
| 1 | the four gate lines, the five goldens only, both builds | Task 11 Step 1 |
| 2 | a parameter change regenerates, a neighbour's too | P2, N2, SP3 |
| 3 | one undo step; undo and redo restore both, same handles | P3, BX2 |
| 4 | load → save byte-identical, typed | N8 |
| 5 | same state plus same edit gives the same bytes | N5, N6 |
| 6 | a mutual dependency terminates, with no iteration | N1, N2, M-06e N/A |
| 7 | no `QueryReentrancyError` from regeneration | P4, N12 |
| 8 | the allocation invariants unchanged | Task 10 |
| 9 | draw order: unchanged objects keep their child handles | P2, P3 |
| 10 | a direct edit of a generated child is refused | G1, G2 |
| 11 | delete detaches the component; undo restores it | G3, BX5 |
| 12 | runtime inheritance, undo and redo included | G4, G5, SP5 |
| 13 | every mutant killed, or recorded as N/A or covered | the mutation log |
| 14 | the human's look | OWED (Task 11) |

## Self-review

**Spec coverage.**

| spec item | covered by |
|---|---|
| D1 | Task 2; the Task 10 grep; P10 (Ruling 06-13) |
| D2 | Task 1, `_expand` (Task 2); X1–X4, P6, P8, G8 |
| D3 | Task 2; P7; the catalog (Ruling 06-1) |
| D4 | Task 2 `_run`, `_plan`, `_closure`; P1–P5, N1–N14, G6, G7 |
| D5 | `_isObject`, `diagnostics()`; N11 |
| D6 | `_refused`; G1, G2 |
| D7 | `ParametricEdit.capabilities`, `ParametricReplay`; G4, G5 |
| D8 | the cleanup; G3, BX5 |
| D9 | `capability`, single use; P4, P9 |
| D10 | `drift()`, the catalog; N8, N9, N10 |
| D11 | N5, N6, N7, P3 |
| D12 | P2, P3; the results note's debt |
| D13 | Tasks 5–8 |
| Invariants | Task 10; P4, N12 |

**Placeholder scan.** No TBD. Some steps name a fallback where the plan's
reading of Flutter or of an existing fixture could be wrong:
- CN1 and CN2 adapt to the draw fixture's rig names;
- BX4's counts are derived by hand if the geometry disagrees;
- BX5 falls back to `undo()` if meta+Z does not reach the shell;
- SP's `onTapOutside` has a fallback ruling.

Each says what to paste and what to do instead.

**Type and name consistency.** These names are used identically across
tasks:
- `ParametricCatalog`, `register`, `registerComponents`;
- `ParametricSystem(doc, catalog)`, `install`, `dispose`, `drift`,
  `diagnostics`;
- `ParametricEdit`, `ParametricReplay`, `Generated`,
  `GeneratedGeometryError`, `ParametricView.paramsOf`, `toWorld`,
  `neighbours`;
- `BoxParams.componentTypeId`, `BoxType`, `boxCatalog`, `installBoxes`,
  `BoxTool`, `SelectionPanel`;
- the keys `tool-box`, `box-width`, `box-height`, `selection-panel`.

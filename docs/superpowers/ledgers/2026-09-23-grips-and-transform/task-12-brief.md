### Task 12: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-23-plan-03-results.md`
- Modify: the spec
- Modify: `roadmap/03-grips-and-transform.md` (status line)
- Modify: `roadmap/00-README.md` (status row)
- Modify: `STATUS.md` (a Plan 03 section in the shape of Plan 04's; the
  header; the Resume paragraph)

**Interfaces:**
- Consumes: every earlier task's result, the mutation log, and the
  differential's printed line.

- [ ] **Step 1: The gate commands, all four lines.** Paste each output into
  the results note, with exit codes. Name the five golden failures.
  Expected counts, by adding the tests this plan lands to the branch
  point's:
  - engine: branch point + 11 (grips) + 6 (rigid) + 9 (drag snap);
  - render layer: branch point + 1 (O1) + 7 (C) + 1 (I1) + 11 (D) + 19
    (T and W: T7 was folded away, so the T numbers skip it) + 6 (P) + 1 (K1), and 1 skip;
  - harness: 82;
  - app: 21 + 4, with both builds `✓ Built`.

  Report what ran, not these sums: a difference means a test was not
  counted as planned. Explain it in the note.

- [ ] **Step 2: The results note.** Include:
  - One row per exit criterion 1–16, each with its witness (test file and
    test name, the mutation log, or the pasted gate line; see "Exit gate"
    below).
  - The differential: seed `0x5EED0003`, 200 trials, and the worst residual
    per kind, pasted from the test's printed line.
  - The mutation tally.
  - Every Ruling 03-1…03-21, one line each.
  - The debt: the root-transform disagreement (spec Open questions, still
    open); grips as widgets (accessibility, 12); snapping to the dragged
    object's ghost; move exactness is within one rounding; the unfillable
    room's preview; F3 in a browser.
  - **Criterion 16 marked OWED — not looked at; the human looks after this
    branch is presented**, with these items itemised per platform (macOS,
    Chrome, Firefox from `build/web`):
    1. Grips on a selected wall, a room, an arc and the door swing: squares
       of 8 px, the centre grips in the move colour, the hover's hot grip.
    2. A wall end stretched onto another wall's end with the endpoint
       marker showing, and landing on it.
    3. A body move of three objects with grid snap on: they stay on the
       grid.
    4. The rotation grip above the selection box. A rotate, then a shift
       rotate in 15° steps.
    5. Escape mid-drag: the preview vanishes and nothing changes.
    6. Undo after each drag: cmd+Z on macOS, ctrl+Z in a browser, one step
       per drag.
    7. F3 toggles `osnap-text`. **In Chrome and Firefox: does the browser's
       find-next also fire?** If it does, the finding picks another key
       (spec Open questions).
    8. The cursor: precise over a grip, grab over the rotation grip, move
       over a selected body, grabbing while rotating.
    9. A room corner stretched so the room self-intersects: the preview
       shows the outline, and the fill drops on release.
    10. Whether snapping to the dragged object's own ghost feels sticky.
    11. A drag carried past the canvas edge continues.
    12. Grid snap with a fixed `gridStepMm` skipping the drawn minor lines:
        **not reachable from the app** (04's panel does not expose it).
        Recorded, not looked at.

- [ ] **Step 3: The spec amendments.** Add these "Amended at execution
  (Plan 03)" paragraphs. None rewrites the original text; each cites its
  ruling.
  - D2: Rulings 03-6 and 03-9.
  - D3: Ruling 03-1, for the end angle modulo 2π and exit criterion 2's
    wording.
  - D5: Ruling 03-8.
  - D6: Rulings 03-10 and 03-15.
  - D7: Ruling 03-3.
  - D8: Ruling 03-11.
  - Invariant 5: Ruling 03-12.
  - Testing: Ruling 03-16 for the differential's scale, and Ruling 03-17's
    M-03ab…M-03ax table with ids, mutation and test.

- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 04's shape:
  - In `STATUS.md`, add a "Plan 03 — grips and transform (executed on
    `plan-03/grips-and-transform`, not merged)" section with the task
    table and each task's head commit.
  - Add "What Plan 03 measured": the four counts, the mutations, the
    differential, the allocation gates, and the look OWED.
  - Update the header and the Resume paragraph.
  - Set `roadmap/03-grips-and-transform.md`'s status to "executed, not
    merged", with links to the spec, the plan and the results.
  - Update the matching row of `roadmap/00-README.md`.

- [ ] **Step 5: Commit, then archive the ledger.**

```bash
git add docs/superpowers/notes/2026-09-23-plan-03-results.md docs/superpowers/specs/2026-09-23-grips-and-transform-design.md roadmap/03-grips-and-transform.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 03 results, spec amendments, STATUS and roadmap

Exit gate 15 of 16; criterion 16 (the human's look on macOS, Chrome and
Firefox) is OWED. Spec amended at execution for Rulings 03-1, 03-3, 03-6,
03-8, 03-9, 03-10, 03-11, 03-12, 03-15, 03-16 and 03-17.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Then archive the ledger as the branch's **last commit before the merge**:

```bash
mkdir -p docs/superpowers/ledgers/2026-09-23-grips-and-transform
cp -R .superpowers/sdd/2026-09-23-grips-and-transform/. docs/superpowers/ledgers/2026-09-23-grips-and-transform/
git add docs/superpowers/ledgers/2026-09-23-grips-and-transform
git commit -m "$(cat <<'EOF'
docs: archive the Plan 03 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

Hand over to `superpowers:finishing-a-development-branch`. **The merge is
the human's decision.** If the auto-mode classifier refuses the merge, try
once from the main checkout. If it is refused again, give the human the
exact command (memory: `sandbox-blocks-git-merge`).

---

## Exit gate

The spec's sixteen criteria, each with the task and test that witnesses it:

| # | criterion (short) | witness |
|---|---|---|
| 1 | `leafGrips` returns D3's set, closed-polyline rule | Task 1: "the grip set per kind, in owner space", "isClosedPolyline is an exact stored-value test"; Task 4: C1 |
| 2 | a stretch moves only the grabbed coordinate; the arc's derived end within `Tolerance` | Task 1: the line, middle-vertex, room-corner, both arc ends (both signs) and radius tests (the end angle modulo 2π, Ruling 03-1) |
| 3 | `rigidTransformLeaf` passes the differential | Task 2: R6 (seed `0x5EED0003`, 200 trials, scaled tolerance) |
| 4 | a body drag and a centre grip move the whole selection; on-grid stays on-grid | Task 7: T2, T8, T5 |
| 5 | a rotated group and an instance compose `T.multiply(node.transform)`; the definition and the other instance are untouched | Task 6: D2, D3 |
| 6 | rotation about the box centre (arcs by `arcBounds`, points by position); shift 15° | Task 4: O1, C2; Task 7: T11, T12 |
| 7 | one drag is one `CompoundCommand` labelled Move, Rotate or Stretch; a no-op adds none | Task 6: D1, D4, D5, D6; Task 7: T3, T4 |
| 8 | undo restores with `==`; M-03e is the survivor, with its 1-ulp check | Task 6: D10, D11; Task 10: M-03e's log entry |
| 9 | Escape, pointer cancel, activation and revalidation are byte-identical; a drag past the edge continues | Task 7: T15, W1, T16, W3, T17, W2 |
| 10 | a stretch lands exactly on an endpoint; object beats grid; ortho is overridden and re-pinned; F3 off | Task 3: S3, S4, S6, S7; Task 7: T9; Task 9: A1, A2 |
| 11 | permissions at press and all-or-nothing at release | Task 4: C5; Task 7: T13; Task 8: P4; Task 6: D8 |
| 12 | grips in O(1) draw calls; the cap at `kMaxGrips` | Task 8: P2; Task 4: C4 |
| 13 | every named mutant fired and killed, except M-03e | Task 10's log: fifty-one entries (27 spec, 23 plan, plus `ah′`) |
| 14 | the allocation invariants pass unchanged | Task 11 |
| 15 | the four gate lines, the five goldens only, both builds | Task 12, step 1 |
| 16 | a human looked on macOS, Chrome and Firefox | **OWED** to the human; Task 12's note itemises it |

## Self-review

**Spec coverage.** Each decision, invariant and exit criterion, with the
tasks that carry it:

| spec item | task(s) |
|---|---|
| D1: move, rotate, reshape, rigid only | 1, 2 (`isRigidTransform`), 6 |
| D2: `GripDrag` in `SelectTool`; press classes; slop; shift's two meanings; capability at press | 6, 7 (T1, T6, T13); Rulings 03-2, 03-6 |
| D3: the grip set, closedness, reshape, `rigidTransformLeaf` | 1, 2 |
| D4: one `CompoundCommand`; `T`; `T.multiply(node.transform)`; order; fills; permissions; revalidation; no-ops | 6 (D1–D10) |
| D5: phases and kinds; world per event; camera listener; cancel paths; keys; cursor; hover | 5 (I1), 7 (T2, T14, T15, T16, W1–W3); Rulings 03-7, 03-8 |
| D6: `GripCache`; `worldBoundsOf`; the cap; the shell owns the caches; `drawRawPoints`; hot grip; rotation grip | 4, 8 (P2, P4), 9; Rulings 03-4, 03-10, 03-15, 03-19 |
| D7: the preview matrix; point crosses at `T(p)`; the reshape path in rebased world; the guide line | 5, 8 (P1, P5, P6, P8); Ruling 03-3 |
| D8: `resolveDragPoint`; precedence; base point; exactness; rotate; the grid step | 3, 7 (T4, T5, T9, T12); Ruling 03-11 |
| D9: snap markers | 8 (K1, P8) |
| D10: `SnapSettings`; `ToolContext` fields; F3 with `includeRepeats: false`; `osnap-text` | 5, 9 (A2, A3) |
| D11: undo is exact; M-03e and its companion | 6 (D10, D11), 10; Ruling 03-20 |
| D12: 02 behaviour changes | 7 (the renamed 02 test, T1, T15); Ruling 03-21 |
| Architecture: the test seam | 9; Ruling 03-18 |
| Invariant 1: no command during a drag | T3, M-03d |
| Invariant 2: cancel paths byte-identical | T15, T16, W1, W3, T17 |
| Invariant 3: undo with `==` | D10, D11 |
| Invariant 4: draw order untouched | T3 (`handleSeed.current`, live count) |
| Invariant 5: frame path unchanged | Task 11; Ruling 03-12 |
| Invariant 6: O(1) grip draw calls | P2, M-03v |
| Invariant 7: no `SnapResult.point` held | S3; Task 11's grep |
| Invariant 8: `==` for stored values, `Tolerance` for decisions | Global Constraints; G2, G10, R5, T2, and G7 (Ruling 03-1) |
| Differential check | R6 |
| Widget tests 1–4 | A1 (1, 2), A2 (3), A4 (4) |
| Exit criteria 1–16 | the Exit gate table above |

Every spec mutant, with the task that kills it:

| mutant | task |
|---|---|
| M-03a | 7 (T2) |
| M-03b | 3 (S5) |
| M-03c | 6 (D3) |
| M-03d | 7 (T3) |
| M-03e | 6 (D10 survives; D11 is its companion) |
| M-03f | 3 (S2), 7 (T6) |
| M-03g | 3 (S4) |
| M-03h | 2 (R2, R6), 6 (D4) |
| M-03i | 6 (D2) |
| M-03j | 7 (T11) |
| M-03k | 6 (D8) |
| M-03l | 7 (T15) |
| M-03m | 2 (R3, R6) |
| M-03n | 1 |
| M-03o | 1 |
| M-03p | 6 (D6), 7 (T4) |
| M-03q | 3 (S6) |
| M-03r | 1 |
| M-03s | 7 (T5) |
| M-03t | 6 (D7), 7 (T17) |
| M-03u | 8 (P1) |
| M-03v | 8 (P2) |
| M-03w | 7 (T12) |
| M-03x | 3 (S7), 9 (A2) |
| M-03y | 1, 4 (C1) |
| M-03z | 4 (C4) |
| M-03aa | 7 (T15), 9 (A4) |

The plan's M-03ab…M-03ax are each tied to the one test they guard in Task
10's second table.

**Fixture rules.**
- The camera is zoomed (1.1 or 2.0), panned, and rotated (0.35 rad). T2
  asserts `b ≠ 0` and `scale ≠ 1`, and C7 asserts the rotation.
- The group's transform is a rotation, and D2 asserts `b ≠ 0`.
- There are two instances of one definition (D3).
- The arcs have non-zero starts, and `arcNeg` sweeps −1.4.
- A closed room.
- Everything sits at x ≈ 7000, and P1 asserts a non-zero origin.
- The root is the identity, asserted in `gripScene` and in T3.

**Placeholder scan.** No TBD, no "similar to Task N", and no test without
its code. Task 7 and Task 8 name exact line ranges and method names to
keep, because they edit an existing file rather than repeat 150 unchanged
lines. The spec is re-derivable from the rulings wherever the plan departs
from it.

**Type and name consistency.**
- `Grip(role, index, x, y)`, `leafGrips`, `reshapeLeaf`,
  `rigidTransformLeaf` and `isRigidTransform` (Tasks 1–2) are used with
  the same signatures in Tasks 4, 6, 7 and 8.
- `resolveDragPoint`'s named parameters and `dragGridStepMm(page,
  pxPerWorldMm)` (Task 3) match `SelectTool._resolve` (Task 7).
- `GripCache.grips`, `hot`, `box`, `rotatable`, `leafGripsLive`,
  `hitTest`, `hitsRotationGrip`, `stretchCount` and `moveCount` (Task 4)
  are read in Tasks 7 and 8.
- `GripRef.key/grip/ordinal` is read in Tasks 4 and 7.
- `rotationGripOf(box, m).anchor/.centre` is used in Tasks 4, 7 and 8.
- `GripDrag.move/rotate/reshape`, `base`, `target`, `transform`,
  `previewPayload`, `leafKind`, `theta`, `capabilities`, `permittedBy`,
  `moveTo`, `rotateTo(…, step:)` and `command(permissions)` (Task 6) are
  used in Tasks 7 and 8.
- `DragKind`, `PressClass`, `SelectTool.dragKind/pressClass` (Tasks 6–7)
  are used in the tests of Tasks 7, 8 and 9.
- `Tool.paintWorldOverlay(Canvas, Vector2, double)` (Task 5) is overridden
  in Task 8.
- `ToolContext.page/snap/grips` (Task 5) is built by `GripRig` (Task 7)
  and by the shell (Task 9).
- `gripRig(DraftDocument, …)` takes a document everywhere; `gripScene()`
  returns a `GripScene` whose `.document` is passed in.

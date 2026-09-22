### Task 12: Gates, the results note, the owed look, the resume point

**Files:**
- Create: `docs/superpowers/notes/2026-09-21-plan-02-results.md`
- Modify: `roadmap/02-interaction-core.md` (status line), `roadmap/00-README.md` (status row), `STATUS.md` (a Plan 02 section and the Resume paragraph)

- [ ] **Step 1: The eleven gate commands, all four lines**, outputs pasted
  into the results note with exit codes; the five golden failures named.
- [ ] **Step 2: The results note**: one row per exit criterion 1–15 with its
  witness; criterion 15 (the human's look, macOS + Chrome + Firefox) marked
  **OWED — not looked at; the human looks after this branch is presented**,
  with the seven items itemised; D10's N-undo-steps debt and the partial-undo
  hazard stated in as many words; the differential's trial count.
- [ ] **Step 3: STATUS and roadmap** as 01 did (`STATUS.md` Plan 01 section
  is the template).
- [ ] **Step 4: Commit**, then hand to `superpowers:finishing-a-development-branch`.

---

## Exit gate

The spec's fifteen criteria, verbatim, each with the task that witnesses it:

| # | witness |
|---|---|
| 1 | Task 5 tests 2–4; Task 9 test 1 |
| 2 | Task 2 test 1; Task 5 test 7; Task 9 test 2 |
| 3 | Task 3 test 1 |
| 4 | Task 5 test 1; Task 9 test 3; Task 8 test 4 |
| 5 | Task 6 tests 1, 3; Task 9 test 5 |
| 6 | Task 8 test 1 |
| 7 | Task 4 |
| 8 | Task 11's log, thirty entries |
| 9 | Task 2 test 10 |
| 10 | Task 11 |
| 11 | Task 11's diff, Task 12's harness line |
| 12 | Task 12 |
| 13 | Task 10 tests 1–3 |
| 14 | Task 8 test 5 |
| 15 | OWED to the human, Task 12's note |

## Self-review

- **Spec coverage:** D1 → Tasks 5, 9; D2 → Task 3; D3 → Task 6; D4 → Task 4;
  D5 → the file table; D6 → Task 3; D7 → Tasks 5, 9; D8 → Tasks 1, 2, 5
  (Ruling 02-2); D9 → Tasks 7, 8; D10 → Task 6; D11 → Task 3; D12 → Task
  10. The pointer routing table → Task 9. Every mutant has a task: a, g, s,
  t, u, z → 2; b, o → 2; c′, k, p, aa → 3; d, f, h, r → 5; j, n, x (tool
  level) → 6; v, w → 7; e′, m, ab, ac → 8; g, i, l, x, y → 9. c and e →
  Task 11's equivalence entries.
- **Placeholder scan:** none. Task 2's `_bandDescend` is the corrected
  form (window walks the whole container through `_kAllBox`).
- **Type consistency:** `SelectionKey.root(Handle)` used in Tasks 3, 5, 6,
  10; `ToolPointerEvent` fields identical in Tasks 4, 5, 9;
  `OutlineCache.pathFor(key, origin)` in Tasks 7, 8; `SelectionOverlay`'s
  constructor identical in Tasks 8, 10; `kPickRadiusPixels` moves from Task
  5 to Task 9 and is imported from `interaction_layer.dart` after that.

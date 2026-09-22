### Task 12: Gates, the results note, the spec amendments, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-22-plan-04-results.md`
- Modify: the spec (amendments at execution: Rulings 04-1, 04-2, 04-7 as
  "Amended at execution (Plan 04)" sentences at D12, D10 and D7),
  `roadmap/04-page-grid-rulers.md` (status line), `roadmap/00-README.md`
  (status row), `STATUS.md` (a Plan 04 section, the header, the Resume
  paragraph)

- [ ] **Step 1: The gate commands, all four lines**, outputs pasted into
  the results note with exit codes; the five golden failures named.
- [ ] **Step 2: The results note**: one row per exit criterion 1–16 with its
  witness; criterion 16 (the human's look, macOS + Chrome + Firefox) marked
  **OWED — not looked at; the human looks after this branch is presented**,
  with the seven items itemised per platform; the `header.units` non-goal
  stated in as many words; the adaptive-snap-follows-zoom sentence from D6;
  the differential's seed and trial count.
- [ ] **Step 3: STATUS and roadmap** as 02 did (`STATUS.md`'s Plan 02
  section is the template).
- [ ] **Step 4: Commit**, archive the ledger as the branch's last commit,
  then hand to `superpowers:finishing-a-development-branch`.

---

## Exit gate

The spec's sixteen criteria, each with the task that witnesses it:

| # | witness |
|---|---|
| 1 | Task 3 test 1 |
| 2 | Task 3 test 2 |
| 3 | Task 2 test 1 (undo/redo by value); Task 10 test 1 |
| 4 | Task 7 test 1 |
| 5 | Task 4 `pick` tests; Task 6 coincidence test |
| 6 | Task 6 bounded and breaks tests |
| 7 | Task 2 test 1; Task 6 chrome-toggle test |
| 8 | Task 11 |
| 9 | Task 4 snap tests |
| 10 | Task 4 format test; Task 7 upward test |
| 11 | Task 4 zoom test; Task 9 fit test |
| 12 | Task 6 differential |
| 13 | Task 10 |
| 14 | Task 11's log, twenty-two entries |
| 15 | Task 12 |
| 16 | OWED to the human, Task 12's note |

## Self-review

- **Spec coverage:** D1 → Tasks 1, 4, 9; D2 → Task 6 breaks; D3 → Task 1;
  D4 → Tasks 4, 5, 9; D5 → Tasks 4, 7; D6 → Task 4; D7 → Task 4 (with
  Ruling 04-7's `minorMinPixels`); D8 → Task 6; D9 → Task 3; D10 → Task 5;
  D11 → Tasks 7, 8; D12 → Tasks 9, 10; D13 → Task 2. Every mutant in the
  spec's table has a task and a test above; M-04g's placement is the one
  Ruling 04-7 moves.
- **Placeholder scan:** nothing says TBD; Ruling 04-7 in Task 4 records
  the one place where the spec's own thresholds made a named mutant
  unreachable and how the plan makes it reachable.
- **Type consistency:** `GridScale.pick` returns `GridScale?` everywhere
  (Tasks 4, 6, 7); `divisor` is defined in Task 4 and used in 6 and 7;
  `PageNotifier` is a `ValueListenable<PageComponent?>` wherever a painter
  takes `page`; `fitToPage(page, Size)` in Tasks 5 and 9; `zoomOf(double,
  page, double)` in Tasks 4 and 9; the `capability` parameter name is the
  same in Tasks 2 and 3's `CommandApplied` literal.

# Table groups fixes — progress ledger

**Plan:** docs/superpowers/plans/2026-10-05-table-groups-fixes.md (at `cfee751`).
**Spec:** docs/superpowers/specs/2026-10-05-table-groups-fixes-design.md rev 2, approved 2026-10-05.
**Branch:** `claude/dreamy-gates-2kgh4o`, main checkout.
**Branch point gates** (code identical to `8f56773`, measured on the merged tree, Flutter 3.47.6): render +1304 ~1 -7 (standing; not edited); planner +1278; restaurant symbols +94; app `floor_planner` +201; demo `restaurant_demo` +24; `dev_harness_2d` +82.

## Tasks

| Task | Implementer commits | Review | Status |
|---|---|---|---|
| 1 selectableMembers + grow rule | `d8d06ed` | Approved (no findings, 2 notes; 4 named + 7 own mutants red) | done |
| 2 Chip outside the frame | `7a96dc5` | Approved (no findings, 2 notes; 3 named + 4 own mutants red; only TG-L7 and TG-V2 changed, as X3 says) | done |
| 3 Exit | `402a775` (docs only) | — | done (owed: the human's look, the merge decision) |

## Rulings (with cost-if-wrong)

- **R-C1-1 (accepted by review 1):** TG-C15 also runs a `lockFive` variant (locked carrier first in handle order), which alone kills the "first table decides" mutant. Cost if wrong: one loop and a fixture flag.
- **R-C1-2 (accepted):** the empty-request guard is in `_merge`, not the static `mergeGroups` (documented: numbers non-empty).
- **Notes (review 1):** no test covers a host-only grow that empties another group (code path pinned by the new-group tests); a direct empty `mergeGroups` call yields a memberless group `setTableGroups` refuses.
- **R-C2-1..3 (accepted by review 2):** TG-L7's title reworded; M-TGF-8/9 at 0.125 px/mm in a new TG-L11 (two groups, per-group pairing); TG-V2's extra premise that its reference pixel is clear of the chip.

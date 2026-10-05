# Plan — table groups fixes (F-1 and the chip at low zoom)

**Spec:** [2026-10-05-table-groups-fixes-design.md](../specs/2026-10-05-table-groups-fixes-design.md),
revision 2 (X1–X4, F-1..F-7, M-TGF-1..10; review R-1..R-12 applied).
**Approved** by the human ("Onaylıyorum, planı yaz", 2026-10-05).
**Branch:** `claude/dreamy-gates-2kgh4o`, restarted from `main` at
`3753ca4`; spec at `ee553e1`.

## Global constraints

- **Repo rules.** The `CLAUDE.md` non-negotiables apply. The engine and
  the render package are **not edited**. Groups never reach the document.
- **Unedited tests.** Existing tests pass unedited, with two exceptions.
  The deliberate X3 expectation changes, TG-V2 and TG-L7, are allowed.
- **Gates.** Every task ends green: the planner, `floor_planner` and
  `restaurant_demo` run `flutter test`, `flutter analyze` and `dart format`.
  The render package is run once at the exit to show it unchanged.
- **Named mutants.** Each task kills its named mutants by a scratch edit,
  reverted, and records the red command in the ledger
  (`.superpowers/sdd/2026-10-05-table-groups-fixes/`).

## Tasks

### Task 1 — `selectableMembers` and the demo's grow rule (X1, X2)

- **Controller.** `FloorPlanController.selectableMembers(String groupId)`:
  - reads the cached `_groupLookup`;
  - trims the id;
  - returns an unmodifiable `Set<String>`;
  - returns an empty set for an unknown id.
- **Demo.** `DemoHomeState.mergeGroups(groups, numbers, selectable)`
  applies X2's literal grow rule and its edge cases. `_merge` passes
  `c.selectableMembers`.
- **Docs.** In the parent spec's "Amended at execution", R-C5-1 is marked
  retired and F-1 closed.
- **Tests,** killing:
  - M-TGF-1, -2 and -3 (with a locked/unlocked duplicate variant);
  - M-TGF-10 (freshness after `setTableGroups` and after a mode switch);
  - M-TGF-4 (a host sets groups under a live selection: new group, not a
    grow);
  - M-TGF-6 (a group with no selectable member never grows);
  - M-TGF-7 (a grow that takes 5 from a labelled `G1` with a status);
  - M-TGF-5, by re-firing D18 under the new rule.

### Task 2 — the chip outside the frame (X3)

- **Painter.** In `TableGroupPainter`, the chip's translate becomes
  `sy - (p.height + kGroupChipPaddingY)`. Its doc comments and the
  `_Group` anchor doc are updated.
- **Docs.** The parent spec's "Amended at execution" gains an X3 bullet.
- **Tests:**
  - TG-L7's expectation changes to the new translate, and its scale loop
    gains 0.04 px/mm;
  - TG-V2 moves table 20 up by 8 px, with a premise that the row lies
    inside the chip;
  - M-TGF-8 and M-TGF-9 are killed (bottom ≤ anchor and = anchor, within
    1e-6, at 0.04 and 0.125 px/mm);
  - M-TG-22 is still killed by TG-V2.

### Task 3 — the exit

- **Gates:** every gate, plus the render package run once (unchanged),
  and `flutter build web --release` for the demo.
- **Screenshot:** a Chromium screenshot of the demo at the default fit
  with a group, showing the chip clear of the chairs. It goes in
  `docs/superpowers/notes/2026-10-05-table-groups-fixes/`.
- **Results note:** `docs/superpowers/notes/2026-10-05-table-groups-fixes-results.md`.
- **STATUS.md** is updated.
- **Owed:** the human's look.

### Task 11: Gates, the results note, the spec amendments, STATUS, the owed look

**Files:**
- Create: `docs/superpowers/notes/2026-09-23-plan-05-results.md`
- Modify: the spec, `roadmap/05-drawing-tools.md`, `roadmap/00-README.md`,
  `STATUS.md`

**Interfaces:**
- Consumes: every earlier task, the mutation log, and the differential's
  printed line.

- [ ] **Step 1: The four gate lines, pasted with exit codes.**
  - **Expected counts** (the branch point plus what this plan lands):
    - engine: 894 + 10 (E) + 7 (S) = **911**;
    - render layer: 854 plus every `test/draw/` case (count them from the
      run; the per-flipY loops double some), with 1 skip and the five
      goldens;
    - harness: **82**;
    - app: 26 + 12 (A) + 2 (SP) = **40**;
    - both builds `✓ Built`.
  - **Report what ran, not these sums.** Explain any difference.
- [ ] **Step 2: The results note.** Include:
  - one row per exit criterion 1–14, each with its witness;
  - the differential's printed line;
  - the mutation tally;
  - every Ruling 05-1…05-15, one line each;
  - the Review Focus items and their tests;
  - the debt:
    - the text field's font jump;
    - no fill preview;
    - the app camera in `planner_grips_test.dart` still a reflection;
    - the sample-plan count margin (Ruling 05-12);
  - **criterion 14 marked OWED: not looked at; the human looks after this
    branch is presented.** It is itemised per platform: macOS, Chrome, and
    Firefox from `build/web`. Each platform's list:
    1. Every tool once. The palette highlights the active tool, and the
       top bar names it.
    2. A line chain snapped onto a wall end, and ended by clicking its
       start.
    3. A polyline closed by clicking its first vertex, with Fill on and
       then off.
    4. A rectangle and a circle with Fill on: grey fills under their
       outlines.
    5. An arc drawn clockwise, then counter-clockwise, then across the
       left-hand horizontal.
    6. Text: T, click, type "Living room" (it contains `l`, `v`, `r`),
       Enter. Then Escape on a second one, and a canvas click on a third.
    7. Escape mid-shape and then undo: one step per shape.
    8. The filled furniture over the tiles and the parquet.
    9. In Chrome and Firefox, whether the browser also takes any single
       letter, or F.
    10. Whether the text field's position and font jump on commit are
        acceptable.
- [ ] **Step 3: The spec amendments.** Add "Amended at execution (Plan 05)"
  paragraphs, each citing its ruling:
  - D4: Ruling 05-2;
  - D5: Rulings 05-6 and 05-8;
  - D8 and the differential: Ruling 05-1;
  - D9: Rulings 05-8 and 05-11;
  - Testing: Ruling 05-9, M-05v's observable.
- [ ] **Step 4: STATUS and the roadmap.** Follow Plan 03's shape:
  - a "Plan 05 — drawing tools (executed on `plan-05/drawing-tools`, not
    merged)" section;
  - the header;
  - the Resume paragraph;
  - the branch map;
  - `roadmap/05-drawing-tools.md`'s status line;
  - the row in `roadmap/00-README.md`.
- [ ] **Step 5: Commit, then archive the ledger.**

```bash
git add docs/superpowers/notes/2026-09-23-plan-05-results.md docs/superpowers/specs/2026-09-23-drawing-tools-design.md roadmap/05-drawing-tools.md roadmap/00-README.md STATUS.md
git commit -m "$(cat <<'EOF'
docs: Plan 05 results, spec amendments, STATUS and roadmap

Exit gate 13 of 14; criterion 14 (the human's look on macOS, Chrome and
Firefox) is OWED. Spec amended at execution for Rulings 05-1, 05-2,
05-6, 05-8, 05-9 and 05-11.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
mkdir -p docs/superpowers/ledgers/2026-09-23-drawing-tools
cp -R .superpowers/sdd/2026-09-23-drawing-tools/. docs/superpowers/ledgers/2026-09-23-drawing-tools/
git add docs/superpowers/ledgers/2026-09-23-drawing-tools
git commit -m "$(cat <<'EOF'
docs: archive the Plan 05 ledger

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

The ledger archive is the branch's **last commit before the merge**. Hand
over to `superpowers:finishing-a-development-branch`. **The merge is the
human's decision.**

---

## Exit gate

The spec's fourteen criteria and where each is witnessed:

| # | criterion | witness |
|---|---|---|
| 1 | each tool, documented geometry, both cameras | B1, L1, PL1, PL3, R1, C1, AR1, TX1–TX2 |
| 2 | one shape, one undo step; redo, same handles | E4, L1, L4, PL1, PL4, R3, C2, TX2, A11 |
| 3 | a snapped start is exact | B2, L1 |
| 4 | Escape, tool switch, dispose: byte-identical | B4, B9, PL9, TX5, A6, A10 |
| 5 | a rectangle round-trips closed, plain and filled | E5, R5 |
| 6 | text at the requested cap height | E7 |
| 7 | the palette and shortcuts reach all seven tools and Fill; an idle Escape returns | A1, A2, A4 |
| 8 | the arc's direction follows the pointer; the differential | S2–S6, AR1–AR4, the differential |
| 9 | Fill: regions, the fallback, the kinds that ignore it | E9, PL4, PL5, R3, R4, C2, AR5 |
| 10 | the sample plan's furniture is filled over the finishes | SP1, SP2 |
| 11 | every mutant killed | `plan-05-mutation-log.md` |
| 12 | the allocation invariants unedited; the overlay's structural test | Task 10 greps, OV1, OV2 |
| 13 | the four gate lines, the five goldens only, both builds | Task 11 Step 1 |
| 14 | the human's look | OWED (Task 11) |

## Self-review

**Spec coverage.** Each part of the spec, and where the plan covers it:

| spec item | covered by |
|---|---|
| D1 | Tasks 3–6: 02's API is untouched, checked by the Task 10 grep |
| D2 | Task 1: `draftRecord` and `addDrafted` |
| D3 | Task 3 |
| D4 | Task 3 `_resolve`; PL8 |
| D5 | Task 7 |
| D6 | Tasks 3 and 4 |
| D7 | Tasks 4 and 5 |
| D8 | Tasks 2 and 5 |
| D9 | Tasks 1, 6 and 7 |
| D10 | B4, B6, B8, B9, TX5 |
| D11 | Tasks 1 and 2 |
| D12 | Task 3's `band`; OV1 and OV2 |
| D13 | Tasks 1, 3 and 4, and the Task 7 palette |
| D14 | Task 8 |
| Invariants 1–6 | B1, L1, PL3 (1); E4, R3 (2); B4, PL9, A6 (3); Task 10 grep (4); OV1, OV2 and the allocation tests (5); E9, PL4, R3 (6) |

**Fixture rules.** No test uses scale 1.0, a 0° or 90° camera, the origin,
or the default 1:50. The render and app cameras run unflipped, which
guards against a `b`/`c` transposition, as `fix/grip-camera-bc-swap`
taught.

**Placeholder scan.** There is no TBD and no "similar to Task N".

Three steps name a fallback to take if a measured behaviour differs from
this plan's reading of Flutter:
- A8's `sendKeyEvent` result;
- AR6's round trip;
- M-05k's bits.

Each says what to paste and what to do instead.

**Type and name consistency.** These names are used identically across
Tasks 1–8:
- `PlacementTool`, `commit`, `commitShape`, `acceptingSelf`, `band`,
  `bandPaint`, `hoverPoint`, `hoverVisible`, `isPending`, `clearShape`,
  `hovered`;
- `TextPlacement`, `pending`, `controller`, `commitText`, `cancelText`;
- `addDrafted`, `addDraftedRegion`, `kDraftFillColor`, `textHeightMm`,
  `SweepTracker`, `wrapAngle`;
- `ShellShortcutGuard`, `ToolPalette`, `PaletteEntry`, `TextEntryOverlay`,
  `kTextEntrySize`.

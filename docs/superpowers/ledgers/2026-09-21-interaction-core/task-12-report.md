# Task 12 report — gates, the results note, the owed look, the resume point

## Step 1: the four gate lines

All run with `CI=true` from each package directory, one line at a time;
`git status --short` checked after every line — clean throughout, no
`analysis_options.yaml` rewrite at any point.

**`packages/jet_cad_2d`**: `CI=true dart test` → `00:03 +820: All tests
passed!`, exit 0. `dart analyze` → `No issues found!`, exit 0. `dart format
--output=none --set-exit-if-changed .` → `Formatted 116 files (0 changed)`,
exit 0.

**`packages/jet_cad_2d_flutter`**: `CI=true flutter test` → `00:10 +765 ~1
-5: Some tests failed.`, exit 1. Failing tests, all five and only five:
`text ladder rung 1 (RenderBackend.canvas)`, `text ladder rung 2
(RenderBackend.canvas)`, `text ladder rung 3 (RenderBackend.canvas)`, `text
ladder rung 4 (RenderBackend.canvas)`, `text ladder rung 5
(RenderBackend.canvas)`, all in `test/golden/text_ladder_golden_test.dart` —
the Plan 01 baseline exactly. `flutter analyze` → `No issues found!`, exit 0.
`dart format --output=none --set-exit-if-changed .` → `Formatted 136 files
(0 changed)`, exit 0.

**`apps/dev_harness_2d`**: `CI=true flutter test --concurrency=1` → `00:20
+82: All tests passed!`, exit 0 — matches the branch-point count and the
brief's expectation. `flutter analyze` → `No issues found!`, exit 0. `dart
format --output=none --set-exit-if-changed .` → `Formatted 22 files (0
changed)`, exit 0.

**`apps/floor_planner`**: `CI=true flutter test` → `00:00 +11: All tests
passed!` (12 tests, indices 0–11). `flutter analyze` → `No issues found!`,
exit 0. `dart format --output=none --set-exit-if-changed .` → `Formatted 5
files (0 changed)`, exit 0. `flutter build macos --debug` → `✓ Built
build/macos/Build/Products/Debug/floor_planner.app`, exit 0. `flutter build
web` → `✓ Built build/web`, exit 0 (run as its own command, ~24s).

All four gate lines match the brief's expectations exactly; no fixture
adjustment, no threshold move, no rewritten `analysis_options.yaml`.

## Step 2: the results note

Written to
`docs/superpowers/notes/2026-09-21-plan-02-results.md`: one row per exit
criterion 1–15 with its witness (test file and test name, the mutation log,
or the pasted gate line); criterion 15 marked OWED with all fourteen items
(seven per platform: macOS, and Chrome/Firefox from `build/web`); the
mutation tally (28 fired, 28 killed, 0 survived, 2 equivalent, from
`plan-02-mutation-log.md`); the differential's trial count (52 bands, 104
comparisons, from `band_query_test.dart` and the Task 2 report); the Plan 01
baseline (five text-golden failures) recorded again; and a "Debt and
rulings the human should know" section covering D10's N-undo-steps and
partial-cascade-undo debt, the group-band-vs-outline asymmetry (Ruling P-1
vs. Task 7's outline ruling), the band-edge clip (Task 8), the
exit-during-drag ruling (Task 9, spec amended), `worldPointOf`'s accepted
per-point allocation, the `SelectionOverlayPainter` rename, and M-02c/M-02e's
equivalence.

## Step 3: spec amendments

Six amendments landed in
`docs/superpowers/specs/2026-09-21-interaction-core-design.md`, each a short
"**Amended at execution (Plan 02, 2026-09-22):**" sentence appended after
the original text (nothing original rewritten):

1. D8 gains the group-membership rule (Ruling P-1).
2. D8's band-walk paragraph gains the singular-instance-transform ruling
   (Task 2).
3. D9 gains the `SelectionOverlayPainter` name and its reason; the Files
   list entry for `selection_overlay.dart` corrected the same way.
4. D9 gains the point-key cross-paint rule (Task 7/8).
5. D9 gains the `ui.Path.getBounds` conic-hull note (Task 7).
6. The `SelectTool` table's "exit while dragging" clause is superseded by an
   amendment sentence (Task 9).

## Step 4: STATUS and the roadmap

`STATUS.md`: a new "Plan 02 — interaction core (executed on
`plan-02/interaction-core`, NOT merged)" section (task list with each task's
head commit, the four rulings a reader must know, the measured table, the
14/15 exit gate); the header's "Last updated" line now leads with Plan 02's
executed-not-merged status before Plan 01's merged status; the "Resume here"
paragraph gains a paragraph saying sub-project 02 is executed and awaits the
human's look and the merge decision, and the "twelve sub-projects" count is
corrected to eleven.

`roadmap/02-interaction-core.md`: status line → "spec 2026-09-21 (rev 2,
amended at execution), plan 2026-09-21, executed on
`plan-02/interaction-core` (2026-09-22), the human's look OWED".

`roadmap/00-README.md`: the 02 row's Spec/Plan/Executed columns filled in,
linking the spec, the plan and the results note, with the executed-not-merged
state named in the Executed column.

No merge is claimed anywhere; every mention of Plan 02 says NOT merged and
that the merge is the human's decision.

## Commit

`b02410a` — `docs: Plan 02 results — gate 14 of 15, the look owed`. Trailer
verified: `git log -1 --format=%B | grep -c "Fable 5.1"` → `1`. Files: the
five listed above (`STATUS.md`, the spec, both roadmap files, the new
results note) — nothing else. `git status --short` clean after the commit.

## Concerns

- Criterion 15 (the human's look) is OWED, as the brief requires — this
  session ran headless, with no display, no `flutter run`, no browser. This
  is not a gap in the work; it is the one criterion this task cannot
  discharge.
- The exit gate is 14 of 15 with no MISS — every criterion this session
  could measure passed on the tree as committed at `afe7d64`, unchanged by
  this task (which touched no code, only docs).
- The four rulings summarised in STATUS.md's Plan 02 section are a
  condensed pointer to the full ledger (`.superpowers/sdd/2026-09-21-interaction-core/progress.md`)
  and the results note's own "Debt and rulings" section, which is more
  complete; a reader who wants every ruling verbatim should go to the
  ledger, not stop at STATUS.md's summary.

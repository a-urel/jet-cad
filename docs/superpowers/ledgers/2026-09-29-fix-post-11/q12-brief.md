# Q1+Q2 brief — the liveness filter at a wall joint, the palette's drawing flag, two stale comments

You are the implementer for Q1+Q2 on branch `fix/post-11`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11` (HEAD `47a7fcb`, Q3's engine
guard). Work only there. Read `CLAUDE.md`, then the ledger
`.superpowers/sdd/fix-post-11/progress.md` and `q3-report.md` (what the guard
now does). Commit; do NOT push. An independent reviewer is reviewing `47a7fcb`
in another worktree and an investigator works in a third; touch neither. Do not
change engine code (`packages/jet_cad_2d/lib`).

Source: `docs/superpowers/notes/2026-09-28-plan-11-results.md`, "Found, not
fixed": (e), "A stale comment in the render layer", "An unpinned palette flag".

## Q2 — (e) the liveness filter at a wall joint (a MUST before merge)
`apps/floor_planner/lib/parametric/wall_grips.dart` `_endsAt` loops over
`withComponent<WallParams>()` with no liveness filter, so an orphan `WallParams`
a file brought in (on a handle with no node, or on a nested group) joins a
wall-end drag. Before Q3 it was silently moved and drew a phantom preview; since
Q3's guard the drag's commit is refused and the select tool's pointer-up
rethrows (`q3-report.md`, "App paths"). Fix: `_endsAt` considers live wall
objects only — a root-level `GroupNode` — the same rule `wall_bands.dart`'s
survey applies (about line 124) and `_keptPut` already applies (read it; reuse
one predicate if there is one, don't add a third spelling). Check every other
`withComponent<…Params>()` loop in `apps/floor_planner/lib` for the same gap
and report each (fix the ones on an edit or preview path; list the rest).
Correct the comment at `wall_bands.dart:124-127`: "(… on a handle with no node,
which no tool or file path makes)" is false — a file can.

Tests (non-degenerate: the wall in a turned group off the origin; the orphan's
stored end on the dragged joint in world, so only liveness excludes it; both a
node-less handle and a nested group):
- the preview during the drag does not include the orphan;
- the commit through the **select tool** (the real pointer path, as the
  existing wall-grip tests drive it) succeeds, moves the live walls at the
  joint, leaves the orphan's `WallParams` `==` to what it was, and one undo
  restores everything;
- a live neighbour at the same joint still follows (control).
Mutants: M-Q2a the filter removed (the commit must go red — on `47a7fcb` it
throws); M-Q2b liveness only (`tree[h] != null`), so the nested-group orphan
joins; M-Q2c the filter applied to the dragged wall itself too (if that is a
distinct seam in your code).

## Q1 — the palette's drawing flag
`apps/floor_planner/lib/main.dart`'s `PaletteEntry` list sets `drawing:` per
tool; `planner_draw_test.dart`'s `A12` pins `tool-line` only, so flipping
`drawing` on 07's, 08's, 10's or 11's entries survives every test
(`rvF-paletteNotDrawing` in the Plan 11 mutation log). Read what `drawing`
controls (A12: under runtime permissions the drawing tools are disabled) and pin
it for **every** entry: each drawing tool disabled under the no-geometry
permission, Select not. One table-driven test is fine if each entry is
asserted by key and a missing key fails. Mutants: flip `drawing` on the
Dimension entry, on one of 07/08/10's, and on Select; each must go red.

## The render layer's stale comment
`packages/jet_cad_2d_flutter/lib/src/.../select_tool.dart` (find it; the band
rule about lines 483–489) names the leaves `picking()` rejects as "hidden, or on
a locked layer"; since spec 11 D19 a not-pickable leaf
(`EntityFlags.unpickable`) is skipped the same way. Correct the comment only.

## Procedure, gates, commit
Mutants: `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q12-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.

Gates (`export PATH=/root/flutter/bin:$PATH`):
```sh
(cd packages/jet_cad_2d_flutter && CI=true flutter test ; CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)
(cd apps/floor_planner          && CI=true flutter test && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed . && CI=true flutter build web --release)
```
At `47a7fcb`: render 940 + 1 skip + 7 standing (`text_ladder` 1–5,
`text_lod_ladder` 1–2); app 491. Paste summaries and exit codes.

Two commits are fine (Q2, then Q1 and the comment), or one. Messages in English,
e.g. `fix(app): a wall-end drag moves live walls only (post-11 (e))`, each
ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-post-11/q12-report.md` and return it: hashes; what
changed; the other `withComponent` loops you checked; red before the fix; every
mutant; gates; deviations; anything outside scope (reported, not fixed).

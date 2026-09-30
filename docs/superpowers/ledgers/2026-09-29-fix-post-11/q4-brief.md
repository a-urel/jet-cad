# Q4 brief — a wall thickness bound, the triangulator's far-away area, the panel's number text

You are the implementer for Q4 on branch `fix/post-11`, worktree
`/home/user/jet-cad/.claude/worktrees/fix-post-11`. Work only there. Read
`CLAUDE.md`; the ledger `.superpowers/sdd/fix-post-11/progress.md` (the Q4
probe line and the three rulings after it are binding); and the probe's report
`q4-probe-report.md` (its probe sources are in the scratchpad, prefix `q4p-`;
reuse them). Commit; do NOT push. Other agents may be reviewing in
`.claude/worktrees/fix-post-11-review`; touch nothing there.

## 1. (c) The bound (app)
`apps/floor_planner/lib/parametric/wall.dart`: `isWallThickness(t)` also
requires `t <= kWallMaxThickness`, a new named constant = 1e7 mm (10 km), with a
doc comment saying why (the probe's numbers: the smallest thickness that
collapses the band ring is 1.33e10 mm over its sweep; 1e7 leaves a margin of
about 1,300). Every caller then refuses above it: the Selection panel and the
Wall tool's settings. Check both refuse the same way they refuse a thickness
≤ `wallJoin.linear` (read how that shows in the UI; match it).
Tests:
- the probe's killing test: in tool mode type "1e100" without Enter, click a
  diagonal wall (non-degenerate: off-axis, off the origin): no exception, a new
  wall at the previous valid thickness (200, or whatever the setting keeps —
  say which and why), history one step, handle seed advanced only by that
  wall;
- the boundary: `isWallThickness(kWallMaxThickness)` true, the next double up
  false;
- the panel on a turned wall with a value just above the bound: refused, the
  field reverts, the document byte-identical.
Mutants: M-q4-noUpperBound (the bound clause removed), M-q4-boundary (`<`
instead of `<=`), M-q4-hugeBound (1e30).

## 2. (B) The triangulator's signed area (engine)
`packages/jet_cad_2d/lib/src/geometry/triangulate.dart` `_signedArea`: compute
the shoelace sum relative to the ring's first vertex (subtract it from every
point first), so far-away rings keep their area. The probe's patch is
`scratchpad/q4p-shoelace.patch`; read it, don't trust it. Check every other
caller of the same sum in the engine (grep for a shoelace / `signedArea`
elsewhere in `packages/jet_cad_2d/lib`) and report; change only what this
ruling covers. Keep the zero-allocation property if the function has one.
Tests: an engine test that triangulates the probe's ring (a 0.01 × 150 mm
rectangle at 1e9) and expects 2 triangles (0 today), plus the same ring at the
origin as the control, and a clockwise far ring (the reversal branch). An app
test: a short wall far away that the probe showed refused (its most realistic
case, e.g. a 3 mm wall at georeferenced mm coordinates) now lands through the
Wall tool. Mutant: M-q4-absShoelace (the raw
sum back).

## 3. The panel's number text (app)
`apps/floor_planner/lib/selection_panel.dart` `_number`: `v.round()` saturates
at 2^63−1, so 1e20 shows "9223372036854775807" and the focus-loss commit writes
a second, silent undo step. Make the shown text parse back to exactly `v`
(read how the field parses: `double.parse`? a unit parser?) for every finite
`v` — integers below 2^53 still show without ".0". Tests: a round-trip over
0, 1, 200, 2^53, 2^53+2, 1e20, 1e300, 0.1, -0 (whatever the field can hold);
and the widget path the probe found: a Box width of 1e20 committed with Enter,
then focus loss, leaves exactly one undo step and the stored value 1e20.
Mutant: the old `_number`.

## Docs
Short "Amended by fix/post-11" paragraphs: spec 07 D11 (the bound, and that a
loaded thicker wall still throws on the tool and grip paths — a known limit);
and wherever the engine spec that owns the triangulator states its winding rule
(find it; if none, say so in the report and skip).

## Procedure, gates, commit
Mutants: `cp` to a backup under
`/tmp/claude-0/-home-user-jet-cad/b8151ae2-5006-5f50-b81d-c013381534fe/scratchpad/q4-`
(yours alone), mutate, run, `cp` back, `diff` (exit 0). NEVER `git checkout --`
a .dart file. `CI=true` on every test command. Never synthesize output. Never
commit `analysis_options.yaml`.
Gates (`export PATH=/root/flutter/bin:$PATH`): [engine], [render], [harness],
[app] as in `q3-brief.md`, plus
`(cd apps/dev_harness_2d && CI=true flutter test --concurrency=1 && CI=true flutter analyze && CI=true dart format --output=none --set-exit-if-changed .)`
(the triangulator reaches every fill). Standing: engine −2, render ~1 −7.
Paste summaries and exit codes; state the counts at your branch point.

Commits (one per part is clearest), English, each ending with
```
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013XiH3QE4FtMMNUjbASxiEv
```
Write `.superpowers/sdd/fix-post-11/q4-report.md` and return it: hashes; what
changed; red before each fix; every mutant; gates; deviations; outside scope.

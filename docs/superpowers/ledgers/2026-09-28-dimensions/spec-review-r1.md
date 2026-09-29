# Sub-project 11 (dimensions): independent spec review

**Reviewed:** `docs/superpowers/specs/2026-09-28-dimensions-design.md`,
revision 1, commit `a2ba486` on `spec-11/dimensions` (read-only; the
worktree was left clean).
**Against:** the human's decisions (`11-brainstorm-decisions.md`, 1–21), the
spike note on the branch and the spike code (`spike/11-dimensions` at
`675f997`), `CLAUDE.md`, `roadmap/11-dimensions.md`, and the code on `main`
at `9774a55` (`regeneration.dart`, `parametric_system.dart`,
`wall_geometry.dart`, `opening_geometry.dart`, `placement_tool.dart`,
`grip_cache.dart`, `select_tool.dart`, `drag_snap.dart`,
`vertices_draw_sink.dart`, `startup_plan.dart`, `main.dart`).
**Runs made for this review** (all in a detached worktree
`.claude/worktrees/spec11-review` on `spike/11-dimensions`, removed
afterwards; scratch copies prefixed `spec11r-`):

1. The spec author's lineweight sweeps, set-ups 1 and 2, with
   `kDimLineweight` set to 25 in the worktree:
   `CI=true flutter test --no-pub test/spike_dims/spec11_lw_test.dart test/spike_dims/spec11_lw_dpr1_test.dart`
   ```
   lineweight 25 at 0.052 px/mm (dpr 3.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {depth: 2, hall: 2, width: 2}
   lineweight 25 at 0.15 px/mm (dpr 3.0): frames per probe {width: 32, hall: 32}, frames with the line lost {width: 1, hall: 1}
   lineweight 25 at 0.3 px/mm (dpr 3.0): frames per probe {hall: 32}, frames with the line lost {hall: 1}
   lineweight 25 at 0.052 px/mm (dpr 1.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {}
   lineweight 25 at 0.15 px/mm (dpr 1.0): frames per probe {width: 32, hall: 32}, frames with the line lost {}
   lineweight 25 at 0.3 px/mm (dpr 1.0): frames per probe {hall: 32}, frames with the line lost {}
   00:06 +2: All tests passed!
   ```
2. `spec11r-fallback_test.dart` (R-5's `drawnCapsOf` written as the spec
   words it, with and without step 1's fallback, over every spike Q1 case at
   the six placements):
   `CI=true flutter test --no-pub test/spike_dims/spec11r_fallback_test.dart`
   ```
   origin C9 A: capsOf fellBack true, mutant drawn fellBack true
   origin: points compared 258, differing under M-11fallback 0, fellBack differing 0
   corpus far origin, 23 deg: points compared 258, differing under M-11fallback 0, fellBack differing 0
   corpus far origin, 23 deg, own groups: points compared 258, differing under M-11fallback 0, fellBack differing 0
   +1e9 mm (1e6 m), 23 deg: points compared 258, differing under M-11fallback 0, fellBack differing 0
   +1e9 mm (1e6 m), 0 deg: points compared 258, differing under M-11fallback 0, fellBack differing 0
   +1e9 mm (1e6 m), 23 deg, own groups: points compared 258, differing under M-11fallback 0, fellBack differing 0
   00:00 +1: All tests passed!
   ```
   (the C9 line is printed at every placement, all `true`/`true`; abridged).
3. `spec11r-negzero.dart` (`dart run`): `{"offset":-0.0} true -1 true 0 true`
   (the JSON text, `isNegative` after decode, `(-0.0).compareTo(0.0)`,
   `-0.0 == 0.0`, `nan.compareTo(nan)`, equal hash codes of the two zeros).
4. `spec11r-fmt.py` (D9 reimplemented in python) over D17's five values:
   ```
   width 14000 ['14000', '1400.0', '14.00', '551 1/8', '45\'-11 1/4"']
   depth 9000 ['9000', '900.0', '9.00', '354 3/8', '29\'-6 1/4"']
   Hall 4690 ['4690', '469.0', '4.69', '184 5/8', '15\'-4 3/4"']
   Kitchen 4380 ['4380', '438.0', '4.38', '172 1/2', '14\'-4 1/2"']
   diag 3578.407467016578 ['3578', '357.8', '3.58', '140 7/8', '11\'-9"']
   143 7/8 in 12'-0" 1005 1.01 4000 ftin 13'-1 1/2"
   ```
5. `spec11r-halfsearch.dart` (`dart run`): every integer-mm vector
   (a, b), 0 ≤ b ≤ a ≤ 20,000, whose true length lies **below** a half
   quantum by at most 1e-6 mm, decided exactly with integers:
   ```
   mm: none up to 20 m
   m: none up to 20 m
   in 1/8: (4160, 2697): L = 4957.7624993539175 mm, 6.46e-7 below the half; R-13 -> 1562 quanta, exact half-up -> 1561
       (4583, 2173): L = 5072.0624996149245 mm, 3.85e-7 below the half; R-13 -> 1598 quanta, exact half-up -> 1597
       ...
   ft-in 1/4: (2124, 1731): L = 2740.02499988595 mm, 1.14e-7 below the half; R-13 -> 432 quanta, exact half-up -> 431
       (2691, 516): L = 2740.02499988595 mm, 1.14e-7 below the half; R-13 -> 432 quanta, exact half-up -> 431
       (5011, 3284): L = 5991.22499994784 mm, 5.22e-8 below the half; R-13 -> 944 quanta, exact half-up -> 943
   ```

## Verdict

**Ready with amendments.** No blocking finding. Three major findings must be
settled before the plan is written: one fidelity question for the human
(S-1), one named mutant that cannot be killed as specified (S-2), and one
contradiction an implementer cannot satisfy both ways (S-3). The rest are
minor.

What holds, checked independently:

- **"No engine change" (D1, D5).** `_closure` (`regeneration.dart:385-401`)
  puts the seeds' before/after neighbours and references in the core and
  takes referrers of the whole core, so a dimension on W regenerates when W,
  or any wall that is W's reach neighbour before or after the edit, is a
  seed. I constructed the cases the brief lists and each lands W in the
  core: a neighbour added (it is W's after-neighbour) or deleted
  (before-neighbour, the before-survey still holds it); a joint formed or
  broken by a third wall (the third wall is the seed and W's neighbour on one
  side of the edit); an end re-attach from A to B (the dimension is the seed;
  A and B are its before/after references); undo (the same `_run`); load
  (the spike's `Q2d`, `drift()` empty). `classify`, `cap`, `capsOf` and
  `localOutlineOf` are pure over `(w, others)` and read nothing of a
  neighbour's own joints (07's "neighbours unaffected" note at
  `wall_geometry.dart:404-408`), so no neighbour-of-neighbour path exists. A
  node cluster spread over 2 × `wallJoin.linear` is still inside two reach
  boxes grown by `wallJoin.linear` each, so the "neighbour of a neighbour
  through 07's node cluster" case is covered up to 07's own recorded edge,
  which the spec inherits and names. `openingsInView` filters referrers to
  `OpeningParams` whose host is the wall (`opening_geometry.dart:646-652`) and
  `opening.dart:196` only asks `contains(self)`, so a second referrer type
  breaks nothing.
- **Frame path.** Nothing in `packages/` changes; dimensions add ordinary
  LINE and TEXT children; the preview and the rings are tool-overlay work on
  pointer moves. The allocation invariants are untouched.
- **R-31 (decision 20).** Re-run (run 1) and re-derived: a lineweight is
  `hundredths/100 × pixelsPerPaperMm` logical px, floored at one **device**
  pixel (`vertices_draw_sink.dart:558-565`). A capture at pixel ratio 1 of
  a view at ratio 3 rasterises 0.945 px quads, which miss every pixel
  centre when their centre falls within `(1 − w)/2` = 0.0275 px of an edge,
  1 position in 18 (measured 1–2 of 32); at 0.18 mm, 0.16 px, 1 in 3
  (measured 10–11 of 32). At a matched ratio every stroke is at least one
  device pixel, which the fill rule always paints, and that holds at any
  ratio a browser can produce (below 1 as well, since the floor is in device
  pixels). The app uses this sink (`planner_view.dart:12-13`, no backend).
  So 0.25 mm survives, and the spec's overturn of the spike's finding holds.
  (Consequence: the matched sweep cannot fail for any weight; see S-10.)
- **Attach points.** Recomputed by hand: C3 (3950, 150), (4050, −150); C4
  with A left-justified and B right-justified: left (4000, 200), right
  (4120, 0), which the formula `(4000 − l_B, l_A)`, `(4000 − r_B, r_A)` gives;
  C5 (T) S/0: (2450, 100), (2500, 0), (2550, 100); C5c (T, left-justified
  stem, non-centre): (2600, −100), (2500, −100); C7 (Y) B/0/left
  (−115.470, 0), right (57.735, 100); C9 A's joined caps cross at (50, 50)
  and B/C keep (0, 100), (200, −100) / (100, 100), (−100, −100). All match
  the table.
- **Values.** D17's five 1:50 m values and every cell of the every-unit
  table recomputed (run 4 and by hand): all match, and the "nearest to a
  tie" remarks are right (Hall 738.58 quarters, 0.525 mm off; Kitchen
  1379.528 eighths, 0.09 mm). DL1, DL2's four `offsetFor` rows, DL3's
  children at 1:50 and 1:100 and the right-to-left aligned case, TL2's
  ortho case and AM3's σ values (0.334 / 0.942) recomputed by hand: all
  right.
- **`-0.0`.** Run 3 confirms D2's claims on the VM: `-0.0` is written and
  read back negative, `compareTo` separates the zeros, `NaN.compareTo(NaN)`
  is 0 (so `==` stays reflexive for R-3's NaN offset). `offsetFor`'s two
  zero cases produce `+0.0` (`0.0 / s`) and `-0.0` (`−(0.0 / s)`) as the
  spec says, and `o = offset · s` keeps the sign.
- **Transforms.** D6/D7/D11 are consistent: fixed ends local, attached ends
  world, linear axes the group's, offset a local length scaled by
  `scaleMagnitude`; the move, rotate, rotate-alone and far-origin rows match
  the spike's `Q4a`–`Q4e`. Mirror is a recorded limit (file only).
- **Mutants.** The count is 52 (6 roadmap + 18 spike + 28 new); every one
  but M-11fallback has a named test whose fixture I checked can see it
  (S-2). M-11d's redefinition (`k` ignored) plus M-11d2 (`side` ignored)
  covers the roadmap's "by handle only" for a `(wall, k, side)` reference;
  justified.
- **Fixtures.** Non-degenerate: six placements, non-axis pairs ((0,0)–(3000,
  1200), the sample's diagonal, AM3's outer corner), rotated and scaled
  dimension groups, `k = 1` and face sides, non-centre justifications, ft-in
  at 1:100, `-0.0`, F3 off, openings in the measured walls.

## Findings

### S-1 — Decision 19's "when" is re-decided as a ruling — **major**

**Where:** D10 "When it is decided", lines 839-853 (and R-17, line
1660-1662); the decision table row 19, line 63, restates the human's
"decided once both ends are known (the second click, or an end-grip drop)"
and so contradicts D10 on its own page; "Open questions for the human:
None", lines 1686-1694.

**Evidence.** Decision 19: "the choice is made once both ends are known (the
second click, or an end-grip drop)". R-17 moves the tool's choice to the
third click, with the committed kind's axis. The two timings give different
stored references on the spec's own fixture: AM3's outer corner (4100, −100)
to (3000, 3000), committed Shift-horizontal. Decided at the second click
(only the points are known, `u = (−1100, 3100)/3289.4`), `σ_B = 0.334`,
`σ_A = 0.942`: **B/0/right**. Decided at the commit with the horizontal
axis: **A/1/right** (the spec's AM3 expectation, and the only kill of
M-11lineardir's tool half). The decision's own "[Spec to pin: the parallel
measure for linear vs aligned]" is satisfiable under the literal timing too:
the kind is known at every end-grip drop. The spec's argument (the only way
to use the committed kind's direction at the tool) is reasonable, but it
changes something the decision settled, and the difference is invisible
until a joint breaks, which is exactly the kind of thing the human should
be asked rather than told.

**Amendment.** Either (a) follow decision 19 literally: the tool decides at
the second click with `u = (P1 − P0)/|P1 − P0|` for every kind; end-grip
drops use the current kind's `u` (as now); AM3's Shift-horizontal row then
expects B/0/right, and M-11lineardir is killed by a grip-drop row in GE3
instead; or (b) keep R-17 and move the question to "Open questions for the
human" with both outcomes on AM3's fixture, and mark row 19's "Here" cell as
"deviates, see D10". Do not leave it as a [spec ruling].

### S-2 — M-11fallback is an equivalent mutant under R-5 — **major**

**Where:** D4 "The drawn caps: 07's two fallbacks", lines 347-368; the
mutant table, line 1517 (`M-11fallback | 07's short-wall fallback ignored |
AP1 (C9)`); exit gate 15, line 1615.

**Evidence.** R-5's step 2 re-tests the ring in local space whenever step 1
did not fall back. With step 1's fallback removed, C9's joined ring (edges
crossing at (50, 50)) reaches step 2, whose affine image is still not simple,
so step 2 returns both free caps with `fellBack` true: the same points as
the correct code. Run 2 wrote `drawnCapsOf` exactly as the spec words it and
compared it with that mutant over all 43 walls of the spike's Q1 cases at
all six placements: **0 of 258 points differ, and `fellBack` never
differs**. AP1 cannot go red, so gate 15 ("every named mutant is killed")
cannot be met as written. (Step 1 is still worth keeping: it makes the
decision bitwise `localOutlineOf`'s in the rounding edge where a world ring
that is not simple has a simple local image, the reverse of WR13; but no
fixture in the spec reaches that edge.)

**Amendment.** Redefine M-11fallback as "no fallback at all in
`drawnCapsOf` (both steps return the joined caps)", killed by AP1 (C9:
A/0/left becomes (100, 100) instead of (0, 100)); keep M-11localring for
step 2. Or keep the definition and log it as equivalent, with this
reasoning, and exclude it from gate 15's count. Also have AP2 assert, as a
premise, that C9's A falls back in step 1 (`capsOf(...).fellBack`), so the
mutant's site is exercised.

### S-3 — A grid point on a wall end point: D10 attaches it, D12 says it is fixed — **major**

**Where:** D10, lines 796-809 (`attachCandidates(doc, index, q)`, gated by
F3 only); D12 "Unsnapped points", lines 989-991 ("a grid or raw point ...
gives a fixed end"); AM4 (line 1387-1388) tests the grid case only with F3
**off**; decision 9 ("attaches ... when the snap lands on one").

**Evidence.** `resolveDragPoint` (`drag_snap.dart`) returns the grid point
whenever no object snap lies within the aperture of the **raw** pointer.
At the whole-plan zoom (0.052 px/mm) the aperture is 10 px = 192 mm, while
the page's minor grid there is coarser; the sample's four outer corners
(12,000 / 26,000, 8,000 / 17,000) lie on any 500 or 1,000 mm grid. A pointer
300 mm from a corner therefore resolves, with F3 on, to the corner by the
grid: D10 attaches it, D12 says it is fixed. The grips cannot tell the two
apart anyway: `ObjectGripProvider.drag` receives only the resolved point
(`grip_cache.dart:37`), and the select tool's `DragPoint.objectKind` never
reaches the provider; the render package is frozen (decision 20).

**Amendment.** Pick one rule and state it once. Recommended, because the
grips can implement it without a render-layer change: **point-based** — an
end attaches when F3 is on and the resolved point, however it was resolved,
lies within `dimAttach.linear` of a wall end point. Rewrite D12's bullet to
"a point that is not within `dimAttach.linear` of a wall end point (a jamb,
furniture, another dimension, mid-face) is fixed", and add rows to AM4 and
TL6: with F3 on, a grid point that lands on a corner attaches; with F3 off it
stays fixed. (The alternative, object-snap-only, needs the tool to test
`hoverKind != null` and the grips to re-query `index.snapInto` at the
dropped point with the camera's aperture, which the provider does not have;
say so if it is chosen.)

### S-4 — The half-up tolerance rounds up true values just below a half in inch units — **minor**

**Where:** D9, R-13, lines 742-768; DF2, line 1410; D18.

**Evidence.** Run 5. For integer-millimetre geometry, metric units are safe
(no case up to 20 m; by the arithmetic, a true value below a half needs
`|N − H²| ≥ 0.25` for mm and cm, so δ ≥ 0.125 / L: over 125 m; ≥ 1 for m:
over 500 m). In inches and feet-inches the half `(2n + 1) · 127/80` is not a
multiple of 1/4 mm, so near-misses occur at room sizes: the aligned pair
(0, 0)–(2124, 1731) is 2,740.02499988595 mm, 1.14e-7 mm **below**
107 7/8", and R-13 prints `9'-0"` where exact half-up gives `8'-11 3/4"`;
(0, 0)–(4160, 2697) in inches prints `195 1/4` for a true 195 1/8 + a hair.
A one-quantum difference on a sub-micron question, and it is the price of
the tolerance (the spike showed exact arithmetic decides the intended halves
wrongly), but it is an accepted wrong answer, and nothing records or pins
it. Separately, the margin for detecting an intended half at +1e9 mm is
thin: the spike's worst attach error there is 3.77e-7 mm per point (Q1), so
a value between two such corners can be off by about 7.5e-7 against the
1e-6 tolerance (about 1.3×); DF3 exercises only free-wall faces (1.5e-8).

**Amendment.** Record both directions in D18 (a true value within 1e-6 mm
below a half shows rounded up; at +1e9 mm the half's margin is about 1.3×).
Add DF2 rows that pin the rule's contract: (0, 0)–(2124, 1731) in ft-in →
`9'-0"`, and 3450.5 − 0.9e-6 → `3451` next to the existing
3450.5 − 2e-6 → `3450`.

### S-5 — R-5's step 2 recomputes the free corners in world, which differ from the stored ones under a scaled wall group — **minor**

**Where:** D4, lines 352-365 ("the attach point is the drawn free corner
computed in world, which equals the stored local corner mapped to world to
rounding").

**Evidence.** `WorldWall` takes `t = p.thickness` unscaled
(`wall_geometry.dart:20-24`), so step 2's world free caps have thickness `t`,
while `localOutlineOf`'s fallback stores the free rectangle at the identity
in local space (`wall_geometry.dart:478-483`), which the group maps to
thickness `t · s`. Under a scaled wall group (file only) the attach point is
then not the drawn corner, and a snap on the drawn corner matches nothing.
Under a mirrored group, "left" in the stored `side` and left in world
disagree as well.

**Amendment.** In step 2, take the fallback points from the stored ring:
`localOutlineOf`'s local free rectangle mapped through `w.toWorld`. That is
exactly what is drawn and snapped, at any similarity. Or list scaled and
mirrored wall groups (file only) under D18's inherited limits.

### S-6 — The cost bound leaves out the seed-opening case and the hub wall's fan-out — **minor**

**Where:** D5 "Cost bound per edit", lines 451-463; D18, lines 1206-1207;
DN4, lines 1428-1430.

**Evidence.** From `_closure`: an **opening** edit (a door dragged along its
wall) puts its host in the core as a reference, so **every dimension on the
host regenerates**, though no wall end point moved. A **partition** edit puts
the through wall of its T in the core as a neighbour, so every dimension on
the exterior wall regenerates (a T in the middle never moves the through
wall's ends). An offset drag of one dimension regenerates its walls, all
their openings and every other dimension on them. Each is unbounded in the
number of dimensions per wall. None drifts, and the spec's claim ("no edit
pays anything for a dimension whose walls it does not reach") is true. But
the stated bound lists only seed walls and seed dimensions.

**Amendment.** State the bound as "every referrer of every wall in the
core, where the core holds the seeds' neighbours and references", name the
opening and hub-wall cases, and have DN4 print (not assert) the generate
count for a door move and for a partition thickness change on a wall that
carries N dimensions.

### S-7 — The hover attach search runs on nearly every pointer move over a wall, among all walls — **minor**

**Where:** D10 costs, lines 869-872; D12 costs, lines 992-994; TL8.

**Evidence.** Candidates are gathered whenever a wall **child's box**
touches `q ± 1e-5`. A wall's band box covers the whole wall, so every hover
inside any wall's box triggers the search. Hover points are nearly all
distinct, so "once per distinct resolved point" is once per move. Each
candidate wall then builds `wallsInDocument` (every live wall) and six
points, whose `classify` scans all of them: O(candidates × walls) per move.
The spike's own cost paragraph (note Q3, "A hover marker per pointer move
would want the candidates' neighbours from the index rather than all
walls") is not carried.

**Amendment.** Pre-filter the candidates on the stored ring vertices and
centreline ends near `q`, which is cheap from the child payloads, before
building any `WorldWall`; or compute the six points among the index's
neighbours of the candidate. Give TL8 a printed budget and a
`debugAttachSearches` count at 600 walls. If S-3 chooses object-snap-only,
gate the search on `hoverKind != null` as well.

### S-8 — Tool details an implementer would guess — **minor**

**Where:** D12, lines 915-994; `placement_tool.dart`.

**Evidence and amendments.**
- **Shift.** `accept(point, ctx)` and `hovered(raw)` do not carry Shift;
  `_lastShift` is private. Say that `DimensionTool` records `e.shift` in
  `onPointerMove`/`onPointerDown` and the Shift key's state in `onKey`, then
  calls `super`.
- **Enter** with one or two points pending: unspecified (the default
  `finish` is a no-op). State it: ignored.
- **The status line** is built as `'$base — $notice'` (`main.dart:321-326`).
  With a tool named "Dimension" and a notice `Dimension: 4.69` it reads
  `Dimension — Dimension: 4.69`. Pin the tool's name and the notice's
  wording together, and TL5's expected string.
- **R-18's "not `0.0`"** is ambiguous for a small negative angle:
  `(-0.04).toStringAsFixed(1)` is `-0.0`, which is not the string `0.0`.
  Compare the rounded number, `|angle| < 0.05°`, instead.
- **Grip drags** show no attach ring (only the tool's preview does); say
  whether that is intended.

### S-9 — AM1's "54 wall end points of the sample plan" is the spike's nine-wall fixture, not the sample plan — **minor**

**Where:** AM1, line 1374; D5's DZ1, line 467 ("nine walls").

**Evidence.** `startup_plan.dart` has ten wall objects: the column is a
tenth wall (`p.wall(x0 + 11500, …, 400)`, line 177), so 60 end points. The
spike's 54 came from `room_fixture.dart`'s `sampleWalls()` (nine walls,
line 360), not `samplePlan()`, which adds `sampleColumn` (line 417).

**Amendment.** Name the fixture: `samplePlan` (60 points, the column's
free-wall points included), or `sampleWalls()` with the fifteen openings
(54), and say which.

### S-10 — Tests with no named mutant; RR2 cannot fail by construction — **minor**

**Where:** Testing, lines 1352-1490; the mutant tables.

**Evidence.** CLAUDE.md's bar is that a test lands only if a named mutant
turns it red. No mutant names DP1, AP3, AM2, DN4, DO3, DO4, DO5, TL1, TL7,
GE1, GE4, GE5, PN1, PN3, PN4, PN5, SP1, SP5, SP9, RR2 or RR3. RR2 is
admitted to be unkillable, and the re-derivation above shows why: at a
matched ratio no weight can drop out. M-11nearest's kill on AM3 depends on
a tie-break the mutant does not define (the L corner is bitwise one point,
so "nearest" ties).

**Amendment.** Add mutants for the load-bearing ones, for example:
M-11negzero (`toJson` writes `offset.abs()`, or `==` uses `==` on the
offset) → DP1, DO3; M-11axesline (the axes line never shown) → PN3;
M-11key (I missing from `kShellLetterKeys`) → TL7; M-11colour (a TrueColor
instead of ByLayer) → RR3, DO1; M-11vertex (a face point from the cap's
second point) → AP3. Mark RR2 and the printed cost tests as recorded
measurements, not tests. Define M-11nearest as "nearest, ties to the lowest
handle".

### S-11 — M-11b's camera half is writable — **minor**

**Where:** the M-11b row, line 1503; "Retired from the spike", lines 1566-1568.

**Evidence.** The spec says the camera half "cannot be written: `generate`
never sees the camera". But the property lives in the render layer's text
path, which can be mutated for the log exactly as M-11closure and M-11text
mutate the frozen engine (text height divided by the camera scale in the
vertices sink's text op). RR1's two-camera assertion is the natural killer.

**Amendment.** Carry M-11b's camera half as a render-layer mutant killed by
RR1, restored with `cp` like the engine mutants, instead of retiring it.

### S-12 — Extension lines on wall faces take the wall's clicks — **minor**

**Where:** D18, the third bullet (lines 1195-1197); SL1.

**Evidence.** `pickInto` returns the **topmost** entity within the pick
radius (`spatial_index.dart:733`), and dimensions are added after the walls,
so they draw above them. The Hall's and Kitchen's extension lines lie on
E4's, P1's and P5's faces (x 12,250, 16,940, 17,060, 21,440, y 8,325–9,250).
A click on those face stretches, or inside the band within the pick radius,
selects the dimension instead of the wall.

**Amendment.** Record it in D18 next to "drawn along the band's edge and not
seen", add it to gate 16's look, and add an SL1 row that pins which object a
click on E4's face at (12,250, 8,800) selects, whichever answer is kept.

## Fidelity checklist (decisions 1–21)

Honoured: 1–18, 20 and 21. Decision 19 is honoured in its order (parallel,
then lowest handle, then face/centre, k, left/right) and in "never
re-decided by a switch or a move", but **not in its timing** (S-1). Rulings
that stay within the latitude the decisions leave: R-1 to R-16 and R-18 to
R-31. Of those, R-10's "no default offset" is justified by decision 18 and
the three-click tool; R-15's marks in ft-in only were delegated explicitly;
R-31 re-scopes how decision 20 is measured and is correct (run 1 and the
derivation). Only R-17's timing re-decides a settled point.

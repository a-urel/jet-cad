# Sub-project 11 (dimensions): independent spec review, round 2

**Reviewed:** `docs/superpowers/specs/2026-09-28-dimensions-design.md`,
revision 3, commit `17e7eda` on `spec-11/dimensions` (revision 2 is
`4fcf228`). I only read it; the spec worktree was left clean.
**Against:** decisions 1–25 (`11-brainstorm-decisions.md`), my round-1
review (`11-spec-review.md`, S-1 to S-12), and the engine and app code on
`main` at `9774a55`.

**Runs made for this review.** All were in a detached worktree
`.claude/worktrees/spec11-review2` on `spike/11-dimensions` (the wall,
opening and index code there is `main`'s), removed afterwards. Copies are
in the scratchpad with the prefix `spec11r2-`.

1. `spec11r2-fallback_test.dart`: round 1's probe, with revision 2's
   M-11fallback (both steps of `drawnCapsOf` removed).
   `CI=true flutter test --no-pub test/spike_dims/spec11r2_fallback_test.dart`
   ```
   origin C9 A: capsOf fellBack true, mutant drawn fellBack false, A/0/left good [0.0,100.0] mutant [100.0,100.0]
   origin: points compared 258, differing under M-11fallback 4, fellBack differing 1
   corpus far origin, 23 deg: points compared 258, differing under M-11fallback 4, fellBack differing 1
   corpus far origin, 23 deg, own groups: points compared 258, differing under M-11fallback 4, fellBack differing 1
   +1e9 mm (1e6 m), 23 deg: points compared 258, differing under M-11fallback 4, fellBack differing 1
   +1e9 mm (1e6 m), 0 deg: points compared 258, differing under M-11fallback 4, fellBack differing 1
   +1e9 mm (1e6 m), 23 deg, own groups: points compared 258, differing under M-11fallback 4, fellBack differing 1
   00:00 +1: All tests passed!
   ```
   The C9 line is printed at every placement, each with A/0/left moved;
   abridged here.
2. `spec11r2-flush_test.dart`: a door placed flush with a wall end, and
   whether that end's attach points are still vertices the wall stores.
   `CI=true flutter test --no-pub test/spike_dims/spec11r2_flush_test.dart`
   ```
   T clamped c=450: S/0/left (2450,100) stored false, S/0/centre (2500,0) stored false, S/0/right (2550,100) stored false
   T flush c=550: S/0/left (2450,100) stored false, S/0/centre (2500,0) stored false, S/0/right (2550,100) stored false
   T inset c=650: S/0/left (2450,100) stored true, S/0/centre (2500,0) stored true, S/0/right (2550,100) stored true
   flush: A/0/left (0,100) stored false, A/0/centre (0,0) stored false, A/0/right (0,-100) stored false; A/1/left (4000,100) stored true; diagnostics []
   inset 100: A/0/left (0,100) stored true, A/0/centre (0,0) stored true, A/0/right (0,-100) stored true; A/1/left (4000,100) stored true; diagnostics []
   00:00 +2: All tests passed!
   ```
   The T fixture is spike C5: C (0,0)→(6000,0) 200, S (2500,0)→(2500,3000)
   100, with a 900 mm door on S. "Clamped c=450" is a door centre that
   `placeCut` clamps into the stretch that starts at C's face; the free-end
   fixture is A (0,0)→(4000,0) 200 with the same door at c = 450.

## Verdict

**Ready with amendments.** No blocking finding and one major one (S-13).
Revision 2 opened a gap there in my S-7 pre-filter, and it also exposes a
gap in revision 1's candidate query. Four minor findings. The engine flag
(decisions 24 and 25, D19) checks out against `main` on every point the
brief lists.

## 1. S-1 to S-12: closed?

| Finding | Status |
|---|---|
| S-1 (decision 19's timing) | **Closed** by decision 22. Row 19 is marked superseded, row 22 added, R-17 cut to the measure, D10 and D13 cite it. A wording nit remains (S-16) |
| S-2 (M-11fallback equivalent) | **Closed, verified.** Run 1: with both steps removed, C9's A/0/left becomes (100, 100) instead of (0, 100) at all six placements, as the mutant table says. AP2's step-1 premise is added |
| S-3 (grid point on a corner) | **Closed** by decision 23. D10 and D12 are reworded; AM4 and TL6 get the F3-on grid row; M-11snaponly is killable through TL6, where the tool can see `hoverKind`. **But see S-13**: an attach point whose corner a flush opening removed is dropped before decision 23 applies |
| S-4 (half-up both ways) | **Closed.** D9 and D18 record it, R-32 keeps the tolerance, DF2 and DF3 gain the rows. DF3's two-corner half is right: 3,550.5 − 100 = 3,450.5 |
| S-5 (scaled wall group) | **Closed.** Step 2 maps the stored local free rectangle; AP2 gets a scaled variant; the mirrored wall group is listed in D18. A wording nit remains (S-16) |
| S-6 (cost bound) | **Closed.** All four cases are named, and DN4 prints them |
| S-7 (hover attach search) | **Closed as asked, but its pre-filter's premise is false** in a reachable case (S-13) |
| S-8 (tool details) | **Closed.** Shift is captured before `super`; Enter is R-33; the status line reads `Dimension — 4.69`; R-18 tests the number; no ring during grip drags (R-34) |
| S-9 (AM1's fixture) | **Closed.** `samplePlan` has ten walls and 60 points; DZ1 uses `sampleWalls()` |
| S-10 (tests without mutants) | **Closed.** Sixteen mutants were added and each killer is plausible; see S-15 for GE5's fixture |
| S-11 (M-11b camera half) | **Closed.** M-11b-cam is fired in the render layer and restored |
| S-12 (extension lines take clicks) | **Superseded and closed** by decisions 24 and 25 (D19, SL1) |

## 2. The engine flag, verified against `main` @ `9774a55`

- **No bit collision.**
  - `EntityFlags` defines only `invisible = 1 << 0` (`style.dart:129-132`).
  - The column is a `Uint8List` (`entity_store.dart:265`).
  - Its only readers are `query_filter.dart:76` and
    `jet_cad_2d_flutter/lib/src/reference_walk.dart:119`, both testing
    `invisible` only.
  - Every writer in `packages/` and `apps/` writes `0` or
    `EntityFlags.invisible` (`room.dart:301, 306`, the parametric test
    client, `draftRecord`, `commands.dart:554, 567`).
  - No test fixture JSON stores a non-zero `flags`.
  - There is no DXF reader anywhere in `lib` (the only DXF mentions are doc
    comments), so no load path can set bit 1 today.
- **`acceptsEntity` stays O(1).** It already begins with `isPassthrough` and
  one column read (`query_filter.dart:69-84`). One more bool test, then one
  column read when the filter asks, allocates nothing and does no map
  lookup. The frame path's filter is `rendering()`, which never asks.
- **Every pick and snap path goes through `acceptsEntity` with the caller's
  filter:**
  - `pickInto` → `_descend`'s `visitLeaf` (`spatial_index.dart:861-862`);
  - the snap leaf walk (the same `visitLeaf`, 868);
  - the centre tree (`visitSnapCentre`, 877-878);
  - the intersection snap (`_considerIntersections`, 1548);
  - band leaves and bands inside instances (`forEachLeafInBand` 391,
    `_bandDescend` 568);
  - the select tool's click and hover (`_pick`, `select_tool.dart:107-109`,
    `picking()`), its bands (452-453, 474) and `_everyLeafIn` (498).

  A dimension's grips are object grips at computed positions, and its
  extension lines are group children, so they never get leaf grips. The
  outline cache and the painter use `rendering()`, so a selected dimension
  still outlines its extension lines, as D19 says. Nothing in the app
  picks.
- **Save and load.** `flags` is written as an int and read back
  (`entity_store.dart:145, 173`) into the column (419). Bit 1 round-trips,
  and no schema bump is needed (see S-16).
- **Changing `snapInto`'s default is silent in behaviour.** The callers in
  `lib` come down to one, `resolveDragPoint` (`drag_snap.dart:72`), which
  every placement tool and the select tool's drags use (the render layer
  has no other snap call); the others are the benchmark and the engine
  tests. No existing fixture carries bit 1, so every existing result is
  unchanged. `snapping()` keeps `excludeLocked` false, so locked-layer
  snapping is unchanged. The one visible trace: the reason text of
  `snap_centre_index_test.dart:521-525` says "defaults to
  QueryFilter.rendering()". It still passes (hidden layers are still
  excluded) but should be reworded along with the doc comment at
  `spatial_index.dart:1446-1458`.
- **Nothing in 01–10 sets bit 1.**

The four flag mutants are killable as listed: M-11pickflag by QF1/SL1,
M-11snapflag by QF2/TL9 (see S-14), M-11extflag by DO1/SL1, M-11flagdraws
by QF1/RR1.

## 3. Findings (continuing from S-13)

### S-13 — A flush opening removes a wall end's stored vertices, and D10 then never offers that end, against decision 23 — **major**

**Where:**
- D10, the candidate walls ("its stored boxes hold them", about line 903,
  from revision 1);
- the vertex pre-filter ("Every attach point is such a stored point (D4,
  R-5), so the filter loses none", lines 907-913, from revision 2);
- AP3 (line 1665, "every face point is a vertex of the stored ring");
- M-11prefilter (line 1894).

**Evidence.** Run 2. `_pieces` (`opening_geometry.dart:421-465`) adds the
start piece only when its extent is over `wallJoin.linear`. A cut flush with
the end therefore leaves no ring piece and no centreline piece there.
`stretchesOf` starts at `frame.uS`, and `placeCut` clamps into a stretch,
so this is the **normal** result of placing a door near a T. On spike C5
with a 900 mm door at c = 450 (clamped to C's face) or c = 550, the stem S
stores none of S/0/left (2450, 100), S/0/centre (2500, 0) or S/0/right
(2550, 100). A free end with a flush door stores none of A/0's three
points. Nothing is diagnosed.

At such a point the index query finds no wall child, since no box of S's
remaining pieces holds it, and the pre-filter finds no vertex. So the end
is fixed. Yet decision 23 says any end within the attach tolerance of a
wall's attach point attaches. The door's own symbol (its leaf starts at the
jamb corner on the face) puts an object snap exactly there, so the person
sees a snap on the corner and gets a fixed end.

`generate` is unaffected, because it computes the point from parameters,
so an end attached before the door was slid flush keeps measuring the
corner. Only attaching there fails. I proposed the pre-filter in S-7 and
missed this; revision 1's candidate query already had the gap.

**Amendment.** Pick one and state it:
- **(a) Keep decision 23 whole** (recommended):
  - Gather the candidate walls from the rect query's wall children **and**
    from the hosts (`OpeningParams.host`) of any opening child the query
    touches. A jamb corner always has an opening child at or next to it.
  - Replace the stored-vertex pre-filter with an exact O(1) test from
    `WallParams`: take `q` to the wall's local frame and pass the wall only
    if `q` lies within `dimAttach.linear` of its left face line, centreline
    or right face line (offsets from D2's justification).
  - Every attach point lies on one of those three lines. This holds for
    mitre, T and Y corners, the free rectangle (scaled too) and the
    degenerate case, so the test loses none. A hover over a wall's middle
    passes only on the exact lines, not in the band.
  - Redefine M-11prefilter on the new test, for example "the centreline
    omitted from the line test", killed by AM1's centre points.
  - Add an AM row for C5 with a flush door, attaching S/0/left by position
    and through the door's jamb snap.
  - Reword AP3 as "every face point of a wall with no flush opening".
- **(b) Declare an undrawn corner unattachable.** That departs from
  decision 23, so it needs the human's word. Then record it in D18, pin it
  with the same C5 row expecting a fixed end, and fix the "loses none"
  sentence.

### S-14 — TL9's aperture is not pinned, and the Hall's own dimension-line end is 100 mm away — **minor**

**Where:** TL9, line 1767; M-11snapflag, line 1910.

**Evidence.** The probe point (12,250, 9,250) is the extension line's
overshoot end. The dimension line's end Q0 is (12,250, 9,150), 100 mm away,
and the slash ends are about 110 mm away. At the whole-plan zoom the 10 px
aperture is 192 mm, so Q0 would win the snap with or without the flag, and
"nothing else within the aperture but that line" silently fails. The
fixture only holds when the aperture is under 100 mm, that is above
0.1 px/mm.

**Amendment.** Pin TL9's camera, for example 0.3 px/mm (a 33 mm aperture).
Assert both that the resolved point is not (12,250, 9,250) and that no
object snap won. Add a premise run showing that under `rendering()` the
same hover snaps to (12,250, 9,250).

### S-15 — GE5 needs a linear dimension on a non-axis pair to kill M-11previewkind — **minor**

**Where:** GE5, line 1780; M-11previewkind, line 1908.

**Evidence.** The mutant lays the grip preview out as aligned whatever the
kind. On an axis-aligned pair, aligned and horizontal give the same lines,
which is the degenerate fixture CLAUDE.md warns of. GE5 names no fixture.

**Amendment.** Put GE5 on a horizontal (or vertical) dimension over a
non-axis pair, such as DL1's (0, 0)–(3000, 1200), with the offset grip and
an end grip dragged.

### S-16 — Wording and small precision points — **minor**

- **Line 957**, "decision 22 chose the second": it is ambiguous next to
  "the second click". Say "chose the commit (A/1/right)".
- **Line 403**, "bit for bit the point the index holds": this is not
  established. The snap composes the group and leaf transforms in its own
  order (`_composeLeafTransform`), while `drawnCapsOf` calls
  `w.toWorld.transformPoint`. Say "to rounding, well inside
  `dimAttach.linear`", which AP2 already checks.
- **The pre-filter's payload read**, if it survives S-13: `GeometryStore.read`
  copies; the non-copying accessor is `peek` (`geometry_store.dart:130`).
  This is pointer-move work, not the measured frame path, but say which.
- **D19:** state that the flag needs no schema version change (`flags` was
  already a free int), and that the plan rewords the reason string in
  `snap_centre_index_test.dart:521-525` with the `snapInto` doc comment.

## Anything else new in revisions 2 and 3

I found no contradiction with decisions 1–25 beyond S-13's conflict with
decision 23:
- decision 22's timing is followed in D10 and D13;
- decision 24's selection by line, slashes or text is pinned by SL1's three
  rows, and the window-band row is killed by M-11pickflag through
  `_everyLeafIn`;
- decision 25's scope, tests, round trip and frame-path check are all in
  D19 and gate 13.

The count of 73 mutants is right (52 + 16 + M-11b-cam + 4). Apart from
S-13's M-11prefilter redefinition and S-15's fixture, each has a killer
whose fixture can see it.

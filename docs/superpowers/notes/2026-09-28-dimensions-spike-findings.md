# Sub-project 11 spike: findings

**Date:** 2026-09-28.
**Branch:** `spike/11-dimensions`, cut from `main` at `f81c585`.
**Status:** throwaway. The branch is never merged; this note is its only
output. It is an input to 11's spec, not a design.
**Where it ran:** a Linux x86_64 cloud container, the workspace's Flutter
and Dart (`/root/flutter/bin`), not the human's macOS machine. Timings are
JIT, in this container, and only indicative.

Every number below is quoted from a run made on this branch. Unless a line
says otherwise it comes from
`cd apps/floor_planner && CI=true flutter test --no-pub test/spike_dims`
on the code commit (`00:06 +45: All tests passed!`). The mutants were fired
by a scratch driver that ran the same command once per mutant.

## The decisions the spike worked under

The human's brainstorm decisions of 2026-09-28, as the spike read them:

| # | Decision |
|---|---|
| 1 | Each end is a wall feature it follows, or a fixed point. Drafted geometry and openings are not referents |
| 2 | v1 types: aligned (true distance) and linear (horizontal or vertical component) |
| 3 | A referenced wall deleted deletes the dimension in the same edit and undo step (08's `cascade`) |
| 4 | Attach points: a wall's six end points, (wall, k ∈ {0, 1}, side ∈ {left, centre, right}); a face point is the cleaned-up corner; anything else is fixed |
| 5 | Terminators: the architectural 45° slash, drawn as lines |
| 6 | Fixed paper sizes scaled by the page scale; text follows the paper, never the camera; a page-scale change regenerates every dimension |
| 7 | Value: the page's unit at plan precision (mm 1, cm 0.1, m 0.01, in 1/8, ft-in 1/4), round-half-up, no unit symbol |
| 8 | Text centred above the line, aligned, readable from the bottom or the right |
| 9, 10 | One Dimension tool on I, three clicks; Shift for linear |
| 11 | Grips: the offset and the two ends; the offset is stored relative to the measured points |
| 12 | A fixed end moves and rotates with the selection; an attached end follows its wall |
| 13, 14, 15 | A panel section; only placed dimensions; the sample plan ships a few |

The controller's readings, checked:

- **Layer 0, no dimension `EntityKind`, lines plus one `Generated.text`:**
  agreed; the spike's dimension is five LINEs and one TEXT, ByLayer on
  layer 0, so it follows the paper's foreground like drafting.
- **References to up to two walls, policy cascade:** agreed (deduplicated
  when both ends are on one wall).
- **"Suspected engine need" for the neighbour case: wrong.** 08 already
  closed it. `_closure` takes referrers of the whole *core* (seeds ∪ their
  neighbours ∪ their references), not of the seeds only: that is option
  (a) below, and it is on `main` today. Q2 shows it rebuilds the neighbour
  case, and that removing it (08's brief rule, M-closure) goes red.

Three premises of the brief were also wrong, and the spike worked around
them (Q3):

- `SnapResult.chain` is the **instance** path, not the group path: for a
  wall's child `chainLength` is 0 (`Q3f`: `chain length 0`), and the
  root-level group is the owner of `SnapResult.entity`.
- `resolveDragPoint` does not drop the hit: the caller-owned scratch still
  holds it (`Q3f`). What drops it is `PlacementTool`, whose `_scratch` is
  private.
- A T's butt corner is **not** a vertex of the through wall's ring; it is
  the stem's own (k, left/right) point, one of the six.

## What was built

- `apps/floor_planner/lib/parametric/dimension_geometry.dart` (219 lines):
  `wallEndPoint` (Q1), `formatDimension` and `roundHalfUp` (decision 7),
  `readable` (decision 8), `layoutDimension` (the lines, slashes and text
  placement).
- `apps/floor_planner/lib/parametric/dimension.dart` (304 lines):
  `DimEnd` (`AttachedEnd(wall, k, side)` | `FixedEnd(x, y)`),
  `DimensionParams`, `DimensionType`, the tool's `attachMatches` /
  `attachAt` (Q3), and `debugDimensionReadsPlaces` (Q2's option (b)).
- `catalog.dart` (+5 −1): registers the dimension.
- **No engine change.** `git diff f81c585 HEAD --stat -- packages` is empty.
- Tests, `apps/floor_planner/test/spike_dims/` (45 tests): `corner_test`
  (Q1), `drift_test` (Q2), `snap_test` (Q3), `rotate_test` (Q4),
  `engine_test` (Q5), `render_test` (Q6), `support.dart` (over 10's room
  fixtures: the six placements, `buildPlan`, the sample walls and
  openings).
- Renders, by the floor planner shell inside `flutter_test`
  (`RenderRepaintBoundary.toImage`), as 10's spike did. The camera maps
  world y down the screen, so the images are mirrored top to bottom, and
  "above" a horizontal line is below it on screen. The test font draws
  every glyph as a box. Kept:
  [2026-09-28-dimensions-spike/](2026-09-28-dimensions-spike/).

### Suites

- spike (`cd apps/floor_planner && CI=true flutter test --no-pub
  test/spike_dims`): `00:06 +45: All tests passed!`;
- app (`cd apps/floor_planner && CI=true flutter test --no-pub`): `01:40
  +393: All tests passed!`. That is `main`'s 348 (`01:32 +348: All tests
  passed!` in this container before any change) plus the 45 spike tests;
- `flutter analyze --no-pub` (app): `No issues found!`; `dart format
  --output=none --set-exit-if-changed lib test/spike_dims`: exit 0;
- the engine and the render layer were not touched and not re-run.

## Answers

### Q1 The wall end point

**Rule.** For a wall `w` among its wall neighbours:

- **centre** is the stored centreline end, `w.endpoint(k)`;
- **left / right** is the first or last point of 07's cap at that end,
  `capsOf(w, neighbours)`. A cap runs from the end's *outgoing*-left face
  to its outgoing-right face. At the start (k = 0) outgoing-left is the
  wall's left; at the end (k = 1) it is the wall's right. So the left point
  is `startCap.first` or `endCap.last`, and the right point is
  `startCap.last` or `endCap.first`. `capsOf` already applies 07's
  short-wall fallback (`fellBack`: both free caps). A node owner's cap
  walks its lobe, but its first and last points are still its own
  corners;
- a **degenerate** wall (07 D2) has no outline: all three sides are its
  centreline end.

**What "centre" is at a joint: the raw centreline end.** It is what the
wall generates as its centreline polyline's end, so it is what a snap
finds. At an L it is the node point, which is where the two centrelines
meet. At a T butt it is the stem's end on the through wall's centreline,
inside the through wall's band (C5: (2500, 0)), so a centre-to-centre
dimension measures centreline to centreline, which is the architectural
convention. The alternative, the cap's midpoint, gives (2500, 100) at the
T and differs from the raw end whenever the justification is not centred
(M-centre-mid is red on C4, C5 and C5c).

**What the T means for the through wall's own points: nothing.** Its ends
are wherever they are. C5 checks the through wall's four face points at
its free ends, unchanged by the butt. The butt corners belong to the
stem.

**Checked by hand**, every case at all six placements of 10's fixtures
(the origin; the corpus far origin turned 23°, at the identity and with
every wall in its own rotated group; +1e9 mm turned 23°, not turned, and
turned in own groups). Plan coordinates, mm. A wall's left normal is
`(-d.y, d.x)`: +y for a wall running east, −x for one running north.

| Case | Walls | Arithmetic | Expected points |
|---|---|---|---|
| C1 free | A (0,0)→(4000,0), 200 | faces y = ±100 | A/0: (0,100), (0,0), (0,−100); A/1: (4000,100), (4000,0), (4000,−100) |
| C2 L | A as C1; B (4000,0)→(4000,3000), 200 | A left y = 100, B left x = 4000 − 100 | inner (3900,100) = A/1/left = B/0/left; outer (4100,−100) = A/1/right = B/0/right; centre (4000,0) |
| C3 L 300/100 | A 300, B 100 | A faces ±150, B faces 4000 ∓ 50 | (3950,150), (4050,−150) |
| C4 L, 3 × 3 justifications | A 200, B 120 | A (l, r): centre (100,−100), left (200,0), right (0,−200); B: (60,−60), (120,0), (0,−120); B's face at offset o is x = 4000 − o | left corner (4000 − lB, lA), right (4000 − rB, rA); A/0 free: (0, lA), (0, rA) |
| C5 T | C (0,0)→(6000,0), 200; S (2500,0)→(2500,3000), 100 | S faces x = 2500 ∓ 50, cut at C's near face y = 100 | S/0: left (2450,100), centre (2500,0), right (2550,100); C's ends free: (0,±100), (6000,±100) |
| C5b T, stem ending on C | S (2500,3000)→(2500,0) | direction (0,−1), left normal (1,0): left x = 2550 | S/1: left (2550,100), right (2450,100) |
| C5c T from below, stem left-justified | S (2500,0)→(2500,−3000), 100, left | offsets (100, 0), left normal (1,0): left x = 2600, right x = 2500; near face y = −100 | S/0: left (2600,−100), right (2500,−100) |
| C6 X | A as C1; B (2000,−2000)→(2000,2000), 200 | no joint | all ends free: B/0 (1900,−2000), (2100,−2000) |
| C7 Y | three 200 mm walls from (0,0) at 0°, 120°, 240° | each wedge 120°: its corner on the bisector at 100 / sin 60° = 115.470 | A/0: (57.735,100), (57.735,−100); B/0: left (−115.470,0), right (57.735,100); C/0: left (57.735,−100), right (−115.470,0) |
| C8 + | four 200 mm walls at 0°, 90°, 180°, 270° | wedges 90°, corners (±100, ±100) | A/0: (100,100), (100,−100); B/0: (−100,100), (100,100); … |
| C9 fallback | A (0,0)→(100,0); B north from A's end; C north from A's start; all 200 | A's joined caps: end [(200,−100), (0,100)], start [(100,100), (−100,−100)]; edges x + y = 100 and y = x cross at (50,50): not simple | A falls back: (0,±100), (100,±100); B keeps its mitre (0,100), (200,−100); C keeps (100,100), (−100,−100) |
| C10 degenerate | t = 0; length 0 | no outline | every side is the centreline end |

Worst error against the hand values (`Q1 every case`):

```
Q1 worst error at origin: 4.973799150320701e-14 mm
Q1 worst error at corpus far origin, 23 deg: 1.041250292910165e-9 mm
Q1 worst error at corpus far origin, 23 deg, own groups: 1.877140660839749e-9 mm
Q1 worst error at +1e9 mm (1e6 m), 23 deg: 1.6858739404357614e-7 mm
Q1 worst error at +1e9 mm (1e6 m), 0 deg: 0.0 mm
Q1 worst error at +1e9 mm (1e6 m), 23 deg, own groups: 3.769728732309794e-7 mm
```

Also checked: every face point is a vertex of 07's outline ring
(`Q1 the corner is a vertex…`, within 1e-9 at the corpus in own groups).
An L corner is **bitwise one point** for both walls, because 07 computes a
wedge corner once:
`A/1/left [4503550.8958156165,1201615.9018864536], B/0/left
[4503550.8958156165,1201615.9018864536]`. Two things are not identities:
the Y's owner walks the lobe, so its ring holds a vertex that is another
wall's point (`Q1 Y: wall 1 ring 5 points, not its own:
[[-115.47005383792516,…]]`), and a ring index moves when a joint changes
(`Q1 A/0/right ring index: free 3 of 4, in the Y 4 of 5`).

Mutants (all red, see the table): M-nbrs (the neighbours ignored, which is
also the raw face end: with no neighbours `capsOf` gives the free caps),
M-swap (the k = 1 swap dropped), M-swap-just (left and right swapped for
right-justified walls), M-fallback (07's fallback ignored), M-centre-mid.

### Q2 Which edits must rebuild a dimension

**The neighbour case is already rebuilt by today's closure.** `Q2a`, at the
origin, the corpus in own groups and +1e9 mm in own groups: an L, and a
dimension on A's left face (A/0/left → A/1/left, which references A only).

- B thickened 200 → 300: A's parameters are `==` unchanged, A's mitre
  corner moves from (3900, 100) to (4000 − 150, 100), and the dimension
  reads `3850`, rebuilt exactly once (`debugDimensionGenerates` +1),
  `drift()` empty.
- A wall C joined at A's free start (100, 100): `3750`. C deleted:
  `3850`.
- `Q2b`, a T: the through wall thickened 200 → 400 moves the stem's corner
  (2450, 100) → (2450, 200), and the dimension on the stem reads `2900` →
  `2800`. The through wall's group moved 50 mm along its normal breaks the
  T (07 D4.1) and the stem's start squares at (2450, 0): `3000`.

**Why it is closed** (the argument 08 made for doors, which holds for
dimensions): a dimension reads its referents' parameters, and through
`classify` their wall neighbours. `wallsInView` hands `classify` exactly
`view.neighbours(host)`, and the relation is symmetric. So any edit that
changes a referent's corner lands a seed that is the referent or one of
its neighbours, before or after. That puts the referent in the core, and
the dimension is its referrer.

**The options, with the fuzz as the drift test.** `Q2e`: the sample plan's
nine walls at the corpus far origin, every wall in its own group, and 14
dimensions (random wall end points, a fifth of the ends fixed, aligned,
horizontal and vertical, some in rotated groups). Then 300 seeded edits:
thickness, justification, an end moved ±400 mm (joints made and broken),
a wall's group moved and turned, a wall added at a wall end, a wall
deleted, undo, a dimension's group moved. After every edit, `drift()` must
be empty, and every dimension's text and dimension line must equal an
oracle that recomputes each end among **all** walls (not the view's
neighbours) and re-lays it out (within 1e-6 mm). `neighbourOnly` counts
edits where a dimension's text changed although it references none of the
edited walls.

| Option | Rule | Cost bound | Fuzz, today's engine | Fuzz under M-closure (08's brief rule: referrers of the seeds only) |
|---|---|---|---|---|
| (a) today's closure | `closure = core ∪ referrers(core)`, core = seeds ∪ neighbours ∪ references | map lookups per core member; no dimension pays anything on an edit that does not reach its walls | `Q2e (a): (edits: 300, failures: [], generates: 1466, neighbourOnly: 10, readBoxCalls: 0)` | **red:** `step 7 (add): drift [82, 89]`, …, `generates: 1047` |
| (b) also read by place | the dimension `readsPlaces`; `readBox` = its stored children's box ⊕ `kDimReadMargin` (1.5 paper mm at 1:1000, since `readBox` cannot read the page) | every edit that changes a wall's band asks every live reader (rooms and dimensions) for a read box: O(readers · children) | `Q2e (b): (edits: 300, failures: [], generates: 1585, neighbourOnly: 10, readBoxCalls: 717)` | green: `Q2e (b): (edits: 300, failures: [], generates: 1439, neighbourOnly: 10, readBoxCalls: 717)` |

(b) is a working fallback: it alone keeps the fuzz green under M-closure.
But on today's engine it adds 119 generates and 717 read-box calls to 300
edits for nothing, and it needs a margin tied to an assumed page scale.
**Recommendation: (a), no engine change; do not make dimensions place
readers.** (c), "something better", was not needed. The spec should state
the invariant: a dimension reads only its referents and their one-hop
wall neighbours.

**Cascade (`Q2c`).** A wall referenced by one dimension is deleted (the
select tool's group delete). The dimension goes in the same step (undo
depth +1), and a second dimension on the other wall is rebuilt (`3100` →
`3000`, since that wall's start is free now). Undo restores the canonical
bytes, and every entity comes back with its handle and owner:
`Q2c cascade: 18 entities restored with their handles and owners; undo
depth 6 -> 5`. So ascending-handle draw order is intact. As 08 and 10
found, undo re-links the restored nodes at the end of the root's children
(canonical comparison with the node lists sorted). `Q2d`: save → load →
save is byte-identical, `drift()` is empty after load, and the reference
is intact.

### Q3 Snap to attach point

**Recommendation: re-derive from the snapped point, among every wall whose
stored geometry is under it (an index rect query), and store a canonical
choice.** Do not plumb a feature id.

`Q3a`, all 54 wall end points of the sample plan (nine walls, **fifteen
openings**), each snapped through the real `SpatialIndex.snapInto` (drag
mask, 50 mm aperture) from 5 mm away, then matched two ways: (A) the snap's
root wall only; (B) every wall with a child whose box holds the snapped
point (`forEachInRect`). In both, a (k, side) matches when its computed
point is within `kAttachTolerance` = 1e-5 mm:

```
Q3a origin: 54 points; snap kinds {SnapKind.endpoint: 54}; worst |snapped - computed| 0.0 mm
  (A) chain only: {a coincident point, not canonical: 3, same (wall, k, side): 42, a coincident point, canonical: 9}
  (B) index rect: {same (wall, k, side): 42, a coincident point, canonical: 12}
Q3a corpus far origin, 23 deg, own groups: … worst |snapped - computed| 1.877140660839749e-9 mm
  (A) chain only: {same (wall, k, side): 40, a coincident point, not canonical: 7, a coincident point, canonical: 7}
  (B) index rect: {same (wall, k, side): 42, a coincident point, canonical: 12}
Q3a +1e9 mm (1e6 m), 23 deg, own groups: … worst |snapped - computed| 4.2981520598697533e-7 mm
  (A) chain only: {a coincident point, not canonical: 7, same (wall, k, side): 42, a coincident point, canonical: 5}
  (B) index rect: {same (wall, k, side): 42, a coincident point, canonical: 12}
```

The snapped point is the stored local ring mapped back to world, and the
computed corner is world. They differ by rounding only: 4.3e-7 mm at
+1e9 mm, well inside 1e-5 (M-attach-tol at 1e-9 is red). The 12
"coincident, canonical" rows are the higher-handle wall's three points at
each of the four exterior L corners, which the rule stores on the
lower-handle wall.

**Coincident points (an L corner): which wall is stored, and does it
matter?** Which entity the snap reports depends on sub-ulp distances and
the higher-root-handle tie-break, so (A) stores a non-canonical wall 3 to
7 times in 54, differently at each placement. The spike's rule (`attachAt`)
picks among every match: a face point before a centre point, then the
lowest wall handle, then k, then left before right. So (B) is canonical 54
of 54 (M-attach-nearest, which takes the nearest instead, is red). **It
matters later, not now:** `Q3e` stores the L's inner corner once as
A/1/left and once as B/0/left. Both read `3900`. B then moved 500 mm off
A's end breaks the joint, and the two read `4000` and `4401` (A's free
corner (4000, 100) against B's (4400, 0): √(4400² + 100²) = 4401.1).
Deleting B deletes only the one stored on B.

**A snap on a vertex that is not one of the six:**

- **an opening's jamb** (a piece vertex): `Q3b`, the front door's jamb
  (18000, 8250). An entity of the door wins the snap there (`root 90 (not
  a wall)`). Fixed under (A) and (B);
- **the Y's lobe vertex** on the owner's ring (`Q3d`, handles in the
  prints: roots decimal, ends hex). Chain-only from the owner A is wrong,
  from B or C right: `root 18: fixed`, `root 22: 16/0/left`, `root 26:
  1A/0/right`; the snap reported C (`snap reported 26`), and (B) gives the
  canonical `16/0/left`;
- **a T's butt corner** is the stem's S/0/left, not a through-wall vertex:
  `root C: fixed; root S: 16/0/left; (B): 16/0/left`;
- **an X crossing** has no vertex, and the engine's intersection snap only
  considers root-level entities (`_considerIntersections`), never a group's
  children: `Q3c X crossing: snap none`. The click is a raw or grid point,
  fixed.

**Why not a feature id through the snap.** A ring vertex index is not an
identity (Q1: `free 3 of 4, in the Y 4 of 5`), a wall with openings has
several regions, and turning a vertex into (k, side) needs the caps
anyway. The id would add a field on the zero-allocation snap path and still
need the re-derivation.

**Cost of (B)** per click on the sample plan: `Q3g (B) per click, 9 walls,
15 openings: 60.93 us (JIT)`. That includes rebuilding every world wall
and each candidate's six points among all walls. A hover marker per
pointer move would want the candidates' neighbours from the index rather
than all walls.

**Plumbing.** The tool needs the snapped point and whether an object snap
won, which it already has (`DragPoint`), plus the index for (B). Since (B)
re-derives from the point, **it does not need the snapped entity at all**.
If the spec prefers (A), `PlacementTool` must expose the hit (a protected
getter on its scratch, or `DragPoint` carrying the entity), and the root
group is `entities.ownerAt(entity)`, not `chain[0]`.

### Q4 Linear dimensions under rotation, and the offset

**Proposed representation** (as spiked):

- the dimension is a root-level group whose transform is the select
  tool's (identity when placed; move and rotate compose into it, as for
  every group);
- a **fixed** end is a point in the group's local space, so it moves and
  rotates with the group (decision 12);
- an **attached** end is (wall, k, side) and is read from the wall in
  world; the group's transform never touches it;
- a linear dimension's **axis is the group's local x (horizontal) or local
  y (vertical)**, taken to world, so it is world x or y until the
  dimension is rotated;
- the **offset** is a signed local length (world = offset × the group's
  scale) along the measuring direction's left normal `n = perp(u)`. It is
  measured from the **outermost** measured point on the line's side:
  `c = max(s0, s1) + offset` for offset ≥ 0, `min(s0, s1) + offset`
  below. So an extension line never runs back through the geometry,
  whichever point a wall edit moves;
- children are computed in world, relative to the first point (the local
  frame), and taken to the group's local space, as the room does.

Tests (`rotate_test`, placements origin, the corpus turned 23° and +1e9 mm
in own groups; the dimension groups sit at the placement):

- `Q4a` fixed (0,0) and (3000,1200), rotated 30° about a far pivot: the
  horizontal dimension still reads `3000` and the aligned one `3231`
  (√(3000² + 1200²) = 3231.1); the line and the text now run at the
  placement's angle + 30° (`line at 53.000000000 deg` at 23°);
- `Q4b` one attached end (A/1/left (4000,100)) and one fixed end (4000,
  3100): `3000`. Moved (700, 0): the fixed end moves, the attached one does
  not: `3081` (√(700² + 3000²) = 3080.58). Rotated 37° about (0,0): the fixed
  end goes to (4700c − 3100s, 4700s + 3100c) = (1887.96, 5304.30), and
  √(2112.04² + 5204.30²) = 5616.53: `5617`. The attached end is within
  1e-6 of (4000, 100);
- `Q4c` walls and dimensions rotated together by 30° (one compound, as the
  select tool): horizontal `4100`, vertical `3100` and aligned `3764`
  (√(2900² + 2400²) = 3764.3), all unchanged. The horizontal line is still
  800 from A/0/right;
- `Q4d` a horizontal dimension from A/0/right (0,−100) to a fixed (5000,
  −2000), offset −500: the line at −2500, 2400 below the wall end point and
  500 below the fixed one. A thickened to 4400 (right face y = −2200) puts
  the line 500 below the face and 700 below the fixed point.

**What a 30° rotation does to a "horizontal" dimension:** with local axes
it turns with the dimension. A fixed-fixed one keeps its value, since it
is a rigid rotation. Rotated **alone** with both ends attached (`Q4e`),
its ends stay and its axis turns: `4000` → `3464` (4000 cos 30° =
3464.1). With world axes (M-axis-world), `Q4a` reads `1998` at the origin
(3000 cos 30° − 1200 sin 30° = 1998.1) and `2293` turned 23°. `Q4c`, the
whole plan rotated, would change every linear value. **Recommend local
axes:** rotating the whole drawing then keeps every value. The panel's
"Horizontal" then means "along the dimension's own x"; the spec must say
whether it shows the angle, and whether rotating a linear dimension alone
is allowed.

### Q5 Engine feasibility

**The type works end to end on the real `ParametricSystem` with no engine
change** (`Q5a`, the corpus in own groups):

- children in handle order `line, line, line, line, line, text`: the
  dimension line, two extension lines, two slashes, the value. The five
  lines at lineweight 0.30 mm (see Q6), the text bottom-centre justified,
  ByLayer;
- `reach` empty (nobody's neighbour), `references` its attached walls,
  default policy cascade, `pageKey` = (unit, scale denominator);
- text height 2.5 paper mm × the scale (125 mm at 1:50), 1 paper mm above
  the line's middle (the text at (2000, 750) for a line at y = 700);
- 1:50 m → 1:100 ft-in in one `SetComponentCommand<PageComponent>`: one
  undo step, the text `13'-1 1/2"` (4000 mm = 157.48" → 157.5", to the
  quarter) at height 250, the same child handles; undo restores `4000` and
  125. M-page (page key null) is red.

**Decision 7's format** (`Q5b`): `3450`, `345.0` (cm, the trailing zero
kept), `3.45`, `136 3/8` (in, no mark), `136 1/2` (reduced), `11'-4 1/4"`,
`12'-0"`.

**Round-half-up at an exact .5.** `roundHalfUp(mm, quantum)` counts
quanta from mm with the quantum in mm (1, 1, 10, 3.175, 6.35), and treats
a value within `kHalfTolerance` = 1e-6 mm of `(n + 0.5) · quantum` as the
half, rounding it up. The naive rule (convert, scale, `round()`) gets
these wrong (`Q5c`):

```
1005 mm in m: 1005.0 mm -> naive 100, half-up 101, want 101
3/16": 4.762499999999999 mm -> naive 1, half-up 2, want 2
3/8": 9.524999999999999 mm -> naive 1, half-up 2, want 2
hypot(18.9, 25.2): 31.499999999999996 mm -> naive 31, half-up 32, want 32
far-origin hypot(0.3, 0.4): 0.4999999998882413 mm -> naive 0, half-up 1, want 1
3450.5 - 2e-6: 3450.499998 mm -> naive 3450, half-up 3450, want 3450
```

Through the real object (`Q5d`), a free wall 3450.5 long, face to face:

```
Q5d origin: measured 3450.5, naive 3451, text 3451
Q5d corpus far origin, 23 deg, own groups: measured 3450.5000000000186, naive 3451, text 3451
Q5d +1e9 mm (1e6 m), 23 deg, own groups: measured 3450.499999984674, naive 3450, text 3451
```

An imperial half can never be exact: 1/16" is 1.5875 mm, which has no
double. Metric metres fail naively through the conversion (1.005 × 100).
Every aligned or rotated measurement is a few ulps off wherever it should
land. **Exact rational arithmetic on the stored double does not help**:
it would decide the imperial halves the way the naive rule does. A
tolerance is the only rule that rounds what the user drew. M-11e
(truncate) is red everywhere, even on whole values: `Expected: '3900'
Actual: '3899'` at the far origin.

**Decision 8, readable, the flip at exactly vertical** (`Q5e`, `Q5f`):
`readable(u)` reverses `u` when `u.x < −1e-9`, or when `|u.x| ≤ 1e-9` and
`u.y < 0`. Text angles land in (−90°, 90°], and exactly vertical reads
upwards (+90°, from the right). A group turned −90° gives `u = (6.1e-17,
−1)`. Without the tolerance (M-flip-tol) that does not flip and reads from
the left: `Expected … 90 Actual: <-90.0>`.

**Engine changes 11 needs: none for the dimension object.**
`Generated(EntityKind.line, …, lineweight:)`, `Generated.text`,
`view.page`, `pageKey`, `references` and `cascade` are all on `main`.
What 11 does need, outside the engine proper:

- the render layer: sub-pixel axis-aligned lines vanish (Q6);
- the tool: either nothing (Q3's (B) re-derives from `DragPoint`'s point
  and the index) or a protected accessor for `PlacementTool`'s snap
  scratch (for (A));
- optionally, intersection snaps between groups' children. Today an X
  crossing of two walls' faces gives no snap (`Q3c`); that end would be
  fixed anyway, but the user gets no marker there.

### Q6 Renders

Kept images ([2026-09-28-dimensions-spike/](2026-09-28-dimensions-spike/)):
decision 15's set on the sample plan: overall width (E1's outer face,
`14.00`) and depth (E2's, `9.00`), Hall (`4.69`) and Kitchen (`4.38`)
corner to corner, and the Bath diagonal, aligned, from E2/0/left to a
fixed point (`5.27`, √(4190² + 3190²) = 5266.1 mm):

- `r1_sample_dims_1_50.png`, `r1_sample_dims_1_100.png`: the whole plan at
  0.052 px/mm, page 1:50 and 1:100;
- `r2_hall_zoom_1_50.png`, `r2_hall_zoom_1_100.png`: the Hall dimension,
  the overall width's left end and the Hall/Kitchen slashes at P1, at
  0.15 px/mm; `r2c_hall_zoom_x2_1_50.png` the same at 0.3 px/mm;
- `r3_far_origin_23deg_camera_turned.png`, `r3_far_origin_zoom.png`: the
  sample walls and openings at the corpus far origin, turned 23°, every
  wall in its own group, with the same dimensions (their groups at the
  placement). The camera is turned back −23° in the first and not in the
  second;
- `r0_lineweight_018_lines_lost.png`: the first zoom at 0.18 mm: only the
  slashes show.

**Slash, text and gap read at both scales**, by pixel probes (`R2`, `R2c`;
world mm):

```
R2 1:50: text ink 55..230 mm above the line (want 50..228.6); extension line ink 80..1300 mm below the corner (want 75..1300); slash probe ink
R2c 1:50 at 0.3 px/mm: text ink 49..227 mm
R2 1:100: text ink 100..455 mm above the line (want 100..457.1); extension line ink 155..1400 mm below the corner (want 150..1400); slash probe ink
R2c 1:100 at 0.3 px/mm: text ink 102..458 mm
```

The text's box is the test font's em: cap height h / 0.7 (DXF), so 50 to
228.6 mm at 1:50. It is the same height in world mm at 0.15 and 0.3 px/mm,
so it follows the paper, not the camera. It doubles at 1:100. The
extension line's gap is 1.5 paper mm (75 mm, then 150 mm) and its
overshoot 2 paper mm past the line at 1,200 mm.

**Findings from the renders:**

1. **Every horizontal and vertical dimension line vanished at 0.18 mm**
   (`r0`). A 0.18 mm lineweight is 0.68 logical px at `kLogicalPixelsPerMm`,
   and the vertices sink draws a one-pixel quad. When that quad is exactly
   axis-aligned and falls between pixel centres, the test rasteriser paints
   nothing. This is 10's finding 4 again, and dimensions are mostly
   axis-aligned. The spike uses 0.30 mm (more than one pixel wide always
   covers a row of centres). M-lw18 is red: `extension line ink
   1200..1200 mm` (only where the dimension line crosses). Not checked on
   a device.
2. **Interior corner-to-corner extension lines lie on the perpendicular
   walls' faces** (the Hall's at x = 12,250 and 16,940), so they draw along
   the band's edge and cannot be seen. That is inherent, and harmless.
3. **Two dimensions meeting across a partition cross their slashes**
   (Hall and Kitchen at P1, 120 mm apart; at 1:100 the 300 mm slashes
   overlap: `r2_hall_zoom_1_100`).
4. **Dimension text collides with room labels** at 1:100 (`r1…_1_100`:
   the Kitchen's `4.38` on the Kitchen's name, the Bath diagonal's text on
   the Bath's). Both are auto-placed; the offset grip is the only remedy.
5. A near-vertical dimension's text changes side of its line as the plan
   turns through vertical. At 23° the overall depth's axis is (−sin 23°,
   cos 23°), `u.x < 0`, so `readable` reverses it and "above" becomes the
   outside of the plan: in `r3` its text is not on the inner side as in
   `r1`, and by that arithmetic it falls beyond the canvas edge, under the
   panel. This is decision 8 working, and it looks like a jump.

## Findings nobody asked about

1. `SnapResult.chain` is the instance path; a group's child has
   `chainLength` 0 (Q3).
2. Intersection snaps never involve a group's children (Q3c).
3. The snap's choice among coincident endpoints is not stable across
   placements (Q3a (A): 3, 7 and 7 non-canonical in 54).
4. A select-tool move of a through wall breaks its T (Q2b). A dimension on
   the stem follows the stem's new square end; 07 behaviour, not a
   dimension decision.
5. A dimension's stored offset is model millimetres, so it does not
   follow a page-scale change, while its text, slashes and gaps do (`r1`
   at 1:100: the overall dimensions sit 1,200 mm out at both scales).

## Open decisions for 11's spec

Options cheapest first where there are several.

1. **Centre point:** the raw centreline end (as spiked; a T's is inside
   the through wall's band), or the cap's midpoint.
2. **Which (wall, k, side) a click on a shared point stores:** the
   canonical rule (face before centre, lowest handle, k, left first; as
   spiked), or the snapped entity's wall. Either way, which one was stored
   shows only when the joint breaks or a wall is deleted (Q3e).
3. **How the tool identifies the point:** (B) re-derive among the walls
   under the point via the index (as spiked; no API change), (A) the
   snapped entity's wall (needs `PlacementTool` to expose its hit; wrong at
   a Y's lobe vertex), or a feature id (not recommended).
4. **The attach tolerance:** 1e-5 mm as spiked (worst measured 4.3e-7 at
   +1e9 mm).
5. **Linear axes:** the group's local frame (as spiked) or world; what the
   panel shows after a rotation; whether a linear dimension may be rotated
   alone (Q4e changes its value).
6. **The offset:** from the outermost measured point (as spiked), from the
   first point, or from the midpoint; its sign convention (the measuring
   direction's left normal); model or paper units (finding 5).
7. **Half-up:** `kHalfTolerance` 1e-6 mm as spiked; the cm trailing zero
   (`345.0` as spiked); fraction reduction (as spiked); inches with no
   mark and feet-inches with `'` and `"` (as spiked), or both bare.
8. **The flip boundary:** `|u.x| ≤ 1e-9` counts as vertical, and
   vertical reads upwards (as spiked).
9. **Paper constants:** text 2.5, text gap 1, slash 3, extension gap 1.5,
   overshoot 2, default offset 10 mm, all placeholders.
10. **Lineweight and the render layer:** 0.30 mm (as spiked), or fix
    the vertices sink's sub-pixel axis-aligned quads and use a thinner
    weight.
11. **Degenerate cases:** a degenerate wall's six points collapse to its
    centreline end (as spiked); an aligned dimension whose points
    coincide measures along the local x (as spiked); which diagnostics
    (`dimension.degenerate`?) report them.
12. **07's second fallback:** when `localOutlineOf` replaces a wall's ring
    by its local free rectangle, `capsOf` (world) still gives the joined
    corners, so the dimension and the drawn corner differ, and a snap on
    the drawn corner matches nothing (fixed). Share the stored decision,
    or accept (rare: 07's final review I1).
13. **Collisions:** slashes across a partition, text over room labels
    (Q6 findings 3, 4): accept (the offset grip moves them), or shorten or
    offset automatically.
14. **Dimension groups and the select tool:** the spike moves them with
    `TransformNodeCommand`, as the select tool does. Whether a dimension is
    movable like a box, and not immovable like an opening (08 D16), was
    not tried through the real tool.
15. **Option (b) of Q2:** not recommended. The spec should state the
    invariant that makes (a) sufficient: a dimension reads only its
    referents and their one-hop wall neighbours.

## Mutants fired

Each by the scratch driver: copy the file to a backup in the scratchpad,
apply the edit, run `CI=true flutter test --no-pub test/spike_dims`,
restore with `cp`, then `diff` against the backup and `git diff --quiet`
against the commit: **0 and 0 for all 22 runs**. No run had a compilation
error. The result is the runner's last line.

| Mutant | What it breaks | Result |
|---|---|---|
| M-nbrs | the neighbours ignored (`capsOf(w, const [])`), which is also the raw face end instead of the cleaned corner | red, `+24 -21` |
| M-swap | the k = 1 swap of outgoing sides dropped (left/right swapped at ends) | red, `+23 -22` |
| M-swap-just | left and right swapped for right-justified walls | red, `+39 -6` (Q1 at every placement) |
| M-fallback | 07's short-wall fallback ignored (the joined caps used anyway) | red, `+38 -7` |
| M-centre-mid | centre = the cap's midpoint | red, `+39 -6` |
| M-closure | engine: referrers of the seeds only (08's brief rule) | red, `+38 -7`: Q2a ×3, Q2b, Q2c, Q2e (a) (`step 7 (add): drift [82, 89]`), Q3e; **Q2e (b) green** |
| M-refs | the dimension references nothing | red, `+36 -9` |
| M-text | engine: a matched TEXT's string never rewritten (the value cached, M-11c's effect) | red, `+32 -13` |
| M-attach-nearest | the nearest match instead of the canonical rule | red, `+43 -2`: Q3a at both far placements (`Expected: 12/0/centre Actual: 1E/1/centre`) |
| M-attach-tol | attach tolerance 1e-9 | red, `+43 -2` (`Expected: 12/0/left Actual: <null>`) |
| M-axis-world | linear axes in world, not the group's frame | red, `+36 -9`: Q4a (`['1998', '3231']`, `['2293', '3231']`), Q4c, Q4e, the fuzz, R3 |
| M-offset-p0 | the offset from the first point, not the outermost | red, `+44 -1`: Q4d |
| M-fixed-world | fixed ends ignore the group transform | red, `+33 -12` |
| M-attached-moves | attached ends moved by the group transform | red, `+36 -9` |
| M-11a | aligned computed as the axis-projected distance | red, `+29 -16` |
| M-11d | the reference by handle only (k ignored) | red, `+28 -17` |
| M-11e | truncate instead of half-up | red, `+30 -15` |
| M-half-naive | half-up without the tolerance (`round()` only) | red, `+42 -3`: Q5b (`'0 1/8'`), Q5c, Q5d |
| M-flip-tol | no tolerance at exactly vertical | red, `+43 -2`: Q5e, Q5f |
| M-page-height | text height not scaled by the page (M-11b's page half) | red, `+43 -2`: Q5a, R1 |
| M-page | no page key | red, `+44 -1`: Q5a |
| M-lw18 | lineweight 0.18 mm | red, `+44 -1`: R1 |

**M-11b as the roadmap states it (text scaled with the camera) cannot be
written**: `generate` never sees the camera. `R2c` measures the rendered
text at two camera scales, the same height in world mm, and M-page-height
covers the page half.

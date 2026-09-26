# Sub-project 10 spike: findings

**Date:** 2026-09-26.
**Branch:** `spike/10-rooms`, cut from `origin/main` at `418d4c7`.
**Status:** throwaway. The branch is never merged; this note is its only
output. It is an input to 10's spec, not a design.
**Where it ran:** a Linux x86_64 cloud container, the workspace's Flutter
and Dart (`/root/flutter/bin`), not the human's macOS machine. No test pins
a hash of rotated geometry: every comparison of stored bytes is between two
states of one document built in the same run. Timings are JIT, in this
container, and only indicative.

Every number below is quoted from a run made on this branch. Unless a line
says otherwise, it comes from
`cd apps/floor_planner && CI=true flutter test --no-pub test/spike_rooms`
(`00:03 +79: All tests passed!`). The mutants were fired by a scratch
driver that ran the same command once per mutant.

## The decisions the spike worked under

The human's brainstorm decisions of 2026-09-26, as the spike read them:

| # | Decision |
|---|---|
| 1 | A Room tool click stores a seed and references the bounding walls; each rebuild re-traces from the seed among those walls "and their neighbours"; a new splitting wall needs a re-click |
| 2 | Net floor area: the inner wall faces, from the walls' parameters (uncut faces), per-wall thickness |
| 3, 4 | A label and a light translucent tint on the ring; ascending-handle draw order kept; the tint is never pickable; a room is selected by its label |
| 5 | The label at the ring's pole of inaccessibility (grip offset: not spiked) |
| 6, 7 | Area unit and label heights follow the page (m² for mm/cm/m, ft² for in/ft-in, two decimals; paper heights × the scale denominator) |
| 9 | Deleting a bounding wall deletes the room in the same step (cascade) |
| 10 | A ring that breaks deletes the room in the same step ("dissolve") |
| 11, 17 | A separator: a free two-point line the tracer treats as a zero-thickness wall, joined where an end lies on a face; dashed |
| 12, 13 | Freestanding walls inside the ring, captured at click, are holes; an island's deletion orphans (the room stays) |
| 16 | The sample plan gets six rooms, a separator splitting Living from Dining, and a column in Living |

## What was built

- **The tracer**, `apps/floor_planner/lib/parametric/room_trace.dart` (434
  lines): `traceRoom(seed, inputs)`, a planar arrangement of the walls'
  uncut outline edges and the separators' segments, walked as half-edge
  faces (Q1).
- **The label point**, `room_label.dart` (105 lines):
  `poleOfInaccessibility` (polylabel's quadtree search) and `centroid`.
- **The room**, `room.dart` (421 lines): `RoomParams(seed, bounds,
  islands, name)`, `RoomType` (empty reach, references = bounds +
  islands, per-reference policy, dissolve verdict, reads the page), its
  generate (one tint region, two TEXT labels), `roomAt` (the Room tool's
  click over every wall of the document), `keyhole` (the tint's holes).
- **The separator**, `separator.dart` (91 lines): `SeparatorParams`, a
  dashed `SeparatorType`, and a DASHED linetype put straight into the
  tables.
- **The engine prototypes** (`packages/jet_cad_2d`, +156 −36):
  `parametric_system.dart` (+86 −16), `regeneration.dart` (+62 −20),
  `query_filter.dart` (+5), `style.dart` (+3). All listed under Q5.
- **Tests**, `apps/floor_planner/test/spike_rooms/`: `trace_test.dart`
  (Q1, Q2), `rebuild_test.dart` (Q3, Q5), `label_test.dart` (Q4),
  `render_test.dart` (Q6), `support.dart` (fixtures and placements). 79
  tests.
- **Renders**, made by the floor planner shell inside `flutter_test`
  (`RenderRepaintBoundary.toImage`), as 08's spike did. The camera maps
  world y down the screen, so the images are mirrored top to bottom. The
  test font draws every glyph as a box, so labels show as black (white on
  Blueprint) blocks. Kept images:
  [2026-09-26-rooms-spike/](2026-09-26-rooms-spike/).

### Suites on the spike branch

Quoted from the final runs on the last code commit:

- app (`cd apps/floor_planner && CI=true flutter test --no-pub`):
  `00:53 +323: All tests passed!`. That is `main`'s 244 (`+244: All tests passed!` in this
  container before any change) plus the 79 spike tests;
- engine (`cd packages/jet_cad_2d && CI=true dart test`): `00:13 +1014 -2: Some tests failed.`.
  The two failures are the standing Linux hash tests
  (`generate_document_test.dart`: `the default document is the one Plan 2
  measured, byte for byte` and `both text fractions default to zero and
  change nothing`), as STATUS records for `main` (1,014 + 2 standing);
- render layer (`cd packages/jet_cad_2d_flutter && CI=true flutter test
  --no-pub`): `00:53 +936 ~1 -7: Some tests failed.`, the seven standing
  goldens (`text_ladder` rungs 1–5, `text_lod_ladder` rungs 1–2, confirmed
  by `flutter test --no-pub test/golden`), as STATUS records for `main`
  (936 + 1 skip + 7 standing);
- `flutter analyze` (app) and `dart analyze` (engine): `No issues found!`;
  `dart format --output=none --set-exit-if-changed` on what the spike
  touched: exit 0.

## The fixtures

Plans are written in plan millimetres and placed six ways
(`support.dart`): at the origin; at the corpus's far origin (4,500,000,
1,200,000) turned 23°; the same with **every wall and separator in its own
rotated, translated group**; at +1e9 mm (1e6 m) on both axes, turned 23°;
the same unturned; and the same turned, in own groups. Every expected
area is written out by hand in the test, next to the assertion.

- the real sample plan (`startupPlan`: nine walls, **fifteen openings**,
  furniture, finishes);
- the sample plan's nine walls rebuilt from `startup_plan.dart`'s numbers;
- decision 16: those walls, the column (one 400 × 400 wall) and the
  Living | Dining separator;
- an L of six 200 mm walls **drawn in mixed directions** (three
  anticlockwise, three clockwise), and the same L with a door, a window
  and a gap cut into three of its walls;
- a rectangle of four walls of **four thicknesses** (300, 100, 200, 250);
- two rooms sharing a 100 mm partition, T-joined at both ends;
- a box split by a separator, a **hollow** column (four mitred 100 mm
  walls) in one half; and a thin L (arms 1,000 clear) for the label.

## Answers

### Q1 The tracer algorithm

**Chosen: (a), a planar arrangement walked as half-edge faces.**

1. Every wall contributes 07's **uncut** world outline, `outline(wall,
   wall neighbours)` from its stored parameters: never its stored rings
   and never 08's pieces, so a doorway never opens a room. A separator
   contributes its segment.
2. Everything is taken relative to the seed first (the local frame).
3. Each segment is split at every other segment's endpoint lying within
   `roomJoin` (1e-6 mm, 07's `wallJoin.linear`) of it, and at every proper
   crossing. That is what splits a through wall's face at a T butt, and
   what joins a separator's end to a face.
4. Vertices within `roomJoin` of an earlier one are that one; duplicate
   edges (a collinear overlap) merge, keeping every source.
5. Half-edges around each vertex are sorted by angle; `next(u → v)` is the
   edge leaving `v` just clockwise of `v → u`, so every face lies left of
   its walk and bounded faces walk anticlockwise.
6. The room's outer ring is the anticlockwise cycle of **least** area that
   holds the seed; none means the seed's face is unbounded.
7. Holes: every other connected component whose outer contour (its most
   negative cycle) lies inside that ring and inside no bounded face of a
   third component (an island inside an island's courtyard is not a hole).
8. Spikes (`u → v → u`, a separator's free end) and collinear vertices are
   removed; areas are the shoelace in the local frame.

Why the seed's face is the right region: no outline edge crosses the
component of the plane outside every wall that holds the seed, and no path
leaves that component without crossing an edge. So the arrangement's face
**is** the union's hole, and the arrangement never computes the union.

**(b), union of the wall outlines, then the hole holding the seed**, was
compared on paper, not built:

- it needs a polygon-boolean library (none is in the workspace; it would
  be a new dependency) run on exactly its weakest input: many outlines
  sharing collinear edges and touching at vertices (every mitre and T
  butt);
- **separators do not fit it.** A zero-area segment is lost in a union.
  Fattened into a thin rectangle it costs its width × its length in area
  (1 mm × 5,190 mm = 5,190 mm² for decision 16's separator, 0.005 m², at
  the edge of a two-decimal label). Kept as a line it has to split the
  hole afterwards, which is the arrangement again;
- islands come free in both.

(c), a cycle search on a stored wall graph (the roadmap's decision 2), has
no graph to run on (07 D4 derives joints per generate), and centreline
cycles are not the inner faces when thicknesses differ.

**Cost per call.** O(s²) segment pairs with a bounding-box reject, then
O(e log e) to sort half-edges and O(c·v) for the seed's point-in-polygon
tests; s is the segment count of the traced set. On the whole sample plan
(`Q1 cost`):

```
Q1 cost, all nine walls: 9 inputs, 36 segments, 94 pairs past the box test, 134.115 us per trace (JIT, 200 runs)
Q1 cost, the nine outlines (07 outline among all walls): 43.195 us
```

A rebuild traces only the room's references (Q3), a handful of walls. The
Room tool's click over every wall of a 500-wall plan is where O(s²) would
bite; the spike's `roomAt` does exactly that and the spec should give it
the spatial index or a grid.

### Q2 Correctness on the fixtures

**The sample plan's six areas are right**, and their total is 111.30 m².
Hand arithmetic (in `trace_test.dart`): exterior 250 centred, so inner
faces x 12,250..25,750 and y 8,250..16,750; partitions 120, faces ±60
about their centrelines.

| Room | By hand (mm) | Traced (the real plan, 15 openings) |
|---|---|---|
| Hall | (16,940 − 12,250) × (12,940 − 8,250) = 4,690 × 4,690 = 21,996,100 | `21996100.0 mm2 = 22.00 m²` |
| Bedroom 1 | (14,540 − 12,250) × (16,750 − 13,060) = 2,290 × 3,690 = 8,450,100 | `8450100.0 mm2 = 8.45 m²` |
| Bedroom 2 | (16,940 − 14,660) × 3,690 = 2,280 × 3,690 = 8,413,200 | `8413200.0 mm2 = 8.41 m²` |
| Kitchen | (21,440 − 17,060) × (11,440 − 8,250) = 4,380 × 3,190 = 13,972,200 | `13972200.0 mm2 = 13.97 m²` |
| Bath | (25,750 − 21,560) × 3,190 = 4,190 × 3,190 = 13,366,100 | `13366100.0 mm2 = 13.37 m²` |
| Living | (25,750 − 17,060) × (16,750 − 11,560) = 8,690 × 5,190 = 45,101,100 | `45101100.0 mm2 = 45.10 m²` |
| Total | 111,298,800 | `Q2a total: 111298800.0 mm2` |

Each ring has four points (`4 ring points`): the T-butt vertices on the
through walls' faces are split in and then removed as collinear.

The other fixtures, at all six placements (all green):

| Fixture | By hand (mm²) |
|---|---|
| Dining (decision 16) | (21,500 − 17,060) × 5,190 = 4,440 × 5,190 = 23,043,600 |
| Living with the column | 4,250 × 5,190 − 400 × 400 = 22,057,500 − 160,000 = 21,897,500 |
| The L (mixed directions, and with a door, a window and a gap) | 5,800 × 2,800 + 2,800 × 2,000 = 21,840,000 |
| Four thicknesses | (4,950 − 125) × (3,900 − 150) = 4,825 × 3,750 = 18,093,750 (centrelines: 20,000,000) |
| Two rooms sharing a partition | 2,850 × 3,800 = 10,830,000 and 4,850 × 3,800 = 18,430,000 |
| Box and separator | 2,900 × 3,800 = 11,020,000 and 4,900 × 3,800 − 700 × 700 = 18,130,000 (the hollow column's courtyard: 500 × 500 = 250,000) |

Also: a separator drawn **centreline to centreline** (into both walls'
bands) gives the same two rooms as one drawn face to face (`Q2h`): the
crossing splits it inside the band and the rest dangles there. A separator
50 mm short of a face merges the two halves into one room of 7,800 × 3,800
= 29,640,000, both seeds (`Q2i`).

**Far origin and rotation.** Tolerance 1e-2 mm² on every area; observed:

```
Q2 worst area error at origin: 0.0 mm2
Q2 worst area error at corpus far origin, 23 deg: 0.000007413327693939209 mm2
Q2 worst area error at corpus far origin, 23 deg, own groups: 0.000009510666131973267 mm2
Q2 worst area error at +1e9 mm (1e6 m), 23 deg: 0.0008514076471328735 mm2
Q2 worst area error at +1e9 mm (1e6 m), 0 deg: 0.0 mm2
Q2 worst area error at +1e9 mm (1e6 m), 23 deg, own groups: 0.0007169283926486969 mm2
```

07's joints, and the tracer's 1e-6 mm, held at 1e9 mm (one ulp there is
about 1.2e-7 mm). The local frame is what keeps the area right there (M-local
below: 96 and 182 mm² without it).

### Q3 Which walls a rebuild needs

**On every fixture the restricted trace equals the all-walls trace.** For
each of 15 clicked rooms at each of the six placements, the ring traced by
the room's own rebuild matches a trace over every wall and separator of the
document: area within 1e-6 mm², same ring length, every point within
1e-6 mm, same hole count. That holds for all three candidate sets (`Q3a
... 15 rooms, restricted == all walls, all three sets`, six lines):

- **refs**: the referenced bounds and live islands only, each wall's
  outline still 07's among **all** its wall neighbours;
- **refs + neighbours, intruders break**: the same plus every neighbour
  of a bound; an edge from a non-referenced object breaks the ring;
- **neighbours shape** (decision 1 read literally): refs + neighbours, all
  of which shape the ring.

**T splits do not need the neighbours.** A T butt is in the stem's
outline, and the through wall's face is split by the stem's cap points.
When the stem bounds the room it is a reference; when it butts from the
other side it does not touch the ring.

**Counter-examples exist: walls added or moved after the click.** The two
rooms of `twoRoomWalls`, the right room clicked, then (`Q3b`, areas in
mm²):

| Case | All walls | refs | refs + neighbours (break) | neighbours shape |
|---|---|---|---|---|
| c1 a partition drawn face to face (not joined), origin | 12,920,000 | 18,430,000 (stale) | 18,430,000 (not a neighbour) | 18,430,000 |
| c1, corpus 23° | 12,920,000 | 18,430,000 | broken: `2B now bounds the room` | broken: rule 4 |
| c2 a freestanding wall inside, origin | 18,330,000 | 18,430,000 | 18,430,000 | 18,430,000 |
| c2, corpus 23° | 18,330,000 | 18,430,000 | broken | **18,330,000** (a hole) |
| c3 a partition T-joined at both ends, both placements | 12,920,000 | 18,430,000 | broken | broken: rule 4 |
| c4 the room's own partition moved into the west wall's band, both placements | 29,640,000 | **29,830,000** (the ring runs 50 mm into a wall) | broken: `1E now bounds the room` | broken: rule 4 |

Two things follow:

1. **Neighbours make the rule depend on orientation.** `neighbours` is a
   bounding-box overlap of centrelines (07 D10). The same freestanding
   wall inside the same room is a neighbour of the bounds when the plan is
   turned 23° and not when it is axis-aligned (c1, c2).
2. **Neighbours that shape the ring break the closure.** A neighbour's
   outline reads the neighbour's own neighbours, two hops from any
   reference, and 08's closure (referrers of the seeds' one-hop core) does
   not reach them. `Q3e`: a stub T-joined into the box's south wall (a
   neighbour, so under "neighbours shape" it notches the room: `29.50
   m²`), then a wall joining the stub's free end away from every bound:

   ```
   Q3e RoomTraceSet.refs: after Q [Box, 29.64 m²], drift []; after X, label [Box, 29.64 m²], drift [] (room 34)
   Q3e RoomTraceSet.refsAndNeighbours: after Q [], drift []; after X, label [], drift [] (room 34)
   Q3e RoomTraceSet.neighboursShape: after Q [Box, 29.50 m²], drift []; after X, label [Box, 29.50 m²], drift [34] (room 34)
   ```

   With refs only, a room reads its references' parameters and, through
   07's outline, their neighbours': exactly the one hop 08's closure
   covers (`drift()` empty after every edit of every Q3 and Q5 test).

**Proposed rule (the spike's `RoomTraceSet.refs`).** A rebuild traces
from the seed among the room's live bounding walls and separators and its
live islands; each wall's outline is 07's among all its wall neighbours.
**The ring breaks, and the room is deleted in the same edit, when:**

1. the seed lies inside a traced wall's outline or within `roomJoin` of a
   traced segment; or
2. no bounded face holds the seed.

A bound deleted outright is decision 9's cascade, before the trace. Walls
added after the click that touch the room (c1–c4) do not change it:
decision 1's re-click. The spec must decide whether that staleness is
reported (see the open decisions).

**Tested, e2e on `ParametricSystem`, with the dissolve (`Q3c`):**

- *the seed ends outside*: the partition moved into the left seed (x =
  1,500) and past it (x = 1,000): the left room is deleted, the right
  follows (`24.13 m²`: (7,900 − 1,550) × 3,800 = 24,130,000; then `26.03
  m²`: 6,850 × 3,800 = 26,030,000), one undo step, `drift()` empty;
- *the face becomes unbounded*: the west wall shortened by 1,000 at its
  south end: the left room is deleted, the right unchanged (`18.43 m²`);
- *a bounding wall shortened*: the partition's end pulled back 60 mm,
  still inside the south wall's band (07 no longer joins it): both rooms
  survive unchanged (`Q3c shortened 60: [Left, 10.83 m²] [Right, 18.43
  m²]`); pulled back 150 mm (a 50 mm gap): both are deleted;
- *the separator pulled 50 mm short* (decision 16's plan, own groups):
  Dining and Living are both deleted;
- *decision 9*: deleting E4 deletes the Hall in the same step; *decision
  13*: deleting the column keeps Living (`22.06 m²`, the hole gone) and
  `diagnostics()` reports one `parametric.orphan`.

**A rule 4 was tried and dropped:** "every bound carries an edge of the
outer ring". Under refs it only ever fires on a **valid** room: `Q3d`, a
stub wall standing against the box's south face (the room `29.34 m²`:
7,800 × 3,800 − 1,000 × 300) pushed into that wall's band. The all-walls
trace is 29,640,000 (`Q3d ... all walls 29639999.99999495`), right, and
rule 4 deletes the room anyway (`room alive false`). With rule 4 removed
(M-rule4) only that probe goes red. Every other break above is caught by
rules 1 and 2. (The spike's `roomVerdictOf` still carries rule 4 so that
`Q3d` can show it.)

### Q4 The label point

**The pole of inaccessibility lands inside the thin L; the centroid and
the box centre do not.** The thin L's arms are 1,000 clear; its largest
inscribed circle sits in the corner square, touching both outer faces and
the reflex corner: x − 100 = √2 (1,100 − x), x = 685.786, r = 585.786 mm
(by hand, in the test). At 10 mm precision:

```
Q4a origin: pole [683.3984375,683.3984375] d=583.3984375 (245 cells, 9792 us); centroid d=-813.2075471698113; box centre d=-1900.0
Q4a corpus far origin, 23 deg: pole [366.2025766680017,897.6893415111117] d=583.2406497159436 (346 cells, 2307 us); centroid d=-813.2075471697176; box centre d=-1900.0000000001132
Q4a +1e9 mm (1e6 m), 23 deg: pole [366.20257663726807,897.689341545105] d=583.2406497023877 (346 cells, 734 us); centroid d=-813.2075471278121; box centre d=-1900.0000000124905
```

`d` is the signed distance to the region (positive inside). The centroid,
(1,913.2, 1,913.2) by hand, is 813 mm outside. The room object's own
labels land 584.5 and 582.0 mm inside (`Q4e`, the thin L in own groups).

**Away from a column:** the box's pole sits at the box centre (`2.3e-10
from the box centre`); with a 400 × 400 column there, the pole moves to a
point `1849.784178261614 from the boundary, 1849.784178261614 from the
column` (`Q4b`). Across every fixture the pole is inside the region, and
a trace from the pole finds the same room (`Q4d`).

**Cost:** 245 to 418 cells at 10 mm precision; `Q4c Living (ring 4, hole
4): 418 cells, 1113.08 us per call`. The spike's queue is a linear scan
(no heap), so this is an upper bound for the algorithm.

### Q5 Engine feasibility

All prototypes are in `packages/jet_cad_2d/lib/src/parametric/` unless
named.

**The room type** works end to end on the real `ParametricSystem`
(`Q5`): children, in handle order, `fill, polyline, text, text` (`Q5
children (39:fill, 40:polyline, 41:text, 42:text)`); the fill's record
carries `transparency 191` and the unpickable flag; the texts read `Room
1` and `10.83 m²`, centre-middle justified. A wall moved: both rooms'
areas and labels follow (`12.73 m²`, `16.53 m²`), the same child handles,
one undo step, undo restores the saved bytes, redo, save → load → save
byte-identical, `drift()` empty after load. The sample plan's east wall
dragged out 500 mm at its nodes (a four-command compound): Bath `14.96
m²` (4,690 × 3,190), Living `47.70 m²` (9,190 × 5,190), Hall untouched.

**Generated TEXT: the research is confirmed.** At `418d4c7` `Generated`
has no string; `_plan` adds records with `draftRecord(handle, owner, kind,
color:)`, so a generated TEXT is added with `''` and `textAttrs` 0 (left,
baseline), and a matched child only ever gets `SetEntityGeometryCommand`.
A `SetEntityTextCommand` on a generated label is refused by 06 D6 (`Q5 a
direct edit of a generated label is refused`: `GeneratedGeometryError`).
Restoring `main`'s record builder in the prototype (mutant M-text-add)
turns 14 tests red. **The smallest fix, prototyped:**

- `Generated.text(payload, text, {color, textAttrs, flags})`;
- the planner writes the string and every creation-time attribute into
  the added record (`_recordOf`), and on a matched TEXT compares the
  stored string with `==` and emits `SetEntityTextCommand` when it
  differs (M-10f: without it, 5 tests red);
- `textAttrs` is fixed at creation, like the colour (06 D11), so a
  justification change needs a new child (M-attrs: 1 test red).

**The tint's attributes**: `Generated.region` gains `transparency` and
`flags` (both records) and `boundaryFlags`; `Generated` gains `linetype`
and `lineweight`. All written on add only.

**Reading the page, and regenerating on a page change**, prototyped
because it was cheap:

- `ParametricView.page` reads the root's `PageComponent`;
- `ParametricType.readsPage` (default false);
- each survey records the page; in `_run`, when `before.page !=
  after.page` (value equality: a stored value) every live object whose
  type reads the page joins the seeds. Cost: O(objects) and only on an
  edit that changes the page.

`Q5 a page change`: meters → ft-in and 1:50 → 1:100 in one
`SetComponentCommand<PageComponent>`: the label reads `116.57 ft²`
(10,830,000 / 304.8² = 10,830,000 / 92,903.04), the name's height goes
125 → 250 and the area's 100 → 200, one undo step, undo restores `10.83
m²`. M-page: that test red.

**The dissolve verdict (decision 10)**, prototyped:
`ParametricType.dissolves(view, self)` (default false), asked in `_plan`
of each object of the closure with the after-survey's view, before its
`generate`. A dissolving object's removal is planned there:
`_subtreeRemoval` (08's, the select tool's order) and then its component's
detach. The verdict and the generate share one trace per room per view (an
`Expando` memo, as 08's `hostCutsInView`).

- **06 D6:** the removals are planned commands, not `r0.touched`, so the
  guard never sees them; they remove only the room's own children.
- **06 D8:** the cleanup detaches the components of `lost` objects, and
  `lost` is computed before the plan, so a dissolved room is not in it.
  **The dissolve must detach its own component**, or the component
  outlives its node: M-detach, `Expected: null Actual: <Instance of
  'RoomParams'>`.
- **Undo** restores the room's node last among the root's children, as
  08's cascade does: `Q3c undo of a dissolve: save equal false, canonical
  equal true` (the saved bytes are equal once the root's child order is
  normalised; 06's convention).
- `drift()` reports a room that would dissolve (its plan is non-empty),
  so a loaded broken room shows; `diagnose` reports `room.broken`.

**Per-reference policy (decision 13)**, prototyped:
`ParametricType.policyFor(params, referent)`, default the type's
`referencePolicy`. `_cascade`, `_checkDangling` and `_unresolved` ask it
per (referrer, referent). The room: bounds cascade, islands orphan.
M-policy (islands cascade): the island-deletion test red.

**Unpickable (decision 4)**, prototyped: `EntityFlags.unpickable = 1 <<
1` (not DXF), skipped by `FilterEvaluator.acceptsEntity` under the picking
filter (`excludeLocked`). See Q6: it turned out to be redundant with an
invisible boundary.

### Q6 Renders and picks

Kept images (the shell, software rasteriser, mirrored top to bottom):

- `r1_sample_rooms.png` / `r1_sample_no_rooms.png`: decision 16's plan
  with seven rooms (Hall, Bedroom 1, Bedroom 2, Kitchen, Bath, Dining,
  Living), the dashed separator and the column, on white; and without the
  rooms. The tint stops at the uncut inner faces, so every doorway and
  window gap in the wall band stays untinted;
- `r2_dining_kitchen_zoom.png` / `..._no_rooms.png`: the kitchen/dining
  partition's doorway, the sofa and the counter under the tints;
- `r3_living_column_separator.png`: the separator's dashes and the
  column;
- `r4_blueprint_rooms.png`: the same plan on Blueprint.

**The tint does not hide furniture drawn earlier.** Pixels at the same
world points, without and with the rooms:

```
R2 sofa fill: without rooms #e6e1d8, with rooms #bccad3
R2 counter fill: without rooms #e6e1d8, with rooms #bccad3
R2 dining floor, off the parquet joints: without rooms #ffffff, with rooms #cee0f1
```

The sofa and counter keep their own shade, tinted; the floor takes the
tint.

**A click inside a room still picks what it picked before**, except on a
label. Picks through `SpatialIndex.pickInto` (radius 20 mm) and
`resolveHit`:

```
Q6 sofa middle: without rooms 315 (edge) -> 315; with rooms 315 (edge) -> 315
Q6 counter middle: without rooms 584 (fill) -> 584; with rooms 584 (fill) -> 584
Q6 lamp middle: without rooms 588 (fill) -> 588; with rooms 625 (fill) -> 622
Q6 dining floor, 75 mm off a parquet joint: without rooms miss; with rooms miss
Q6 Dining name label: without rooms 588 (fill) -> 588; with rooms 625 (fill) -> 622
Q6 a room's inner face, 5 mm into the room: without rooms 62 (edge) -> 34; with rooms 62 (edge) -> 34
```

(315 is a parquet joint under the sofa's middle, 584 the counter's fill,
62 a wall's edge, owned by wall 34.) **The Dining label lands on the table
and the lamp** (the pole ignores furniture), and a TEXT answers picks with
its box as a `fill` hit, the highest handle winning: a click on the lamp
there selects the Dining room (622 through its name, 625).

**Two mechanisms each make the tint unpickable, and either suffices.** A
region's fill is hit-tested through its boundary polyline (a closed
polyline answers `HitKind.fill`), so an **invisible** boundary alone
already hides the tint from picks. Unpickable flag removed (M-unpick):
all green; boundary visible with the flag kept: all green; **both
removed** (M-unpick2): red, `Expected: '584 (fill) -> 584' Actual: '614
(fill) -> 612'` (the Kitchen room) and the wall-face probe `with rooms 624
(edge) -> 622`.

## Findings nobody asked about

1. **The engine's triangulator refuses an exact keyhole.** A hole joined
   to the ring by a bridge of two coincident edges (duplicate vertices,
   earcut's shape) triangulates to nothing (`Q5 exact keyhole: 0
   triangles`), so the region is refused and the edit rolled back (M-slit:
   12 tests red). The spike moves the return edge 0.5 mm to the bridge's
   right: a simple ring, `Q5 Living tint: 11 stored points, 8 triangles`.
   The tint is then 0.5 mm × the bridge short of the true region; the
   label's area comes from the trace, not the tint.
2. **A region's boundary is stroked**, so the tint drew the slit as a
   diagonal line and drew over the separator's dashes (seen in the first
   renders). The spike makes the tint's boundary invisible
   (`EntityFlags.invisible`); the fill still draws (the painter reads the
   boundary's geometry, not its visibility).
3. **Dash patterns are model units in the painter**, not paper units as
   `DashPattern`'s comment says: `_dashScale` is the entity's and the
   header's linetype scale times world-to-screen. A `[6, −4]` pattern
   drew 1.2 px dashes at 0.2 px/mm. The spike uses `[200, −100]` model mm
   (4 mm and 2 mm on paper at 1:50), which does not follow the page scale.
4. **An exactly axis-aligned default-weight line can vanish in the test
   rasteriser.** The separator, a vertical 2-point polyline, painted no
   pixel dashed at 0.058 and 0.2 px/mm, nor continuous at 0.2 px/mm; a
   root-level vertical LINE and 2-point POLYLINE added by the drafting
   path painted none at 0.058 px/mm either, while one tilted by 10 mm over
   4 m did (scratch probes, not kept). The index returns them
   (`forEachInRect` saw both). The same happens to the Living parquet at
   0.2 px/mm (`r3`). The spike gives the separator a 0.35 mm lineweight
   (`Generated.lineweight`), which draws. Not checked on a device; it
   looks like a hairline falling between pixel centres without
   anti-aliasing, a question for the render layer, not for rooms.
5. **On Blueprint the tint all but disappears** (`r4`): a fixed blue at
   25% on a dark blue page. A generated child's colour is fixed at
   creation (06 D11), so it cannot follow the paper.
6. **A room label is a pick target over furniture** (Q6's lamp).
7. **The Room tool's click traces over every wall** of the document
   (`roomAt`), O(S²) in the plan's segment count.
8. **Undo of a dissolve reorders the root's children**, as 08's cascade
   does (Q5).
9. **The tracer is robust to a separator drawn into the walls' bands**
   (`Q2h`), so decision 17's "an end on a face" can be a snap preference
   rather than a precondition.

## Open decisions for 10's spec

Options cheapest first where there are several.

1. **Which objects a rebuild traces** (Q3).
   1. The references only (the spike's rule): orientation-independent,
      closed under 08's closure; walls added later that touch the room are
      ignored until a re-click (c1–c4), and c4 leaves the ring 50 mm
      inside a wall.
   2. References plus neighbours, an intruding neighbour breaking the
      ring: catches c3 and c4 always, c1 and c2 only when the plan is not
      axis-aligned.
   3. References plus neighbours shaping the ring (decision 1 literally):
      same orientation dependence, and a two-hop read the closure misses
      (`Q3e`: `drift [34]`); needs a wider closure.
2. **Stale rooms under option 1.1.** Report them or not: a
   `room.stale` diagnostic from `diagnostics()` comparing the rebuild's
   trace with a trace over every wall (off the edit path; O(all walls)
   per room), or nothing.
3. **The ring-breaks rule's wording**: rules 1 and 2 as proposed; drop
   rule 4 (it deletes valid rooms, `Q3d`).
4. **Islands moved** (decision 13's spec detail). As spiked: an island
   moved to touch the outer ring becomes part of it (it is a reference,
   so the ring stays valid); an island moved outside is ignored silently.
   Report either, or not. `generate` cannot drop it from the parameters.
5. **The tint's holes.**
   1. The slit keyhole as spiked (0.5 mm; a constant to choose);
   2. teach the triangulator a bridge of coincident edges (earcut's
      duplicate-vertex handling);
   3. one region per hole-free piece;
   4. no holes in the tint (the area still subtracts them).
6. **The tint's boundary**: invisible (as spiked), or a
   `Generated.region` option that generates the fill's boundary without
   drawing it.
7. **Unpickable**: the invisible boundary alone (no new flag), or the
   `unpickable` bit too (not DXF: it must be dropped on export), or a
   locked room layer (tables have no command, so no undo).
8. **The label over furniture** (Q6): accept, since the label grip
   (decision 5) moves it; or make a TEXT pick only on its glyphs; or keep
   the room below furniture in pick order.
9. **The tint colour on dark paper**: a colour for both papers, or ByLayer
   on a room layer, or let the planner rewrite a generated record's
   colour.
10. **The separator's look**: how the DASHED linetype enters a document's
    tables (no command, a reserved handle in the spike), whether its
    pattern follows the page scale (model units today), and its
    lineweight.
11. **`Generated`'s attribute surface**: which record attributes a client
    may set on add (the spike: transparency, flags, boundary flags,
    linetype, lineweight, TEXT string, `textAttrs`), and which the planner
    rewrites on a match (the spike: the TEXT string only).
12. **Page reads**: a `readsPage` flag (as spiked), or a general
    "document-level components this type reads" declaration.
13. **The dissolve's place and shape**: in `_plan`, before `generate`, with
    its own detach (as spiked), or a pass between the after-survey and the
    plan; and whether undo's root reorder needs normalising (08
    precedent: accepted).
14. **The per-reference policy API**: `policyFor(params, referent)` (as
    spiked), or two declared reference lists.
15. **The Room tool's click cost** (finding 7): the spatial index or a grid
    around the seed.
16. **The seed**: stored where clicked (as spiked). A wall moved onto it
    dissolves the room (Q3c); re-seeding at the pole would need `generate`
    to write parameters, which it cannot.
17. **The dash-pattern units and the axis-aligned hairline** (findings 3,
    4) belong to the render layer, not to 10, but 10's separator is the
    first client to hit both.

## Mutants fired

Each by the scratch driver: copy the file(s) to a backup in the
scratchpad, apply the edit, run `CI=true flutter test --no-pub
test/spike_rooms`, restore with `cp`, then `diff` against the backup and
`git diff --quiet` against the commit: **exit 0 and 0 for all 26 runs**.
Result lines are the runner's last line.

| Mutant | What it breaks | Result |
|---|---|---|
| M-10a | centrelines instead of outlines (room tool and rebuild) | red, `+14 -65`: every area test at every placement |
| M-10d | 08's stored pieces instead of the uncut outline (the tool's trace) | red, `+67 -12`: Q2a (`Actual: <Instance of 'Unbounded'>`: the Hall, the first room asked, leaks through the doorways and out), Q2j at all six placements, Q3a in own groups, the renders. Survives the fixtures without openings, as it must |
| M-holes | islands ignored | red, `+61 -18`: Q2c and Q2g everywhere, the island deletion, Q4b–d |
| M-sep | separators dropped | red, `+63 -16`: Q2c, Q2g, Q2h, the separator break, Q6 |
| M-10b | the outer ring any cycle of least signed area (a winding error) | red, `+8 -71` |
| M-hole-sign | holes not reversed: their area adds | red, `+55 -24` |
| M-seedface | the largest face holding the seed | red, `+73 -6`: Q2g's courtyard at every placement |
| M-local | no local frame (world coordinates throughout) | red, `+61 -18`: every +1e9 mm placement, worst errors `96.0` and `182.0 mm2`; green at the corpus far origin (`0.0009765625 mm2` < 1e-2) |
| M-tol | `roomJoin` 1e-12 instead of 1e-6 | red, `+52 -27`: T butts missed off the origin, rooms merge (worst `53514299.99838462 mm2` at +1e9 mm) |
| M-10e | a wall already bounding a room is not referenced by the next | red, `+66 -13`: Q3a everywhere, the moves, Q6 |
| M-10c | the label at the ring's box centre | red, `+73 -6`: Q4a, Q4b, Q4d, Q4e |
| M-centroid | the label at the centroid | red, `+73 -6`: the same |
| M-10f | the planner never rewrites a matched TEXT's string | red, `+74 -5`: the moves, the page change, the dissolve cases |
| M-text-add | the planner adds records without the string (`main`'s builder) | red, `+65 -14` |
| M-attrs | `textAttrs` not written on add (`main`) | red, `+78 -1`: Q5 children |
| M-page | no page seeds | red, `+78 -1`: Q5 page change |
| M-dissolve | `dissolves` always false | red, `+73 -6`: every Q3c break, Q3d, Q3e |
| M-detach | the dissolve leaves the component | red, `+78 -1`: `Expected: null Actual: <Instance of 'RoomParams'>` |
| M-policy | islands cascade | red, `+78 -1`: the island deletion |
| M-slit | the exact keyhole (slit 0) | red, `+67 -12`: every column fixture on the system refused |
| M-rule3 | intruders allowed under refs + neighbours | red, `+78 -1`: Q3e |
| M-rule4 | rule 4 removed | red, `+78 -1`: only Q3d, the probe that shows rule 4 deleting a valid room (see Q3) |
| M-unpick | the unpickable flag ignored by picking | **survives** (`+79`): the invisible boundary already hides the tint |
| M-visible | the tint's boundary visible, the flag kept | **survives** (`+79`): the flag alone suffices |
| M-unpick2 | both | red, `+78 -1`: Q6 picks |

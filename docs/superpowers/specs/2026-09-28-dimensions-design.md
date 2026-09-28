# Dimensions — design

**Date:** 2026-09-28. **Status:** design, **revision 2**. Revision 1
(`a2ba486`) was reviewed independently: "Ready with amendments", 0
blocking, 3 major and 9 minor findings (S-1 to S-12). Revision 2 applies
them and the human's answers to the two that were theirs, decisions 22 and
23; see [Revision 2](#revision-2).
**Amended at execution:** nothing yet. The plan's last task adds
paragraphs headed "**Amended at execution (Plan 11)**" under each section
it makes precise or departs from, in 10's form; they rewrite nothing above
them.
**Sub-project:** `roadmap/11-dimensions.md`. **Size:** M, application code
only (D1).
**Branch:** `spec-11/dimensions`, cut from `main` at `9774a55`; revision
1 is written on top of `ccd5345` (the spike's findings note and renders,
brought over unchanged), revision 2 on top of `a2ba486`.
**Depends on:** 06 (the parametric layer), 07 (walls), 08 (references,
cascade), 10 (generated text, the page on the view, the page key), all
merged.
**Blocks:** nothing. 12 (the app shell) inherits two lines: a dimension
style table and a dimensions layer (Files).
**Brainstormed with the human on 2026-09-28**, on `main`, followed by a
throwaway spike whose findings are the evidence for most decisions below:
[2026-09-28-dimensions-spike-findings.md](../notes/2026-09-28-dimensions-spike-findings.md)
(branch `spike/11-dimensions`, head `675f997`, code at `383dc57`, cut from
`f81c585`, never merged). Its renders are in
[2026-09-28-dimensions-spike/](../notes/2026-09-28-dimensions-spike/).

**Inputs read for this revision:** `CLAUDE.md`; `STATUS.md`;
`roadmap/11-dimensions.md`, `roadmap/00-README.md`, `roadmap/12-app-shell.md`;
the brainstorm's decision record (below); the spike note, the spike's code
(`apps/floor_planner/lib/parametric/{dimension,dimension_geometry,catalog}.dart`)
and its tests (`apps/floor_planner/test/spike_dims/`); spec 06
([2026-09-24-parametric-layer-design.md](2026-09-24-parametric-layer-design.md)),
spec 07 ([2026-09-24-walls-design.md](2026-09-24-walls-design.md)), spec 08
([2026-09-25-openings-design.md](2026-09-25-openings-design.md)) and spec 10
([2026-09-26-rooms-design.md](2026-09-26-rooms-design.md)), whose shape this
spec follows.

**Decisions the human made on 2026-09-28**, numbered as in the brainstorm
record: 1–16 before the spike, 17–21 after it, 22–23 the answers to
revision 1's review. **Later decisions refine earlier ones where they say
so:** 17 pins 12's rotation question, 18 pins the offset's units, 19 pins
which wall a shared point stores, 20 pins the lineweight and 21 the
collisions; **22 supersedes 19's timing** (the choice is made at the
commit, not the second click), and 23 pins how a point attaches (by
position, while F3 is on).

| # | Question | Answer | Here |
|---|---|---|---|
| 1 | What a dimension attaches to | Each end is a wall feature it follows (a wall end, or a point on its left or right face, corners included), or a fixed point (no wall feature snapped). Drafted geometry is not followed; openings are not v1 referents | D2, D4, D10 |
| 2 | v1 types | Aligned (true distance) and linear (the horizontal or vertical component, locked by where the line is dragged). No chains, angular, radial or ordinate | D6, D12 |
| 3 | A referenced wall deleted | The dimension is deleted in the same edit and undo step (08's `cascade`); undo restores both | D3, D16 |
| 4 | Wall attach points | The six end points: (wall, k ∈ {0, 1}, side ∈ {left, centre, right}); a face point is the joint's cleaned-up outline corner; anything else is fixed. No along-face points | D4, D10 |
| 5 | Terminators | The architectural 45° slash, drawn as lines. No arrowheads | D7 |
| 6 | Sizes | Fixed paper constants scaled by the page scale, as the room labels are; text follows the paper, never the camera (M-11b); a page-scale change regenerates every dimension; no style table or UI in v1 | D7, D8 |
| 7 | Value format | The page's unit at plan precision (mm 1, cm 0.1, m 0.01, in 1/8, ft-in 1/4, `11'-4 1/4"`), round-half-up (M-11e), no unit symbol | D9 |
| 8 | Text | Centred above the line, aligned with it, readable from the bottom or the right (flipped by 180° otherwise) | D8 |
| 9 | Tool | One Dimension tool, three clicks: first point, second point, place the line. Aligned by default; Shift while placing for linear, by the side dragged to. Esc as in the other tools. An end attaches when the snap lands on a wall end point, else it is fixed | D12 |
| 10 | Key | **I**, in the palette and `kShellLetterKeys` | D12 |
| 11 | Grips | The line offset and the two ends. The line keeps its offset, stored relative to the measured points, when walls move. End grips re-pick an end with the tool's snaps: attach, detach, re-attach. No text grip | D13 |
| 12 | Select-tool move and rotate | A fixed end moves and rotates with the selection; an attached end never moves by itself and follows its wall | D11 |
| 13 | Panel | A Dimension section: the value (read-only, as displayed), a switch Aligned \| Horizontal \| Vertical, each end's state. Each change one undo step. No text override | D14 |
| 14 | Automatic dimensions | None. Rooms keep 10's labels; no transient wall-length readout | Non-goals |
| 15 | The sample plan | Overall width and depth outside the plan, two interior room widths corner to corner, one aligned dimension on a non-axis pair (a fixed-end one if the plan has no angled wall): every kind and both end states | D17 |
| 16 | Process | Spike first, on a throwaway branch | this header |
| 17 | Linear axes | The dimension's own (group-local) axes. Rotating a plan keeps every value; a both-ends-attached linear dimension rotated alone turns its axis (the spike's 4000 → 3464), and the panel shows it as rotated | D6, D11, D14 |
| 18 | The offset's units | A model length: the line stays where it was placed when the page scale changes; only the paper constants grow or shrink | D2, D6 |
| 19 | A shared point | Attaches to the wall the dimension runs along: the candidate wall most nearly parallel to the measuring direction, then the lowest handle, then face before centre, k, left before right. A wall-length dimension stays on that wall's ends. *Its timing, "once both ends are known (the second click, or an end-grip drop)", is superseded by 22* | D10 |
| 20 | Lineweight | 0.25 mm; the spec measures whether 0.25 survives the rasteriser's axis-aligned drop-out at the look's zooms and raises it to 0.30 if not. The render-layer fix stays a separate follow-up (10's R-17); the render package stays frozen in 11 | D7 |
| 21 | Collisions | Accepted; the user drags to fix (the offset grip, 10's label grip). A known limit; no diagnostic | D18 |
| 22 | When decision 19 chooses (review S-1) | **At the commit** (the third click), with the direction the committed dimension measures: aligned, or the group-local x or y for horizontal or vertical; at an end-grip drop, for the dropped end, with the dimension's current kind. Supersedes 19's "second click". Revision 1's R-17 timing, now the human's | D10, D12, D13 |
| 23 | How a point attaches (review S-3) | **By position.** While F3 is on, any end that lands within the attach tolerance of a wall's attach point attaches, whether an object snap or the grid put it there; the tool and the grips behave the same, since they see only the resolved point | D10, D12, D13 |

**The controller's readings** of the decision record are checked in
[The controller's readings, checked](#the-controllers-readings-checked). In
short: layer 0, no dimension `EntityKind`, lines and one
`Generated.text`, references to up to two walls with `cascade` are all
right; the "suspected engine need" was wrong, as the spike found: today's
closure (08 D3) already rebuilds a dimension whose wall's corner a
neighbour moves (D5).

**Where this spec had to resolve something the decisions leave open**, the
paragraph is tagged **[spec ruling]**; the tags are indexed in
[Spec rulings](#spec-rulings). Every item of the spike's "Open decisions
for 11's spec" is closed there or in the decision it names; the
[Open questions for the human](#open-questions-for-the-human) section is
empty, and says why. **Revision 2** also cites the independent review's
runs, as "the review's run", where they settle a finding.

**Numbers.** Every measured number below is quoted from the spike note
(which quotes its own runs on `spike/11-dimensions`) and says so, or from
**this spec's own runs**: the lineweight sweeps of D7, in three capture
set-ups, run on the spike's code extracted to the session's scratchpad
(never committed anywhere), quoted with their command. Lengths and
formatted values are worked by hand for this spec, with the arithmetic
shown; the sample plan's values were also recomputed with a small python reimplementation of D9's rules in
the scratchpad. No test output was produced for this document otherwise.

**Evidence of record.** Every claim about what exists was read from the
tree at `9774a55` (code) on 2026-09-28, or from `spike/11-dimensions` at
`383dc57` where marked.

- **The engine's parametric layer** (`packages/jet_cad_2d/lib/src/parametric/`):
  - `ParametricType` (`parametric_system.dart:24-171`): `editCapability`,
    `reach`, `generate`, `diagnose`, `references` (56; "called once per
    live object per survey"), `referencePolicy` (60; default `cascade`),
    `pageKey` (75), `dissolves`, the place roles (10 D16);
  - `Generated` (205-313): the plain form takes `lineweight` (219), and
    `Generated.text(payload, text, {color, textAttrs, flags})` (268) keeps
    its string; every attribute is written on add only;
  - `ParametricView` (355-458): `paramsOf` and `toWorld` read the survey's
    snapshot, `neighbours` (444), `referrers` (451), `page` (457);
  - `_closure` (`regeneration.dart:385-401`): `core = seeds ∪ neighbours
    before and after (seeds) ∪ references before and after (seeds) ∪
    triggered`, `closure = core ∪ referrers before and after (core)`;
    its comment (377-384) is 08 D3's "one extra hop" argument;
  - `_cascade` (641), `_subtreeRemoval` (707), `_checkDangling` (771),
    `_pageSeeds` (267, called at 864), `_run` (816-929).
- **Walls** (`apps/floor_planner/lib/parametric/`):
  - `wallJoin = Tolerance(linear: 1e-6, angular: 1e-9)` (`wall.dart:19`);
    `reach` is the centreline's box grown by `wallJoin.linear` (147); a
    degenerate wall generates its centreline alone (175-193);
  - `WorldWall` (`wall_geometry.dart:19-61`), `classify` (196), `cap`
    (263), `outline` (425), `localOutlineOf` (468-485: the local ring, and
    07's second fallback to the free rectangle when the local image is not
    simple), `capsOf` (491-506: the two caps in world, with 07's short-wall
    fallback, but **not** the local-ring fallback);
  - `wallsInView` (`opening_geometry.dart:603-615`: the host and
    `view.neighbours(host)`), `openingsInView` (646-652: referrers filtered
    to `OpeningParams` whose host is the wall), `wallsInDocument` (716-732:
    the host and every live wall).
- **Snapping and tools:**
  - `kDragSnapMask` (`index/drag_snap.dart:10`: the cheap five plus
    intersection), `kSnapAperturePixels` (14), `DragPoint` (17),
    `resolveDragPoint` (39: ortho, then an object snap that wins outright,
    then the grid);
  - `SpatialIndex.forEachInRect` (`index/spatial_index.dart:294`),
    `snapInto` (1466), `_considerIntersections` (1530: root-level entities
    only);
  - `PlacementTool` (`jet_cad_2d_flutter/lib/src/draw/placement_tool.dart:34`):
    `markerPoint` (81), `orthoBase` (84: the last placed point), `hovered`
    (95), `_resolve` (105), Shift re-resolves (`onKey`), Esc cancels a
    pending shape, `commit` (229).
- **Grips and the select tool** (`jet_cad_2d_flutter/lib/src/`):
  `ObjectGripProvider` (`grip_cache.dart:29-51`: `gripsOf`, `drag(d, group,
  grip, world)` with the point the select tool resolved through the chain,
  `preview`, `movable`), `movableKey` (57), `GripCache.rotatable` (254),
  `isMovable` (263); `GripDrag` calls `provider.drag` (`grip_drag.dart:286`).
- **The app:**
  - `ObjectGrips` (`parametric/object_grips.dart`) dispatches Wall,
    Opening, Room and Separator; the shell builds it with the index in
    reach (`main.dart:64` `_index`, 257-266);
  - `kShellLetterKeys` (`shortcut_guard.dart:5-21`): V L P R B W D N G M S
    C A T F. **I is free.** The palette is `_entries` (`main.dart:137`);
  - the status line merges the Room tool's notice (`main.dart:277-279`,
    `_statusLine` 321-326);
  - the Selection panel's sections and the Wall section's
    `SegmentedButton` (`selection_panel.dart:676-693`), the Room section's
    read-only Area (730-735);
  - 10's label pattern (`room.dart:112-135, 282-316`): paper height ×
    `scaleDenominator`, world placement, the TEXT's rotation minus the
    group's, the height divided by the group's scale, `PageComponent()`'s
    defaults when no page is attached;
  - the page (`document/page_component.dart:96-108`): A4 landscape
    (297 × 210 effective), 1:50, `DisplayUnit.meters` by default;
    `formatLength` (`geometry/grid_scale.dart:113-145`) is the ruler's,
    with `'` and `"` in its feet-inches;
  - the sample plan (`startup_plan.dart`): nine 07 walls, fifteen 08
    openings, a column, a separator, the page (1:50 m, centred on the
    extents), seven rooms, then the system is disposed; 581 entities
    (`startup_plan_test.dart:147`).
- **The render layer's stroke width** (`vertices_draw_sink.dart:559-566`):
  a lineweight is `hundredths / 100 × pixelsPerPaperMm` logical pixels,
  `kLogicalPixelsPerMm = 96 / 25.4` (`draft_canvas.dart:22`), whatever the
  zoom; 0.25 mm is 0.945 logical px, 0.30 mm is 1.134.

## What this delivers

1. **Associative dimensions.** A dimension is its own parametric object:
   two ends, each a wall end point it follows or a fixed point, a kind
   (aligned, horizontal, vertical) and an offset. It generates a dimension
   line, two extension lines, two architectural slashes and its value, and
   regenerates in the same undo step whenever anything it measures moves.
2. **The six wall attach points** per wall, computed from 07's joint
   geometry exactly as 07 draws it.
3. **The Dimension tool (I):** three clicks, Shift for linear, snaps that
   attach.
4. **Grips:** the offset, and the two ends (attach, detach, re-attach).
5. **A Dimension section** in the Selection panel.
6. **Diagnostics:** a dimension that measures zero; one whose end a file
   broke.
7. **The sample plan** gains five dimensions: every kind, both end states.
8. **No change to the engine or the render layer** (D1): `git diff 9774a55
   -- packages/` stays empty.

## Non-goals

- **Automatic dimensions** (decision 14): no room widths from 10, no
  transient wall-length readout while drawing.
- **Chains, baselines, angular, radial, diameter, ordinate** (decision 2).
- **A dimension style table or UI, and a dimensions layer** (decision 6;
  roadmap 11's fixed-layer question): both come with 12's shell and layer
  panel (Files). Dimensions stay on layer 0.
- **Text override, a text grip, arrowheads** (decisions 5, 11, 13).
- **Openings, drafted geometry, rooms and boxes as referents** (decision
  1): an end on them is fixed and does not follow.
- **Collision avoidance** (decision 21).
- **The render layer's sub-pixel fix** (decision 20, 10's R-17): 11 does
  not need it; 0.25 mm survives a capture matched to the display (D7).
- **Intersection snaps between groups' children** (spike Q3c): an X
  crossing of two wall faces gives no snap; such an end would be fixed
  anyway (decision 4).
- **Dimensions inside definitions or instances** (06 D5: parametric objects
  are root-level).
- **Handle remapping on paste or import** (08 R4): a dimension stores wall
  handles; paste and import do not exist yet, and remapping them is theirs.

## Decisions

### D1 — Where dimensions live, and what changes outside the app

- **The dimension is application code**, like 07's Wall, 08's Opening and
  10's Room, in `apps/floor_planner/lib/parametric/`. Nothing in the engine
  knows what a dimension is.
- **Files (app):**
  - `dimension.dart`: `WallSide`, `DimEnd` (`AttachedEnd`, `FixedEnd`),
    `DimKind`, `DimensionParams`, `DimensionType`, the paper constants,
    `debugDimensionGenerates`;
  - `dimension_geometry.dart`, **pure Dart, no Flutter import**:
    `wallEndPoint` and `wallEndPoints` (D4), the measuring direction, the
    layout and the placement function (D6–D8), `readable` (D8),
    `roundHalfUp` and `formatDimension` (D9), the two named tolerances;
  - `dimension_attach.dart`, **pure Dart**: the attach candidates through
    the index and decision 19's choice (D10);
  - `dimension_tool.dart` (D12), `dimension_grips.dart` (D13);
  - `wall_geometry.dart` gains `drawnCapsOf` (D4); `catalog.dart`
    registers the type; `object_grips.dart` gains a dispatch arm;
    `selection_panel.dart` the Dimension section; `main.dart` the tool, its
    key, its notice and the grips' index; `shortcut_guard.dart` the key;
    `startup_plan.dart` the five dimensions.
- **No engine change.** Checked against `packages/jet_cad_2d/lib/src/parametric/`
  at `9774a55` (evidence above), as the spike found (`git diff f81c585
  HEAD --stat -- packages` empty on the spike): `Generated(EntityKind.line,
  …, lineweight:)`, `Generated.text`, `ParametricView.page`, `pageKey`,
  `references`, `ReferencePolicy.cascade` and the closure that takes
  referrers of the whole core are all on `main`. D5 states the invariant
  that makes them sufficient.
- **No render-layer change** (decision 20 freezes it): the tool is a
  `PlacementTool` subclass in the app, the grips an `ObjectGripProvider`,
  and nothing needs a new render-layer API (D10 explains why the snapped
  entity is not needed).

**Pinned by:** the exit gate's `git diff` (gate 13) and the import grep for
the two pure files (10's pattern).

### D2 — `DimensionParams`

- **Fields**, in the dimension group's local space:
  - `a`, `b` — the two ends, each a `DimEnd`:
    - **`AttachedEnd(wall, k, side)`** — a wall end point (decision 4): the
      wall's handle, `k ∈ {0, 1}` (its start or its end) and `side ∈
      {left, centre, right}` (`WallSide`), looking from the wall's start to
      its end. It stores no coordinate: its point is read from the wall
      (D4), and the dimension group's transform never touches it
      (decision 12);
    - **`FixedEnd(x, y)`** — a point in the dimension group's **local**
      space, so it moves and rotates with the group (decision 12)
      **[spec ruling]** (R-1: the spike's representation; the tool places
      the group at the identity, so a fixed end is stored at its world
      point, D12);
  - `kind` — `DimKind.aligned`, `.horizontal` or `.vertical` (D6);
  - `offset` — a signed **model length** in the group's local units
    (decision 18), from the outermost measured point on the line's side
    (D6). **Its side is its sign bit** **[spec ruling]** (R-2): `+0.0` and
    every positive value lie on the measuring direction's left normal,
    `-0.0` and every negative value on its right. So a line through the
    lower measured point, a zero offset on the minus side, is `-0.0`
    (D6's between band makes one).
- **`typeId`:** `floor_planner.dimension`.
- **`toJson`**, every key always written, in this order: `a`, `b`, `kind`,
  `offset`; an attached end is `{"wall": <handle int>, "k": 0|1, "side":
  "left"|"centre"|"right"}`, a fixed end `{"point": [x, y]}`; `kind` by name.
  `-0.0` is written `-0.0` and read back as `-0.0` (checked for this spec:
  `jsonEncode({'offset': -0.0})` gives `{"offset":-0.0}` and
  `jsonDecode` returns `-0.0`, `isNegative` true, with the workspace's
  Dart).
- **Value-equal, exact** (stored values, CLAUDE.md): ends, kind, and the
  offset compared with **`compareTo(other) == 0`**, which tells `-0.0`
  from `+0.0` (`-0.0 == 0.0` is true in Dart; `(-0.0).compareTo(0.0)` is
  `-1`, checked with the same run). `hashCode` may collide across the two
  zeros; unequal values may share a hash.
- **Validation** **[spec ruling]** (R-3): `fromJson` accepts anything
  well-typed (an unknown `kind` or `side` name throws, as 07's
  justification does). A `k` outside {0, 1}, a non-finite fixed coordinate
  or a non-finite offset are accepted and reported `dimension.broken`
  (D15); `generate` makes nothing for them. The tool, the grips and the
  panel produce none of them.

**Pinned by:** `DP1`, `DO3`; M-11negzero.

### D3 — `DimensionType`: reach, references, cascade, page key

- **`reach` is `Aabb2.empty()`:** a dimension is nobody's neighbour and has
  none, as 08's opening (`opening.dart:120`). It reaches its walls by
  reference.
- **`references`** is the set of its attached ends' wall handles, in `a`,
  `b` order, deduplicated (both ends on one wall name it once): zero, one
  or two handles. A field read, as `references` must be (called once per
  live object per survey).
- **`referencePolicy` is the default, `cascade`** (decision 3): deleting a
  referenced wall deletes the dimension in the same edit; undo restores
  both (08 D4, spike `Q2c`). A wall that stops being a root-level group
  counts as deleted, as for openings.
- **`pageKey(page)`** is the record `(displayUnit, scaleDenominator)` of
  `page`, or of `PageComponent()`'s defaults (1:50, metres) when `page` is
  null, as 10's room (10 R-14). A page-scale or unit change regenerates
  every dimension in the page edit's own undo step; a paper colour or grid
  change regenerates none (decision 6).
- **`editCapability = Capability.geometry`**, as every other type.
- **`contributesPlace` and `readsPlaces` stay false** and `dissolves` stays
  the default: a dimension reads by reference only (D5).
- **A counter,** `debugDimensionGenerates` (`@visibleForTesting`, never
  reset by the library), counts `generate` calls, as 10's
  `debugRoomGenerates`.

**Pinned by:** `DO1`, `DO2`, `DN3`; M-11refs, M-11page.

### D4 — The wall attach points

Decision 4's six points per wall, from 07's own joint geometry. For a wall
`w` among its wall neighbours `others` (07 D10's neighbours; degenerate
walls and `w` itself ignored, as in `classify`):

- **centre** — the stored centreline end, `w.endpoint(k)` **[spec
  ruling]** (R-4, the spike's open item 1). It is the end of the
  centreline polyline the wall generates, so what a snap finds. At an L it
  is the node point, where the two centrelines meet; at a T butt it is the
  stem's end on the through wall's centreline, inside the through wall's
  band (spike C5: (2500, 0)), so a centre-to-centre dimension measures
  centreline to centreline, the architectural convention. The alternative,
  the cap's midpoint, gives (2500, 100) at the T and differs whenever the
  justification is not centred (spike M-centre-mid, red on C4, C5, C5c).
- **left / right** — the first or last point of the wall's **drawn** cap
  at that end. A cap runs from the end's outgoing-left face to its
  outgoing-right face; at the start (`k = 0`) outgoing-left is the wall's
  left, at the end (`k = 1`) its right. So the left point is
  `startCap.first` or `endCap.last`, and the right point `startCap.last`
  or `endCap.first` (the spike's Q1 rule). A node owner's cap walks its
  lobe, but its first and last points are still its own corners (spike
  C7). A T butt's corners are the **stem's** own `(k, left/right)` points,
  never vertices of the through wall (spike Q3d).
- **A degenerate wall** (07 D2: length ≤ `wallJoin.linear` or thickness
  ≤ 0) has no outline: all three sides are its centreline end.

**The drawn caps: 07's two fallbacks** **[spec ruling]** (R-5, the spike's
open item 12). `drawnCapsOf(w, others)`, new in `wall_geometry.dart`:

1. `capsOf(w, others)`: the joined caps, or both free caps when 07 D6's
   short-wall fallback applies (the world ring is not simple);
2. when step 1 did not fall back: the ring `simplifyRing([...endCap,
   ...startCap])` is taken to `w`'s local space through
   `w.toWorld.invert()`; when that image is not `isSimpleCcw`, the free
   caps **of the stored ring**: the caps of `WorldWall(w.handle, w.params,
   Transform2.identity())` among no walls (the local free rectangle
   `localOutlineOf` stores, `wall_geometry.dart:478-483`), each point mapped
   through `w.toWorld`; `fellBack` true. **[amended, revision 2, S-5]**:
   revision 1 recomputed the free caps in world, whose thickness is the
   stored `t` (`WorldWall` does not scale it), while the drawn rectangle is
   the local one mapped, `t · s` thick under a scaled group; taking the
   stored rectangle makes the attach point the drawn corner at any
   similarity.

Step 2 is **exactly `localOutlineOf`'s decision** (`wall_geometry.dart:468-485`:
the same ring, the same mapping, the same test). So the attach point and
the drawn corner can no longer differ: under the spike's rule (`capsOf`
alone) they did, in 07's final-review I1 case (an acute L rotated about its
node, 07's `WR13`), where 07 stores the local free rectangle while `capsOf`
still gives the joined corner, and a snap on the drawn corner matched
nothing (spike open item 12). With R-5 the attach point is the drawn free
corner: the stored local corner mapped to world, bit for bit the point
the index holds for it.
`localOutlineOf` itself is not edited: 07's stored children stay bit for
bit, and 07's, 08's and 10's tests pass unedited. `AP2` pins that
`drawnCapsOf`'s `fellBack` equals `localOutlineOf`'s on every fixture.

**The two steps under mutation** (review S-2). Step 2 re-tests every ring
step 1 let through, so removing step 1 **alone** is equivalent on every
fixture: an affine image of a world ring that is not simple is not simple
either, and step 2 then returns the same free rectangle (the review's run:
`drawnCapsOf` with and without step 1 over all 43 walls of the spike's Q1
cases at the six placements, `points compared 258, differing under
M-11fallback 0, fellBack differing 0` at each). Step 1 stays: it makes the
decision `localOutlineOf`'s bit for bit in the reverse rounding edge (a
world ring that is not simple whose local image is), which no fixture
reaches. So the named mutant **M-11fallback** removes **both** steps (the
joined caps always), killed by `AP1`'s C9 (A/0/left becomes (100, 100)
instead of (0, 100)), and M-11localring removes step 2 alone (`AP2`).

**The hand-worked cases** (the spike's Q1 table, plan coordinates, mm; a
wall's left normal is `(−d.y, d.x)`: +y for a wall running east, −x for
one running north):

| Case | Walls | Expected points |
|---|---|---|
| C1 free | A (0,0)→(4000,0), 200 | A/0: (0,100), (0,0), (0,−100); A/1: (4000,100), (4000,0), (4000,−100) |
| C2 L | A as C1; B (4000,0)→(4000,3000), 200 | inner (3900,100) = A/1/left = B/0/left; outer (4100,−100) = A/1/right = B/0/right; centre (4000,0); A/0 (0,±100); B/1 (3900,3000), (4100,3000) |
| C3 L 300/100 | A 300, B 100 | (3950,150), (4050,−150) |
| C4 L, 3 × 3 justifications | A 200, B 120; A's (left, right) offsets: centre (100,−100), left (200,0), right (0,−200); B's (60,−60), (120,0), (0,−120) | left corner (4000 − l_B, l_A), right (4000 − r_B, r_A); A/0 free: (0, l_A), (0, r_A) |
| C5 T | C (0,0)→(6000,0), 200; S (2500,0)→(2500,3000), 100 | S/0: left (2450,100), centre (2500,0), right (2550,100); C's ends free: (0,±100), (6000,±100) |
| C5b T, stem ending on C | S (2500,3000)→(2500,0) | S/1: left (2550,100), right (2450,100) |
| C5c T from below, stem left-justified | S (2500,0)→(2500,−3000), 100, left | S/0: left (2600,−100), right (2500,−100) |
| C6 X | A as C1; B (2000,−2000)→(2000,2000), 200 | all ends free: B/0 (1900,−2000), (2100,−2000) |
| C7 Y | three 200 mm walls from (0,0) at 0°, 120°, 240° | corners on the bisectors at 100 / sin 60° = 115.470: A/0: (57.735,100), (57.735,−100); B/0: left (−115.470,0), right (57.735,100); C/0: left (57.735,−100), right (−115.470,0) |
| C8 + | four 200 mm walls at 0°, 90°, 180°, 270° | corners (±100, ±100); A/0: (100,100), (100,−100); B/0: (−100,100), (100,100) |
| C9 short-wall fallback | A (0,0)→(100,0); B north from A's end; C north from A's start; all 200 | A falls back: (0,±100), (100,±100); B keeps its mitre (0,100), (200,−100); C keeps (100,100), (−100,−100) |
| C10 degenerate | t = 0; length 0 | every side is the centreline end |
| **C11 local-ring fallback** (new) | 07's `WR13`: A 200 right-justified into the hub, B 200 left-justified out of it at 178°, both at the identity, turned 133° about the hub at the far origin | A falls back in local space only: its four points are its stored free rectangle's corners mapped to world; its world joined corner is not among them (a premise the test asserts, as 10's `RT5`) |

The spike measured its rule against C1–C10 at six placements (`Q1 every
case`): worst 4.97e-14 mm at the origin, 1.88e-9 mm at the corpus far origin
in own groups, 3.77e-7 mm at +1e9 mm turned 23° in own groups. An L corner
is **bitwise one point** for both walls (07 computes a wedge corner once):
`A/1/left [4503550.8958156165,1201615.9018864536], B/0/left
[4503550.8958156165,1201615.9018864536]`.

**Costs:** per point, one `drawnCapsOf`: two `classify` among the wall's
neighbours, two caps, one `isSimpleCcw` in world and at most one more in
local space, on rings of a handful of points. **Pinned by:** `AP1`–`AP3`;
M-11nbrs, M-11swap, M-11swapjust, M-11fallback (both steps, S-2),
M-11centremid, M-11localring, M-11d, M-11d2, M-11vertex.

### D5 — What a dimension reads, and why today's closure is enough

**The invariant.** A dimension's `generate` (and `diagnose`) reads only:

1. its own `DimensionParams` and its group's accumulated transform;
2. the page's `(unit, scale)`, which is its page key (D3);
3. for each attached end's wall `W`: `W`'s `WallParams` and transform,
   and the `WallParams` and transforms of `W`'s **reach neighbours**,
   `view.neighbours(W)` (through 08's `wallsInView`), **one hop and no
   further**.

It reads no other dimension, no opening, no room, no stored child, and no
neighbour of a neighbour. Its reach is empty, so it is nobody's neighbour;
it declares its walls as references (D3).

**Why every edit that changes what it reads regenerates it** (the argument
08 D3 made for doors, which holds for dimensions; spike Q2):

- (1) changes only when the dimension is a seed (its component or node was
  touched), and a seed is in the closure;
- (2) changes only on a page edit, which seeds every dimension when the
  key changed (10 D14);
- (3a) `W`'s own parameters or transform change only when `W` is a seed,
  and the dimension is a referrer of `W`: `W ∈ core`, so the dimension ∈
  `referrers(core)`;
- (3b) a neighbour `N`'s parameters or transform change only when `N` is a
  seed. `N` is `W`'s neighbour before or after the edit; the reach-overlap
  relation is symmetric, so `W ∈ neighbours_before(N) ∪
  neighbours_after(N)`, which `_closure` puts in the **core**
  (`regeneration.dart:387-390`), and the dimension is again in
  `referrers(core)`. A wall that joins `W` (added, or moved into a joint),
  or leaves it (deleted, moved away) is a seed that is `W`'s after- or
  before-neighbour: the same step;
- `W`'s attach points depend on nothing else: `classify` and `cap` read
  `W` and the walls that join it at a T or a node, which lie within
  `wallJoin.linear` of `W`'s centreline or ends and so overlap its reach;
  the short-wall fallback reads `W`'s own ring; the local-ring fallback
  (D4 step 2) reads `W`'s own transform;
- deleting `W` deletes the dimension (cascade, D3), so a dimension never
  reads a dead wall after an edit.

So a dimension not in an edit's closure reads exactly what it read before,
and its stored children are what `generate` would produce now: **no
drift**. The inherited assumption is 07's: a wall's band depends only on
its reach neighbours; its known edge, a node cluster spread over up to
2 × `wallJoin.linear` (07 D4's amendment), is 07's own drift edge,
unreachable by snapping, and dimensions inherit it without widening it.

**Cost bound per edit** **[amended, revision 2, S-6]**. The dimensions an
edit regenerates are **every referrer of every wall in the core**, where
the core holds the seeds, their neighbours before and after, and their
references (`_closure`). Named cases, each unbounded in the number of
dimensions per wall and none drifting:

- a **wall** edit: the dimensions on the wall and on each of its reach
  neighbours; a **partition** edit reaches its T's **through wall** as a
  neighbour, so every dimension on that exterior wall regenerates, though
  a T in the middle never moves the through wall's ends;
- an **opening** edit (a door slid along its wall): the host is the
  opening's reference, so every dimension on the host regenerates, though
  no wall end point moved;
- a **dimension** edit (an offset drag): its walls are its references, so
  they, their openings and every other dimension on them regenerate.

The regenerated objects whose inputs did not change plan nothing. Each
dimension's `generate` is O(the neighbour count of its at most two walls)
plus a constant layout. **No edit pays anything for a dimension whose
walls it does not reach**: there is no per-edit pass over dimensions and
no read box. The spike's option (b) (dimensions as place readers, 10 D16)
also held but cost more for nothing on today's engine: 300 fuzz edits made
**1,466** generates and 0 read-box calls under (a), **1,585** generates and
**717** read-box calls under (b) (spike `Q2e`); **not adopted** (spike item
15). `DN4` pins the bound's two ends with `debugDimensionGenerates` (no
generate for an unreached dimension; exactly its walls' dimensions for an
offset change) and prints the counts for a door move and for a partition
thickness change on a wall that carries N dimensions.

**The drift fuzz and its oracle** (`DZ1`, the spike's `Q2e`, extended):
the sample plan's nine walls (`room_fixture.dart`'s `sampleWalls()`, no
column; S-9) at the corpus far origin, every wall in its
own rotated group, page in mm, and fourteen dimensions (random wall end
points, a fifth of the ends fixed, all three kinds, a third of the groups
rotated). Then 300 seeded edits (seed 11): a thickness, a justification,
an end moved ±400 mm (joints made and broken), a wall's group moved and
turned, a wall added at a wall end, a wall deleted, undo, a dimension's
group moved or turned, **and (new) a dimension's kind switched, its offset
set, an end re-attached to a random wall end point or made fixed, and a
page change (unit and scale)**. After every edit:

- `drift()` is empty;
- **the oracle:** every live dimension's ends recomputed **among every
  wall of the document** (the document adapter, not the view's
  neighbours) and re-laid out by D6–D8 from those points; the stored TEXT
  string equals D9's format of the oracle's value exactly, and every
  stored child's world points lie within 1e-6 mm of the oracle's, the text
  insertion included (its height and rotation within 1e-9);
- `neighbourOnly` counts edits where a dimension's text changed although
  it references none of the edited walls. **`DZ1` asserts `neighbourOnly
  > 0`**, so the fuzz is known to exercise the neighbour case (the spike's
  run: 10) and cannot pass vacuously.

The oracle shares D6–D8's layout with the code under test: it is a
**differential** oracle for the closure (which dimensions rebuild, and
from which walls), not for the layout, which the hand-worked tests pin
(`DL1`–`DL5`). Under **M-11closure** (the engine's referrers taken of the
seeds only, 08's brief rule) the spike's fuzz went red at `step 7 (add):
drift [82, 89]` and made 1,047 generates (spike `Q2e`).

**Pinned by:** `DN1`–`DN4`, `DZ1`; M-11closure, M-11refs, M-11c.

### D6 — The measuring direction, the value, the offset

Everything is computed in **world**, relative to the first end's world
point `P0` (the local frame; a far origin costs nothing beyond the points'
own rounding, spike Q1), then taken to the group's local space (D7).

**The ends in world.** `P0`, `P1`: an attached end is D4's point among
`view.neighbours(W)`; a fixed end is `toWorld(dim)` applied to `(x, y)`.

**The measuring direction `u`** (a world unit vector), with `M =
toWorld(dim)`:

- **aligned:** `u = (P1 − P0) / |P1 − P0|` when `|P1 − P0| >
  wallJoin.linear`; otherwise the group's local x taken to world,
  normalised **[spec ruling]** (R-8: a degenerate aligned pair still lays
  out, and reports `dimension.degenerate`, D15);
- **horizontal:** `M.transformDirection((1, 0))`, normalised;
- **vertical:** `M.transformDirection((0, 1))`, normalised.

Linear axes are **the group's local axes** (decision 17): world x and y
while the group is at the identity, as the tool places it (D12), turning
with the group under a rotation (D11). `n = (−u.y, u.x)` is `u`'s left
normal.

**The value:** aligned `|P1 − P0|`; linear `|(P1 − P0) · u|`. Never
negative.

**The heights** of the two measured points along `n`, relative to `P0`:
`h0 = 0`; for a linear kind `h1 = (P1 − P0) · n`; **for aligned `h1 = 0`
by definition**, not computed (the measuring direction runs through both
points; a computed dot product would leave a rounding-sized band between
them). `hi = max(h0, h1)`, `lo = min(h0, h1)`.

**The offset** **[spec ruling]** (R-6, the spike's open item 6, with
decision 18's units):

- stored in the group's local units; in world it is `o = offset ·
  M.scaleMagnitude` (the select tool never scales; only a file makes a
  scaled group, and a non-uniform one uses the geometric mean, as 10 D10);
- **measured from the outermost measured point on the line's side**: the
  dimension line lies at height `c = hi + o` when the offset's sign bit is
  clear, `c = lo + o` when it is set (R-2). So whichever point a wall edit
  moves, the line keeps its distance from the outermost one, and an
  extension line never runs back across the line (spike `Q4d`:
  M-offset-p0, from the first point, is red);
- a **model length** (decision 18): a page-scale change moves no line;
  only the paper constants of D7 and D8 grow or shrink (spike finding 5).

**The between band** **[spec ruling]** (R-7). The line can never lie
strictly between `lo` and `hi` (only a linear kind has such a band). The
**placement function** `offsetFor(q)` — used by the tool's third click
(D12) and the offset grip (D13), for a world point `q` — is, with `hq =
(q − P0) · n`:

1. `hq ≥ hi`: `offset = (hq − hi) / s` (`+0.0` on `hi` itself);
2. else `hq ≤ lo`: `offset = −((lo − hq) / s)` (`-0.0` on `lo` itself);
3. else (between): the **nearer** extreme with a zero offset: `+0.0` when
   `hi − hq ≤ hq − lo`, else `-0.0`;

with `s = M.scaleMagnitude`. Why the nearer extreme: the line follows the
pointer outside the band and sticks to the extreme the pointer is nearer
inside it, so the jump across the band happens at its middle, not at one
edge. Why the sign bit: it is the one encoding in which "a zero offset on
the lower point" is a stored value `==` can see (D2), with no extra field.

**Pinned by:** `DL1`, `DL2`, `DL5`, `DR1`–`DR5`; M-11a, M-11offsetp0,
M-11sign, M-11between, M-11axisworld, M-11scale.

### D7 — The children

**Six children, in this order, fixed for the object's life**
**[spec ruling]** (R-9): a dimension that measures zero still generates
all six (zero-length lines where they collapse), so its handles never
change while it lives. A broken one (D2's file-only values, or an attached
end whose wall is not a live wall) generates nothing: a childless group, as
06's ghost.

1. **the dimension line**: a LINE from `Q0 = P0 + n (c − h0)` to `Q1 = P1
   + n (c − h1)`;
2. **the extension line at `a`**: a LINE from `P0 + σ n · min(g, |c −
   h0|)` to `Q0 + σ n · v`;
3. **the extension line at `b`**: the same at `P1`, `h1`, `Q1`;
4. **the slash at `a`**: a LINE from `Q0 − t` to `Q0 + t`;
5. **the slash at `b`**: the same at `Q1`;
6. **the value**: a `Generated.text` (D8, D9).

`σ` is `−1` when the offset's sign bit is set, else `+1`; `g` is the
extension-line gap and `v` its overshoot (below), both in world;
`t = normalize(ur + nr) · (slash / 2)`, where `ur` is D8's readable
direction and `nr = (−ur.y, ur.x)`: the slash is the architectural 45°
tick through the line's end, drawn as a line (decision 5), rising to the
right along the text's reading direction, so every slash of a plan leans
the same way on the page.

**Record attributes, all written on add and fixed** (10 D13): ByLayer
colour on layer 0 (the paper's foreground, as 08's symbols; decision 1's
"placed like drafting"), ByLayer linetype, flags 0; the five LINEs at
**lineweight 25 (0.25 mm)**, decision 20's value (below); the TEXT
with `packTextAttrs(h: TextJustifyH.centre, v: TextJustifyV.bottom)`.

**The lineweight: 0.25 mm, decision 20's value, which survives the
measurement decision 20 asks for** **[spec ruling]** (R-31: how the
rasteriser is measured). By the render layer's stroke rule (evidence
above) a lineweight is sized for the view's device pixel ratio: 0.25 mm is
0.945 logical pixels, and a stroke is never narrower than one **device**
pixel (`kMinStrokeDevicePixels / devicePixelRatio` logical). **This spec's
runs:** the spike's code (`git archive spike/11-dimensions`, extracted to
the session scratchpad, `flutter pub get --offline`, never committed),
with a scratch test that renders the sample plan and the spike's decision
15 dimensions through the shell (the spike's capture method) at 0.052,
0.15 and 0.3 px/mm, translating the camera by k/32 px (k = 0…31) along
each axis, and counts the frames where an axis-aligned dimension line (the
overall width, the overall depth, the Hall) shows ink on fewer than half
its probed columns. `kDimLineweight` was edited per run; the command was
`CI=true flutter test --no-pub test/spike_dims/<file>.dart`, one file per
capture set-up:

1. **the spike's set-up** (`spec11_lw_test.dart`): the test view at its
   default device pixel ratio 3, captured by `toImage()` at pixel ratio 1:

   ```
   lineweight 30 at 0.052 px/mm (dpr 3.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {}
   lineweight 30 at 0.15 px/mm (dpr 3.0): frames per probe {width: 32, hall: 32}, frames with the line lost {}
   lineweight 30 at 0.3 px/mm (dpr 3.0): frames per probe {hall: 32}, frames with the line lost {}
   lineweight 25 at 0.052 px/mm (dpr 3.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {depth: 2, hall: 2, width: 2}
   lineweight 25 at 0.15 px/mm (dpr 3.0): frames per probe {width: 32, hall: 32}, frames with the line lost {width: 1, hall: 1}
   lineweight 25 at 0.3 px/mm (dpr 3.0): frames per probe {hall: 32}, frames with the line lost {hall: 1}
   lineweight 18 at 0.052 px/mm (dpr 3.0): frames per probe {depth: 32, width: 32, hall: 32}, frames with the line lost {depth: 10, hall: 10, width: 10}
   lineweight 18 at 0.15 px/mm (dpr 3.0): frames per probe {width: 32, hall: 32}, frames with the line lost {width: 11, hall: 11}
   lineweight 18 at 0.3 px/mm (dpr 3.0): frames per probe {hall: 32}, frames with the line lost {hall: 11}
   ```

2. **matched at ratio 1** (`spec11_lw_dpr1_test.dart`): the view set to
   device pixel ratio 1, captured at 1: at 30, 25 and 18, every zoom,
   `frames with the line lost {}`;
3. **matched at ratio 3** (`spec11_lw_cap3_test.dart`): the view at 3,
   captured by `toImage(pixelRatio: 3.0)`: at 30, 25 and 18, every zoom,
   `frames with the line lost {}`.

Every run ended `All tests passed!` (the scratch tests print and assert
nothing). **The drop-out is the spike's capture's, not the rasteriser's
at a display's resolution.** Set-up 1 sizes every stroke for three device
pixels per logical pixel and then rasterises it at one: a stroke under one
logical pixel (0.945 px at 0.25 mm, 0.68 at 0.18) is an axis-aligned quad
narrower than an image pixel, which paints nothing when its centre falls
within `(1 − w) / 2` of a pixel edge (0.0275 px at 0.25 mm, 0.16 at 0.18:
about 1 in 18 and 1 in 3 of the positions, as measured). A display
rasterises at its own device pixel ratio, which set-ups 2 and 3 model: at
ratio 1 the stroke is clamped to one device pixel, which the fill rule
always paints; at ratio 2 or 3, 0.25 mm is 1.89 or 2.83 device pixels. So
0.25 mm **survives the rasteriser's axis-aligned drop-out at the look's
zooms**, and decision 20's fallback to 0.30 mm is not taken: the five
LINEs are at **lineweight 25**. The ruling is which capture counts: **a
pixel test captures at the view's device pixel ratio** (or sets the ratio
to 1), as a display does; set-up 1 stays a recorded caveat for every pixel
test in the plan. Not checked on a device: the human's look (gate 16)
judges 0.25 on macOS, in Chrome and in Firefox, and a line seen vanishing
there makes 0.30, decision 20's fallback, a one-constant change.

**A finding beyond 11:** 10's spike finding 4 (a default-weight
axis-aligned line painting no pixel, the premise of 10's R-3 separator
weight and of its R-17 hairline follow-up) was rendered the same way:
`boundary.toImage()` at its default pixel ratio 1, in a test view left at
its default device pixel ratio (`spike/10-rooms` at `d30bce5`,
`apps/floor_planner/test/spike_rooms/render_test.dart:99`; no ratio is set
in that file). So it likely shares set-up 1's artefact. The R-17
follow-up should re-measure with a matched capture before changing the
render layer (Files). 11 changes nothing of 10's.

**The paper constants** **[spec ruling]** (R-10, the spike's open item 9),
in paper millimetres, each multiplied by the page's `scaleDenominator`
(decision 6), world millimetres:

| Constant | Paper mm | At 1:50 | At 1:100 |
|---|---|---|---|
| `kDimTextPaperMm`, the text's cap height | 2.5 | 125 | 250 |
| `kDimTextGapPaperMm`, the text's bottom above the line | 1.0 | 50 | 100 |
| `kDimSlashPaperMm`, a slash's whole length | 3.0 | 150 | 300 |
| `kDimExtGapPaperMm`, `g`, from the measured point to the extension line | 1.5 | 75 | 150 |
| `kDimExtOvershootPaperMm`, `v`, past the dimension line | 2.0 | 100 | 200 |

These are the spike's values, which its renders read at both scales
(`R2`: text ink 55..230 mm above the line against 50..228.6 wanted at 1:50,
100..455 against 100..457.1 at 1:100; the extension line's gap 80 and 155
against 75 and 150; a slash probe inked; the text's box is its em, cap
height ÷ 0.7). Nothing measured asks for others; the human's look judges
them (gate 16). **No default offset:** decision 6 lists "dimension-line
offset defaults", but decision 18 makes the offset a model length, and the
tool's third click (decision 9) always places the line, so no v1 path
reads a default; none is defined.

**The mapping to local space.** Every world point `w` is stored as
`toLocal(P0) + toLocal.transformDirection(w − P0)`, `toLocal =
M.invert()`, so the children are relative to `P0` in the local frame (the
room's seed pattern, 10 D10).

**Pinned by:** `DO1`, `DL3`, `DL5`, `RR1`, `RR3`; M-11lw, M-11slash,
M-11extpage, M-11stable, M-11colour. `RR2` is D7's measurement of record
(S-10), not a test a mutant can fail.

### D8 — The text

- **Height:** `kDimTextPaperMm × scaleDenominator` in world (10's label
  pattern), the stored height divided by `M.scaleMagnitude`. It follows the
  paper, never the camera: `generate` never sees the camera (M-11b, D18).
- **Where:** the dimension line's midpoint `(Q0 + Q1) / 2`, plus
  `nr · kDimTextGapPaperMm × scaleDenominator`, bottom-centre justified:
  **centred above the line** (decision 8) **[spec ruling]** (R-12: "above"
  is the reading direction's left, 1 paper mm from the line to the text's
  bottom). "Above" does not depend on which side of the measured points
  the line lies: a line below a wall has its text between the line and the
  wall, as drafting does.
- **Aligned and readable** (decision 8): `ur = readable(u)` reverses `u`
  when `u.x < −dimFormat.angular`, or when `|u.x| ≤ dimFormat.angular` and
  `u.y < 0`; otherwise `ur = u`. Text angles land in (−90°, 90°]: a line
  reads from the bottom of the page, and **exactly vertical reads upwards
  (+90°), from the right** **[spec ruling]** (R-11, the spike's open item
  8). The tolerance matters: a group turned −90° gives `u = (6.1e-17, −1)`,
  which without it would read from the left (spike `Q5e`, `Q5f`;
  M-flip-tol red: `Expected … 90 Actual: <-90.0>`). `dimFormat` is D9's
  named tolerance; its angular part, 1e-9, bounds `|u.x|` for a unit `u`,
  about 1e-9 rad of the vertical.
- **The stored rotation** is the world angle `atan2(ur.y, ur.x)` minus the
  group's world rotation `atan2(M.b, M.a)`, plus `0.0` (10's normalisation
  of `-0.0`); the payload's scalars are `[height / s, rotation, 1, 0]`.
- **The string** is D9's format of D6's value in the page's unit; the
  planner rewrites it on a match (10 D12).
- **Under a mirrored group** (only a file makes one) the text is not kept
  readable; recorded, as 10's labels.

**Pinned by:** `DL3`, `DL4`, `DO2`, `RR1`; M-11b, M-11fliptol, M-11flip,
M-11textbelow.

### D9 — The value's format

`formatDimension(mm, unit)`, the page's display unit (decision 7), no
unit symbol, `.` as the decimal separator, no grouping:

| Unit | Quantum | Text | Examples |
|---|---|---|---|
| mm | 1 mm | the integer | `3450`, `3451` (3450.5) |
| cm | 0.1 cm = 1 mm | one decimal, **always** | `345.0`, `345.6` |
| m | 0.01 m = 10 mm | two decimals, always | `3.45`, `14.00`, `1.01` (1005 mm) |
| in | 1/8 in = 3.175 mm | whole inches, then a reduced fraction; **no mark** | `136 3/8`, `136 1/2`, `0 1/4`, `136` |
| ft-in | 1/4 in = 6.35 mm | `F'-I"` or `F'-I N/D"`, fraction reduced | `11'-4 1/4"`, `12'-0"`, `0'-0 1/2"` |

- **Round-half-up, decided robustly** **[spec ruling]** (R-13, the spike's
  open item 7). `roundHalfUp(mm, quantumMm)`: `x = mm / quantum`, `n =
  floor(x)`; if `|mm − (n + 0.5) · quantum| ≤ dimFormat.linear` the value
  is on the half and the result is `n + 1`; otherwise `round(x)`. The
  quantum is in millimetres (1, 1, 10, 25.4/8, 25.4/4), so the half is
  decided in the unit the geometry has. `dimFormat = Tolerance(linear:
  1e-6, angular: 1e-9)`: one `wallJoin.linear`. **Why a tolerance:** a
  length meant to end on a half arrives as a computed double a few ulps
  off it, below it about half the time; an imperial half is never exact
  (1/16" is 1.5875 mm, which has no double), and exact rational arithmetic
  on the stored double would decide those halves as the naive rule does.
  The spike's `Q5c`:

  ```
  1005 mm in m: 1005.0 mm -> naive 100, half-up 101, want 101
  3/16": 4.762499999999999 mm -> naive 1, half-up 2, want 2
  3/8": 9.524999999999999 mm -> naive 1, half-up 2, want 2
  hypot(18.9, 25.2): 31.499999999999996 mm -> naive 31, half-up 32, want 32
  far-origin hypot(0.3, 0.4): 0.4999999998882413 mm -> naive 0, half-up 1, want 1
  3450.5 - 2e-6: 3450.499998 mm -> naive 3450, half-up 3450, want 3450
  ```

  and through the real object, a free wall 3450.5 long face to face
  (`Q5d`): measured `3450.5000000000186` at the corpus far origin and
  `3450.499999984674` at +1e9 mm, both `3451`. M-11e (truncate) is red
  everywhere, even on whole values (`Expected: '3900' Actual: '3899'` at
  the far origin).
- **What the tolerance costs, both ways** **[amended, revision 2, S-4]**.
  *Upwards:* a true length within 1e-6 mm **below** a half prints rounded
  up. For integer-millimetre geometry this cannot happen in mm, cm or m
  below 125 m (a true value below a half needs `|N − H²| ≥ 0.25` for mm and
  cm, so a distance of at least 0.125 / L; at least 1 for m), and the
  review's exhaustive search found none up to 20 m. In inches and
  feet-inches the half `(2n + 1) · 127/80` mm is not a multiple of 1/4 mm,
  so near-misses occur at room sizes: the review's run found the aligned
  pair (0, 0)–(2124, 1731), √(2124² + 1731²) = 2,740.02499988595 mm, 1.14e-7
  mm below 107 7/8", which prints `9'-0"` where exact half-up gives
  `8'-11 3/4"`, and (0, 0)–(4160, 2697) in inches, 6.46e-7 mm below a half,
  which prints `195 1/4`. A one-quantum difference on a sub-micron
  question. *Downwards:* an intended half computed between two attach
  points at +1e9 mm can be off by twice the spike's worst attach error,
  about 7.5e-7 mm (Q1: 3.77e-7 per point), so there the tolerance's margin
  is about 1.3×. **The tolerance stays at 1e-6 mm** **[spec ruling]**
  (R-32): exact arithmetic decides the intended halves wrongly (the spike's
  `Q5c`: 3/16", 1005 mm in metres, the 3-4-5 triangle), a smaller tolerance
  would drop the far-origin halves below that 1.3× margin, and a larger one
  would widen the imperial over-rounding band in proportion; the cost is a
  sub-micron over-rounding in inch units, recorded in D18 and pinned by
  `DF2`'s rows.
- **The cm trailing zero is kept** **[spec ruling]** (R-14): `345.0`, not
  `345`. Every unit then shows its plan precision in a fixed number of
  decimals, as metres keep `3.40`; a dimension's text does not change
  length as a wall moves across a whole centimetre.
- **Fractions are reduced; the inch and foot marks** **[spec ruling]**
  (R-15): inches are bare (`136 3/8`), since decision 7 says no unit
  symbol; feet-inches keep `'` and `"` because they are the notation that
  separates feet from inches (`11'-4 1/4"`, decision 7's own example), not
  a unit symbol. Whole inches with no fraction print no fraction (`136`,
  `12'-0"`); under one inch the whole part is written (`0 1/4`,
  `0'-0 1/2"`), as the spike's `Q5b`. Rounding happens on the total
  before it is split: 143 7/8" (3,654.425 mm) is 575.5 quarters, on the
  half, and prints `12'-0"`, never `11'-12"`.
- **No negative values:** D6's value is a length or an absolute component.

**Pinned by:** `DF1`–`DF3`; M-11e, M-11halfnaive, M-11cmzero, M-11reduce,
M-11marks.

### D10 — Which wall end point a point is

**Identification: re-derive from the resolved point, through the index**
**[spec ruling]** (R-16, the spike's open items 3 and 4). No feature id is
plumbed through the snap: a ring vertex index is not an identity (spike Q1:
`A/0/right ring index: free 3 of 4, in the Y 4 of 5`), and turning a vertex
into `(k, side)` needs the caps anyway. So neither the tool nor the grips
need the snapped entity (the render layer stays frozen, D1).

`attachCandidates(doc, index, q)` in `dimension_attach.dart`:

- **only while object snap (F3) is on**, and then **by position**
  (decision 23): any resolved point within the attach tolerance of a wall's
  attach point attaches, whether an object snap or the grid put it there;
  with F3 off, none, so every end is fixed. The tool and the grips see only
  the resolved point, so they behave the same;
- the walls: every live root-level group carrying `WallParams` that owns a
  child whose stored world box touches the square `q ± dimAttach.linear`
  (`SpatialIndex.forEachInRect` with `QueryFilter.rendering()`, the spike's
  (B)). A wall's attach points are vertices of its stored ring or its
  centreline's ends (D4, R-5), so its stored boxes hold them; no bound from
  reach would be safe (an acute mitre reaches far past a wall's reach, 10
  D16.5);
- **a vertex pre-filter** **[amended, revision 2, S-7]**: of those walls,
  only the ones with a stored child point (a ring vertex, or a centreline
  piece's end, from the child payloads mapped to world) within
  `dimAttach.linear` of `q` go on. Every attach point is such a stored
  point (D4, R-5), so the filter loses none (`AM1` compares with brute
  force); a hover over the middle of a wall, where a band's box holds the
  pointer but no vertex is near, stops here and builds no `WorldWall`;
- each remaining wall's six points among `wallsInDocument(doc, W)`'s walls
  (08's document adapter); a candidate is every `(W, k, side)` whose point
  lies within **`dimAttach.linear` = 1e-5 mm** of `q`, Euclidean.

**The attach tolerance, 1e-5 mm:** the snapped point is the stored local
ring mapped to world, the attach point is computed in world, and they
differ by rounding only: worst 4.3e-7 mm at +1e9 mm turned 23° in own
groups (spike `Q3a`), a 23× margin; M-attach-tol (1e-9) is red. Nothing a
person draws is 1e-5 mm apart. `dimAttach = Tolerance(linear: 1e-5,
angular: 1e-9)`.

**The choice among candidates: decision 19's order, with decision 22's
timing; the measure made exact** **[spec ruling]** (R-17: the measure
`σ` and its band; the timing is no longer a ruling but decision 22):

1. **The parallel measure:** for each candidate wall with world unit
   direction `d_W` (start to end), `σ_W = |u × d_W|`, the sine of the angle
   between the wall and the **measuring direction `u` of the kind being
   committed** (D6): aligned, `(P1 − P0) / |P1 − P0|` from the two resolved
   points; horizontal and vertical, the group's local x or y in world (at
   the tool, world x or y). A degenerate wall (length ≤ `wallJoin.linear`)
   has no direction and takes `σ_W = 1`, the least parallel.
2. **The most parallel:** `m = min σ_W`; keep the candidates with `σ_W ≤ m
   + dimAttach.angular`. A band around the minimum, not a pairwise
   tolerant comparison, so the order is total. Two walls meeting
   end to end in line (a 180° joint) are both parallel to a dimension
   along them, and fall to step 3.
3. **The lowest wall handle.**
4. **Face before centre**, then the lower `k`, then left before right (the
   spike's order). Within one wall only coincident points reach this step:
   a left-justified wall's right face is its centreline, so at a free end
   `(k, right)` and `(k, centre)` coincide, and `right` is stored.

**When it is decided** (decision 22, which supersedes decision 19's
"the second click"):

- **by the tool, at the commit** (the third click), for both ends, from the
  two resolved points and the committed kind's `u`: aligned, the pair's
  direction; horizontal or vertical, the group's local x or y (at the tool,
  world x or y). The candidates are gathered at the commit, against the
  document as it is then. On `AM3`'s outer corner the two timings differ:
  decided at the second click (`u` the pair's) it would store B/0/right,
  at the commit with Shift-horizontal it stores A/1/right; decision 22
  chose the second;
- **by an end-grip drop, for the dropped end only**, with the dimension's
  current kind and, for aligned, the other end's **current** world point.
  **The other end keeps its stored reference**: an edit of one end never
  silently re-attaches the other;
- **never** by a kind switch in the panel (D14), a wall edit, or a move: a
  stored reference changes only when a person re-picks that end.

**What it buys** (decision 19): a wall-length dimension, A/0/left to the L
corner, stores A/1/left, not B/0/left, even when B has the lower handle;
deleting B leaves it measuring A (A's corner squares); deleting A deletes
it. Which wall is stored shows only when the joint breaks or a wall is
deleted (spike `Q3e`: two dimensions to one corner, one stored on A, one
on B, read `3900` and `3900`; with B moved 500 mm off A's end they read
`4000` and `4401`).

**What else a snap can land on** (spike Q3): an opening's jamb (fixed,
`Q3b`), a Y's lobe vertex on the owner's ring (the index finds the two
walls whose points it is, `Q3d`), a T's butt corner (the stem's point,
`Q3d`), an X crossing (no snap at all, `Q3c`), furniture and drafted
geometry (fixed).

**Costs:** per call, one index rect query and the vertex pre-filter over
the touched walls' stored points; then, per wall that passes, one
`wallsInDocument` and six points: `Q3g (B) per click, 9 walls, 15
openings: 60.93 us (JIT)` (spike, without the pre-filter). The O(walls)
part runs only near a wall's vertex. The tool calls it at most once per
distinct resolved point (D12); `AM5` prints a click and `TL8` a hover path
at 600 walls.
**Pinned by:** `AM1`–`AM5`, `GE3`, `TL8`; M-11nearest, M-11attachtol,
M-11parallel, M-11lineardir, M-11centrefirst, M-11otherend, M-11snapoff,
M-11snaponly, M-11reachcull, M-11ownerring, M-11prefilter.

### D11 — Move and rotate; the linear axes

- **Dimensions are movable** by the select tool **[spec ruling]** (R-19,
  the spike's open item 14): `DimensionGrips.movable` is true, so a
  dimension moves and rotates like a box, not like an opening (08 D16) or a
  room (10 R-22). Its group transform takes the move (`t · node.transform`,
  as every group).
- **What that does** (decision 12, spike Q4):
  - a **fixed** end moves and rotates with the group (it is local);
  - an **attached** end never moves by itself: it is read from its wall
    (`Q4b`: moved (700, 0) the dimension reads `3081`, √(700² + 3000²) =
    3080.58; then rotated 37° about (0, 0), `5617`, √(2112.04² + 5204.30²)
    = 5616.53; the attached end within 1e-6 of (4000, 100));
  - a **linear axis turns** with the group (decision 17): rotating walls
    and dimensions together keeps every value (`Q4c`: `4100`, `3100`,
    `3764`, unchanged, the horizontal line still 800 from its point);
    rotating a both-ends-attached linear dimension alone turns its axis
    (`Q4e`: `4000` → `3464`, 4000 cos 30° = 3464.10);
  - the **offset** is unchanged (a local length; a rotation keeps the
    scale), so the line keeps its distance from its outermost point;
  - with world axes (M-11axisworld) `Q4a` read `1998` (3000 cos 30° − 1200
    sin 30°) and `Q4c` would change every linear value when the plan
    turns.
- **What the panel shows after a rotation** **[spec ruling]** (R-18,
  decision 17's "shows it as rotated"): for a linear kind whose group's
  world rotation, `atan2(M.b, M.a)` in degrees normalised to (−180°, 180°],
  satisfies `|angle| ≥ 0.05°` (the rounded number, not the printed string:
  `(-0.04).toStringAsFixed(1)` is `-0.0`; S-8), the Dimension section adds
  a read-only line **`Axes turned 30.0°`**, the angle to one decimal, under
  the switch; the switch
  still reads Horizontal or Vertical. An aligned dimension shows no such
  line (its direction is its points').
- **A dimension selected with its walls** moves with them and every value
  stays; **a dimension selected alone** moves its fixed ends only.
- **A mirrored or scaled group** comes only from a file; D6 and D8 cover a
  similarity (offset × scale, height ÷ scale); a mirror is a known limit
  (D8).

**Pinned by:** `DR1`–`DR5`, `SL1`, `PN3`; M-11movable, M-11axisworld,
M-11fixedworld, M-11attachedmoves, M-11scale.

### D12 — The Dimension tool (I)

- **A `PlacementTool` of three clicks** (decision 9), `DimensionTool`. It
  stays active after a placement; **not chained** **[spec ruling]**
  (R-25): after the commit it waits for a new first click, as 10's
  Separator tool. I joins `kShellLetterKeys`, the palette (after S) and
  `shortcut_guard.dart` (decision 10).
- **Every point resolves through the drawing tools' chain** (05 D4,
  `kDragSnapMask`): object snap (F3), then the grid, else the raw point.
  **The third point too** **[spec ruling]** (R-22): only its height along
  `n` (and, for linear, its side) is used, and snapping it to the grid or
  to geometry lines dimension lines up with each other, as a drawing
  tool's point does.
- **Shift** **[spec ruling]** (R-20):
  - at the **second** click, Shift is 05's ortho relative to the first
    point, as in every drawing tool; an object snap still wins over it;
  - at the **third** click, Shift means **linear** (decision 9) and ortho
    is off: `orthoBase` returns null once two points are placed, because an
    ortho-pinned third point would decide the drag side from the pinned
    point, not from where the person dragged (M-11ortho3);
  - **how the tool knows Shift** (S-8): `accept` and `hovered` do not
    carry it and `PlacementTool`'s `_lastShift` is private, so
    `DimensionTool` records `e.shift` in `onPointerMove` and
    `onPointerDown`, and the Shift key's down and up in `onKey`, each
    before calling `super`.
- **Click 1** stores `P0`, the resolved point. **Click 2** stores `P1`,
  unless the pair is **degenerate** **[spec ruling]** (R-23): `|P1 − P0| ≤
  wallJoin.linear`, or the two points' attach candidate sets share a wall
  end point. Then the click is ignored and the tool keeps waiting for the
  second point; a dimension of nothing is never made.
- **Click 3** commits. **The kind:** aligned without Shift. With Shift,
  **the side dragged to** **[spec ruling]** (R-21), in world (the group is
  the identity), with `[x_lo, x_hi]` and `[y_lo, y_hi]` the two points'
  spans and `q` the resolved third point:
  - `e_x` = how far `q.x` lies outside `[x_lo, x_hi]` (0 inside), `e_y`
    likewise;
  - `e_y > e_x` → **horizontal** (dragged above or below); `e_x > e_y` →
    **vertical** (dragged left or right); a tie (both 0 inside the span box
    included) → horizontal when `|dx| ≥ |dy|` (`(dx, dy) = P1 − P0`), else
    vertical;
  - if the chosen kind would measure ≤ `wallJoin.linear` (a vertical pair
    dragged above), **the other kind** is used, so the tool never makes a
    zero linear dimension from a non-degenerate pair.
  The comparisons are exact: they choose between two valid outcomes from a
  pointer position, the preview shows which, and a tie has no wrong
  answer.
- **The ends** (D10): candidates at `P0` and `P1` gathered at the commit,
  each end the rule's choice with the committed kind's `u`, or
  `FixedEnd(P)` (the world point, since the group is the identity).
- **The offset:** D6's `offsetFor(q)` with the committed kind (the between
  band and the sign bit included).
- **The commit:** `Compound([AddNodeCommand(group at the identity),
  SetComponentCommand<DimensionParams>(a, b, kind, offset)])` through
  `commit(ctx, …, needs: {structure, components, geometry})`: one undo
  step, in which the dimension generates. An `ArgumentError`, `StateError`
  or `DanglingReferenceError` from `execute` is caught and nothing is
  placed, as 07's, 08's and 10's tools do.
- **Esc** (decision 9, 05 D5): with one or two points placed it drops them
  and places nothing; with none, the shell returns to the select tool.
  Undo and redo are swallowed while points are pending (05 D3). **Enter**
  with one or two points pending does nothing (`finish` stays the default
  no-op) **[spec ruling]** (R-33, S-8): a dimension needs its third click.
- **The preview** **[spec ruling]** (R-24):
  - after click 1: the rubber band from `P0` to the resolved hover point,
    as the Line tool;
  - after click 2: the would-be dimension's five lines, in world, for the
    kind Shift selects now (a Shift press or release re-resolves, 05's
    `onKey`), computed from the same functions as `generate` (so the
    preview equals the committed children, `TL5`), each time the pointer
    or Shift changes, and painted from cached geometry, never recomputed
    per frame;
  - **attaching ends are marked:** a small ring (4 px radius, the preview
    colour) at each placed or hovered point that would attach, from the
    same `attachCandidates`, memoised per distinct resolved point and
    document change, and only while F3 is on;
  - **the would-be value in the status line:** `DimensionTool` exposes
    `ValueListenable<String?> notice`: the value alone, D9's string in the
    page's unit, exactly what the TEXT will read (`4.69`), while two points
    are placed; null otherwise and on deactivation. The tool's name is
    `Dimension`, and the shell's `_statusLine` (`main.dart:321-326`) builds
    `'$base — $notice'`, so the status line reads **`Dimension — 4.69`**
    (S-8: revision 1's `Dimension: <value>` notice would have read
    `Dimension — Dimension: 4.69`). The shell merges the notice as 10's
    Room tool notice (`main.dart:277-279`). No text is drawn in the canvas
    preview (the overlay has no text path).
- **Fixed points** (decision 23, rewording revision 1's "unsnapped
  points", S-3): with F3 on, a resolved point that is not within
  `dimAttach.linear` of a wall end point (a jamb, furniture, another
  dimension, the middle of a face) gives a fixed end, however it was
  resolved; a grid point that lands exactly on a wall end point
  **attaches**, as an object snap there does. With F3 off every end is
  fixed (decision 4).
- **Costs:** a hover computes at most one attach search per distinct
  resolved point (`DimensionTool.debugAttachSearches`), which the vertex
  pre-filter (D10) stops before any `WorldWall` unless the point is near
  a stored vertex, and the preview's layout per pointer move. `TL8` walks
  a hover path along the middle of a wall among 600 walls and asserts that
  no wall passes the pre-filter there (a counter), and prints the time per
  move, **recorded against a budget of 1 ms per move** (printed, not
  asserted; the plan records the figure).

**Pinned by:** `TL1`–`TL8`; M-11shift, M-11dragside, M-11zerokind,
M-11ortho3, M-11snapoff, M-11snaponly, M-11notice, M-11degeneratepair,
M-11twosteps, M-11key, M-11prefilter.

### D13 — Grips

`DimensionGrips` (`dimension_grips.dart`), constructed by the shell with
its `SpatialIndex` and an object-snap callback, dispatched by
`ObjectGrips` on `DimensionParams`. Every coordinate is world; every grip
is a `stretch` grip, hit only when `components` and `geometry` are allowed
(07 `OG5`); `drag` receives the point the select tool already resolved
through the chain (08 Ruling 08-15). Ordinals **[spec ruling]** (R-26):

0. **the offset grip**, at the dimension line's midpoint `(Q0 + Q1) / 2`:
   `drag(q)` stores `offsetFor(q)` (D6) with the dimension's **current**
   kind, which the grip never changes; one `SetComponentCommand`, one undo
   step; null when the new offset `compareTo`s equal to the stored one;
1. **the end grip at `a`**, at `P0`; 2. **the end grip at `b`**, at `P1`:
   `drag(q)` makes the dropped end D10's choice at `q` (decisions 22 and
   23: by position, with the dimension's current kind and the other end's
   current point; the other end kept),
   or `FixedEnd(toLocal(q))` when there is no candidate (F3 off, or no
   wall end point there): an end **attaches, detaches or moves to another
   wall end point** (decision 11). The offset is kept, so the line keeps
   its distance from the outermost point. Null when the new end equals the
   stored one, or when the result would be degenerate (the two ends'
   points within `wallJoin.linear`, or the same wall end point).

`preview` draws the would-be five lines, in world, computed once per
pointer move. **No attach ring during a grip drag** **[spec ruling]**
(R-34, S-8): `preview` returns entities in world and knows no camera, so it
cannot size a screen-sized ring, and the render layer is frozen (D1); the
select tool's own snap marker shows where the drop resolves, and the
Dimension section's end lines (D14) show the result. A broken dimension
(D15) has no grips.

**Pinned by:** `GE1`–`GE5`; M-11otherend, M-11gripoffset, M-11gripplace,
M-11runtime, M-11previewkind.

### D14 — The Dimension section

In the Selection panel, shown when **exactly one** selected key is a
root-level group carrying `DimensionParams` (10 D21's rule). No tool mode:
the Dimension tool has no settings.

- **Value**, read-only: the dimension's TEXT child's stored string
  (decision 13's "as displayed"; 10 R-25's pattern), or `—` for a broken
  dimension.
- **Aligned | Horizontal | Vertical**, a `SegmentedButton` like the Wall
  section's Justification toggle. A click on another kind is **one**
  `SetComponentCommand<DimensionParams>` with only `kind` changed: **the
  ends and the offset are kept** **[spec ruling]** (R-27). So a switch and
  the switch back restore the stored children exactly, and the line keeps
  its distance from its outermost point along the new measuring
  direction's normal; where the new normal points the other way (an
  aligned pair drawn right to left switched to horizontal), the line moves
  to the other side, and the offset grip moves it back. A click on the
  current kind issues nothing. Ends are not re-decided (D10). A refused
  edit is caught, as the Justification toggle's.
- **Axes turned N°**, read-only, only as D11 says.
- **End 1** and **End 2**, read-only lines **[spec ruling]** (R-28): an
  attached end reads `Wall <handle hex>, <start|end>, <left face|centreline|right face>`
  (for example `Wall 1A, end, left face`); a fixed end reads `Fixed`. No
  control: re-picking an end is the end grip's (decision 11).
- **Read-only unless** `components` and `geometry` are allowed (07 `WS8`).
- **Keys:** `dimension-section`, `dimension-value`, `dimension-kind` with
  `dimension-aligned`, `dimension-horizontal`, `dimension-vertical`,
  `dimension-axes`, `dimension-end-1`, `dimension-end-2`.

**Pinned by:** `PN1`–`PN5`; M-11kindoffset, M-11sectionmulti, M-11axesline,
M-11endlabel, M-11panelrw.

### D15 — Diagnostics

`DimensionType.diagnose`, each code at most once per dimension:

- **`dimension.degenerate`**, warning **[spec ruling]** (R-29): D6's value
  is ≤ `wallJoin.linear` (the two points coincide for aligned; the
  component is zero for linear, as after a rotation or a wall edit). It
  still draws (D7). Message: `"<handle> measures zero"`.
- **`dimension.broken`**, error: an attached end names a live object that
  is not a wall, or a `k` outside {0, 1}, or a fixed coordinate or the
  offset is not finite. Only a file makes one; `generate` makes nothing
  (D7). An attached end naming a handle that is not a live object at all
  is the engine's `parametric.dangling` (08 D5), which the dimension does
  not repeat.
- **Collisions are not reported** (decision 21).

**Pinned by:** `DD1`, `DD2`; M-11degenerate, M-11broken.

### D16 — Draw order, undo, save and load

- **Ascending handle value** (06 D12): a dimension's six children are
  reserved in generation order, so its text draws over its lines; a
  dimension placed after the walls draws over them.
- **Handles are kept across every regeneration**: five LINEs matched by
  ordinal, one TEXT by ordinal, a zero dimension included (R-9).
- **Undo of a cascade** restores the dimension with every handle and owner
  (spike `Q2c`: `18 entities restored with their handles and owners; undo
  depth 6 -> 5`); the node is re-linked last among the root's children, as
  08's and 10's, and draw order, which follows handles, is unaffected.
- **Save → load → save is byte-identical**, references intact, `drift()`
  empty after load (spike `Q2d`), a `-0.0` offset included (D2).
- **The same state plus the same edit gives the same bytes** (06 D11).
- **Platform** (07 D13): no test pins a literal hash of rotated geometry.

**Pinned by:** `DO3`–`DO5`, `DN3`.

### D17 — The sample plan

Decision 15 on 08 D18's plan (walls: exterior 250 mm centred on the
rectangle (12,125, 8,125)–(25,875, 16,875), faces at x 12,000 / 12,250 and
25,750 / 26,000, y 8,000 / 8,250 and 16,750 / 17,000; partitions 120 mm,
±60 about their centrelines). **Added after the rooms, through the plan's
system, before it is disposed**, each in its own root-level group at the
identity, as the tool adds one, in this order **[spec ruling]** (R-30):

| Dimension | End a | End b | Kind | Offset | Line | Value, 1:50 m |
|---|---|---|---|---|---|---|
| overall width | E1/0/right (12,000, 8,000) | E1/1/right (26,000, 8,000) | horizontal | −500 | y = 7,500 | 26,000 − 12,000 = 14,000 → `14.00` |
| overall depth | E2/0/right (26,000, 8,000) | E2/1/right (26,000, 17,000) | vertical | −300 | x = 26,300 | 17,000 − 8,000 = 9,000 → `9.00` |
| Hall width | E1/0/left (12,250, 8,250) | P1/0/left (16,940, 8,250) | horizontal | +900 | y = 9,150 | 16,940 − 12,250 = 4,690 → `4.69` |
| Kitchen width | P1/0/right (17,060, 8,250) | P5/0/left (21,440, 8,250) | horizontal | +900 | y = 9,150 | 21,440 − 17,060 = 4,380 → `4.38` |
| Bath diagonal | E1/1/left (25,750, 8,250) | fixed: the basin's centre (22,300, 9,200) | aligned | 0 | through the points | √(3,450² + 950²) = √12,805,000 = 3,578.407 → `3.58` |

- **The ends are what the tool would store** (decision 19, D10), worked by
  hand:
  - (12,000, 8,000) is E1/0/right and E4/1/right, (26,000, 8,000) E1/1/right
    and E2/0/right, (12,250, 8,250) E1/0/left and E4/1/left: a horizontal
    dimension takes E1 (`σ` 0 against E4's or E2's 1);
  - (26,000, 17,000) is E2/1/right and E3/0/right: vertical takes E2;
  - (25,750, 8,250) is E1/1/left and E2/0/left; the diagonal's `u` is
    (−3,450, 950) / 3,578.407 = (−0.9641, 0.2655), so `σ` is 0.2655
    against E1 (east) and 0.9641 against E2 (north): **E1/1/left**, not
    E2/0/left as the spike stored it;
  - P1/0/left and P1/0/right are P1's T-butt corners on E1's inner face
    (x = 17,000 ∓ 60, y = 8,250; spike C5), P5/0/left likewise (x =
    21,500 − 60); no other wall's point coincides with them.
  So the width references E1, the depth E2, the Hall E1 and P1, the
  Kitchen P1 and P5, the diagonal E1.
- **Every kind and both end states** (decision 15): horizontal (width,
  Hall, Kitchen), vertical (depth), aligned (diagonal), attached (nine ends)
  and fixed (one). The plan has no angled wall, so the aligned one has a
  fixed end; it is on drafted geometry, the basin's centre (a `center`
  snap, `startup_plan.dart`'s `circleRegion(x0 + 10300, y0 + 1200, 220)`),
  which shows decision 1's "placed, not followed", and it is not a wall end
  point, so the tool would store it fixed. The spike's fixed point sat
  exactly on P5/1/right, where the tool would have attached it.
- **On the sheet.** The page is A4 landscape at 1:50 centred on the plan's
  extents: 14,850 × 10,500 mm about (19,000, 12,500), so x 11,575–26,425
  and y 7,250–17,750 (425 mm clear east and west of the walls, 750 mm north
  and south). The spike's 1,200 mm offsets put both overall dimensions off
  the sheet (its `r1` render). At 1:50: the width's line at y = 7,500, its
  extension lines reach y = 7,400 (100 past) and its text sits between the
  line and the wall (7,550 to 7,550 + 125 / 0.7 = 7,728.6, under the face at
  8,000); the depth's line at x = 26,300, its extension lines reach 26,400
  (< 26,425), its text (reading upwards, on the line's left) spans x
  26,250 down to 26,071.4, clear of the face at 26,000. The Hall and
  Kitchen keep the spike's 900 mm, which the human saw before decision 21.
  At 1:100 the depth's text runs from x 26,200 down to 26,200 − 250 / 0.7
  = 25,842.9 and overlaps the wall by 157.1 mm, a collision decision 21
  accepts (D18); the width's stays clear (7,600 to 7,957.1, under 8,000).
- **The same values in every unit** (for `SP9`, a page switched in one
  command; recomputed with the scratchpad's python reimplementation of D9):

| Dimension | mm | cm | m | in | ft-in |
|---|---|---|---|---|---|
| width, 14,000 | `14000` | `1400.0` | `14.00` | `551 1/8` | `45'-11 1/4"` |
| depth, 9,000 | `9000` | `900.0` | `9.00` | `354 3/8` | `29'-6 1/4"` |
| Hall, 4,690 | `4690` | `469.0` | `4.69` | `184 5/8` | `15'-4 3/4"` |
| Kitchen, 4,380 | `4380` | `438.0` | `4.38` | `172 1/2` | `14'-4 1/2"` |
| diagonal, 3,578.407 | `3578` | `357.8` | `3.58` | `140 7/8` | `11'-9"` |

  By hand, for the imperial columns: 14,000 / 25.4 = 551.181" → eighths
  4,409.45 → 4,409 = 551 1/8; quarters 2,204.72 → 2,205 = 551.25" =
  45 × 12 + 11.25; 9,000 → 354.331" → 2,834.65 → 2,835 eighths = 354 3/8;
  1,417.32 → 1,417 quarters = 354.25" = 29'-6 1/4"; 4,690 → 184.646" →
  1,477.17 eighths → 184 5/8; 738.58 → 739 quarters = 184.75" = 15'-4 3/4";
  4,380 → 172.441" → 1,379.53 eighths → 1,380 = 172 1/2; 689.76 → 690
  quarters = 172.5" = 14'-4 1/2"; 3,578.407 → 140.882" → 1,127.06 eighths
  → 140 7/8; 563.53 → 564 quarters = 141" = 11'-9". The nearest to a tie
  is the Hall's quarters (738.58, 0.08 of a quarter, 0.53 mm, from 738.5)
  and the Kitchen's eighths (0.028 of an eighth, 0.09 mm, above the half);
  both far above rounding at the sample's own placement.
- **The entity count** grows by 5 × 6 = 30, to **611** by this spec's
  count; the plan confirms it by running `SP1`, never by assuming it.
- **Tests:** `SP1` (611), `SP5` extended (the five dimensions' ends,
  kinds, offsets and values, compared exactly; `drift()` and
  `diagnostics()` empty), `SP8` (new: the table above at 1:50 m, the text
  heights 125, each dimension's references as listed, and a click on each
  dimension's line selects it), `SP9` (new: the page switched to 1:100
  ft-in in one command reads the ft-in column, heights 250, one undo step,
  undo restores the metres).

**Pinned by:** `SP1`, `SP5`, `SP8`, `SP9`; M-11a (the diagonal reads
`3.45` projected on x), M-11d, M-11d2.

### D18 — Known limits

- **Collisions** (decision 21): nothing avoids anything and nothing is
  reported. Two dimensions meeting across a partition cross their slashes
  (the Hall and Kitchen at P1, 120 mm apart; at 1:100 the 300 mm slashes
  overlap, spike finding 3); dimension text lands on room labels at 1:100
  (finding 4); the sample's overall depth text overlaps the wall face at
  1:100 (D17). The offset grip, and 10's label grip, fix each.
- **A near-vertical dimension's text changes side** as the plan turns
  through vertical (spike finding 5): decision 8 working; it looks like a
  jump.
- **Interior corner-to-corner extension lines lie on the perpendicular
  walls' faces** (finding 2), drawn along the band's edge and not seen.
  **And they take the wall's clicks there** **[spec ruling]** (R-35, S-12):
  `pickInto` returns the topmost entity in the pick radius
  (`spatial_index.dart:733`), and a dimension added after its walls draws
  above them, so a click on the Hall's extension line along E4's inner face
  (x 12,250, y 8,325 to 9,250) selects the Hall dimension, not E4. Kept: the
  wall is selected anywhere else along its band, and draw order stays
  ascending handle value (CLAUDE.md). `SL1` pins it; gate 16's look shows
  it.
- **No along-face or crossing points** (decision 4): an X crossing gives no
  snap (spike `Q3c`), a mid-face click is fixed.
- **Drafted geometry is not followed** (decision 1): an end on furniture
  keeps its point when the furniture moves.
- **The line never lies strictly between the two measured points' heights**
  (D6's between band).
- **Which wall a corner is stored on** shows only when a joint breaks or a
  wall is deleted (spike `Q3e`); decision 19 makes it the wall the
  dimension runs along.
- **An edit of a dimension regenerates its walls and their other
  referrers** (D5's cost bound), with empty plans; so does an opening edit
  for the dimensions on its host, and a partition edit for those on its
  through wall.
- **The half-up tolerance, both ways** (D9, R-32): in inches and
  feet-inches a true length within 1e-6 mm below a half prints rounded up
  (the review's `(0, 0)–(2124, 1731)`: `9'-0"` for a true 8'-11 3/4" and a
  hair); at +1e9 mm an intended half computed between two attach points
  keeps a margin of only about 1.3× on the tolerance. `DF2` and `DF3` pin
  both.
- **Inherited:** 07's wide node cluster (the document adapter the tool uses
  and the view `generate` uses can differ there; unreachable by snapping,
  10 D4's amendment); a mirrored dimension group (file only) does not keep
  the text readable, and under a mirrored **wall** group (file only) a
  stored `side` names the face on the other hand in world (S-5); a scaled
  wall group is covered (R-5). And the lineweight is measured in the test
  rasteriser with a capture matched to the view (D7), not on a device: the look judges it.

## The controller's readings, checked

| Reading | Verdict | Where |
|---|---|---|
| Everything on layer 0; roadmap 11's "fixed layer" deferred to 12 | **Agreed.** ByLayer on layer 0, the paper's foreground; `roadmap/12` gains the dimensions layer with its layer panel | D7, Files |
| No dimension `EntityKind`; lines and one `Generated.text` | **Agreed.** Five LINEs and one TEXT (the spike's `Q5a`: `line, line, line, line, line, text`) | D7 |
| References to up to two walls, policy cascade | **Agreed,** deduplicated when both ends are on one wall | D3 |
| Suspected engine need for the neighbour case | **Wrong,** as the spike found: `_closure` takes referrers of the whole core, which holds the seeds' neighbours; the neighbour case is rebuilt today (spike `Q2a`, `Q2b`), and taking referrers of the seeds only (M-11closure) goes red. No engine change; D5 states the invariant | D5 |

## What the roadmap and the spike asked 11 to decide

| Asked | Answer |
|---|---|
| Roadmap: the reference model | `(wall handle, k, side)`: a stable wall identity and a wall end, never a ring index; deleting the wall deletes the dimension (D2–D4) |
| Roadmap: which types in v1 | Aligned and linear (decision 2) |
| Roadmap: dimension style | Paper constants, no table (decision 6; D7) |
| Roadmap: arrowheads | The architectural slash (decision 5) |
| Roadmap: a fixed layer | Deferred to 12 (controller's reading; Files) |
| Roadmap: do rooms auto-dimension | No (decision 14) |
| Roadmap: text scales with camera or paper | Paper (decision 6; D8) |
| Roadmap decision 1 (a component holds what is measured and the style) | What is measured, yes; the style, no (constants) |
| Spike 1: the centre point | The stored centreline end (R-4) |
| Spike 2: which wall a shared point stores | Decision 19's order, decision 22's timing, the measure made exact (R-17) |
| Spike 3: how the tool identifies the point | Re-derive through the index, by position (R-16; decision 23) |
| Spike 4: the attach tolerance | 1e-5 mm (R-16) |
| Spike 5: linear axes, the panel, rotating alone | Local axes (decision 17); the axes line (R-18); allowed (D11) |
| Spike 6: the offset | From the outermost point, the side its sign bit, model units (R-2, R-6, R-7; decision 18) |
| Spike 7: half-up, cm, fractions, marks | 1e-6 mm; `345.0`; reduced; marks in ft-in only (R-13–R-15) |
| Spike 8: the flip | 1e-9, vertical reads upwards (R-11) |
| Spike 9: paper constants | The spike's, no default offset (R-10) |
| Spike 10: lineweight and the render layer | 0.25 mm: it survives decision 20's measurement once the capture matches the view; the spike's drop-out was its capture's (R-31, D7); the render fix stays a follow-up, to be re-measured first |
| Spike 11: degenerate cases and diagnostics | Six children kept, local x for a coincident aligned pair, `dimension.degenerate` and `dimension.broken` (R-8, R-9, R-29) |
| Spike 12: 07's second fallback | The attach point shares `localOutlineOf`'s decision (R-5) |
| Spike 13: collisions | Accepted (decision 21) |
| Spike 14: the select tool | Movable, pinned through the real tool (R-19, `SL1`) |
| Spike 15: option (b) and the invariant | Not adopted; the invariant stated (D5) |

## Architecture

### Files

- **Engine, `packages/jet_cad_2d`:** no change.
- **Render layer, `packages/jet_cad_2d_flutter`:** no change (decision
  20). Its gate stays green with only its standing failures.
- **App, `apps/floor_planner`:** D1's files. `dimension_geometry.dart` and
  `dimension_attach.dart` import no Flutter; `dimension.dart` may import
  `package:flutter/foundation.dart` for `@visibleForTesting`, as `room.dart`
  does. Of the existing app files only `wall_geometry.dart` (a new
  function; nothing existing edited), `catalog.dart`, `object_grips.dart`,
  `selection_panel.dart`, `main.dart`, `shortcut_guard.dart`,
  `startup_plan.dart` and the tests that pin their exact contents
  (`startup_plan_test.dart`'s count and `SP5`; the shell's letter list) may
  change.
  - Tests, new files: `dimension_params_test`, `dimension_attach_points_test`,
    `dimension_attach_test`, `dimension_layout_test`, `dimension_format_test`,
    `dimension_object_test`, `dimension_follow_test`, `dimension_fuzz_test`,
    `dimension_rotate_test`, `dimension_tool_test`, `dimension_grips_test`,
    `dimension_panel_test`, `dimension_paint_test`, and
    `test/support/dimension_fixture.dart` over 10's `room_fixture.dart`
    (its six placements).
- **Roadmap:**
  - `roadmap/12-app-shell.md` gains, under its open questions, "**A
    dimension style table** (11 decision 6: 11 ships fixed paper constants,
    D7)" and "**A layer for dimensions** (roadmap 11's fixed-layer question,
    deferred by 11: dimensions are on layer 0)";
  - the render follow-up that 10 recorded as R-17 gains D7's finding, in
    STATUS's debt list at the merge: its premise (an axis-aligned line
    painting no pixel) was measured with a capture below the view's device
    pixel ratio, and it is re-measured with a matched capture before the
    render layer changes;
  - `roadmap/11` is marked done at the merge, as usual.

### Amendments to earlier specs

| Section | Amended by | What changes |
|---|---|---|
| 05 D4 (points, ortho) | D12, R-20 | the Dimension tool turns ortho off at its third point, where Shift means linear |
| 07 D6 (the fallbacks) | D4, R-5 | `drawnCapsOf` reads `localOutlineOf`'s local-ring decision for the caps; the stored ring is unchanged |
| 08 D2, D3 (references) | D3, D5 | a second referrer type; a wall's `generate` already filters its referrers to `OpeningParams` (`openingsInView`), so it ignores dimensions |
| 08 D16 (movable) | D11, R-19 | a dimension is movable; the one movable rule (08's F2) is unchanged |
| 10 D19, R-29 (the status notice) | D12, R-24 | the status line merges a second tool's notice |

### Invariants

- **The frame path allocates nothing new.** Attach searches, layouts,
  previews and the panel run on edits, pointer moves and selection
  changes; the preview and the attach rings are painted from cached
  geometry. The render layer is untouched and its allocation tests stay
  green, unedited.
- **Draw order is ascending handle value;** a dimension's children keep
  their handles (D16).
- **Decisions use `dimAttach`, `dimFormat` and `wallJoin`; stored values
  use exact `==`** (the offset by `compareTo`, D2).
- **Generation reads parameters, never geometry,** and only what D5's
  invariant lists.
- **An edit never leaves a dimension naming a dead wall** (cascade, D3).
- **`packages/` is untouched** (`git diff 9774a55 -- packages/` empty).

## Testing

CLAUDE.md's bar: a test lands only if a named mutant turns it red. **A
horizontal dimension along a free, centre-justified wall at the origin,
from its start's centreline end to its end's, in a group at the identity,
is this feature's degenerate fixture**: it cannot tell aligned from linear
(the roadmap's trap), local axes from world axes, an attached end from one
the group moved, a mitred corner from a square end, left from right, or a
face from the centreline. It may appear only as a recorded control.

**Required fixture properties,** each carried by at least one relational
test:

- **placements** (10's six): the origin; the corpus's far origin
  (4,500,000, 1,200,000) turned 23°; the same with **every wall in its own
  rotated, translated group**; +1e9 mm on both axes turned 23°, unturned,
  and turned in own groups; the **dimension's own group** at the placement;
- **a non-axis rotation** of the dimension group itself (30°, 37°), and one
  group at a rotated, translated, **scaled** similarity (file-only);
- **a non-axis-aligned dimension** (the roadmap's trap): the pair (0, 0),
  (3000, 1200); the sample's diagonal;
- **every joint kind** (D4's C1–C11), **`k = 1` and face sides** on every
  relational test's ends (M-11d, M-11d2);
- **non-default attributes:** left- and right-justified walls, mixed
  thicknesses (60–400), a ft-in page at 1:100, a negative offset, a `-0.0`
  offset, F3 off;
- **openings in the measured walls** (the sample plan's fifteen).

**Oracles, not counts alone:**

- **expected values by hand**, the arithmetic in the test (the roadmap's
  trap: never the code under test);
- **the all-walls oracle** of `DZ1` as a differential check of the closure;
- **`drift()` empty** after every edit of every relational test (D5's
  argument checked);
- **pixels through the shell** for the text heights and the lineweight
  (the spike's capture method), **captured at the view's device pixel
  ratio** (R-31): a capture below it draws every stroke at a fraction of
  its device width and invents drop-outs (D7).

### Tests by area

Identifiers are this spec's; the plan may renumber, keeping the kills.

**Placements per test:** all six for `AP1`, `AP3`, `DL1`, `DF3` and `DR1`;
the origin, the corpus far origin in own groups and +1e9 mm in own groups
for `AM1` and `DN1`; at least the origin and the corpus far origin in own
groups for every other relational test; the sample plan's own placement
(off-origin, not symmetric, 08 D18) for `SP*`, `SL1` and the renders.

- **Parameters:** `DP1` round trip, key order, both end shapes, exact
  `==`, `-0.0` ≠ `+0.0` in `==` and kept through save → load → save,
  `references` deduplicated.
- **Attach points (pure):** `AP1` C1–C10 against the hand table, worst
  error printed, bound 1e-6 mm; `AP2` C11: A's four face points equal its
  stored free rectangle's corners mapped to world within `dimAttach.linear`
  and differ from `capsOf`'s joined corner by more than 1 mm (premises
  asserted: A's world outline simple, its local image not, A reports
  `wall.fallback`), and `drawnCapsOf`'s `fellBack` equals
  `localOutlineOf`'s on every `AP1` fixture and 07's `WR13` sweep; as a
  premise, C9's A falls back in step 1 (`capsOf(...).fellBack` true), so
  M-11fallback's site is reached (S-2); and a C11 variant whose wall groups
  are also scaled 1.5 (file-only): the points are still the stored
  rectangle's corners (S-5); `AP3` every face point is a vertex of the
  stored ring, in world, within 1e-9 of it at the far origin in own groups.
- **Identification:** `AM1` all 60 wall end points of `samplePlan`
  (`room_fixture.dart`: ten walls, the column's free-wall points included,
  fifteen openings; S-9), each snapped through the real `snapInto` from 5 mm
  away: the candidate set through the index equals the brute-force set
  (every wall, every point within `dimAttach.linear`), and the decided end
  equals decision 19's rule restated in the test over the brute-force
  set, for a horizontal and a vertical `u`; `AM2` the jamb (fixed), the Y
  lobe vertex (B/0/left and C/0/right found), the T butt corner (the
  stem's), the X crossing (no snap, fixed), with the candidates taken through the index,
  not from the snap's owner; `AM3` decision 19: an L whose **vertical** wall
  B has the **lower** handle — along A (horizontal or aligned) the corner
  is A's, along B it is B's; the outer corner (4100, −100) to (3000, 3000):
  aligned stores B/0/right (`u` = (−1,100, 3,100) / 3,289.4, so `σ` is 0.334
  against B and 0.942 against A), Shift-horizontal
  A/1/right; two collinear walls end to end, the lower handle; a
  left-justified wall's free end, `right` before `centre`; `AM4` decision
  23 (S-3): a page with a fixed 500 mm grid and a pointer placed so that
  no object lies within the snap aperture and the grid resolves it to the
  sample's outer corner (12,000, 8,000) (the review's case: at 0.052 px/mm
  the aperture is 10 px = 192 mm); with F3 **on** that grid point attaches
  (E1/0/right for a horizontal dimension); with F3 **off** the same point
  gives no candidate and stays fixed; `AM5` the
  attach search per click among 600 walls (JIT, median of five, printed,
  not asserted).
- **Layout and value (pure and object):** `DL1` the pair (0, 0), (3000,
  1200): aligned `3231` (√(3000² + 1200²) = 3,231.1), horizontal `3000`,
  vertical `1200`; `DL2` the outermost rule (spike `Q4d`: the line 2,400
  below A/0/right and 500 below the fixed point, then 500 below the
  thickened face and 700 below the point) and `offsetFor` on the pair (0,
  0), (3000, 1200), horizontal: `q` at y 2,000 → +800; y −300 → −300; y 900
  → `+0.0` (line at 1,200); y 400 → `-0.0` (line at 0); `DL3` the children
  by hand, fixed (0, 0) and (4000, 0), horizontal, offset 600, mm page:
  at 1:50 the line (0, 600)–(4000, 600), extension lines (0, 75)–(0, 700)
  and (4000, 75)–(4000, 700), slashes (∓53.033, 600 ∓ 53.033) about each
  end (75 / √2), text at (2000, 650), height 125, rotation 0, `4000`; at
  1:100 the gap 150, overshoot 200, slash ±106.066, text at (2000, 700),
  height 250; the same pair drawn right to left and aligned: its line at y
  −600, its text above it at −550, angle 0; `DL4` `readable` (the spike's
  `Q5e` table) and a vertical dimension in a group turned −90° reading
  +90° (`Q5f`); `DL5` a coincident aligned pair and a vertical pair
  measured horizontally: six children, `0`, `dimension.degenerate`.
- **Format:** `DF1` D9's table in every unit (the spike's `Q5b` rows,
  `345.0`, `136 1/2`, `12'-0"`, `0'-0 1/2"`, a carry to the next foot);
  `DF2` the `Q5c` rows and the tolerance's contract both ways (S-4):
  3450.5 − 0.9e-6 mm → `3451` beside 3450.5 − 2e-6 → `3450`, and the
  review's aligned pair (0, 0)–(2124, 1731) in ft-in → `9'-0"`, the
  recorded over-rounding (R-32); `DF3` `Q5d` through the object at all six
  placements, and a half between **two computed corners** (S-4): A
  (0, 0)→(3550.5, 0) and B north from A's end, both 200, A/0/left →
  A/1/left = 3,550.5 − 100 = 3,450.5 → `3451` at all six placements, the
  distance from the half printed (the far-origin margin).
- **The object:** `DO1` children kinds and order (`line` × 5, `text`),
  lineweight 25, ByLayer, layer 0, the TEXT's `textAttrs`, at the corpus
  far origin in own groups; `DO2` a page change 1:50 m → 1:100 ft-in in one
  command (`Q5a`: `13'-1 1/2"`, height 250, the same child handles, one
  undo step, undo restores `4000` and 125), a paper colour or grid change
  calls no dimension `generate`, and no page reads 1:50 m; `DO3` save →
  load → save byte-identical with references intact and `drift()` empty;
  `DO4` the same state and edit give the same bytes; `DO5` handles across
  twenty regenerations, undo and redo.
- **The closure:** `DN1` the spike's `Q2a` at three placements (B 200 → 300
  moves A's mitre: `3900` → `3850`, exactly one generate, A's parameters
  `==` unchanged; C joined at A's start: `3750`; C deleted: `3850`); `DN2`
  `Q2b` (the T: `2900` → `2800` with the through wall at 400; `3000` once
  its group moves 50 mm off the stem); `DN3` `Q2c` (a referenced wall
  deleted: the dimension goes in the same step, the other one rebuilds
  `3100` → `3000`; undo restores every handle and owner); `DN4` the cost
  bound: an edit of a wall that is neither a referenced wall nor a
  neighbour of one calls no dimension `generate`; an offset change of one
  dimension regenerates exactly the dimensions on its walls; and, printed
  not asserted (S-6), the generate counts for a door slid along a wall that
  carries N = 1, 10, 50 dimensions and for a thickness change of a
  partition T-joined to it.
- **The fuzz:** `DZ1`, D5's.
- **Move and rotate:** `DR1` `Q4a` at six placements (fixed-fixed, 30°:
  `3000` and `3231`, the line at the placement's angle + 30°); `DR2` `Q4b`;
  `DR3` `Q4c`; `DR4` `Q4e`; `DR5` a dimension group at a similarity
  turned 30°, translated and scaled 1.5 at the corpus far origin: the
  world offset is 1.5 × the stored one, the text is 125 world mm tall.
- **The tool:** `TL1` three clicks, one undo step; ends on wall end points
  attach, others are fixed; `TL2` Shift at the third click by drag side
  (above → horizontal, right → vertical, a corner quadrant by the larger
  excess, a tie by the larger component, a vertical pair dragged above →
  vertical), no Shift → aligned, and ortho: with Shift, `P0` (0, 0), `P1`
  (3000, 1200), the raw third point (1500, 1400) commits horizontal with
  the line at y 1,400 (offset +200), where an ortho-pinned point (1500,
  1200) would give 1,200; at the second click Shift still pins; `TL3` the
  third click's offset: outermost, between band, sign bit; `TL4` Esc after
  one and after two points places nothing, and Esc again returns to the
  select tool; a second click on the first point is ignored; `TL5` the
  preview's five lines equal the committed children in world within 1e-9;
  the status line reads `Dimension — 4.69` (the notice `4.69`) over the
  Hall's corners, and the notice clears
  after the commit and on deactivation; attach rings appear only at
  attaching points; `TL6` decision 23 through the tool: with F3 on
  a grid point landing on a corner attaches (as `AM4`), with F3 off every
  end is fixed; Enter with points pending does nothing; `TL7` I switches
  to the tool, and typing I in a panel text field does not; `TL8` hover
  cost at 600 walls, printed, and one attach search per distinct resolved
  point (`debugAttachSearches`).
- **Grips:** `GE1` three grips at the line's midpoint and the two
  measured points, in world, under a turned group; `GE2` the offset grip
  (outermost, between band, sign bit, kind unchanged, one step, no-change
  null); `GE3` end grips: attach a fixed end to a wall end point, detach an
  attached one (a drop on no candidate, and a drop on the same corner with
  F3 off), move one to another wall's point; on the L of `AM3`, a
  dimension whose corner end is stored on A, switched to vertical in the
  panel, then its **other** end dragged: the corner end stays A/1/left;
  `GE4` a degenerate drop and a runtime document return null or are not
  hit; `GE5` the preview equals the committed lines.
- **The panel:** `PN1` the section shows for exactly one dimension, with
  the value as the TEXT reads; `PN2` each kind click is one step with the
  ends and offset unchanged, and switching back restores the children bit
  for bit; the current kind issues nothing; `PN3` `Axes turned 30.0°` after
  a 30° rotation of a linear dimension, none for aligned, none at 0°;
  a rotation of 0.04° shows none and 0.06° shows `Axes turned 0.1°`
  (S-8); `PN4` the end lines for an attached and a fixed end; `PN5` read-only
  under runtime; a refused edit leaves the switch on the model's kind.
- **The select tool:** `SL1` through the real select tool on the sample
  plan: a click on a dimension's line selects it; a body drag moves it
  (the diagonal's fixed end moves, its attached end stays); a rotation
  grip shows for a dimension alone; walls selected with their dimensions
  move and every value stays; deleting a dimension; deleting E1 deletes
  the width, Hall and diagonal dimensions in one step; a click on E4's
  inner face at (12,250, 8,800), under the Hall's extension line, selects
  the Hall dimension (R-35, S-12).
- **Diagnostics:** `DD1` `dimension.degenerate`; `DD2` `dimension.broken`
  from a file (a live box as a wall, `k = 2`, a NaN point, a NaN offset),
  childless, and a dead wall handle reported `parametric.dangling` only.
- **Renders (the shell in `flutter_test`):** `RR1` the text's world height
  the same at 0.15 and 0.3 px/mm, and doubled at 1:100 (the spike's `R2`,
  `R2c`), a slash inked, the extension gap; it is M-11b's camera half's
  killer (S-11); `RR2` D7's sweep on the built
  dimension at 0.25 mm, captured at the view's device pixel ratio: no
  frame loses a line. `RR2` is **the measurement of record** for decision
  20, asserted and printed; no mutant of the product can make a matched
  capture lose a line (set-ups 2 and 3 kept even 0.18 mm), so the weight
  itself is pinned by `DO1`'s record check (M-11lw); `RR3` on Blueprint paper
  the dimension ink is the foreground.
- **Recorded measurements, not tests** (S-10): `RR2`, `AM5`, `TL8`'s time
  and `DN4`'s printed counts are measurements of record, printed and kept
  in the results note; no mutant is owed for them. `DO4`, `DO5` and `SP1`
  are carried gate pins (06 D11's determinism, 06 D12's handles, 10 D23's
  entity count), whose mutants belong to those plans.
- **The sample plan:** `SP1`, `SP5`, `SP8`, `SP9` (D17).

### Named mutants

Each is fired with a `cp` backup, restored with `cp`, then `diff` against
the backup and `git diff --quiet` (never `git checkout`), and logged in
`plan-11-mutation-log.md`.

**From the roadmap** (M-11a–e, carried or redefined):

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-11a | aligned computed as the axis-projected distance | `DL1` (3000 for 3231), `SP8` (the diagonal `3.45`), `DZ1` |
| M-11b | **the paper half:** the text height not multiplied by the page's scale (spike M-page-height) | `DO2`, `RR1` |
| M-11b-cam | **the camera half, as the roadmap states it** (S-11): a **render-layer** mutant, the painter's TEXT height divided by the camera's scale in `jet_cad_2d_flutter`'s text path (the plan names the site), fired with a `cp` backup and restored, as M-11closure and M-11text are fired in the frozen engine; the render package's `lib` is unchanged at the gate | `RR1` (the text's world height at 0.15 and 0.3 px/mm) |
| M-11c | the value computed once per dimension and reused (a memo by handle), never recomputed | `DN1`, `DN2`, `DZ1` |
| M-11d | **redefined for `(wall, k, side)`:** an attached end resolved by its wall handle and side only, `k` ignored (always the start) | `AP1` (every `k = 1` row), `SP8` (E1/1/right) |
| M-11d2 | **new, the other half of "by handle only":** `side` ignored (always the centreline end) | `AP1`, `SP8` |
| M-11e | truncate instead of half-up | `DF1`–`DF3` |

**From the spike** (carried, renamed; with M-11a, M-11b's paper half, M-11d
and M-11e above, all 22 of the spike's mutants are carried):

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-11nbrs | the neighbours ignored (`capsOf(w, const [])`), also the raw face end | `AP1`, `DN1` |
| M-11swap | the `k = 1` swap of outgoing sides dropped | `AP1` |
| M-11swapjust | left and right swapped for right-justified walls | `AP1` (C4) |
| M-11fallback | **redefined (S-2):** no fallback at all in `drawnCapsOf`, both steps returning the joined caps. Step 1 alone removed is equivalent on every fixture (D4; the review's run: 0 of 258 points differ) and is not fired | `AP1` (C9: A/0/left (100, 100) for (0, 100)) |
| M-11centremid | centre = the cap's midpoint | `AP1` (C4, C5, C5c) |
| M-11closure | engine: referrers of the seeds only (08's brief rule) | `DN1`, `DN2`, `DZ1` |
| M-11refs | the dimension references nothing | `DN1`, `DN3` |
| M-11text | engine: a matched TEXT's string never rewritten (10's M-10f site, M-11c's effect) | `DO2`, `DN1` |
| M-11nearest | the nearest candidate instead of decision 19's rule, **ties to the lowest handle** (S-10: an L corner is bitwise one point for both walls, so the nearest ties) | `AM1` (the far placements), `AM3` (the L whose lower handle is the vertical wall) |
| M-11attachtol | attach tolerance 1e-9 | `AM1` (+1e9 mm) |
| M-11axisworld | linear axes in world, not the group's | `DR1`, `DR3`, `DR4`, `DZ1` |
| M-11offsetp0 | the offset from the first point, not the outermost | `DL2` |
| M-11fixedworld | fixed ends ignore the group transform | `DR2`, `DZ1` |
| M-11attachedmoves | attached ends moved by the group transform | `DR2`, `DR4` |
| M-11halfnaive | half-up without the tolerance | `DF1`, `DF2`, `DF3` |
| M-11fliptol | no tolerance at exactly vertical | `DL4` |
| M-11page | no page key | `DO2` |
| M-11lw | the lines' lineweight not 25 (the spike's M-lw18 site; decision 20's fallback 30 as the fired form) | `DO1` |

**New:**

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-11localring | the attach point ignores the local-ring fallback (`capsOf` alone) | `AP2` |
| M-11parallel | decision 19's parallel step skipped (the lowest handle first) | `AM3` (the L with the lower vertical wall) |
| M-11lineardir | a linear kind's parallel measure uses `P1 − P0` instead of its axis | `AM3` (the outer-corner case) |
| M-11centrefirst | centre before face | `AM3` (the left-justified end) |
| M-11otherend | an end-grip drop re-decides the other end too | `GE3` |
| M-11snapoff | ends attach with F3 off | `AM4`, `TL6` |
| M-11sign | the side taken as `offset < 0` (the zero's sign ignored) | `DL2`, `TL3` |
| M-11between | the between band always goes to the upper extreme | `DL2`, `TL3` |
| M-11dragside | horizontal and vertical swapped in the drag-side rule | `TL2` |
| M-11zerokind | the zero-measuring linear kind is committed | `TL2` |
| M-11ortho3 | ortho stays on at the third click | `TL2` |
| M-11shift | Shift ignored at the third click | `TL2` |
| M-11degeneratepair | a second click on the first point is accepted | `TL4` |
| M-11notice | no status notice | `TL5` |
| M-11gripoffset | the offset grip stores the drop's distance from the first point | `GE2` |
| M-11kindoffset | a kind switch resets the offset to zero | `PN2` |
| M-11movable | dimensions immovable by the select tool | `SL1` |
| M-11scale | the offset not multiplied by the group's scale | `DR5` |
| M-11flip | `readable` never flips | `DL3` (the right-to-left pair), `DL4` |
| M-11textbelow | the text on the line's other side (`−nr`) | `DL3` |
| M-11slash | the slash along `ur − nr` | `DL3` |
| M-11extpage | the extension gap and overshoot not multiplied by the page's scale | `DL3` (1:100) |
| M-11stable | a zero dimension generates fewer children | `DL5` |
| M-11cmzero | the cm trailing zero dropped | `DF1` |
| M-11reduce | fractions not reduced | `DF1` |
| M-11marks | feet-inches without `'` and `"` | `DF1` |
| M-11degenerate | `dimension.degenerate` never reported | `DD1` |
| M-11broken | a broken end generates from a fallback point instead of nothing | `DD2` |
| M-11snaponly | an end attaches only when an object snap won, never a grid point on a wall end point (the rule decision 23 replaced) | `AM4`, `TL6` |
| M-11prefilter | the vertex pre-filter drops a wall whose attach point is a stored vertex (the filter run on ring vertices only, not centreline ends) | `AM1` (every centre point), `TL8` (the counter) |
| M-11reachcull | candidate walls by reach instead of stored boxes | `AM1` (the outer corners lie outside every wall's reach) |
| M-11ownerring | candidate walls from the snapped entity's owner only (the spike's (A)) | `AM2` (the Y lobe vertex) |
| M-11negzero | the offset compared with `==` (the zero's sign lost) and `toJson` writing `offset.abs()` (two fired forms) | `DP1`, `DO3` |
| M-11vertex | a face point taken from its cap's second point, not its first or last | `AP3`, `AP1` |
| M-11colour | the lines and text generated in a `TrueColor`, not ByLayer | `RR3`, `DO1` |
| M-11axesline | the axes line never shown | `PN3` |
| M-11endlabel | the end lines print `k` swapped (start for end) | `PN4` |
| M-11sectionmulti | the section shown with two dimensions selected | `PN1` |
| M-11panelrw | the kind switch enabled under runtime permissions | `PN5` |
| M-11key | I missing from `kShellLetterKeys` | `TL7` |
| M-11twosteps | the tool commits the node and the component as two commands | `TL1` (two undo steps) |
| M-11gripplace | the offset grip at `Q0` instead of the line's midpoint | `GE1` |
| M-11runtime | the grips hit without `components` and `geometry` | `GE4` |
| M-11previewkind | a grip preview laid out as aligned whatever the kind | `GE5` |

**Retired from the spike:** its option-(b) switch
(`debugDimensionReadsPlaces`; not adopted, D5). Revision 1 also retired
M-11b's camera half as "not writable"; revision 2 carries it as
M-11b-cam, a render-layer mutant (S-11).

### Differential check

- **`drift()` is empty** after every edit in every relational test.
- **`DZ1`'s all-walls oracle** after each of 300 seeded edits, with
  neighbour-only rebuilds known to occur.
- **A reload agrees with the live document:** after `DZ1`, the saved bytes
  loaded into a fresh system give `drift()` empty and the same children.
- **The preview agrees with the object** (`TL5`, `GE5`): one layout
  function, compared in world.

## Exit gate

1. The four gate lines are green with `CI=true` **on the human's macOS
   machine** (engine, render layer with only its standing failures,
   harness, app), and `flutter build macos --release` and `flutter build
   web --release` are `✓ Built`. The Linux container's run is recorded as
   the Linux half; **the macOS half is owed by the human and never
   simulated.**
2. Every attach point equals its hand value to 1e-6 mm at every
   placement; the local-ring fallback's points are the drawn corners.
3. An aligned dimension on a non-axis pair reads the true distance, a
   linear one its component, at every placement.
4. Editing a measured wall or a neighbour of one updates every dimension on
   it in **one** undo step; undo and redo restore it exactly; `drift()` is
   empty; `DZ1` is green with neighbour-only rebuilds.
5. Deleting a referenced wall deletes its dimensions in the same step, and
   undo restores them with their handles.
6. Values format per unit with round-half-up at an exact half despite
   binary floating point; `345.0`, reduced fractions, `'` and `"` in
   feet-inches only.
7. The text is 2.5 paper mm at two camera scales and two page scales,
   centred above its line, readable from the bottom or the right, and
   upward at exactly vertical.
8. A page change regenerates every dimension in one step; a paper change
   regenerates none.
9. Save → load → save is byte-identical; references intact; `drift()`
   empty after load.
10. Linear axes are the group's: rotating a plan keeps every value, a
    linear dimension rotated alone turns its axis, and the panel says so.
11. The Dimension tool (I), its grips and its section behave as D10–D14
    say, decisions 19, 22 and 23 included.
12. The dimension lines are 0.25 mm, and `RR2`, captured at the view's
    device pixel ratio, shows no drop-out at the look's zooms.
13. `git diff 9774a55 -- packages/` is empty; the allocation invariants
    pass unedited.
14. The sample plan is D17's: five dimensions with their values, 611
    entities, `drift()` and `diagnostics()` empty.
15. Every named mutant is killed and logged in `plan-11-mutation-log.md`
    (M-11b-cam fired in the render layer and restored; M-11fallback as
    redefined in revision 2);
    `roadmap/12` carries its two lines.
16. **The human's look — owed by the human, never simulated:** on macOS,
    in Chrome and in Firefox: the Dimension tool's three clicks, its
    preview, Shift's linear choice, the attach rings and the status value;
    the sample plan's five dimensions at 1:50 and at 1:100, on White and on
    Blueprint; whether 0.25 mm reads, and never vanishes, beside the
    walls; the slashes, the text's size and its side on a vertical
    dimension; moving a wall, a joint breaking, deleting a wall, and undo;
    rotating the plan with its dimensions, and one linear dimension alone;
    the offset and end grips, and a grid drop on a corner attaching; the
    Dimension section's switch and end lines; the collisions decision 21
    accepts, and a click on a wall face under an extension line selecting
    the dimension (R-35).

## Spec rulings

Every place this spec resolved something the decisions leave open.

- **R-1** (D2) — a fixed end is stored in the group's local space; the
  tool places the group at the identity.
- **R-2** (D2, D6) — the offset's side is its sign bit (`-0.0` is a zero
  offset on the minus side); `==` compares the offset with `compareTo`.
- **R-3** (D2) — `fromJson` accepts anything well-typed; out-of-range `k`
  and non-finite values are reported, not refused.
- **R-4** (D4) — the centre point is the stored centreline end.
- **R-5** (D4) — the attach points read 07's local-ring decision, so an
  attach point is always the drawn corner.
- **R-6** (D6) — the offset is measured from the outermost measured point
  on the line's side, along the measuring direction's left normal; aligned
  heights are both zero by definition.
- **R-7** (D6) — the between band goes to the nearer extreme.
- **R-8** (D6) — a coincident aligned pair measures along the group's
  local x.
- **R-9** (D7) — six children, fixed order, kept for a zero dimension.
- **R-10** (D7) — the paper constants are the spike's; no default offset.
- **R-11** (D8) — `|u.x| ≤ 1e-9` is vertical, which reads upwards.
- **R-12** (D8) — the text's bottom 1 paper mm above the line's middle, on
  the reading direction's left.
- **R-13** (D9) — half-up decided within 1e-6 mm of the half, in mm.
- **R-14** (D9) — cm keeps its trailing zero.
- **R-15** (D9) — fractions reduced; inches bare; feet-inches keep `'` and
  `"`.
- **R-16** (D10) — attach points re-derived through the index at the
  resolved point, a vertex pre-filter first (revision 2, S-7), within
  1e-5 mm; when an end may attach is decision 23's.
- **R-17** (D10) — decision 19's parallel measure made exact: `σ = |u ×
  d_W|` with the committed kind's `u`, and a 1e-9 band around the minimum.
  *Revision 1's timing half (at the commit, the dropped end only, never by
  a kind switch) is now decision 22.*
- **R-18** (D11, D14) — `Axes turned N°` for a turned linear dimension,
  shown when `|angle| ≥ 0.05°` (revision 2, S-8).
- **R-19** (D11) — dimensions are movable by the select tool.
- **R-20** (D12) — Shift is ortho at the second click and linear at the
  third, where ortho is off.
- **R-21** (D12) — the drag-side rule, its tie, and the swap of a
  zero-measuring kind.
- **R-22** (D12) — the third point resolves through the chain.
- **R-23** (D12) — a degenerate second click is ignored.
- **R-24** (D12) — the preview: the rubber band, then the five lines;
  attach rings; the would-be value in the status line.
- **R-25** (D12) — the tool is not chained.
- **R-26** (D13) — the grips' places and ordinals; the offset grip keeps
  the kind.
- **R-27** (D14) — a kind switch keeps the ends and the offset.
- **R-28** (D14) — the end lines' wording, read-only.
- **R-29** (D15) — `dimension.degenerate` and `dimension.broken`.
- **R-30** (D17) — the sample plan's five dimensions: their ends (by
  decision 19), their on-sheet offsets, and the diagonal's fixed end on
  the basin.
- **R-31** (D7) — the rasteriser is measured with a capture at the view's
  device pixel ratio; so measured, 0.25 mm survives and decision 20's
  fallback is not taken.
- **R-32** (D9, revision 2, S-4) — the half-up tolerance stays 1e-6 mm,
  accepting a sub-micron over-rounding in inch units and a 1.3× margin at
  +1e9 mm, both recorded and pinned.
- **R-33** (D12, revision 2, S-8) — Enter with points pending does
  nothing.
- **R-34** (D13, revision 2, S-8) — no attach ring during a grip drag.
- **R-35** (D18, revision 2, S-12) — an extension line lying on a wall's
  face takes that stretch's clicks (topmost pick, draw order kept).

## Open questions for the human

**None.** Every item of the spike's open-decision list is closed by a
decision (17–23) or a ruling above. Revision 1's two findings that were
the human's (S-1, S-3) are answered by decisions 22 and 23. Each ruling a
person sees — the between band (R-7), the kind switch keeping the offset
(R-27), the drag-side tie (R-21), the panel's wording (R-18, R-28), the
sample's on-sheet offsets and basin end (R-30), a face click under an
extension line (R-35) — is part of gate 16's look, where the human can
overturn it. Decision 20's lineweight question was a measurement, made
(D7).

## Revision 2

The independent review of revision 1 (`a2ba486`; "Ready with amendments",
0 blocking, 3 major, 9 minor) and the human's decisions 22 and 23. Each
finding was checked against the spec, the code or the review's runs before
it was applied.

| Finding | Outcome |
|---|---|
| S-1 (major) decision 19's timing re-decided as a ruling | **Answered by the human: decision 22.** The choice is made at the commit with the committed kind's direction, and at an end-grip drop for the dropped end with the current kind. R-17 keeps only the measure `σ` and its band; decision row 19 is marked superseded in its timing, row 22 added; D10's "When it is decided" cites decision 22 and shows the two timings' outcomes on `AM3`'s fixture; D13 cites it |
| S-2 (major) M-11fallback equivalent under R-5 | **Adopted, the first option.** M-11fallback now removes both steps of `drawnCapsOf` (killed by `AP1`'s C9); step 1 removed alone is recorded as equivalent with the review's run as evidence, and why step 1 stays; `AP2` asserts C9's step-1 fallback as a premise. Gate 15 is meetable |
| S-3 (major) grid point on a corner: attached or fixed | **Answered by the human: decision 23, attach by position** while F3 is on. D10's F3 bullet cites it; D12's "unsnapped points" is reworded as "fixed points"; `AM4` and `TL6` gain the F3-on grid row; new M-11snaponly |
| S-4 imperial over-rounding, far-origin margin | **Adopted.** D9 records both directions with the review's cases; the 1e-6 mm tolerance is kept as R-32, with the reason; D18 lists it; `DF2` gains 3450.5 − 0.9e-6 → `3451` and (0, 0)–(2124, 1731) → `9'-0"`; `DF3` gains a half between two computed corners at six placements |
| S-5 step 2's free corners under a scaled group | **Adopted, the first option.** Step 2 takes the stored local free rectangle mapped through the wall's transform, so the attach point is the drawn corner at any similarity; `AP2` gains a scaled-group variant; a mirrored wall group is listed in D18 |
| S-6 the cost bound's opening and hub-wall cases | **Adopted.** D5 states the bound as every referrer of every wall in the core and names the wall, partition-through-wall, opening and dimension cases; `DN4` prints the counts for a door move and a partition change on a wall carrying N dimensions |
| S-7 the hover attach search per move | **Adopted.** A vertex pre-filter on the stored child points near `q` runs before any `WorldWall` is built (D10); `TL8` asserts that a hover along a wall's middle passes no wall through it and prints the time against a 1 ms budget; new M-11prefilter |
| S-8 tool details | **Adopted.** Shift is recorded from the pointer events and `onKey` before `super`; Enter does nothing (R-33); the notice is the value alone, so the status line reads `Dimension — 4.69`, and `TL5` expects that; R-18's threshold is `|angle| ≥ 0.05°` on the number, with a `PN3` row; no ring during a grip drag, by ruling (R-34) |
| S-9 AM1's 54 points | **Adopted.** `AM1` names `samplePlan` (ten walls, 60 points, the column included); `DZ1` names `sampleWalls()` (nine walls) |
| S-10 tests with no named mutant | **Adopted.** Sixteen mutants added (M-11negzero, M-11vertex, M-11colour, M-11axesline, M-11endlabel, M-11sectionmulti, M-11panelrw, M-11key, M-11twosteps, M-11gripplace, M-11runtime, M-11previewkind, M-11reachcull, M-11ownerring, and S-3's and S-7's M-11snaponly and M-11prefilter); M-11nearest defined with ties to the lowest handle; `RR2`, `AM5`, `TL8`'s time and `DN4`'s counts are marked measurements of record; `DO4`, `DO5` and `SP1` are marked carried gate pins |
| S-11 M-11b's camera half is writable | **Adopted.** M-11b-cam, a render-layer mutant fired with a `cp` backup and restored, killed by `RR1` |
| S-12 extension lines take the wall's clicks | **Adopted, recorded and kept** (R-35): D18, gate 16's look, and an `SL1` row pinning that a click on E4's face at (12,250, 8,800) selects the Hall dimension |

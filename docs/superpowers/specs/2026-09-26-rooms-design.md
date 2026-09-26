# Rooms and area — design

**Date:** 2026-09-26. **Status:** design, **revision 1**, not yet reviewed.
An independent reviewer checks it before the plan (decision 19).
**Sub-project:** `roadmap/10-rooms-and-area.md`. **Size:** L (the roadmap's
M, grown by five engine changes).
**Branch:** `spec-10/rooms`, cut from `main` at `418d4c7`; this revision is
written on top of `3054616` (the spike's findings note and renders).
**Depends on:** 06 (the parametric layer), 07 (walls), 08 (openings,
merged at `b96ed12`).
**Blocks:** nothing. 13 (export and print) inherits one line from it:
"separators do not plot" (decision 15).
**Brainstormed with the human on 2026-09-26**, on `main` at `418d4c7`,
followed by a throwaway spike whose findings are the evidence for most
decisions below:
[2026-09-26-rooms-spike-findings.md](../notes/2026-09-26-rooms-spike-findings.md)
(branch `spike/10-rooms`, head `d30bce5`, never merged). Its renders are in
[2026-09-26-rooms-spike/](../notes/2026-09-26-rooms-spike/).

**Inputs read for this revision:** `CLAUDE.md`; `STATUS.md`;
`roadmap/10-rooms-and-area.md` and `roadmap/13-export-and-print.md`; the
brainstorm's decision record (below); the spike note, the spike's code
(`apps/floor_planner/lib/parametric/{room_trace,room_label,room,separator}.dart`,
the engine prototypes in `packages/jet_cad_2d/lib/src/parametric/`,
`index/query_filter.dart`, `document/style.dart`) and its tests
(`apps/floor_planner/test/spike_rooms/`); spec 06
([2026-09-24-parametric-layer-design.md](2026-09-24-parametric-layer-design.md)),
spec 07 ([2026-09-24-walls-design.md](2026-09-24-walls-design.md)) and
spec 08 ([2026-09-25-openings-design.md](2026-09-25-openings-design.md)).

**Decisions the human made on 2026-09-26**, numbered as in the brainstorm
record (1–19 before the spike, 20–25 after it). **Later decisions supersede
earlier ones where they say so:** 20 over 1, 24 over 9 (and over 1's stored
bounding walls), 25 over 13 and qualifying 23.

| # | Question | Answer | Here |
|---|---|---|---|
| 1 | Where rooms come from | A Room tool click inside a closed ring of walls stores a seed. *Its "references its bounding walls", "among those walls and their neighbours" and "a new splitting wall needs a re-click" are superseded by 20 and 24* | D2, D19 |
| 2 | Which outline | Inner wall faces (net floor area), traced from wall parameters (uncut faces), so doorways never break it; per-wall thickness | D4, D11 |
| 3 | The look | A label and a light translucent tint on the inner-face ring | D9 |
| 4 | Order and picks | Ascending-handle draw order kept; the tint is translucent and never pickable; a room is selected by its label | D9, D18, D21 |
| 5 | Label placement | The inner ring's pole of inaccessibility; a label grip stores an offset from it in the parameters (null = auto); the offset rides with the room | D10, D21 |
| 6 | Area unit | Follows the page: m² for mm, cm, m; ft² for in, ft-in; two decimals. The view reads the page; a page change regenerates what read it, one undo step | D11, D14 |
| 7 | Label size | Paper heights (name 2.5 mm, area 2.0 mm) × the page's scale denominator | D11 |
| 8 | Naming | The tool stores `Room N`, the lowest unused N among live rooms; the Room section gains a free-text name field, committed on Enter as one undo step | D19, D21 |
| 9 | Wall deleted | *Superseded by 24* (was: cascade) | D8 |
| 10 | Ring breaks | The room is deleted in the same undo step. Engine change: a per-type dissolve verdict applied inside the edit. "Breaks" to be defined exactly | D8, D15 |
| 11 | Open plan | A room separator in 10: the tracer treats it as a zero-thickness wall; dashed on screen, hidden in print; own tool and grips | D3, D20, D21 |
| 12 | Islands | Freestanding walls inside the ring are subtracted: holes in the tint and the area | D6, D9 |
| 13 | Islands captured at click | *Superseded by 25* | D6 |
| 14 | Keys | M = Room tool, S = Separator tool | D19, D20 |
| 15 | Separators in print | A thin dashed line in 10; non-printing; roadmap 13 gains "separators do not plot"; no plot flag now | D3, Files |
| 16 | The sample plan | Rooms for all six spaces (Hall, Bedroom 1, Bedroom 2, Kitchen, Bath, Living), one separator splitting Living from a Dining area, one column island in Living | D23 |
| 17 | Separator geometry | A free two-point line placed with existing snaps; the tracer joins it where an end lies on a wall's inner face; it does not draw into or cut walls. *Its "a wall moved away … room deleted" is superseded by 24* | D3, D20 |
| 18 | Spike | Yes, throwaway | this header |
| 19 | Spec review | Yes, independent | this header |
| 20 | The trace set | **Re-trace among all live walls** (supersedes 1). Engine change: spatial dependencies — a room rebuilds when a changed wall's before or after extent touches the room's; must not drift two hops away (spike Q3e) | D7, D16 |
| 21 | Tint on dark paper | Follows the paper by contrast, like ACI 7's foreground, resolved at paint time, no rebuild | D9 |
| 22 | Label over furniture | Accepted: the label wins the click; move it with its grip | D21 |
| 23 | Island touching or leaving the ring | *Qualified by 25* (was: cut only while wholly inside; otherwise ignored and diagnosed) | D6 |
| 24 | Wall deleted or moved | **One rule:** every change re-traces; a room is deleted only when its seed lands in an unbounded face, inside a wall or on a separator. Two rooms in one face both survive; `diagnose` reports that they share a space. Supersedes 9 and the stored bounding walls | D8, D22 |
| 25 | Islands live | Any wall component wholly inside the face is a hole, found on every re-trace; no island list is stored. Supersedes 13; no per-reference policy. A column touching the ring is part of its boundary; a column outside the face is not in it; neither is diagnosed | D6 |

**The controller's "net engine changes" list** (a)–(e) is checked against
the code and the spike in
[The controller's engine list, checked](#the-controllers-engine-list-checked).
In short: (a) and (d) are right as stated; (b) is right without the
spike's `unpickable` flag; (c) is right, refined to a per-type page key;
**(e) is incomplete** — it needs a before-edit view, a place query for
`generate`, and the seeds' neighbours in its trigger, or it drifts two hops
away; and a small sixth change, **(f)**, reserves the separator's linetype
handle.

**Where this spec had to resolve something the decisions leave open**, the
paragraph is tagged **[spec ruling]**; the tags are indexed in
[Spec rulings](#spec-rulings). Choices only the human can make are in
[Open questions for the human](#open-questions-for-the-human).

**Numbers.** Every measured number below is quoted from the spike note
(which quotes its own runs on `spike/10-rooms`) and says so. Areas are
worked by hand for this spec, with the arithmetic shown; no test output was
produced for this document.

**Evidence of record.** Every claim about what exists was read from the
tree at `418d4c7` (code) on 2026-09-26, or from `spike/10-rooms` at
`d30bce5` where marked.

- **06's planner** (`packages/jet_cad_2d/lib/src/parametric/regeneration.dart`):
  - `_survey` (96-143) records the live objects, one `reach` per object,
    the children, the set G, and 08's `declared`/`references`/`referrers`;
    it keeps **no parameters, transforms or page**;
  - `_closure` (168-182) is 08 D3's: seeds, their neighbours before and
    after, their references, then referrers of that core;
  - `_plan` (240-316) matches regions through their fills, then plain
    children by `(kind, ordinal)`; an added child's record is
    `draftRecord(handle, owner, kind, color:)` (276-280, 297-298), so a
    generated TEXT is added with `text: ''` and `textAttrs: 0`; a matched
    child only ever gets `SetEntityGeometryCommand` (271, 293);
  - `_refused` (329-344) is 06 D6's guard on `r0.touched`;
  - `_cascade` (378-423) and `_subtreeRemoval` (441-498) are 08 D4's;
  - `_run` (542-639): before-survey, `inner`, the guard, the cascade, then
    one `try` holding the after-survey, `lost`, the D8 `cleanup`, the
    seeds, `_checkDangling`, the early return and `_plan`; then the
    hand-rolled apply loop. `_geometryChanged` (594) is set when the plan
    is non-empty or the cascade removed something.
- **`ParametricType`** (`parametric_system.dart:22-62`): `editCapability`,
  `reach`, `generate`, `diagnose`, `references`, `referencePolicy`.
  **`Generated`** (85-117): a plain form that refuses `fill`, and
  `Generated.region`; both carry only `color`. **`ParametricView`**
  (149-178): `paramsOf` reads the **live** component store for a handle
  that is a live object of its survey (162-163), `toWorld` reads the live
  tree (166), `neighbours`, `referrers`. It has no page.
- **Text:** `SetEntityTextCommand(handle, text, tag)` (`commands.dart:235-265`)
  replaces the record's text and tag, touches the handle, summarises as
  `geometry`. `draftRecord` (`drafting.dart:27-44`) takes only `text` and
  `color`; every other attribute is fixed (`transparency: kByLayer`,
  `flags: 0`, ByLayer linetype and lineweight, `textAttrs: 0`).
- **Colour and transparency** (`document/style_resolver.dart`): alpha is
  `255 − transparency` (211); ACI 7, by whichever route, resolves to the
  host's `foreground` (`_rgbOf`, 233), which the floor planner derives from
  the paper (`main.dart:65-87`, `foregroundFor`).
- **Flags** (`document/style.dart:117-120`): only `EntityFlags.invisible`.
  The picking and rendering filters drop an invisible entity
  (`index/query_filter.dart:72-79`). The painter draws a fill from its
  boundary's geometry and never reads the boundary's flags
  (`jet_cad_2d_flutter/lib/src/draft_painter.dart:700-760`). Band queries
  skip fills (`spatial_index.dart:392`); the select tool's window band
  skips fills and picking-rejected leaves (`select_tool.dart:445-518`); the
  selection outline skips what `rendering()` rejects and every fill
  (`outline_cache.dart:377-379`).
- **Linetypes** (`document/style.dart:104-114`, `document/tables.dart`):
  handles 1–5 are reserved and filled (layer 0, BYLAYER, BYBLOCK,
  CONTINUOUS, STANDARD); `firstFree` is 16, so **6–15 are reserved and
  unused**. Tables have no command. The codec saves every linetype record
  (`codec/json_codec.dart:42-43`). The painter resolves a pattern by
  `tables.linetypes[style.linetype]`, and a missing record draws
  continuous (`draft_painter.dart:656-661`); dash lengths are scaled by
  `linetypeScale × globalLinetypeScale × toScreen.scaleMagnitude`
  (668-671), i.e. **model units**, not the paper units `DashPattern`'s
  comment claims (spike finding 3).
- **The page** (`document/page_component.dart`): `PageComponent()` defaults
  to A4 landscape, 1:50, `DisplayUnit.meters`, white paper (95-107);
  `formatLength` exists for the ruler only (`geometry/grid_scale.dart:113`);
  nothing formats an area.
- **Walls** (`apps/floor_planner/lib/parametric/`): `_localOutlineOf`
  (`wall.dart:144-160`) is the uncut ring 07 stores, in local space,
  falling back to the free rectangle when the local ring is not simple;
  `outline` (`wall_geometry.dart:425`) and `capsOf` (461) are 07's world
  functions; `reach` is the centreline box grown by `wallJoin.linear`
  (`wall.dart:173`). `wallsInDocument` (`opening_geometry.dart:716`) is
  08's document adapter.
- **The app:** tool keys V L P R B W D N G C A T and F are taken
  (`shortcut_guard.dart:5-19`, `kShellLetterKeys`); **M and S are free**. The palette lives in
  `main.dart`'s `_entries` (129-214). `ObjectGrips` (`object_grips.dart:21`)
  dispatches `WallParams` and `OpeningParams`. The Selection panel's
  fields are numeric only (`selection_panel.dart:72-100`, `_commit` 399).
  The drawing tools' snap mask is `kDragSnapMask`, endpoint through
  insertion plus intersection (`index/drag_snap.dart:10`): **no `nearest`,
  no `perpendicular`**.
- **The sample plan** (`startup_plan.dart`): installs a system (56), builds
  walls, openings, finishes and furniture, disposes the system (161), then
  registers and sets the page (166-170) and clears the history.
  `startup_plan_test.dart` pins 549 entities (`SP1`, 128).
- **The world is y-up in the app** (`viewport_transform.dart:10-11`); the
  spike's test renders mapped y down, which is why its images are
  mirrored.
- **The spike** (`spike/10-rooms` at `d30bce5`): the tracer
  (`room_trace.dart`, 434 lines), the label point (`room_label.dart`),
  `RoomType` and `roomAt` (`room.dart`), `SeparatorType` (`separator.dart`);
  engine prototypes of (a)–(d), the per-reference policy and an
  `unpickable` flag (+156 −36 in the engine).

## What this delivers

1. **Rooms.** A room is its own parametric object that stores a seed point
   and a name. It regenerates from **every live wall and separator**: the
   face of the plan that holds its seed, bounded by the walls' uncut inner
   faces and the separators, minus the walls standing wholly inside it. It
   draws a translucent tint on that face and two labels, its name and its
   net area in the page's unit, at the face's pole of inaccessibility.
2. **Room separators:** a free two-point line, drawn dashed, that splits a
   face as a zero-thickness wall would.
3. **Two tools:** Room (**M**, one click inside a face) and Separator
   (**S**, two clicks).
4. **A Room section** in the Selection panel with a free-text **Name** field
   and the area; a **label grip**; end grips on a separator.
5. **Diagnostics:** two rooms sharing one face, a room whose seed no longer
   lies in a room (from a file), a tint that could not show its holes.
6. **The sample plan** gains its seven rooms, the Living | Dining separator
   and a column.
7. **Engine changes to 06's mechanism**, all generic: generated text with
   its string; generated record attributes; reading the page; a dissolve
   verdict; spatial dependencies (a before-edit view, place contributors and
   place readers); one reserved linetype handle.

## Non-goals

- **Plotting and print** (13). A separator is screen-only by intent
  (decision 15); 10 adds no plot flag, and 13's roadmap gains the line
  (Files).
- **Bounding dimensions** such as the roadmap screenshot's `19 x 15`, room
  types, per-room colours, perimeter, ceiling height, a schedule or a total
  area. None in v1; a later field arrives as an optional JSON key.
- **Detecting every room of a plan automatically.** A room exists because
  a person clicked; a face with no seed is not a room.
- **Rooms or separators inside definitions or instances** (06 D5:
  parametric objects are root-level).
- **Dash patterns in paper units, and the vanishing axis-aligned
  hairline** (spike findings 3 and 4). Both are render-layer questions; 10
  is their first client and works around them (D3), and hands them to a
  render-layer follow-up ([Spec rulings](#spec-rulings), R-17).
- **Handle remapping on paste or import** (08 R4). Rooms and separators
  store no handles, so there is nothing to remap.
- **Moving a room with the select tool** (D21): its place is its face.
- **A cache of wall outlines across edits.** D7 recomputes what it needs
  per edit; a persistent cache is the follow-up if the cost measurement
  (`RK2`) demands it.

## Decisions

### D1 — Where rooms live, and what the engine gains

- **The room and separator types are application code**, like 06's Box,
  07's Wall and 08's Opening, in `apps/floor_planner/lib/parametric/`.
  Nothing in the engine knows what a room is.
- **Files (app):**
  - `room.dart`: `RoomParams`, `RoomType`, the tint and label constants;
  - `room_trace.dart`: the tracer (D5–D7), **pure Dart, no Flutter
    import**;
  - `room_label.dart`: the pole of inaccessibility (D10), pure Dart;
  - `room_inputs.dart`: the uncut bands and separator segments as trace
    inputs, through two adapters (the view and the document) that agree bit
    for bit (D4), pure Dart;
  - `separator.dart`: `SeparatorParams`, `SeparatorType`, the DASHED record
    (D3);
  - `room_tool.dart`, `separator_tool.dart` (D19, D20);
  - `room_grips.dart`, `separator_grips.dart` (D21); `object_grips.dart`
    gains two dispatch arms;
  - `catalog.dart` registers both types.
- **What the engine gains is generic** (D12–D17): text and record
  attributes on `Generated`, the page on `ParametricView`, a dissolve
  verdict, place contributors and readers with a before-edit view, and one
  reserved linetype handle. Each is usable by a type that is not a room.
- **Why a room is an object and not derived state of the walls:** it has a
  name the user gives it, it selects and deletes as one thing, and the
  decisions store its seed and label offset; the walls do not know it
  exists.

**Pinned by:** nothing directly: D1 is a layout. The pure-Dart rule is
checked by the invariants' import grep (07's Task 10 grep, extended to the
three new pure files).

### D2 — `RoomParams`

- **Fields:**
  - `seed` — `[x, y]`, the clicked point in the room group's local space;
  - `name` — `String`;
  - `label` — `null` (auto) or `[dx, dy]`, the label anchor's offset from
    the pole of inaccessibility, in the room group's local space (D10).
- **`typeId`:** `floor_planner.room`.
- **`toJson` key order:** `seed`, `name`, `label`. **All three keys are
  always written**, `label` as `null` when auto (08 D6's one-shape rule).
- **Value-equal, exact `==`** on every field (stored values, CLAUDE.md).
- **Stores no handle.** Decisions 24 and 25 drop the spike's `bounds` and
  `islands`; `references` stays the default (none), so rooms take no part
  in 08's references, cascade or dangling checks.
- **`reach` is `Aabb2.empty()`.** A room is nobody's neighbour and has
  none; it reaches its walls by place (D16), not by reach.
- **`editCapability = geometry`**, as the wall, the box and the opening:
  a rename changes a generated label, and the label grip moves one.
  **[spec ruling]** (R-1) — a runtime user can neither rename a room nor
  move its label, as they can resize no box.
- **Validation:** `fromJson` accepts anything well-typed. A non-finite seed
  traces as `Unbounded` (D8). A `label` with a non-finite component is
  treated as `null` and reported `room.degenerate` (D22). The tool and the
  panel produce neither.
- **The seed is stored where clicked, never re-seated** (spike open
  decision 16): `generate` cannot write parameters, and a seed moved by a
  rebuild would make the room's identity drift. A wall moved onto the seed
  dissolves the room (D8).

**Pinned by:** `RP1` (round trip, key order, `==`, `label: null`).

### D3 — The separator: `SeparatorParams` and `SeparatorType`

- **`SeparatorParams`:** `start` and `end`, `[x, y]` in the group's local
  space. `typeId` `floor_planner.separator`; key order `start`, `end`;
  exact `==`. Its group sits at the identity when the tool makes it.
- **`reach` is `Aabb2.empty()`** **[spec ruling]** (R-2). Nothing reads a
  separator through the neighbour relation: its input to rooms (its
  segment, D4) depends on its own parameters and transform only, so it
  needs to enter an edit's closure only when it is a seed itself, which it
  does. An empty reach keeps separators out of every wall's neighbour list,
  which would cost time and change nothing.
- **It is a place contributor** (D16): `placeBox` is the world box of its
  segment, or `null` when its length is not more than `roomTrace.linear`
  (degenerate).
- **`generate`:** one open two-point POLYLINE from `start` to `end`, added
  with (D13):
  - **colour ByLayer** on layer 0: the foreground, black on light paper,
    white on Blueprint, like 08's symbols;
  - **linetype `ReservedHandles.dashedLinetype`** (D17);
  - **lineweight 35** (0.35 mm) **[spec ruling]** (R-3). Decision 15 asks
    for a thin line; the spike found that an exactly axis-aligned
    default-weight line can paint no pixel in the test rasteriser and that
    35 draws (finding 4). 35 is the lightest weight with evidence. The
    render-layer follow-up (R-17) may let 10 go thinner.
  A degenerate separator generates nothing (a childless group, 06's
  ghost, `separator.degenerate` in D22).
- **The DASHED record.** `LinetypeRecord(handle: dashedLinetype, name:
  'DASHED', pattern: DashPattern(dashes: [200, −100], totalLength: 300))`.
  **[spec ruling]** (R-4):
  - **Model millimetres,** because the painter scales patterns by world to
    screen (finding 3): 4 mm and 2 mm on paper at 1:50, 2 mm and 1 mm at
    1:100. It does not follow the page scale; the follow-up (R-17) owns
    that.
  - **It enters a document's tables outside the history**, as the page's
    registration does: the sample plan writes it when it builds its
    document (D23), and test fixtures through `ensureDashedLinetype(doc)`.
    `installParametric` does **not** write it: on a loaded file that would
    change the document outside the history, and load → save would no
    longer be byte-identical. **A document without the record draws its
    separators continuous** (the painter's missing-record fallback,
    `draft_painter.dart:656-661`) and nothing else changes. 12's file-open
    path decides whether to add it (recorded).
- **Non-printing** (decision 15): a statement of intent for 13; 10 has no
  export path and adds no flag.
- **`editCapability = geometry`.**
- **It does not draw into walls** (decision 17): the tool and the grips
  trim an end placed inside a wall's band back to the face (D20). A
  separator that reaches into a band anyway (a wall moved later, a file)
  still splits the face correctly (D5, spike `Q2h`); only its drawing
  shows inside the band.

**Pinned by:** `SR1`–`SR4` (params, generate and attributes, the missing
record, the empty reach), `RR4` (dashed pixels).

### D4 — What a room traces: uncut bands and separator segments

- **A wall's input is its uncut band:** the ring 07 stores for the wall
  when it has no openings, `_localOutlineOf(view, w, params).ring`
  (`wall.dart:144-160`), taken to world through `toWorld(w)`. It is
  computed from parameters, never read from the wall's stored children, so
  **no doorway, window or gap breaks a room** (decision 2; roadmap M-10d).
- **[spec ruling]** (R-5): the local ring, not 07's world `outline()` as
  the spike used. The two differ only where 07's local ring is not simple
  and 07 stores the free rectangle instead (07 D6's amendment, the final
  review's I1; 41 of 8,892 acute-L rotations there). Tracing what 07
  **draws** keeps the tint flush with the drawn band in that case too. The
  local-to-world mapping adds a few ulps (about 1e-7 mm at 1e9 mm), three
  orders below `roomTrace.linear`.
- **A degenerate wall** (07 D2: an empty ring) contributes nothing.
- **A separator's input** is its world segment, open; a degenerate one
  contributes nothing.
- **Boxes and openings are not inputs.** Rooms ignore both types.
- **One function, two adapters.** `roomInputOf` builds an input from a
  wall's `WallParams`, transform and wall neighbours, or from a
  separator's parameters and transform. The **view adapter** (for
  `generate`, `diagnose` and `placeBox`) takes neighbours from
  `view.neighbours`; the **document adapter** (the Room and Separator
  tools, D19, D20) takes them from the document by the engine's own
  predicate (reach overlap by more than `Tolerance.standard.linear` on both
  axes). **They agree bit for bit** (08's `HF7` precedent), pinned by `RI1`
  on every fixture at every placement.
- **A wall's input is memoised per view** (an `Expando` on the view, 08's
  `hostCutsInView` precedent), so `placeBox` (D16) and every room's trace in
  one plan compute each band once.

**Pinned by:** `RI1` (adapters), `RT2` (openings, M-10d), `RT5` (the
local-ring fallback).

### D5 — The tracer

`traceRoom(seed, inputs)` returns one of `SeedInWall(source)`,
`Unbounded()` or `Traced(ring, ringSources, holes, holeSources, outerArea,
holeAreas)`. It is the spike's algorithm (Q1, approach (a)), with the
changes marked.

1. **Local frame.** Every point is taken relative to the seed first. At
   1e9 mm without it the worst area errors were 96 and 182 mm² (spike,
   M-local); with it, 0.00085 mm² (spike Q2).
2. **The seed in a wall.** The seed inside a closed input (crossing-number
   test), or within `roomTrace.linear` of any input segment, is
   `SeedInWall`.
3. **Segments** are the input rings' edges and the separators' segments,
   each tagged with its source handle; a segment no longer than
   `roomTrace.linear` is dropped.
4. **The pair search is a sweep** over segments sorted by `minX`, with a
   box reject on `y` **[changed from the spike's O(s²) double loop]**, so
   its cost is O(s log s + pairs). For each pair:
   - each endpoint of one within `roomTrace.linear` of the other splits the
     other there (a T butt on a through face; a separator's end on a face;
     a collinear overlap);
   - otherwise, unless the two are parallel (`|d₁ × d₂| ≤
     roomTrace.angular · |d₁||d₂|`), a proper crossing splits both.
5. **Vertices** within `roomTrace.linear` of an earlier vertex are that
   vertex (a grid hash of cell `4 × roomTrace.linear`; the lowest index
   wins). Duplicate edges merge and keep every source.
6. **Faces.** Half-edges around each vertex sorted by angle; `next(u → v)`
   is the edge leaving `v` just clockwise of `v → u`, so every face lies to
   the left of its walk and bounded faces walk anticlockwise.
7. **The seed's face** is the anticlockwise cycle (positive area) of
   **least** area that holds the seed. None: `Unbounded`.
8. **Holes** (D6).
9. **Clean-up:** spikes (`u → v → u`, a dangling separator end) are
   removed, then vertices collinear within `roomTrace.linear` (between
   their neighbours); holes are reversed to anticlockwise, their sources
   moving with their edges. Areas are the shoelace in the local frame; the
   net area is the outer area minus the hole areas.

- **`roomTrace = Tolerance(linear: 1e-6, angular: 1e-12)`** **[spec
  ruling]** (R-6). The linear part is 07's `wallJoin.linear`, so a joint
  07 builds is a joint the tracer sees (with 1e-12 the T butts are missed
  off the origin and rooms merge: spike M-tol, worst error 53,514,299.998
  mm² at 1e9 mm). The angular part is the spike's parallel threshold,
  tested at all six placements; CLAUDE.md wants geometric decisions in a
  named `Tolerance`, which this is.
- **Why the face is the right region** (spike Q1): no input edge crosses
  the component of the plane outside every band that holds the seed, and
  no path leaves it without crossing an edge; so the arrangement's face is
  the union's hole, and no polygon union is computed.
- **Inputs are processed in ascending source-handle order**, so the output
  is a deterministic function of the input set.

**Costs:** O(s log s + pairs) per call, s the segment count. The spike's
O(s²) loop took 134.115 µs over the sample plan's nine walls (36 segments,
94 pairs past the box test; JIT, spike Q1). **Pinned by:** `RT1`–`RT9`;
mutants M-10a, M-10b, M-10seedface, M-10local, M-10tol, M-10sep.

### D6 — The room's face: outer ring, holes, islands

- **Holes** are every connected component of the arrangement, other than
  the outer ring's own, whose outer contour (its most negative cycle) lies
  inside the outer ring **and inside no bounded face of a third component
  that does not hold the seed**: an island inside an island's courtyard is
  not a hole of the room (spike Q2, the hollow column).
- **A component with no area** (a free separator lying inside the face,
  both ends loose) is not a hole and changes nothing.
- **Decision 25, as the arrangement reads it:**
  - a wall, or a group of walls joined to each other, standing wholly
    inside the face without touching its boundary is a separate component:
    a **hole**, subtracted from the area and cut out of the tint;
  - a wall touching the boundary (a column against a wall, a stub T-joined
    into one) is in the ring's own component: the ring **walks around it**,
    so its footprint is excluded exactly, as part of the boundary;
  - a wall outside the face is not in it.
  Holes are found on every trace; nothing is stored. Neither of the last
  two cases is diagnosed (decision 25).
- **Decision 23** is superseded in its "otherwise ignored and diagnosed":
  a touching column is now part of the boundary, not ignored.

**Pinned by:** `RT3` (column), `RT4` (hollow column, courtyard not a hole),
`RT6` (a column pushed against the ring); M-10holes, M-10holesign,
M-10seedface.

### D7 — Tracing among every wall at the cost of a few

Decision 20 traces among **all** live walls and separators. Tracing all of
them for every rebuild costs O(S log S) in the plan's segment count; a
room needs only the inputs near its face. D7 finds them exactly.

- **`traceRoomAmong(seed, source)`**, where `source` answers `placedIn(box)`
  (the contributors whose place box touches `box`, ascending; D16) and
  `inputOf(h)`:
  1. **Growth.** `B = seed ⊕ r`, `r = 1,000 mm`. Trace among
     `placedIn(B)`. `SeedInWall` is final (the wall holding the seed
     touches `B`). `Unbounded`: double `r` and repeat, until `placedIn(B)`
     is every contributor, when `Unbounded` is final.
  2. **Certificate.** On `Traced(F)`: let `C = placedIn(box(F) ⊕ m)`, `m =
     1 mm`. If `C` holds a contributor not yet traced, add it and trace
     again (the face can only shrink or gain holes); repeat until `C` adds
     nothing.
  3. **Canonical trace.** Trace once more among exactly `C`, and return
     that.
- **Why exact.** Edges disjoint from the closed face grown by `m` do not
  change the face: removing them leaves its boundary in place, and adding
  them adds nothing inside it. `m = 1 mm` is 10⁶ × `roomTrace.linear`, far
  above any rounding (≈1e-7 mm at 1e9 mm), so no vertex merge or split
  within `roomTrace.linear` reaches across it. Every contributor not in `C`
  is disjoint from `box(F) ⊕ m`, so the face among `C` is the face among
  all. `SeedInWall` and `Unbounded` are decided among a set that holds
  every input that could change them.
- **Why the canonical trace.** The output is then a function of `C` and
  the seed only, and `C` is a function of the face and of the contributors
  near it only. The growth rounds that led there, and which far
  contributors they passed over, leave no trace in the bits. D16's
  no-drift proof needs exactly this.
- **Growth and margins are [spec rulings]** (R-7): `r₀ = 1,000 mm`
  (a room is metres across, so one or two doublings find its walls), `m =
  1 mm`.
- **The source in `generate` and `diagnose`** is the view (`placedIn` and
  the memoised inputs, D4, D16); in the tools it is a cache of the
  document's inputs (D19).

**Costs:** per room, a few traces of the inputs near its face; `Unbounded`
(a room about to dissolve) traces every contributor once. **Pinned by:**
`LZ1` (localised equals all, bit for bit, every fixture and placement, and
with far clutter added), `LZ2` (the triangle: a hole beyond the first
face's box), `LZ3` (the traced-segment counter); M-10cand, M-10cert,
M-10grow.

### D8 — When a room dissolves (the ring-breaks rule)

Decision 24's one rule, made exact. In every edit that regenerates a room,
its trace in the after-state (D7) decides:

- **`SeedInWall`** — the seed lies inside a wall's uncut band or within
  `roomTrace.linear` of any band edge or separator: the room **dissolves**;
- **`Unbounded`** — no bounded face holds the seed: the room
  **dissolves**;
- **`Traced`** — the room **survives and regenerates**, whatever its face
  now is: grown, shrunk, merged with another room's, split by a new wall.

"Dissolves" is D15's verdict: the room is deleted inside the same edit,
one undo step.

- **Nothing else dissolves a room.** The spike's rule 4 ("every bound
  carries an edge") is not a rule: it deleted a valid room (spike `Q3d`),
  and there are no bounds now. Rule 3 needed references; there are none.
- **Two rooms in one face both survive** (decision 24); D22 reports them.
- **A new wall splitting a face** leaves the room on its seed's side;
  the other side has no room until someone clicks it.
- **The spike's `Q3c` cases under decisions 24 and 25** (the two-room box
  of `twoRoomWalls`, left seed (1,500, 2,000), right (5,500, 2,000); areas
  worked by hand in the spike):

| Edit | The spike (refs, decision 9) | This spec |
|---|---|---|
| partition moved onto the left seed (x = 1,500) | left deleted; right 24.13 m² | the same: the left seed is in the partition's band |
| west wall shortened 1,000 at its south end | left deleted; right unchanged | the same: the left face is unbounded |
| partition end pulled back 60 mm, still in the south wall's band | both survive | the same |
| partition end pulled back 150 mm (a 50 mm gap) | both deleted | **both survive**, one face of 29.64 m² (7,800 × 3,800), `room.shared` |
| decision 16's separator pulled 50 mm short | Dining and Living deleted | **both survive**, one face, `room.shared` |
| the sample plan's E4 deleted | Hall deleted (cascade) | **Hall and Bedroom 1 dissolve**: both faces open to the outside |
| the column deleted | Living kept, hole gone, `parametric.orphan` | Living kept, hole gone, **no diagnostic** |

**Pinned by:** `RD1`–`RD8`; M-10dissolve, M-10shared.

### D9 — The room's children: the tint and the two labels

A live room generates, in this order (fixed at creation, so its handles
never change while the tint keeps its form):

1. **the tint** — one region (`Generated.region`), a fill and its closed
   boundary;
2. **the name** — a TEXT (`Generated.text`), `RoomParams.name`;
3. **the area** — a TEXT, the formatted net area (D11).

**The tint's attributes** (written on add, D13):
- **colour `IndexedColor(7)`** on both records: ACI 7 is the foreground,
  black on White, Ivory and Grey paper, white on Blueprint, resolved **at
  paint time** by the resolver the shell rebuilds on a paper change
  (fix/post-07). That is decision 21's mechanism: no rebuild, no new
  colour model. **[spec ruling]** (R-8): explicit ACI 7, not ByLayer, so a
  later change to layer 0's colour does not recolour tints;
- **transparency 229 on the fill** (alpha 26 of 255, about 10%)
  **[spec ruling]** (R-9): black at 10% over white is `#E6E6E6`, a light
  grey; white at 10% lifts Blueprint visibly (the spike's fixed blue at
  25% all but vanished there: finding 5). The look is owed (Open question
  3);
- **the boundary is invisible** (`EntityFlags.invisible` on the boundary
  record only). An invisible boundary is dropped by picking and rendering
  (`query_filter.dart:72-79`), the painter still draws the fill from the
  boundary's geometry, bands skip fills, and the selection outline skips
  both. So **the tint is never pickable, band-selectable or snappable, and
  its edges are never stroked** (the spike's slit and separator-overdraw
  artefacts, finding 2). **No `unpickable` flag** **[spec ruling]**
  (R-10): the spike showed either mechanism alone suffices (M-unpick and
  M-visible both survived there); one mechanism is simpler, needs no
  non-DXF bit that an export must strip, and M-10visible now kills.

**The tint's shape** (spike open decision 5):
- **Holes are cut by a keyhole with a slit** **[spec ruling]** (R-11):
  each hole, in descending order of its rightmost `x`, joins the ring
  through a bridge from its rightmost vertex to the nearest ring vertex it
  can see; the return edge runs **0.5 mm** to the bridge's right, so the
  ring stays simple. The engine's triangulator refuses an exact keyhole
  (two coincident edges: 0 triangles, spike Q5, M-slit); the slit version
  of the spike's Living triangulated (11 stored points, 8 triangles). The
  tint is then short of the true region by 0.5 mm × the bridge's length;
  the **area label comes from the trace, never from the tint**.
- **A fallback chain**, so an edit is never refused because of a tint:
  1. the keyholed ring, if it triangulates;
  2. else **the outer ring alone** as the region (holes tinted over), if it
     triangulates;
  3. else **an invisible, unfilled closed POLYLINE** of the outer ring, in
     place of the region.
  Steps 2 and 3 are reported `room.tint` (D22). Step 3 changes the child's
  kind, so a later return to a region adds it with fresh, higher handles
  than the labels (06 D12's accepted cost; invisible in practice, since
  the tint is translucent). Every form keeps **every outer-ring vertex among
  the stored points**, which D16's read box relies on.

**The labels' attributes:** ByLayer on layer 0 (the foreground, like 08's
symbols), `STANDARD` text style, justification **centre, middle**
(`textAttrs`, D13), flags 0. They are pickable: **a room is selected by
its labels** (decision 4), and a label over furniture wins the click
(decision 22; the spike's lamp, `Q6`).

**Pinned by:** `RG1` (children, order, attributes), `RG2` (holes and the
fallback chain), `RR1`–`RR4` (renders and picks); M-10slit, M-10visible,
M-10tintcolour, M-10tintalpha.

### D10 — The label point and the stored offset

- **The pole of inaccessibility** of the face (outer ring minus holes):
  polylabel's quadtree search with a **binary-heap** queue (the spike's
  linear scan bounds the cost from above: 245–418 cells, 1,113 µs for
  Living with its column, spike Q4c), at **10 mm precision** **[spec
  ruling]** (R-12): a label needs no finer place, and the spike's numbers
  are at 10 mm. The search runs relative to the ring's first vertex, so a
  far-origin room costs what a near one does.
- **Why not the centroid or the box centre:** on the spike's thin L (arms
  1,000 clear) the centroid lies 813 mm outside and the box centre 1,900 mm
  outside; the pole lies 583 mm inside, against 585.786 by hand (spike
  Q4a). With a 400 × 400 column at the box centre, the pole moves off it
  (spike Q4b).
- **The anchor** is `toLocal(pole) + label`, with `label = (0, 0)` when
  auto. **The offset is relative to the pole** (decision 5's "rides with
  the room"): when a wall moves and the pole moves, the label moves with it
  by the same amount, and keeps its offset. **[spec ruling]** (R-13): the
  alternatives — relative to the seed, or absolute — leave a dragged label
  behind when the room changes shape.
- **The two lines**, `h` their heights (D11), centre-middle justified:
  the name at `anchor + (0, 0.7 · h_name)` and the area at `anchor − (0,
  0.7 · h_area)`, in world directions (y up), so the name reads above the
  area with a gap of `0.2 · (h_name + h_area)` (0.9 mm on paper).
- **Horizontal in world.** Points are computed in world and taken to the
  room's local space by `toWorld(room)⁻¹`; each TEXT's rotation is the
  negative of the room group's world rotation and its height is divided by
  the group's scale, so the labels stay horizontal and sized on paper under
  any similarity transform on the room's group (only a file makes one).
  Under a non-uniform scale the height is divided by the geometric mean
  scale (recorded).
- **The label may lie outside the face** when dragged there; nothing is
  reported.

**Pinned by:** `RL1` (thin L, three placements), `RL2` (the column),
`RL3` (offset rides with the pole), `RL4` (a rotated room group);
M-10c, M-10centroid, M-10offset, M-10offsetref.

### D11 — The area, its format, and the label heights

- **The area** is the trace's net area (outer minus holes), in mm², from
  the uncut inner faces: net floor area (decision 2).
- **Format** (decision 6): `DisplayUnit.millimeters`, `.centimeters`,
  `.meters` → `(a / 1e6).toStringAsFixed(2)` + `' m²'`; `.inches`,
  `.feetInches` → `(a / (304.8 × 304.8)).toStringAsFixed(2)` + `' ft²'`
  (`304.8 × 304.8` evaluated in double arithmetic). Always two decimals,
  `.` as the separator, no grouping. The spike's page test read
  `116.57 ft²` for 10,830,000 mm² (10,830,000 / 92,903.04 = 116.573…).
- **Heights** (decision 7): the name `2.5 mm × scaleDenominator`, the area
  `2.0 mm × scaleDenominator`, in world millimetres: 125 and 100 at 1:50,
  250 and 200 at 1:100 (the spike's page test).
- **With no page on the root**, the room reads `PageComponent()`'s
  defaults: 1:50 and metres **[spec ruling]** (R-14), the page the app
  opens with.
- **Test values avoid rounding ties:** every expected label in this spec's
  fixtures is at least 0.0005 m² from a tie, checked by hand.

**Pinned by:** `RA1` (every unit), `RA2` (page change), `RX1`.

### D12 — Engine (a): generated text

- **`Generated.text(GeometryPayload payload, String text, {DraftColor
  color = ByLayer, int textAttrs = 0, int flags = 0})`**: a TEXT child
  whose string the planner owns.
- **The plain `Generated(EntityKind.text, …)` and `Generated(
  EntityKind.attrib, …)` throw `ArgumentError`** **[spec ruling]** (R-15):
  a TEXT without its string is exactly the defect the research found; an
  ATTRIB needs a tag nobody generates.
- **On add**, the record carries the string, `textAttrs`, colour and flags
  (D13's record builder).
- **On a match** (the i-th generated TEXT against the i-th existing TEXT
  child, ascending), the planner compares, in this order:
  1. the payload, exact `==` → `SetEntityGeometryCommand` when it differs;
  2. **the stored string, exact `==`** (a stored value) →
     `SetEntityTextCommand(child, text, '')` when it differs.
  Nothing else of a matched record is compared or rewritten.
- **06 D6 is unchanged.** Its guard judges `r0.touched`, the inner edit's;
  the planner's own `SetEntityTextCommand` is a planned command and never
  meets it. A caller's `SetEntityTextCommand` on a generated label is
  refused with `GeneratedGeometryError`, as the spike showed (`Q5`).
- **`textAttrs` is fixed at creation**, like the colour (06 D11, 07 D8's
  amendment). A type that must change a label's justification needs a new
  child. Rooms never do.
- **The capability summary** is `geometry` whenever the plan is non-empty,
  a string rewrite included (06 D9): a string changes a TEXT's bounds, and
  the index must hear it.

**Costs:** one string comparison per matched TEXT. **Pinned by:** `TX1`
(engine client: add, match, rewrite, undo, the guard), `RG3` (the room's
labels follow a wall move); M-10f, M-10textadd, M-10attrs.

### D13 — Engine (b): the record attributes a client sets on add

- **`Generated`** (plain) gains `transparency` (default `kByLayer`),
  `flags` (0), `linetype` (`ReservedHandles.byLayerLinetype`) and
  `lineweight` (`kByLayer`).
- **`Generated.region`** gains `transparency` (both records), `flags` (the
  fill's) and `boundaryFlags` (the boundary's; default: `flags`). A region
  takes no linetype or lineweight: its boundary is the fill's outline.
- **The planner writes every one of them, and the colour, into the record
  only when it adds the child.** On a match it rewrites geometry and a
  TEXT's string (D12), nothing else. So **a client must keep every
  attribute fixed for an object's life**, as 06 D11 already requires of
  the colour.
- **One record builder** (`_recordOf`) serves the plain, region and text
  forms; `draftRecord`'s defaults stay for every attribute a `Generated`
  does not set.
- **No `unpickable` flag** (R-10). `EntityFlags` is unchanged.

**Pinned by:** `AT1` (engine client: each attribute on add, none on a
match), `RG1`, `SR2`.

### D14 — Engine (c): the page

- **`ParametricView.page`**: the root's `PageComponent` in the view's
  survey (a snapshot, D16), or `null` when none is attached or the type is
  not registered.
- **`ParametricType.pageKey(PageComponent? page) → Object?`**, default
  `null`: the part of the page this type's `generate` reads, compared with
  `==`. The room returns the record `(unit, scaleDenominator)` of the page,
  or of `PageComponent()`'s defaults when `page` is null.
- **Seeds on a page change.** In `_run`, after the seeds are formed: when
  `before.page != after.page` (value equality; a stored value), for each
  registered type whose `pageKey(before.page) != pageKey(after.page)`,
  every live object of that type joins the seeds. **[spec ruling]**
  (R-16): a key rather than the spike's `readsPage` flag, so a paper-colour
  change (decision 21 resolves the tint at paint time) or a grid change
  regenerates no room.
- **One undo step:** the page edit and every regenerated label are one
  `ParametricEdit`. The Page panel's edit and `startupPlan`'s page are
  `SetComponentCommand<PageComponent>` through the dispatcher, so the
  expander sees them.
- **Cost:** O(types) per page edit, plus the regeneration of each seeded
  object; nothing on any other edit.

**Pinned by:** `PG1` (engine client), `RA2` (a room: metres 1:50 → ft-in
1:100 in one command reads `116.57 ft²` and heights 250 and 200, one undo
step, undo restores `10.83 m²`; the spike's `Q5 a page change`), `PG2`
(a paper-colour change plans nothing for rooms); M-10page, M-10pagekey.

### D15 — Engine (d): the dissolve verdict

- **`ParametricType.dissolves(ParametricView view, Handle self) → bool`**,
  default `false`. The room answers `true` for D8's `SeedInWall` and
  `Unbounded`, sharing one trace per room per view with `generate` (an
  `Expando` memo on the view).
- **Where it is asked:** in `_plan`, for each object of the closure,
  **before** its `generate`, with the after-view. A dissolving object's
  plan is:
  1. `_subtreeRemoval(t, after, h)` — 08's helper, the select tool's order
     (every fill first, then the other leaves, nested groups, the node);
  2. **then its component's detach**, `SetComponentCommand<T>(h, null)`.
  Its `generate` is not called.
- **Interaction with 06 D6 (the guard):** the removals are planned
  commands, not in `r0.touched`, so the guard never sees them; they remove
  only the dissolving object's own children and node.
- **Interaction with 06 D8 (the cleanup):** `lost` is computed from the
  after-survey, where the dissolving room is still live, so the cleanup
  does not detach it. **The dissolve must detach its own component**, or
  it outlives its node (spike M-detach: `Expected: null Actual: <Instance
  of 'RoomParams'>`). And because it is not in `lost`, it is never detached
  twice.
- **Undo** replays the concrete inverse: the component, the node (linked
  last among the root's children, as 06's and 08's deletes are), and every
  child with its handle. State-equal, compared with the root's child order
  normalised (06's convention); **draw order is unaffected**, since it
  follows handles, not tree order (D18).
- **`drift()`** names a room that would dissolve (its plan is non-empty),
  so a loaded broken room shows; `diagnose` reports `room.broken` (D22).
- **Permissions:** the removals inherit the triggering edit's authority
  (06 D7), as 08's cascade does. The capability summary is `geometry`
  (the plan is non-empty), which the index needs to drop the children.
- **Why in `_plan` and not a pass before it** (spike open decision 13):
  the verdict needs the after-view and the same trace as `generate`; in
  `_plan` it costs nothing extra, and no other object reads a room.

**Pinned by:** `DV1` (engine client: dissolve, one step, undo, component
detached, the guard untouched), `RD1`–`RD4`; M-10dissolve, M-10detach.

### D16 — Engine (e): spatial dependencies

Decision 20 makes a room read **every** wall and separator by where it is.
06's closure follows reach neighbours and 08's references; neither finds
the rooms a wall edit changes. (e) adds a third relation, by place, and
makes it exact.

**The API** (`parametric_system.dart`):

```dart
// ParametricType<T>
/// Spec 10 D16: this type's geometry is an input to place readers. Default false.
bool get contributesPlace => false;
/// The world box of what this object contributes, from the view (a wall:
/// its uncut band's box; a separator: its segment's), or null for nothing.
/// Called only when [contributesPlace]; must not mutate.
Aabb2? placeBox(ParametricView view, Handle self) => null;
/// Spec 10 D16: this type's generate reads contributors by place. Default false.
bool get readsPlaces => false;
/// The world box whose contributors this object's current output depends
/// on, from its parameters, its transform and [stored], the world box of
/// the points of its stored children. Called only when [readsPlaces].
Aabb2 readBox(T params, Transform2 toWorld, Aabb2 stored) => stored;

// ParametricView
/// Ascending live contributors whose place box touches [box] (closed:
/// touching counts, no tolerance). Computes every contributor's box on the
/// first call per view, then scans.
List<Handle> placedIn(Aabb2 box);
/// [h]'s place box in this view, or null.
Aabb2? placeBoxOf(Handle h);
```

`ParametricCatalog.register` throws `ArgumentError` for a type that both
contributes and reads: the rule below gives one hop, and a type that did
both would need another.

**1. The before-edit view (e1).** `_run` applies `inner` right after the
before-survey, so a view over the before-survey today reads **after**
parameters (`paramsOf` and `toWorld` read the live stores). The survey now
**snapshots**, for each live object, its registered component and its
accumulated transform (both already computed for `reach`), and the root's
page. **Every view reads the snapshot:** `paramsOf<U>(h)` answers the
snapshot component when it is a `U` (null otherwise, and for any handle
that is not a live object of the survey, as 08 D4's amendment), `toWorld(h)`
the snapshot transform for a live object (the live tree for any other
handle, as today), `page` the snapshot. For the after-, drift and
diagnostics views nothing changes (their snapshot is the live state while
they are used); **the before-view becomes true.** Cost: two map entries
per object per survey and no client call (08's `RC1` count of
`references` calls is unchanged).

**2. The trigger.** Inside `_run`'s `try`, after the seeds and the
dangling check, when the seeds are non-empty:
- `K = seeds ∪ neighbours_before(seeds) ∪ neighbours_after(seeds)` — the
  spatial part of 08 D3's core, already computed;
- `L` = the non-null boxes `placeBox(beforeView, k)` for `k ∈ K` live
  before, and `placeBox(afterView, k)` for `k ∈ K` live after, over the
  contributors in `K`;
- if `L` is empty, nothing more. Otherwise, **every live reader `R` (after)
  that is not a seed and whose `readBox(params, toWorld, stored)` touches
  any box of `L` joins the core**, before 08 D3's referrer step. `stored` is
  the world box of the coordinates of `R`'s children's payloads, from the
  after-survey's children.

The room's `readBox` is `stored`, grown to include the seed, then grown by
**2 mm** **[spec ruling]** (R-7): twice D7's `m`, so rounding in the
local-to-world map of the stored tint cannot put `box(F) ⊕ m` outside it.

**3. Why `K` holds the seeds' neighbours, not only the seeds.** A wall's
band depends on its own parameters **and its neighbours'** (07 D4: joints,
and the short-wall fallback that squares **both** ends). A seed can change
a neighbour's band at an end far from the seed, and a room may touch only
that end: a **two-hop** read. The `FB` fixture (Testing) does exactly
this: moving X squares its neighbour W's far end, which opens a
5,000 mm² notch into a room about 750 mm from X. With `K = seeds` (M-10nbr) that
room is not rebuilt and `drift()` names it. This is the shape of the
spike's `Q3e` drift (`drift [34]`), where neighbours shaped a ring beyond
the closure; under decision 20, `Q3e` itself is covered directly (the new
wall lies inside the room) and passes as `RS5`.

**4. The proof it does not drift.** Claim: after an edit, a live room `R`
that is not in the closure has a stored output equal to what `generate`
would produce now. By induction on edits (the base is a fresh room, or a
file, trusted by 06 D10):
- `R`'s output is a function of its parameters, its transform, the page
  key and D7's canonical trace, which is a function of the seed and of the
  set `C` of contributors whose inputs touch `box(F) ⊕ m`, with their
  inputs. `R` not a seed ⇒ parameters and transform unchanged; the page
  key unchanged (else D14 seeded it).
- An input can change only if its object is in `K`: a separator's depends
  on itself (a seed); a wall's on itself and its neighbours (07's one-hop,
  the argument 06 D4 step 6 makes for walls' own drift-freedom).
- For each changed `k`, its before and after boxes miss `readBox(R) ⊇
  box(F_before) ⊕ m`. So no member of `C_before` changed, no changed input
  touches `box(F_before) ⊕ m` after, and by D7's lemma the face after is
  `F_before`, `C_after = C_before` with the same inputs, and the canonical
  trace returns the same bits. ∎
- **The inherited assumption:** "a wall's band depends only on its reach
  neighbours" is 07's. Its known edge — a node cluster whose ends spread
  over up to 2 × `wallJoin.linear`, where a member can fail the neighbour
  predicate (07 D4's amendment, Ruling 07-3) — is 07's own drift edge,
  unreachable by snapping; rooms inherit it and do not widen it.

**5. `placedIn` is exact, and bulk.** `generate` needs every contributor
whose **band** touches a box, and a band can reach far beyond its wall's
reach: an acute mitre is never clamped (07 D6), and a node's lobe owner
walks the corners of the other members' wedges. No bound from reach is
safe, so the first `placedIn` of a view computes **every** contributor's
box. To keep that O(n log n) rather than O(n²), it first fills the
survey's neighbour memo for every object with **one sort-and-sweep pass**
over the reach boxes (the same predicate, the same ascending lists as
`neighboursOf`, each pair test counted in `debugOverlapTests`). A plan that
regenerates no reader never calls `placedIn` and pays nothing.

**6. Cost bound, per edit:**
- a plain entity edit (no seeds): nothing (the early return);
- an edit whose `K` holds no contributor (a door, a box, a room's own
  rename): nothing beyond 08's closure;
- an edit whose `K` holds contributors: `2 × |K ∩ contributors|` place-box
  calls, O(|K| · n) overlap tests (07 D10's order), and one read box per
  live reader (O(its stored points));
- **the rooms rebuilt:** those whose read box touches a changed
  contributor's before or after box: for a wall move, the rooms on both
  sides of it and of its joint partners;
- if any room regenerates: one bulk pass, O(n log n + pairs), and one place
  box per contributor, O(n) band computations, once per edit; then D7's
  localised traces per room.
- **Counters,** `@visibleForTesting`, never reset by the library:
  `debugPlaceBoxCalls` and `debugReadBoxCalls`.

**Pinned by:** `SV1`–`SV3` (the before-view), `SD1`–`SD8` (engine clients:
the trigger, two hops, before and after, readers, the counters, the bulk
pass), `RS1`–`RS6` (rooms: c1–c4, `Q3e`, `FB`), `RK1`, `RK2`; M-10nbr,
M-10before, M-10snap, M-10e, M-10bulk, M-10cand.

### D17 — Engine (f): the dashed linetype's handle

- **`ReservedHandles.dashedLinetype = Handle(6)`**, a named constant in the
  engine's reserved range, documented as "reserved for an application's
  DASHED record; not in the default tables".
- **The engine's default tables do not change** (the default document's
  bytes, and the hash tests in `generate_document_test.dart` that pin
  them, stay as they are). The
  app writes the record (D3).
- **Why a reserved handle:** `generate` writes a linetype handle into the
  records it adds and cannot read the tables, so the handle must be the
  same in every document; 6–15 are the engine's reserved range, and an
  app claiming one silently would collide with the engine's next use.

**Pinned by:** `SR2` (the separator's record names it), `RP2` (the
default tables unchanged).

### The engine changes against 06's guarantees

One row per change; "—" means the change does not touch that guarantee.

| | Lives in | 06 D6 guard | 06 D8 cleanup | Undo | Save and load | Draw order | Frame path |
|---|---|---|---|---|---|---|---|
| (a) text | `Generated.text`; `_plan`'s TEXT match | unchanged: judges `r0.touched` only; a caller's text edit of a generated child is still refused | — | the rewrite is a planned command inside the one `ParametricEdit`; its inverse restores the old string | the string is in the record, persisted as any TEXT's | a matched TEXT keeps its handle | — (edit time only) |
| (b) attributes | `Generated`, `Generated.region`; `_recordOf` | — | — | written by the add, removed by its inverse | persisted with the record | — | the resolver already maps transparency and linetype; nothing new per frame |
| (c) page | `ParametricType.pageKey`, `ParametricView.page`; the survey's page; `_run`'s page seeds | — | — | the page edit and its regeneration are one step | the page is a component, as before | regenerated children keep their handles | — |
| (d) dissolve | `ParametricType.dissolves`; `_plan` | never meets it (planned commands) | the dissolve detaches its own component; `lost` never holds it | one step; the node is re-linked last (state-equal, root order normalised) | — | handles restored, so unchanged | — |
| (e) place | `contributesPlace`, `placeBox`, `readsPlaces`, `readBox`, `placedIn`, `placeBoxOf`; the survey's snapshots; `_closure`'s trigger; the bulk pass | — | — | only decides the closure; replay never regenerates | — | — | — (edit time only) |
| (f) handle | `ReservedHandles.dashedLinetype` | — | — | — | the default tables are unchanged; the app's record persists | — | — |

### D18 — Draw order, undo, save and load

- **Ascending handle value, unchanged** (06 D12). A room's children are
  reserved in generation order: tint fill < tint boundary < name < area, so
  **the labels draw over the tint**, and a room drawn after walls,
  finishes and furniture tints them (translucent: the spike measured a
  sofa `#e6e1d8` becoming `#bccad3` under its 25% blue; R2).
- **A room's children keep their handles** across every regeneration:
  one region matched by ordinal, two TEXTs by ordinal. Only D9's fallback
  step 3 changes a kind (recorded).
- **The tint never covers a wall's band:** its outer ring is the bands'
  faces, so the two share edges only. Opening symbols and furniture inside
  the face are tinted, not hidden.
- **Undo of a dissolve** links the room's node last among the root's
  children (D15). Draw order follows handles, so it is stable; the saved
  bytes are state-equal (root order normalised), 06's and 08's accepted
  convention.
- **Save → load → save is byte-identical**; `RoomParams` and
  `SeparatorParams` come back equal; labels keep their strings; the DASHED
  record persists with the tables; `drift()` is empty after load.
- **The same state plus the same edit gives the same bytes** (06 D11): the
  trace is a deterministic function of the state (D7's canonical trace).
- **Purge** keeps handles; nothing changes.
- **Platform** (07 D13): no test pins a literal hash of rotated geometry;
  byte comparisons are between documents built in one run.

**Pinned by:** `RG4` (undo, redo, handles), `RG5` (round trip),
`RG6` (determinism: a document and its reload, the same edit).

### D19 — The Room tool (M)

- **A `PlacementTool` whose one click commits.** It stays active; Esc
  returns to the select tool (05 D5). M joins `kShellLetterKeys`, the
  palette and `shortcut_guard.dart`.
- **The seed is the raw pointer**, unsnapped **[spec ruling]** (R-18): a
  snap would pull the seed onto a wall's vertex or face, where it
  dissolves at once.
- **The trace** is D7's over the **document adapter** (D4): a cache of
  every wall's band and every separator's segment, with their boxes, marked
  stale on a document change and rebuilt at the next hover, like 07's and
  08's band cache (its neighbour search is the same sweep as D16's). The
  click and the hover run the same code as `generate`, so what the preview
  shows is what the room gets (`RI1`, `TT2`).
- **No room is made** (no preview, the click does nothing) when the trace
  is `SeedInWall` or `Unbounded`, **or when the face already holds a live
  room's seed** **[spec ruling]** (R-19; Open question 1): decision 24's
  shared space is for faces that later edits merge, not one the tool
  should create.
- **The name** is `Room N`, `N` the lowest positive integer such that no
  live room's name is exactly `Room N` (`^Room ([1-9][0-9]*)$`): with
  `Room 1`, `Room 3` and `Kitchen` live, the next is `Room 2`.
- **The commit:** `Compound([AddNodeCommand(group at the identity),
  SetComponentCommand<RoomParams>(seed, name, label: null)])` through
  `commit(ctx, …, needs: {structure, components, geometry})`: one undo
  step, in which the room regenerates.
- **The hover preview:** the would-be face's outer ring and holes, in
  world, as open polylines in the tool's overlay. It is recomputed only
  when the pointer leaves the cached face (a point-in-face test,
  allocation-free) or the cache goes stale; painted from cached payloads,
  so the frame path gains no allocation.
- **Refused commits:** an `ArgumentError` or `StateError` from `execute`
  is caught and nothing is placed, as 07's and 08's tools do.

**Pinned by:** `TT1`–`TT6`; M-10name, M-10occupied, M-10seedsnap.

### D20 — The Separator tool (S)

- **A `PlacementTool` of two clicks per separator**, not chained
  **[spec ruling]** (R-20): decision 17's "a free two-point line". After
  the second click the tool waits for a new first click; Esc cancels a
  pending start, then returns to the select tool. S joins the keys, the
  palette and the guard.
- **Points** resolve through the drawing tools' chain and mask (05 D4,
  `kDragSnapMask`), as the Line tool's do: decision 17's "existing snaps".
- **Band trimming** **[spec ruling]** (R-21). The chain has no `nearest`
  or `perpendicular`, so a person cannot land an end exactly on a face at
  an arbitrary point. Instead, **an end that lies inside a wall's uncut
  band is moved back along the separator to the first point where the
  segment, walked from its other end, enters that band.** The stored end
  then lies on the face (to rounding, far inside `roomTrace.linear`), so it
  joins the face (D5) and the separator does not draw into the wall
  (decision 17). Like 07's band joining, trimming is object snapping and is
  **gated on F3**; with F3 off the end stays where it was put, and still
  splits the face correctly (spike `Q2h`). An end in open space is kept as
  placed. Both ends inside the same band, or a trimmed length not more than
  `roomTrace.linear`: no separator.
- **The commit:** `Compound([AddNodeCommand(group at the identity),
  SetComponentCommand<SeparatorParams>(…)])`, needs `{structure,
  components, geometry}`, one undo step.
- **Preview:** the rubber-band segment, trimmed as it would be stored.

**Pinned by:** `ST1`–`ST4`; M-10trim.

### D21 — Editing: selection, the Room section, the grips

**Selecting a room.** A click on either label selects the room's group
(`resolveHit`, topmost group); a window band selects it when its labels are
inside, a crossing band when it crosses them. The tint never answers
(D9). **What selection shows:** the labels' outlines (the selection
overlay draws what is rendered, and the tint's boundary is invisible), the
**label grip**, and the **Room section**. The ring itself is not outlined
(Open question 2).

**No move or rotate by the select tool** **[spec ruling]** (R-22):
`RoomGrips.movable` is false, as 08's openings. A group move would carry
the seed into another face, silently re-seating the room, or into a wall,
deleting it. In a mixed selection a room is skipped, as an opening is. A
`TransformNodeCommand` that reaches one anyway (hand-built) is accepted
and re-traces at the moved seed. **Delete** is the select tool's group
delete; 06 D8 detaches the component; nothing else changes.

**The Room section** (the Selection panel):
- shows when **exactly one** selected key is a root-level group carrying
  `RoomParams`;
- **Name**, a free-text field: the panel's `_Field` gains a **text kind**
  (its value a `String`, its `loadedValue` a `String`), with every
  convention of 07, 08 and fix/post-07:
  - a `PanelFieldFocusNode`; **Enter commits and hands focus back**; a tap
    outside hands back; the field commits on its own focus loss **[spec
    ruling]** (R-23: decision 8 says Enter; losing focus also commits, as
    every Selection-panel field does);
  - the **target pinned at focus gain**, re-pinned after a commit; a
    pinned target that is no longer a live room discards the text;
  - the text is trimmed; **empty after trimming, it reverts** **[spec
    ruling]** (R-24): a nameless room has an invisible name label and
    cannot be told apart in the panel;
  - an unchanged name issues no command; a changed one is **one**
    `SetComponentCommand<RoomParams>`, one undo step, in which the name
    label is rewritten (D12);
  - a refused edit (`ArgumentError`, `StateError`) reverts; a reload never
    writes into a focused field; read-only unless `components` and
    `geometry` are allowed;
  - `shortcut_guard.dart` covers every shell letter, M and S included, so
    **every letter types** into the field (`RN3` types one of each);
- **Area**, read-only: the area label's stored string **[spec ruling]**
  (R-25): it is the derived value exactly as drawn, and recomputing it in
  the panel would trace on every rebuild.

**The label grip** (`room_grips.dart`):
- one `stretch` grip at the anchor, in world: the name TEXT's stored
  insertion point minus `(0, 0.7 · h_name)`, mapped by `toWorld(room)`;
- `drag(point)` resolves through the chain, then stores `label = toLocal(p)
  − toLocal(pole)`, where `pole = anchor − label` from the stored values;
  **a drop within the snap aperture of the pole stores `null`** (auto)
  **[spec ruling]** (R-26: the one way back to auto, with no extra
  control); a drop that stores what is stored returns null. One undo step;
- `preview`: a line from the pole to the would-be anchor;
- hit only when `components` and `geometry` are allowed (07 `OG5`).

**Separator grips** (`separator_grips.dart`): two `stretch` grips at the
ends; a drag moves one end, resolved through the chain and band-trimmed as
the tool does (D20), one undo step; `movable` true (a separator moves and
rotates with the select tool like any line).

**`ObjectGrips`** dispatches `RoomParams` → `RoomGrips`, `SeparatorParams`
→ `SeparatorGrips`; `movable` stays one rule (08's F2).

**Pinned by:** `RN1`–`RN6` (the section), `GR1`–`GR5` (grips, movable);
M-10pin, M-10movable, M-10offset.

### D22 — Diagnostics

`RoomType.diagnose` and `SeparatorType.diagnose` report, each at most once
per object, severity `warning` unless stated:

- **`room.shared`** (decision 24) — two live rooms whose seeds lie in one
  face. **Once per pair, by the lower handle** (08 R2's rule): the lower
  room reports each higher room whose seed lies inside its face (in the
  outer ring, in no hole). Handles `[lower, higher]`; message `"<name A>
  and <name B> share a space"`.
- **`room.broken`**, severity `error` — the trace is `SeedInWall` or
  `Unbounded`. An edit never leaves one (D8 dissolves it); only a file
  does, and `drift()` names it too.
- **`room.tint`** — D9's fallback step 2 or 3 was taken.
- **`room.degenerate`** — a non-finite `label` component (D2).
- **`separator.degenerate`**, severity `error` — a separator of length
  `≤ roomTrace.linear` (from a file only).
- **Not reported** (decision 25): a column touching the ring, a column
  outside the face.

`diagnose` traces with the diagnostics view (D7's source), memoised per
view, so O(rooms) traces plus O(rooms²) point tests, off the edit path.

**Pinned by:** `DG1`–`DG4`; M-10share2.

### D23 — The sample plan

Decision 16, on 08 D18's plan (coordinates relative to `x0 = 12000, y0 =
8000`; inner faces worked out in the spike: exterior faces at x 12,250 and
25,750, y 8,250 and 16,750; partitions ±60 about their centrelines).

**Added, in this order, after the furniture:**
1. **the column:** a wall `(x0 + 11500, y0 + 6000) → (x0 + 11900, y0 +
   6000)`, 400 thick, centre: a 400 × 400 square, x 23,500–23,900, y
   13,800–14,200. After the finishes, so its band draws over the parquet
   it stands on;
2. **the separator:** `(x0 + 9500, y0 + 3560) → (x0 + 9500, y0 + 8750)`,
   i.e. x = 21,500 from P3's north face (y 11,560) to E3's inner face (y
   16,750), both ends on faces; clear of the sofa (ends x 21,000) and the
   table;
3. **the page**, set through the plan's system **before the rooms**
   **[spec ruling]** (R-27): the rooms then read the real page, not D11's
   fallback. `PageComponent.register` moves up with it; the page's origin
   is centred on the extents, which the rooms do not change;
4. **seven rooms** **[spec ruling]** (R-28: decision 16 names six spaces
   and a separator that splits "Living from a Dining area"; the Dining
   area is a room, or it is an untinted, unlabelled half), each by a
   `RoomParams` whose seed is below:

| Room | Seed | Area by hand (mm²) | Label |
|---|---|---|---|
| Hall | (14,500, 10,500) | (16,940 − 12,250) × (12,940 − 8,250) = 4,690 × 4,690 = 21,996,100 | `22.00 m²` |
| Bedroom 1 | (13,300, 15,000) | (14,540 − 12,250) × (16,750 − 13,060) = 2,290 × 3,690 = 8,450,100 | `8.45 m²` |
| Bedroom 2 | (15,800, 15,000) | (16,940 − 14,660) × 3,690 = 2,280 × 3,690 = 8,413,200 | `8.41 m²` |
| Kitchen | (19,000, 10,000) | (21,440 − 17,060) × (11,440 − 8,250) = 4,380 × 3,190 = 13,972,200 | `13.97 m²` |
| Bath | (23,500, 10,000) | (25,750 − 21,560) × 3,190 = 4,190 × 3,190 = 13,366,100 | `13.37 m²` |
| Living | (24,500, 16,000) | (25,750 − 21,500) × (16,750 − 11,560) − 400 × 400 = 4,250 × 5,190 − 160,000 = 22,057,500 − 160,000 = 21,897,500 | `21.90 m²` |
| Dining | (19,000, 16,000) | (21,500 − 17,060) × 5,190 = 4,440 × 5,190 = 23,043,600 | `23.04 m²` |
| Total | | 111,138,800 (the spike's six, 111,298,800, less the column's 160,000) | |

  The first five and the separated pair are the spike's measured values
  (`Q2`: `21996100.0 mm2` … and Dining 23,043,600, Living with the column
  21,897,500), every one from the real plan with its fifteen openings. The
  seeds lie in no band, no furniture matters (furniture is not a wall),
  and the Living seed avoids the column. Then the system is disposed and
  the history cleared, as today;
5. **the DASHED record** (D3) is written into the tables when the document
  is made.

**The sample plan's tests:**
- the entity count stays in 500–1,000; **by this spec's count 581** (549 +
  28 room children + 1 separator child + 3 column children); the plan
  confirms or corrects it by running `SP1`, never by assuming it;
- `SP1`–`SP4` unchanged in intent; the column stands clear of every
  doorway's 900 mm approach (the nearest door, P3's kitchen/living door at
  x 23,150–23,850, reaches y 12,460; the column starts at y 13,800);
- **`SP5` is extended:** ten walls (the column the tenth), one separator,
  seven rooms with the table's names and seeds, compared exactly; each
  room's area label as the table says; `drift()` and `diagnostics()`
  empty (no `room.shared`, no `wall.*`);
- `SP6` (save → load → save) unchanged;
- **new:** each room's net area against the table to 1e-2 mm², its label's
  heights 125 and 100, and the pole inside its face.

**Pinned by:** `SP1`–`SP7`.

## The controller's engine list, checked

The decision record ends with the controller's reading of the engine
changes. Checked against the code at `418d4c7` and the spike:

| Item | Verdict | Where |
|---|---|---|
| (a) `Generated.text` keeps its string, attributes at creation, the planner rewrites the string on a match | **Right.** Plus: the plain form refuses TEXT and ATTRIB (R-15); the payload is compared before the string | D12 |
| (b) transparency, flags, linetype, lineweight "as needed" (translucent unpickable tint, invisible boundary, dashed separator) | **Right, without "unpickable".** An invisible boundary makes the tint unpickable by itself (spike Q6: M-unpick survived); no new flag bit | D13, R-10 |
| (c) the view reads the page; a page change regenerates every object that reads it, one step | **Right, refined:** a per-type `pageKey` compared before and after, so a paper change regenerates no room; the page is snapshotted with the survey | D14, R-16 |
| (d) dissolve inside the edit; detach before 06 D8's cleanup | **Right.** Precisely: the dissolve plans its own detach, because `lost` never holds it (it is live in the after-survey); "before the cleanup" is not the mechanism | D15 |
| (e) a room rebuilds when a wall or separator **changed in the edit** has a before/after extent touching the room's extent (last generated extent and seed); no two-hop drift | **Incomplete.** (1) "Changed in the edit" must be the seeds **and their neighbours** before and after, or a neighbour's band changed at a far end drifts (`FB`, M-10nbr). (2) "Before extent" needs a **before-view**: today every view reads the live stores, so after `inner` a before-extent is the after one (M-10snap). (3) Re-tracing among all walls needs a **place query** on the view, and it must be exact, which rules out reach-based bounds (D16.5). (4) The room's extent is its stored points, grown by a margin (the read box). | D16 |
| Dropped: references for rooms, per-reference policy | **Agreed.** Also dropped: the spike's `unpickable` flag and `readsPage` | — |
| (f) — | **Missing from the list:** the separator's linetype needs a reserved handle (D17) | D17 |

## What the roadmap and the spike asked 10 to decide

| Asked | Answer |
|---|---|
| Roadmap: which boundary bounds the area? | The inner faces, net floor area (decision 2; D4, D11) |
| Roadmap: do doorways break a room? | No: the uncut bands are traced, never the stored pieces (D4; M-10d) |
| Roadmap: an open plan? | A separator, in v1 (D3, D20) |
| Roadmap: rooms inside rooms? | A wall component wholly inside is a hole; a closet with its own walls touching the ring is part of the boundary (D6) |
| Roadmap: label placement | The pole of inaccessibility, plus a draggable offset (D10, D21) |
| Roadmap: units and format | m² or ft², two decimals, from the page; no `19 x 15` (D11, Non-goals) |
| Roadmap: naming | `Room N`, renamed in the Room section (D19, D21) |
| Roadmap: a loop that opens | The room dissolves only when its seed's face is unbounded or its seed is in a wall; otherwise it follows its face (D8) |
| Roadmap decision 1 (`RoomComponent` holds the name **and the derived area**) | **Changed:** `generate` cannot write parameters, so the area is derived and shown, never stored (D2, D11) |
| Roadmap decision 2 (a cycle search on 07's wall graph) | **Stale:** 07 D4 caches no graph; a planar arrangement of the uncut bands (D5) |
| Roadmap decision 3 (the label is a generated text) | Kept, with engine change (a) (D12) |
| Spike open 1: which objects a rebuild traces | All live walls and separators (decision 20), localised exactly (D7) |
| Spike open 2: stale rooms | None can exist: every edit near a room re-traces it (D16) |
| Spike open 3: the ring-breaks wording | Rules 1 and 2 only; rule 4 dropped (D8) |
| Spike open 4: islands moved | Live (decision 25; D6); not reported |
| Spike open 5: the tint's holes | The 0.5 mm slit keyhole, with a fallback chain (D9, R-11) |
| Spike open 6: the tint's boundary | Invisible (D9) |
| Spike open 7: unpickable | The invisible boundary alone (R-10) |
| Spike open 8: the label over furniture | Accepted (decision 22; D9, D21) |
| Spike open 9: the tint on dark paper | ACI 7, translucent, resolved at paint time (decision 21; D9) |
| Spike open 10: the separator's look | DASHED at a reserved handle, model-unit pattern, 0.35 mm, written into the sample plan's tables (D3, D17) |
| Spike open 11: `Generated`'s attribute surface | On add: colour, transparency, flags, boundary flags, linetype, lineweight, string, `textAttrs`; on a match: the string only (D12, D13) |
| Spike open 12: page reads | A per-type page key (D14, R-16) |
| Spike open 13: the dissolve's place | In `_plan`, before `generate`, with its own detach; undo's root reorder accepted (D15) |
| Spike open 14: the per-reference policy API | Dropped with the references (decision 25) |
| Spike open 15: the Room tool's click cost | A cached document adapter and D7's localised trace, with the sweep (D5, D19) |
| Spike open 16: the seed | Stored where clicked (D2) |
| Spike open 17: dash units and the hairline | A render-layer follow-up (R-17); 10 uses a model-unit pattern and 0.35 mm |

## Architecture

### Files

- **Engine, `packages/jet_cad_2d`:**
  - `lib/src/parametric/parametric_system.dart`: `Generated` (D12, D13),
    `ParametricType.pageKey`, `dissolves`, `contributesPlace`, `placeBox`,
    `readsPlaces`, `readBox`; `ParametricView.page`, `placedIn`,
    `placeBoxOf`; the snapshot reads; the catalog's both-roles check;
    `_Registration` adapters;
  - `lib/src/parametric/regeneration.dart`: the survey's snapshots (D16.1),
    `_recordOf` and the TEXT match (D12, D13), the page seeds (D14), the
    dissolve in `_plan` (D15), the trigger in the closure (D16.2), the bulk
    neighbour pass (D16.5), `debugPlaceBoxCalls`, `debugReadBoxCalls`;
  - `lib/src/document/style.dart`: `ReservedHandles.dashedLinetype` (D17);
  - `test/parametric/`: `text_test.dart`, `attributes_test.dart`,
    `page_test.dart`, `dissolve_test.dart`, `place_test.dart`,
    `before_view_test.dart`, with **test-only clients**: a text client, a
    page-key client, a dissolving client, a contributor whose place box
    depends on its neighbours (for the two-hop test), and a reader that
    lists the contributors placed in a stored field.
- **Render layer, `packages/jet_cad_2d_flutter`:** **no `lib` change.**
  Translucent fills, ACI 7's foreground, dashed polylines and invisible
  boundaries all exist. Its gate must stay green unchanged.
- **App, `apps/floor_planner`:** D1's files; `object_grips.dart`,
  `catalog.dart`, `selection_panel.dart` (the text field kind and the Room
  section), `main.dart` (two tools, keys, the grips), `shortcut_guard.dart`
  (M, S), `startup_plan.dart` (D23); tests.
- **Roadmap:** `roadmap/13-export-and-print.md` gains, under "Decisions
  already made": "**Room separators do not plot** (10, decision 15): a
  separator is a screen aid; an export skips entities carrying
  `SeparatorParams`' group, or 13 adds a plot flag." `roadmap/10` is marked
  done at the merge, as usual.

### Amendments to 06, 07 and 08

| Section | Amended by | What changes |
|---|---|---|
| 06 D3 (`ParametricType`, `Generated`, `ParametricView`) | D12–D16 | text; attributes; page; dissolve; place roles; the view reads snapshots |
| 06 D4 step 1 (the survey) | D16.1 | components, transforms and the page are snapshotted |
| 06 D4 steps 5–6 (seeds, closure) | D14, D16.2 | page seeds; place readers join the core |
| 06 D4 step 7 (the plan) | D12, D13, D15 | records built with attributes; a TEXT's string rewritten; a dissolving object removed and detached |
| 06 D6 (the guard) | — | unchanged; planned text rewrites and dissolves never meet it |
| 06 D8 (delete) | D15 | a dissolve detaches its own component; the cleanup is unchanged |
| 06 D11 (the colour is fixed at creation) | D13 | every record attribute is |
| 07 D10 (neighbour search) | D16.5 | a bulk sweep, used only when a place reader regenerates |
| 08 D3 (the closure) | D16.2 | place readers join the core before the referrer step |
| 08 D4's amendment (the view hides a lost object) | D16.1 | kept, and extended to the snapshot |

### Invariants

- **The frame path allocates nothing new.** Traces, poles and previews
  run on edits and pointer moves; the tint is one more fill per room. The
  allocation tests stay green, unedited.
- **Draw order is ascending handle value;** a room's children keep their
  handles (D18).
- **Decisions use `roomTrace` and `wallJoin`; stored values use `==`**
  (D5, D12, D14).
- **Generation reads parameters, never geometry.** `generate` never reads
  stored children; only `readBox` receives the stored box, and it decides
  which rooms regenerate, never what they draw.
- **An edit never leaves a room whose seed is in a wall or in an unbounded
  face** (D8).
- **`packages/jet_cad_2d` stays pure Dart;** `room_trace.dart`,
  `room_label.dart` and `room_inputs.dart` import no Flutter.

## Testing

CLAUDE.md's bar: a test lands only if a named mutant turns it red.
**A rectangle of four equal, centred, axis-aligned walls at the origin,
drawn anticlockwise, is this feature's degenerate fixture** (the roadmap's
trap): it hides winding errors, centroid errors, centreline-versus-face
errors (with equal thickness the difference is uniform), wrong-frame errors
and non-convex handling. It may appear only as a recorded control.

**Required fixture properties,** each carried by at least one relational
test:
- **placements** (the spike's six): the origin; the corpus's far origin
  (4,500,000, 1,200,000) turned 23°; the same with **every wall and
  separator in its own rotated, translated group**; +1e9 mm on both axes
  turned 23°, unturned, and turned in own groups;
- an **L-shaped** room with walls **drawn in mixed directions**, and the
  same L with a door, a window and a gap;
- **four thicknesses** on one room; a **justification mix** on one room;
- **two rooms sharing** a partition, T-joined at both ends;
- a **column** island, a **hollow** column, a column **touching** the ring;
- a **separator** face to face, centreline to centreline (into the bands),
  and 50 mm short;
- **non-default page:** ft-in at 1:100;
- **a room group at a non-identity similarity transform** (file-only);
- a room with a **non-null label offset** and a name that is not `Room N`;
- the **triangle** (D7's certificate) and the **fallback two-hop `FB`**
  (D16).

**The fixtures, by hand** (the spike's where marked; the rest worked for
this spec):

| Fixture | Area (mm²) |
|---|---|
| L, six 200 mm centred walls, mixed directions (spike) | 5,800 × 2,800 + 2,800 × 2,000 = 21,840,000 |
| Four thicknesses 300, 100, 200, 250 (spike) | (4,950 − 125) × (3,900 − 150) = 4,825 × 3,750 = 18,093,750; centrelines 20,000,000 |
| Two rooms, 100 mm partition (spike) | 2,850 × 3,800 = 10,830,000 and 4,850 × 3,800 = 18,430,000 |
| Box and separator, hollow column (spike) | 2,900 × 3,800 = 11,020,000 and 4,900 × 3,800 − 700 × 700 = 18,130,000; courtyard 500 × 500 = 250,000 |
| **Justification mix `JM`:** centrelines (0,0)→(6000,0) t 200 left; (6000,0)→(6000,4000) t 100 right; (6000,4000)→(0,4000) t 300 centre; (0,0)→(0,4000) t 250 right (drawn upwards) | inner faces y 200, x 6,000, y 3,850, x 250: (6,000 − 250) × (3,850 − 200) = 5,750 × 3,650 = 20,987,500 (`20.99 m²`). Every inner corner is a 90° wedge's, within the mitre limit of its node (the farthest, (250, 200), is √(250² + 200²) ≈ 320 mm from (0, 0), against 4 × ½ × 250 = 500) |
| **Triangle `TR`:** centred 200 mm walls (0,0)→(12000,0), (12000,0)→(0,6000), (0,6000)→(0,0); a column (10000,400)→(10400,400) t 400; seed (800, 800) | the inner faces: y = 100, x = 100, and x + 2y = 12,000 − 100√5; legs L_x = 11,700 − 100√5 and L_y = 5,850 − 50√5 = L_x / 2; area L_y² = 34,235,000 − 585,000√5 ≈ 32,926,900.23; less the column 160,000: ≈ 32,766,900.23 (`32.77 m²`). The column clears the diagonal face (at x = 10,400 the face is at y ≈ 688 > 600) |
| **`FB` (fallback two-hop):** W (−2000,0)→(0,0) t 400; V (0,0)→(0,3000) t 100; U (−500,0)→(−500,−3000) t 100 (a T into W); bottom (−500,−3000)→(3037,−3000), right (3037,−3000)→(3037,3000), top (3037,3000)→(0,3000), all t 100; X (−2000,0)→(−2000,−800) t 100; the room R2's seed (1500, 0) | R2 = [−450, 2,987] × [−2,950, 2,950] less [−450, 50] × [−200, 2,950] = 3,437 × 5,900 − 500 × 3,150 = 20,278,300 − 1,575,000 = 18,703,300 (`18.70 m²`). **The edit:** X's end to (−2000 + 800 cos 5°, −800 sin 5°): X meets W at 5°, W's acute corner at ≈ 2,860 mm along W (> its 2,000), so W falls back and squares both ends (07 D6); at B the mitre with V remains V's cap, so a notch (0,0), (0,−200), (50,−200) opens into R2: 18,703,300 + ½ × 50 × 200 = 18,708,300 (`18.71 m²`). X's boxes stay west of x ≈ −1,150; R2's read box starts at −452 |

`FB`'s test **asserts its own premises** (W reports `wall.fallback` after
the edit and not before; X's before and after place boxes miss R2's read
box), so it cannot silently become degenerate.

**Oracles, not counts alone:**
- **expected areas by hand**, the arithmetic in the test (the roadmap's
  M-10a trap);
- **the all-inputs trace** as a differential oracle for D7 (`LZ1`), bit for
  bit;
- **`drift()` empty** after every edit of every relational test, which is
  D16's proof checked;
- **picks and pixels** through the shell for the tint (the spike's R2 and
  Q6 method).

### Tests by area

Identifiers are this spec's; the plan may renumber, keeping the kills.

- **Engine (test-only clients):**
  - `TX1` a text client: added with its string and `textAttrs`; a
    parameter change rewrites the string in place (same handle), one undo
    step; undo and redo; a caller's `SetEntityTextCommand` on the child is
    refused; the plain form refuses TEXT and ATTRIB;
  - `AT1` each attribute written on add, none rewritten on a match; a
    region's boundary flags apart from its fill's;
  - `PG1` a page-key client: a page change seeds exactly the types whose
    key changed; one undo step; `PG2` a change outside every key plans
    nothing;
  - `DV1` a dissolving client: removed in the edit, component detached,
    one undo step, undo restores handles (root order normalised);
    `drift()` names a loaded one;
  - `SV1`–`SV3` the before-view: parameters, transforms and the page as
    they were, for a moved, re-parameterised and deleted object;
  - `SD1` a contributor moved into a reader's field regenerates the reader;
    `SD2` moved out of it (before box); `SD3` moved far (before-view); `SD4`
    the two-hop: a contributor's neighbour's place box changes; `SD5` two
    readers touched by one contributor both regenerate; `SD6` counters:
    no seeds → 0 place and read box calls; a non-contributor edit → 0; a
    contributor edit → exactly `2 × |K ∩ contributors|` place boxes
    (before and after) and one read box per live reader; `SD7` the bulk
    pass gives the same neighbour lists as `neighboursOf`, its overlap
    tests counted and below n²/4 on a spread layout; `SD8` the catalog
    refuses a type with both roles.
- **Tracer and inputs (app, pure):**
  - `RI1` the view and document adapters agree bit for bit;
  - `RT1` the sample plan's six rooms, 15 openings, six placements (the
    table); `RT2` the L with a door, a window and a gap; `RT3` the column;
    `RT4` the hollow column and its courtyard; `RT5` a wall whose local
    ring falls back (07's I1 case): the band traced is the one drawn;
    `RT6` a column pushed against the ring; `RT7` four thicknesses and
    `JM`; `RT8` separators face to face, into the bands, 50 mm short;
    `RT9` `SeedInWall` and `Unbounded`;
  - `LZ1` localised equals all, bit for bit, with 200 far walls added;
    `LZ2` the triangle; `LZ3` traced segments per rebuild on the sample
    plan, pinned.
- **The room object (app):**
  - `RP1` `RoomParams`; `RP2` the default tables unchanged;
  - `RG1` children, order, attributes; `RG2` holes and the fallback chain
    (a forced step 2 and step 3); `RG3` the shared partition of the two-room fixture moved
    500 mm: both rooms' areas and labels follow, same handles, one step,
    undo, redo; `RG4` handles across undo, redo,
    purge; `RG5` save → load → save; `RG6` same state + same edit;
  - `RL1` the thin L at the origin, the corpus and +1e9 mm placements:
    the pole inside, against 685.786 by hand, to the 10 mm precision;
    `RL2` a column at the box centre moves the pole off it; `RL3` an
    offset rides with the pole across a wall move (`anchor − pole ==
    label`, and the anchor is not `seed + label`); `RL4` a room group at a
    rotated, translated, scaled similarity: labels horizontal in world,
    heights on paper;
  - `RA1` the format in each of the five units, hand values clear of ties;
    `RA2` the page change (the spike's `Q5`); `RX1` a room with no page
    reads 1:50 and metres;
  - `RD1` the seed covered by a moved wall; `RD2` a face opened; `RD3` E4
    deleted (Hall and Bedroom 1 dissolve, one step); `RD4` the column
    deleted (Living kept); `RD5` the partition pulled 150 mm (both
    survive, `room.shared`); `RD6` the separator pulled 50 mm short;
    `RD7` a dissolve's undo; `RD8` a separator moved 60 m
    away (its two rooms merge, `room.shared`);
  - `RS1`–`RS4` the spike's c1–c4 (the right room clicked, then: c1 a
    face-to-face partition, 12,920,000; c2 a freestanding wall, 18,330,000;
    c3 a T-joined partition, 12,920,000; c4 the partition moved into the
    west wall's band, both rooms 29,640,000 and `room.shared`), at the
    origin and the corpus placement; `RS5` `Q3e` (the stub then the joining
    wall: every room follows, `drift()` empty); `RS6` `FB`;
  - `RK1` a line draw among the sample plan: 0 place and read box calls;
    `RK2` timing (06's NC4 method, JIT, median of five, printed, not
    asserted) for a wall move at 100, 300 and 600 walls with a room per
    four walls, recorded in the results note.
- **Renders and picks (app, the shell in `flutter_test`):**
  - `RR1` a click on a furniture fill inside a room picks the furniture;
    on a wall's face 5 mm inside, the wall; on bare floor, nothing;
    on a label, the room (the spike's Q6 probes);
  - `RR2` the tint's pixel over white paper and over furniture: the
    foreground at ~10% over what is there; `RR3` the same on Blueprint;
  - `RR4` the separator paints dashed pixels at 1:50.
- **The separator (app):** `SR1` `SeparatorParams` round trip, key
  order, `==`; `SR2` one open polyline, ByLayer, linetype
  `dashedLinetype`, lineweight 35, written once on add; `SR3` a document
  without the DASHED record draws the separator continuous and refuses
  nothing; `SR4` its reach is empty: no wall lists it as a neighbour.
- **Tools, panel, grips (app):**
  - `TT1` M places one room in one click, one undo step, name `Room 1`;
    `TT2` preview equals the generated ring; `TT3` no room in a wall, an
    unbounded face or an occupied face; `TT4` the name's lowest unused N;
    `TT5` the seed is the raw point with F3 on near a vertex; `TT6` the
    hover allocates nothing in steady state;
  - `ST1` S places one separator in two clicks, one undo step; `ST2` band
    trimming, F3 on and off; `ST3` both ends in one band: nothing; `ST4`
    the new separator splits its room (one side keeps the room);
  - `RN1` the section shows for one room only; `RN2` Enter commits one
    step and hands focus back, Esc works after; `RN3` every shell letter
    types; `RN4` pinned target; `RN5` empty reverts, runtime read-only,
    refused edit reverts; `RN6` the area line shows the label's string;
  - `GR1` the label grip: at the anchor, a drag stores the offset, one
    step; `GR2` a drop on the pole stores null; `GR3` not hit under
    runtime; `GR4` a body drag on a selected room moves nothing, no
    rotation grip for rooms alone; `GR5` separator end grips, trimmed.
- **Diagnostics:** `DG1` `room.shared` once per pair by the lower handle,
  three rooms in one face give three entries; `DG2` `room.broken` from a
  file; `DG3` `room.tint`; `DG4` `separator.degenerate` and
  `room.degenerate`.
- **The sample plan:** `SP1`–`SP7` (D23).

### Named mutants

Each is fired with a `cp` backup, restored with `cp`, then `diff` against
the backup and `git diff --quiet` (never `git checkout`), and logged in
`plan-10-mutation-log.md`.

**From the roadmap** (M-10a–f, carried; M-10e redefined):

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-10a | centrelines traced instead of the uncut bands | `RT1`, `RT7` (four thicknesses: 20,000,000 against 18,093,750), `SP7` |
| M-10b | the outer ring chosen as the cycle of least **absolute** area (a winding error) | `RT1`, `RT2` (the mixed-direction L); spike: `+8 −71` |
| M-10c | the label at the ring's box centre | `RL1` (thin L) |
| M-10d | the stored cut pieces traced instead of the uncut bands | `RT1` (15 openings: the Hall leaks out, spike `Actual: <Instance of 'Unbounded'>`), `RT2` |
| M-10e | **redefined** (the roadmap's "a shared wall belongs to one room" has no stored ownership left to break): the trigger adds only the **lowest-handle** reader each contributor touches | `RG3` (the shared partition moved 500 mm: both rooms must follow; `drift()` names the higher one), `SD5` |
| M-10f | the planner never rewrites a matched TEXT's string | `RG3`, `TX1`, `RA2` |

**From the spike** (carried):

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-10holes | holes ignored | `RT3`, `RT4`, `SP7` |
| M-10holesign | holes not reversed: their area adds | `RT3` |
| M-10seedface | the **largest** face holding the seed | `RT4` (the courtyard) |
| M-10local | no local frame | `RT1` at +1e9 mm (spike: 96 and 182 mm²) |
| M-10tol | `roomTrace.linear` 1e-12 | `RT1` off the origin (T butts missed) |
| M-10sep | separators dropped | `RT8`, `SP7` |
| M-10centroid | the label at the centroid | `RL1` |
| M-10textadd | the planner adds records without the string | `TX1`, `RG1` |
| M-10attrs | `textAttrs` not written on add | `AT1`, `RG1` |
| M-10page | no page seeds | `PG1`, `RA2` |
| M-10dissolve | `dissolves` always false | `DV1`, `RD1`–`RD3` |
| M-10detach | the dissolve leaves the component | `DV1` |
| M-10slit | the exact keyhole (slit 0) | `RG2` (the column's tint: fallback 2 is taken, `room.tint` is reported and the tint covers the column), `SP5` (`diagnostics()` no longer empty) |
| M-10visible | the tint's boundary visible | `RR1` (the tint wins picks: spike `Actual: '614 (fill) -> 612'`) |

**New:**

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-10nbr | the trigger's `K` is the seeds only | `RS6` (`FB`), `SD4` |
| M-10before | the trigger uses after boxes only | `SD2`; `RD4` (the column, which has no neighbour, deleted: Living keeps its hole without the before box); `RD8` (a separator moved 60 m away: the two rooms it split must merge). A partition's own neighbours mask it, so partition fixtures cannot kill it |
| M-10snap | the before-view reads the live stores (no snapshot) | `SV1`–`SV3`, `SD3` |
| M-10cand | `placedIn` by reach instead of place box | `SD1`, `RG1`, `SP7` (a band's faces lie outside its wall's reach, so every room traces `Unbounded` and dissolves) |
| M-10cert | D7 stops at the first `Traced` face (no certificate) | `LZ2` (the triangle's column is missed: 32.93 against 32.77) |
| M-10grow | no growth: straight to every contributor | `LZ3` (the segment counter) |
| M-10bulk | the bulk pass replaced by per-object `neighboursOf` | `SD7` (the overlap-test count) |
| M-10pagekey | every page change seeds every room | `PG2` |
| M-10shared | a room whose face holds another room's seed dissolves | `RS4`, `RD5` |
| M-10share2 | `room.shared` reported by both rooms of a pair | `DG1` |
| M-10offset | the stored label offset ignored | `GR1`, `RL3` |
| M-10offsetref | the offset taken from the seed, not the pole | `RL3` (a wall move shifts the pole) |
| M-10tintcolour | the tint a `TrueColor`, not ACI 7 | `RR3` (Blueprint), `RG1` |
| M-10tintalpha | the tint's transparency not written | `RR2` (furniture covered) |
| M-10name | `Room N` as the largest N plus one | `TT4` |
| M-10occupied | the Room tool places in an occupied face | `TT3` |
| M-10seedsnap | the seed is the snapped point | `TT5` (the room dissolves at once) |
| M-10trim | no band trimming | `ST2` |
| M-10pin | the Room section's target read at focus loss | `RN4` |
| M-10movable | rooms movable by the select tool | `GR4` |

**Retired from the spike:** M-policy (no per-reference policy), M-rule3 (no
references), M-rule4 (no rule 4; M-10shared covers the wrong-deletion
direction), M-unpick and M-unpick2 (no flag; M-10visible is the one
mechanism now).

### Differential check

- **`drift()` is empty** after every edit in every relational test.
- **A full regeneration from scratch agrees with the incremental one** on
  the sample plan after a scripted sequence of twenty edits (wall moves,
  end drags, a partition added and deleted, a separator added and moved, a
  column added, a page change).
- **The localised trace equals the all-inputs trace, bit for bit**
  (`LZ1`), on every fixture at every placement, with and without far
  clutter.

## Exit gate

1. The four gate lines are green with `CI=true` **on the human's macOS
   machine** (engine, render layer with only its standing failures,
   harness, app), and `flutter build macos --release` and `flutter build
   web --release` are `✓ Built`. The Linux container's run is recorded as
   the Linux half; **the macOS half is owed by the human and never
   simulated.**
2. Every fixture's area equals its hand arithmetic to 1e-2 mm² at every
   placement, the sample plan's seven included.
3. A doorway, a window and a gap never break a room.
4. Moving a wall updates every room it touches, in **one** undo step,
   labels included; undo and redo restore it exactly; `drift()` is empty,
   the two-hop `FB` included.
5. A room dissolves exactly when D8 says, in the same undo step; two rooms
   in one face both survive and are reported once.
6. Holes: a wall component wholly inside is subtracted and cut out of the
   tint; one touching the ring is walked around.
7. The label lands inside the thin L; its offset rides with the pole; it
   stays horizontal under a rotated room group.
8. The area follows the page's unit and the heights its scale, and a page
   change regenerates in one step; a paper change regenerates no room.
9. Save → load → save is byte-identical; `drift()` is empty after load.
10. The tint is translucent, follows the paper at paint time, and is never
    picked, band-selected or stroked.
11. The separator is dashed, splits a face, and is trimmed to faces.
12. The Room and Separator tools, the Room section (focus hand-back,
    pinned target, free text), the label grip and the separator grips
    behave as D19–D21 say.
13. The spatial trigger is exact (the proof's tests) and its cost is
    pinned by counters; the timing is recorded.
14. The allocation invariants pass unchanged; the render layer's `lib` is
    unchanged.
15. The sample plan is D23's; its tests pass; `drift()` and
    `diagnostics()` are empty.
16. Every named mutant is killed, logged in `plan-10-mutation-log.md`;
    `roadmap/13` carries "separators do not plot".
17. **The human's look — owed by the human, never simulated:** on macOS,
    in Chrome and in Firefox: the Room and Separator tools and their
    previews; the sample plan's tints and labels on White and on Blueprint;
    moving and deleting walls around rooms, and undo; the label grip; the
    Room section's name field.

## Spec rulings

Every place this spec resolved something the decisions leave open.

- **R-1** (D2) — `RoomParams`' `editCapability` is `geometry`.
- **R-2** (D3) — a separator's `reach` is empty.
- **R-3** (D3) — the separator's lineweight is 0.35 mm.
- **R-4** (D3) — the DASHED pattern is `[200, −100]` model mm, written by
  the sample plan and fixtures, never by `installParametric`.
- **R-5** (D4) — a wall's input is the local ring 07 stores, mapped to
  world, not 07's world `outline()`.
- **R-6** (D5) — `roomTrace = Tolerance(linear: 1e-6, angular: 1e-12)`.
- **R-7** (D7, D16) — growth from 1,000 mm, doubling; the certificate
  margin 1 mm; the room's read box grown by 2 mm.
- **R-8** (D9) — the tint's colour is explicit ACI 7.
- **R-9** (D9) — the tint's transparency is 229 (about 10%).
- **R-10** (D9, D13) — no `unpickable` flag; the invisible boundary alone.
- **R-11** (D9) — holes cut by a 0.5 mm slit keyhole, with a three-step
  fallback.
- **R-12** (D10) — the pole at 10 mm precision, with a heap.
- **R-13** (D10) — the label offset is relative to the pole.
- **R-14** (D11) — with no page, 1:50 and metres.
- **R-15** (D12) — the plain `Generated` refuses TEXT and ATTRIB.
- **R-16** (D14) — a per-type `pageKey`, not a `readsPage` flag.
- **R-17** (Non-goals, D3) — dash patterns in paper units and the
  axis-aligned hairline go to a render-layer follow-up.
- **R-18** (D19) — the seed is the raw pointer.
- **R-19** (D19) — the Room tool makes no room in an occupied face.
- **R-20** (D20) — the Separator tool is not chained.
- **R-21** (D20) — band trimming of separator ends, gated on F3.
- **R-22** (D21) — rooms are not moved or rotated by the select tool.
- **R-23** (D21) — the Name field also commits on focus loss.
- **R-24** (D21) — an empty name reverts.
- **R-25** (D21) — the Room section's area is the label's stored string.
- **R-26** (D21) — a label dropped on the pole returns to auto.
- **R-27** (D23) — the sample plan sets its page before its rooms.
- **R-28** (D23) — the sample plan has seven rooms, Dining included.

## Open questions for the human

Only product-visible choices the decisions do not settle; each has a
default above that the plan follows unless the human rules otherwise.

1. **A Room tool click in a face that already has a room** (R-19). Default:
   nothing happens. Alternative: a second room is made and reported as
   sharing the space.
2. **What a selected room outlines.** Default: its labels only, as the
   overlay draws what is rendered and the tint's boundary is invisible.
   Alternative: the ring outlined too, which needs a render-layer change
   (the overlay drawing a selected group's invisible boundaries).
3. **The tint's strength** (R-9): the foreground at about 10%. The look
   decides; any value is one constant.

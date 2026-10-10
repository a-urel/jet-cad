# Rooms and area — design

**Date:** 2026-09-26. **Status:** design, **revision 3**: revision 2
(`6163da8`) was re-reviewed ("Ready with amendments", T-1 to T-8); see
[Revision 3](#revision-3). Revision 1
(`5015828`) was reviewed independently (decision 19): "Ready with
amendments", findings S-1 to S-19. Revision 2 applies them, and the
human's answers to revision 1's open questions (decisions 26–28); see
[Revision 2](#revision-2).
**Amended at execution (Plan 10):** Tasks 14b and 14c (decision 29, added
in flight) amended D5 step 9, D6 and D9 themselves; those paragraphs are
marked "amended at execution, Plan 10, decision 29" and "Task 14c" in
place. The paragraphs headed "**Amended at execution (Plan 10)**" record
the rest: the plan's rulings that fill this spec's gaps (10-1, 10-3, 10-4,
10-7, 10-10, 10-13, 10-14, 10-16, 10-17, 10-18, 10-23, 10-24, 10-27), the
controller's rulings in flight, and where the build departed from this
text or made it precise. They rewrite nothing above them. Results:
[2026-09-26-plan-10-results.md](../notes/2026-09-26-plan-10-results.md).
**Sub-project:** `roadmap/10-rooms-and-area.md`. **Size:** L (the roadmap's
M, grown by the engine changes and one render-layer change).
**Branch:** `spec-10/rooms`, cut from `main` at `418d4c7`; this revision is
written on top of `3054616` (the spike's findings note and renders);
revision 2 on top of `5015828`.
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
record (1–19 before the spike, 20–25 after it, 26–28 the answers to
revision 1's open questions). **Later decisions supersede
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
| 26 | Room tool click in a face that already has a room | Nothing happens; the status line says so | D19 |
| 27 | What a selected room shows | Its labels **and its inner-face ring**, outlined in the selection colour; a render-layer change | D21, D24 |
| 28 | The tint | The page's foreground at about 10% | D9 |

**The controller's "net engine changes" list** (a)–(e) is checked against
the code and the spike in
[The controller's engine list, checked](#the-controllers-engine-list-checked).
In short: (a) and (d) are right as stated; (b) is right without the
spike's `unpickable` flag; (c) is right, refined to a per-type page key;
**(e) is incomplete** — it needs a before-edit view, a place query for
`generate`, and the seeds' neighbours in its trigger, or it drifts two hops
away; and a small sixth change, **(f)**, reserves the separator's linetype
handle. Decision 27 adds one render-layer change, **(g)**: the selection
outline of a fill whose boundary is invisible (D24).

**Where this spec had to resolve something the decisions leave open**, the
paragraph is tagged **[spec ruling]**; the tags are indexed in
[Spec rulings](#spec-rulings). Revision 1's three open questions are
answered (decisions 26–28); [Open questions for the human](#open-questions-for-the-human)
is empty.

**Numbers.** Every measured number below is quoted from the spike note
(which quotes its own runs on `spike/10-rooms`) and says so; revision 2
also cites the independent review's runs, as "the review's run", where
they settle a finding. Areas are
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
  (`outline_cache.dart:377-379`); D24 changes the fill arm.
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
   and the area; a **label grip**; end grips on a separator; a selected
   room outlines its labels **and its ring** (decision 27).
5. **Diagnostics:** two rooms sharing one face, a room whose seed no longer
   lies in a room (from a file), a tint that could not show its holes.
6. **The sample plan** gains its seven rooms, the Living | Dining separator
   and a column.
7. **Engine changes to 06's mechanism**, all generic: generated text with
   its string; generated record attributes; reading the page; a dissolve
   verdict; spatial dependencies (a before-edit view, place contributors and
   place readers, `objectsOf`); one reserved linetype handle. **One
   render-layer change:** the selection outline of a fill whose boundary is
   invisible (D24).

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
  or an endpoint is not finite (degenerate); `placeInput` is its world
  segment.
- **`generate`:** one open two-point POLYLINE from `start` to `end`, added
  with (D13):
  - **colour ByLayer** on layer 0: the foreground, black on light paper,
    white on Blueprint, like 08's symbols;
  - **linetype `ReservedHandles.dashedLinetype`** (D17);
  - **lineweight 35** (0.35 mm) **[spec ruling]** (R-3). Decision 15 asks
    for a thin line; the spike found that an exactly axis-aligned
    default-weight line can paint no pixel in the test rasteriser and that
    35 draws (finding 4). 35 is the lightest weight with evidence
    (controller's ruling on S-15: the thinnest weight shown to render in a
    cited run stands; the vanishing hairline stays in R-17's render-layer
    follow-up, which may let 10 go thinner). Whether 0.35 mm reads as
    "thin" on the real renderers is part of the human's look (gate 17).
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
    `TableSection.add` throws on a duplicate handle or a duplicate name
    (case-insensitive; `tables.dart:113-118`), so
    `ensureDashedLinetype` is a **no-op when handle 6 already holds a
    record**, and when another handle already carries the name `DASHED` it
    adds nothing and keeps that record: the separator still names handle 6
    and draws continuous there.
    `installParametric` does **not** write it: on a loaded file that would
    change the document outside the history, and load → save would no
    longer be byte-identical. **A document without the record draws its
    separators continuous** (the painter's missing-record fallback,
    `draft_painter.dart:656-661`) and nothing else changes. 12's file-open
    path decides whether to add it (recorded).
    *Answered by spec 12a D8 (R-3): Open does not add it; every document
    the app makes has it.*
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

**Amended at execution (Plan 10):**
- **`ensureDashedLinetype`'s duplicate rules** (handle 6 taken; the name
  `DASHED` on another handle) are pinned by **`SR5`**, a test the plan
  added (Ruling 10-1); `X9-dupName` is red on it.
- **The record's description** is `'Dashed __ __ __'`
  (`LinetypeRecord` requires one; Ruling 10-14).
- **"Not more than `roomTrace.linear`" is exact at the boundary:** a
  separator exactly `roomTrace.linear` long is degenerate, and a wall
  ring with a non-finite coordinate contributes nothing; `DG4` pins both
  (the Task 9 review's `rv9-sepLenGe` and `rv9-wallFinite`, carried to
  Task 13).

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
- **A wall's place** (D16): `placeBox` is the box of this world ring and
  `placeInput` the ring itself, as a value with element-wise exact `==`;
  a separator's are its segment's box and the segment. A ring with a
  non-finite coordinate gives `null` (not placed; S-6), which 07's
  `fromJson` makes possible only from a file (recorded, 07 D2's debt).
- **A wall's input is memoised per view** (an `Expando` on the view, 08's
  `hostCutsInView` precedent), so `placeBox` (D16) and every room's trace in
  one plan compute each band once.

**Pinned by:** `RI1` (adapters), `RT2` (openings, M-10d), `RT5` (the
local-ring fallback).

**Amended at execution (Plan 10):**
- **One local ring** (Ruling 10-8): 07's `_localOutlineOf` is now a thin
  wrapper over a pure `localOutlineOf(WorldWall self, List<WorldWall>
  neighbours)` in `wall_geometry.dart`, so the wall's own generate and
  both room adapters compute one ring. The wall's stored children are
  unchanged bit for bit; 07's and 08's tests pass unedited.
- **The document adapter's predicate** (Ruling 10-10) is one named
  constant in `room_inputs.dart`, the only `Tolerance.standard` in the
  room files; its neighbour pass is a sort-and-sweep. **The adapter is
  `RoomInputs`** (Ruling 10-11), live objects only, stale on each
  `doc.changes` event; it gained **`invalidate()` and a generation** (as
  08's `WallBands`), so a tool that commits can query the edited document
  before `doc.changes` arrives (Task 9 review m-3): the Room tool calls it
  at every click, the Separator tool at the second click and after its
  execute, the separator grips at release.
- **How `RI1` sees the view adapter** (Ruling 10-12): a test-only
  catalog whose `_Probe` object's `diagnose` records `roomInputInView` and
  `view.neighbours` for every contributor, compared with `RoomInputs` by
  `==`. **`RI1` holds 07's wide node cluster** (members within
  `wallJoin.linear` of the anchor, about 2e-6 mm from a wall's end), where
  a trace among all walls and one among reach neighbours differ (Task 9
  review I-1; at the identity and an exact quarter turn, whose premise a
  23° turn cannot hold), and a wall added after a separator (ascending
  lists).
- **`RoomInput`'s `==` is exact and pinned:** `RI2`, a test the plan
  added (Task 9 review I-2): one ulp in any single coordinate, a different
  source, `closed`, or one point fewer breaks `==`, and equal inputs hash
  alike.
- **Known edge, 08's:** `wallsInDocument` (08's document adapter) passes
  every live wall as a wall's neighbours, not the engine's reach list; the
  two give the same ring except inside 07's wide node cluster, where the
  Task 9 review's probe shows a different one (the review's observation).
  Rooms do not use it; it is recorded as a 07/08 edge.

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
9. **Clean-up:** **doubled edges are split out** **[amended at
   execution, Plan 10, decision 29; D9]**: wherever a face's walk takes a
   half-edge and, later, its twin, both are removed and the walk between
   them becomes a loop of its own, until no loop holds a half-edge and its
   twin. A spike (`u → v → u`, a dangling separator end) is the case with
   nothing between them. The outer cycle leaves the outer ring (its loop
   of greatest area) and a hole per island tied to it; a hole's contour
   leaves a hole per island it ties together. Then vertices collinear
   within `roomTrace.linear` (between their neighbours) are removed; holes
   are reversed to anticlockwise, their sources moving with their edges.
   Areas are the shoelace in the local frame; the net area is the outer
   area minus the hole areas.

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

**Amended at execution (Plan 10):**
- **The output is canonical** (Ruling 10-7). Each ring, the outer and
  each hole, starts at its least vertex in `(x, y)` order in the
  seed-relative frame and runs anticlockwise; where a ring passes through
  that vertex more than once (a pinch), at the start whose following
  vertices are least. Holes are ordered by their first vertex in the same
  order; sources move with their edges, each set ascending by handle;
  areas are summed in that order. `SeedInWall` names the lowest-handle
  input that holds the seed. The start is applied before and after the
  collinear clean-up (Task 10). D7's "a function of `C` and the seed"
  needs nothing more.
- **Ruling 10-7's premise, corrected** (Task 11). The ruling said far
  inputs shift vertex indices and so could move a ring's start, which
  `LZ1` would see. They do not: far inputs never move the walk's start,
  and `LZ1` stays green without the canonical order (the mutant
  X11-canonical; the Task 11 review's adversarial probe, 420 comparisons,
  all equal). What the order pins is the output against a **relabelling**
  of the inputs' handles, which does move the start: X11-canonical is
  killed by `RT2`, `RT3`, `RT4`, `RT6`, `RT7` and `RT8`. The ruling
  stands; its reason is this one.
- **A hole needs three vertices** (Task 10 review I-1): a free tree of two
  or more separators could come back as a two-point, zero-area "hole",
  its sign depending on where the cycle started. A cleaned contour of
  fewer than three vertices is not a hole. Since step 9's split (decision
  29) a free tree leaves no loop at all, so the rule is subsumed (its
  removal is now equivalent); a triangle of separators is a hole (`RT8`).
- **Tolerances in the pair search:** the sweep's window and the box
  reject on `y` both use `roomTrace.linear` (separators 0.5 nm short of a
  face still join it, `RT8`), and the parallel test is the angular one (a
  diagonal centreline-to-centreline separator, `RT8`).
- **Sources:** a hole's edges carry their own walls (`RT4`), and a face
  along two collinear joined walls keeps both, ascending (`RT7`).
- **Where M-10d is fired:** `RoomInputs._refresh`, the document adapter
  (`roomInputOf` takes no document, and the view cannot expose stored
  pieces). **X10-collinear's killer is `RT8`,** not `RT1`: the sample
  plan's T-butt splits are room corners, not collinear vertices.
- **`debugTracedSegments`** is not annotated `@visibleForTesting`: the
  pure file takes no `package:meta` dependency (as
  `RoomInputs.debugRebuilds`).

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
- **Amended at execution (Plan 10, decision 29): a tied island is a
  hole.** An island tied to the ring, or to another island, by zero-width
  inputs only (a separator, a chain or a tree of them) is a **hole**,
  subtracted and cut out of the tint as a freestanding island is: the tie
  has no thickness and no area, and the doubled edge it puts in the walk
  is split out (D5 step 9; the rule, where it runs and what follows from
  it are in D9's paragraph). A wall touching the boundary (a column
  against a wall, a stub wall with its thickness) is still walked around:
  a band has two faces, so it makes no doubled edge. The hole test above
  reads the outer cycle as walked, before the split, so a component inside
  a tied island's courtyard stays outside the face.

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
     touches `B`). `Unbounded`: double `r` and repeat, until `B` contains
     `U`, the union of every contributor's **finite** place box (a place
     box with a non-finite coordinate is treated as `null`: not placed, so
     it can neither stall the loop nor be traced; S-6); then `Unbounded` is
     final. With no contributor at all, `Unbounded` at once.
  2. **Certificate.** On `Traced(F)`: let `C = placedIn(box(F) ⊕ m)`, `m =
     1 mm`. If `C` holds a contributor not yet traced, add it and trace
     again (the face can only shrink or gain holes); repeat until `C` adds
     nothing. **One round always suffices:** the re-traced face `F′ ⊆ F`,
     so `box(F′) ⊕ m ⊆ box(F) ⊕ m` and nothing new can touch it; the loop
     is written as a loop only so that its exit condition is the
     certificate itself.
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
growth box `B`), `LZ3` (`debugTracedSegments`, below); M-10cand,
M-10cert, M-10grow.
- **The counter:** `debugTracedSegments` in `room_trace.dart`,
  `@visibleForTesting`, never reset by the library, counts the segments
  each `traceRoom` call takes in (step 3 of D5). `LZ3` pins an upper bound
  per rebuild on the sample plan, set from the plan's own run and recorded
  with it.

**Amended at execution (Plan 10):**
- **`U` for the view source** (Ruling 10-13): the view has no "every
  contributor" query, so `U` is the union of `placeBoxOf(h)` over
  `placedIn` of an infinite box, computed once per view and memoised with
  the room's trace memo. The first `placedIn` computes every box anyway.
- **Step 3's trace is skipped** when the certificate's last trace was
  already among exactly `C`: the same set gives the same bits.
- **The margin is pinned at 0.5 nm:** `LZ1` holds a separator 0.5 nm
  (5e-7 mm) outside a face, which only the 1 mm margin brings into `C`
  (margin 0 is red). Commit `9eb913e`'s subject says "0.5 um"; the case is
  0.5 nm, and the test's name and comments say so (Task 11 review m-1).
- **A non-finite seed** is `Unbounded` and the loop ends; so is any seed
  in an empty or degenerate-only document, on both sources: **`LZ4`**, a
  test the plan added (Task 11 review m-2), each trace in its own isolate
  so a loop that never ends fails on time.
- **`LZ1`** runs 1,440 comparisons, the tied-island fixtures of decision
  29 included (Task 14b).
- **`LZ3`'s bound, from the plan's run** (Ruling 10-20): **50 segments
  per rebuilt room.** Moving P5 10 mm rebuilds the Kitchen and the Bath,
  99 segments in all; their localised traces take in 49 and 50 (growth
  to r = 4,000 mm, the certificate, the canonical trace among four
  walls). One trace among every contributor would take in 41: on a plan
  of 11 contributors the growth costs more than tracing everything, and
  what it buys is a cost that does not grow with the plan. `LZ3`'s
  second case adds 40 walls 40 m east and asserts the same counts. The
  bound has no headroom; it is deterministic.
- **M-10cert's app-level killers** are `FZ1` and `LZ2`, not `DF1`: every
  face in `DF1`'s script closes in its first tracing box (the Task 14
  re-review).
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
| partition end pulled back 160 mm (a 60 mm gap; the spike pulled 150) | both deleted | **both survive**, one face: the partition keeps its T at the north end and its band, 100 × (3,900 − 160) = 374,000, stands in the merged face, so 7,800 × 3,800 − 374,000 = 29,640,000 − 374,000 = **29,266,000** (`29.27 m²`), `room.shared` |
| decision 16's separator pulled 50 mm short | Dining and Living deleted | **both survive**, one face, `room.shared` |
| the sample plan's E4 deleted | Hall deleted (cascade) | **Hall and Bedroom 1 dissolve**: both faces open to the outside |
| the column deleted | Living kept, hole gone, `parametric.orphan` | Living kept, hole gone, **no diagnostic** |

**Pinned by:** `RD1`–`RD8`; M-10dissolve, M-10shared.

**Amended at execution (Plan 10):** the rule as built, and one
consequence in the shell.
- **Deleting an outer wall of the sample plan dissolves the rooms whose
  faces open to the outside,** in the same step, as this section says.
  The shell's two wall-delete undo tests (`planner_shell_test.dart`, 08's)
  counted children before rooms existed; they now name the rooms the
  delete dissolves and check that the undo restores them (Ruling 10-22,
  `2eb2da6`, accepted by the controller). No other 07 or 08 test changed.
- **The undo of a dissolve is content-exact;** what can differ from
  before is the root's child order (a restored group is re-linked last
  among the root's children) and the entity slot order; every handle and
  each room's own children are restored exactly, which is 06's and 08's
  pre-existing undo behaviour (the Task 18 review; the same at
  `10894c6`; the final review's probe D). Draw order follows handles and
  is unaffected (D18); save→load→save is byte-identical in every state.
  *(The root's child order superseded 2026-10-10 by the host embedding
  spec's O-10: an undone removal restores the node's index.)*

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
  colour model. Decision 28 confirms the foreground. **[spec ruling]**
  (R-8): explicit ACI 7, not ByLayer, so a later change to layer 0's colour
  does not recolour tints;
- **transparency 229 on the fill** (alpha 26 of 255, about 10%; decision
  28, "the page's foreground at about 10%"): black at alpha 26 over white
  is 255 − 26 = 229, **`#E5E5E5`**, a light grey; white at 10% lifts
  Blueprint visibly (the spike's fixed blue at 25% all but vanished there:
  finding 5);
- **the boundary is invisible** (`EntityFlags.invisible` on the boundary
  record only). An invisible boundary is dropped by picking and rendering
  (`query_filter.dart:72-79`), the painter still draws the fill from the
  boundary's geometry, and bands skip fills. So **the tint is never
  pickable, band-selectable or snappable, and its edges are never stroked
  by the painter**. Only the selection overlay outlines them, and only
  while the room is selected or hovered (decision 27, D24) (the spike's slit and separator-overdraw
  artefacts, finding 2). **No `unpickable` flag** **[spec ruling]**
  (R-10): the spike showed either mechanism alone suffices (M-unpick and
  M-visible both survived there); one mechanism is simpler, needs no
  non-DXF bit that an export must strip, and M-10visible now kills.

**The tint's shape** (spike open decision 5):
- **Holes are cut by a keyhole with a slit** **[spec ruling]** (R-11),
  computed by one pure function, `tintOf(ring, holes)`, **in the trace's
  seed-relative frame** (D5 step 1) before the result is mapped to the
  room's local space:
  - the holes are taken in descending order of their rightmost `x` in
    that frame;
  - each hole joins the **growing keyholed ring** (the outer ring with
    the holes already joined) through a bridge from its rightmost vertex
    to the nearest vertex of that ring whose bridge properly crosses no
    edge of that ring and no edge of any hole not yet joined;
  - the return edge runs **0.5 mm** to the bridge's right, so the ring
    stays simple;
  - **a hole with no such vertex is left out** of the tint (the tint
    covers it) and `room.tint` reports it (D22); the area is unaffected. The engine's triangulator refuses an exact keyhole
  (two coincident edges: 0 triangles, spike Q5, M-slit); the slit version
  of the spike's Living triangulated (11 stored points, 8 triangles). The
  tint is then short of the true region by 0.5 mm × the bridge's length;
  the **area label comes from the trace, never from the tint**.
- **A fallback chain**, so an edit is never refused because of a tint:
  1. the keyholed ring, if it triangulates;
  2. else **the outer ring alone** as the region (holes tinted over), if it
     triangulates;
  3. else **an invisible, unfilled closed POLYLINE** of the outer ring, in
     place of the region (reachable when the outer ring touches itself at a
     vertex, which a face walk can produce where two bands meet at a single
     corner; `tintOf` is tested directly on such a pinched ring).
  Steps 2 and 3 are reported `room.tint` (D22). Step 3 changes the child's
  kind, so a later return to a region adds it with fresh, higher handles
  than the labels (06 D12's accepted cost; invisible in practice, since
  the tint is translucent). Every form keeps **every outer-ring vertex among
  the stored points**, which D16's read box relies on.

**Amended at execution (Plan 10, decision 29): a doubled edge is split
into a hole before the tint is cut.** A separator (or a chain or tree of
them, or any zero-width input) that ties a freestanding island — a column,
a kitchen island, a triangle of separators — to the ring, or islands to
each other, is walked out and back by the face: the walk carries a
**doubled edge**, one edge in both directions. That is an exact keyhole
with a slit of 0, which the engine's triangulator refuses; the tint fell
through steps 1 and 2 to step 3, and the room showed an unfilled outline
and `room.tint`. Users hit it with a single tie from a wall to a column,
and transiently while drawing wall → column → wall (Task 14's review; 60
of `FZ1`'s tint checks at seed 1010).

- **The rule.** Wherever a face's walk takes a half-edge and, later, its
  twin, both halves are removed and the walk between them becomes a loop of
  its own, until no loop holds a half-edge and its twin. The outer cycle
  leaves one anticlockwise loop, the **outer ring** (its loop of greatest
  area), and one clockwise loop per tied island, which is a **hole**; a
  hole's contour leaves one clockwise loop per island it ties together; an
  empty loop, and a free separator tree, leave nothing (D6: no area, no
  hole). A spike (`u → v → u`) is the case with nothing between the two
  halves, so D5's spike removal is this rule's special case. On a face's
  walk the doubled pairs nest, so the loops do not depend on the order of
  the splits or on where the walk starts: the output stays canonical
  (Ruling 10-7) and `LZ1`'s bit-for-bit agreement holds.
- **Where it runs: the tracer's clean-up (D5 step 9), not the tint
  builder.** The tracer holds the half-edges, so a doubled edge is an
  identity — a half-edge and its twin in one walk — decided exactly, with
  no tolerance and no geometry; a point ring after collinear removal can no
  longer show one reliably (a doubled edge merged into a longer collinear
  edge), and two inputs overlapping are already one edge carrying both
  sources (D5 step 5), walked once, never mistaken for a doubled one. And
  every reader of the trace — the tint, the label pole, `room.shared`, the
  Room tool's occupied-face test, the selected ring (D24) — sees one face:
  a simple outer ring and its holes, the holes a freestanding island
  gives.
- **What follows.** `Traced.ring` is the outer ring without the ties; the
  island is among `Traced.holes`, its sources moving with its edges and
  ordered with the other holes by Ruling 10-7; a tie is in no source set.
  **The area is unchanged:** a doubled edge encloses nothing (its two
  halves' shoelace terms cancel), so outer area minus hole areas is the
  walk's own area, to rounding in the seed-relative frame far below the
  1e-2 mm² of every oracle. **The label pole** (D10) reads the outer ring
  and the holes, so it avoids the island, as it did when the ring walked
  round it; a tie, which bounds nothing, is no obstacle to it, as a free
  separator is not. `tintOf` keyholes the island as any hole: **step 1**,
  and **D22's `room.tint` is not reported** for a tie.
- **What remains for step 3:** an outer ring that touches itself at a
  vertex (a pinch: a column touching the ring at a corner, two bands
  meeting at a single corner; `RG2`'s turned column). A tied island that
  is itself pinched (two columns touching at a corner) is one pinched
  hole, whose keyholed ring does not triangulate: step 2, reported, as the
  same island untied. `FZ1` at seed 1010 now takes step 1 in all 1,855 of
  its tint checks.
- **The slit is checked as well as the bridge, and each of its ends sits
  in its own sector (Task 14c, the 14b and 14c reviews).** "The return
  edge runs 0.5 mm to the bridge's right, so the ring stays simple" held
  only if the slit crossed nothing, and nothing checked it: at an acute
  rightmost vertex whose wedge the bridge runs along, the return edge
  crossed the hole's edge beside it, the keyholed ring was not simple, and
  a simple hole took step 2. A vertex now qualifies only when its bridge
  is clear **and** the slit's three edges (the hole's last edge into `H'`,
  the return `H' → V'`, and `V'` onward) cross, touch, or share an end
  with no other edge of the ring or of a hole not yet joined (an end on an
  end: a later bridge running along an earlier one, whose `V'` lands on
  the earlier `H'`, would pinch the ring; seed 31337's plan t92). The slit
  is first `H' = H + s`, `V' = V + s`, 0.5 mm to the bridge's right; if
  that is not clear, each end goes inside its own sector, 0.5 mm from its
  vertex: `H'` in the sector from `H → V` anticlockwise to the hole's last
  edge, `V'` in the sector from `V`'s next ring edge anticlockwise to
  `V → H`, at the perpendicular point when the sector sweeps between 90°
  and 270°, else on its bisector (under 90° the perpendicular point lies
  outside it; over 270° the edge from its far side cuts back across the
  bridge). Otherwise the next nearest vertex is tried, and a hole with
  none is left out as above. The fallback order is unchanged.
- **Why the perpendicular slit first, and what it costs.** It is what the
  keyhole always did, and any slit that passes the check is simple;
  placing each end in its sector straight away left out more holes near
  the ring than before (31 traces over the 14c review's four fuzz seeds).
  Its cost: at a convex vertex of the ring (nearly every box corner) the
  perpendicular `V'` lies outside the face, by up to 0.5 mm, so the tint
  covers a sliver of the wall there, as before Task 14c; where a later
  hole bridges to an earlier slit end the two add up: each chained bridge
  adds at most 0.5 mm; about 1 mm in the reviews' fuzz (0.99999979 mm).
  The area label is the trace's, never the tint's.
- **What remains.** Step 2 is reached by a pinched hole only (none on a
  simple hole in the 14c review's four fuzz seeds). A **simple** hole is
  left out only within the slit's width (0.5 mm) of the ring or of another
  hole, where no placement of a 0.5 mm slit is clear (`RG2`'s column
  0.2 mm off two faces, unturned; the fuzz, seeds 1414, 2718, 31337 and
  4242: 15, 12, 8 and 12 such holes, none farther). A **pinched** hole
  (two shapes sharing a vertex) takes step 2 **or is left out**, wherever
  it lies (the fuzz: 8, 0, 8 and 3 pinched holes left out, as seed 1414's
  t81, two thin triangles sharing their rightmost vertex 75 mm from the
  ring). **Pinned by:** `TN1` (the acute hole bridged to its nearest
  vertex with both ends on their bisectors; the fuzz plans t107, t0 and
  t92; a slit crossing and a slit touching a hole not yet joined; the
  pinched hole's step 2; six placements), `RG2`; mutants
  X14c-noSlitCheck, X14c-noSectorH, X14c-noSectorV, X14c-noEndOnEnd,
  rv14c-noLater, rv14c-noTouch.

**Pinned by:** `DE1` (the trace: one tie, a chain, a T-branch, a tie drawn
twice, a separator along a face, two ties, two islands tied, a triangle of
separators tied, a pinched island tied; six placements), `DE2` (the room:
step 1, the area, no `room.tint`, the label clear of the column; the
pinched island's step 2; six placements), `DE3` (the Separator tool's
transient), `LZ1` (the same fixtures, localised against all-inputs, bit for
bit), `FZ1` (the census); mutants X14b-noSplit, X14b-oneHalf,
X14b-dropInner, X14b-noSources, X14b-coincident.

**The labels' attributes:** ByLayer on layer 0 (the foreground, like 08's
symbols), `STANDARD` text style, justification **centre, middle**
(`textAttrs`, D13), flags 0. They are pickable: **a room is selected by
its labels** (decision 4), and a label over furniture wins the click
(decision 22; the spike's lamp, `Q6`).

**Pinned by:** `TN1` (`tintOf`: the keyhole rules and step 3), `RG1`
(children, order, attributes), `RG2` (holes and the
fallback chain), `RR1`–`RR4` (renders and picks); M-10slit, M-10visible,
M-10tintcolour, M-10tintalpha.

**Amended at execution (Plan 10):** the slit's real error, the bridge
rule, step 3's handles and the test seam. Decision 29's and Task 14c's
paragraphs above stand; this adds what they do not say.
- **The slit's error, measured** (Task 13's finding, its review's m-3;
  this replaces "the tint is then short of the true region by 0.5 mm ×
  the bridge's length"). The slit's return point can sit **up to 0.5 mm
  outside the face**, on either side of the bridge: into a wall's band,
  across a separator into the neighbouring room's face, or through a wall
  thinner than 0.5 mm. Where bridges chain, each adds at most 0.5 mm
  (Task 14c's paragraph: about 1 mm in the reviews' fuzz). So the tint's
  error against the true region has **either sign**, and it scales with
  the ring edges at `V` and `H` (about 0.25 mm × edge length), not with
  the bridge. The area label is the trace's and is unaffected. D16's 2 mm
  read margin still covers the stored box: an overshoot only grows it.
  D18's "the tint never covers a wall's band" is amended to match.
- **A bridge through a vertex is blocked** (Task 11 review I-1). On
  axis-aligned plans a bridge could run along the hole's own edge, or
  through a vertex of an obstacle, and `_blocked` rejected only proper
  crossings: the keyholed ring was not simple and the tint fell to step
  2 (a column flush below a partition's face). A bridge is also blocked
  when any obstacle-ring vertex lies strictly inside it (collinear,
  between its ends). `TN1`'s case 4 (that column through the real trace,
  six placements) takes step 1.
- **"No vertex whose bridge is clear" is unreachable from a real trace:**
  the rightward ray from `H` meets the ring first (Eberly), so that
  branch is defensive, and `TN1` reaches it with a hole outside the ring.
  A hole **is** left out, reachably, when no clear keyhole (bridge and
  slit) reaches it, as Task 14c's paragraph says; `room.tint` reports
  "no clear keyhole reaches them" (D22).
- **Step 3 and handles** (Task 13). Step 3's POLYLINE is a new kind, so
  it is added with fresh handles above the labels, and a later return to
  a region adds the fill and boundary above the labels too. From then on
  **the tint draws over its own labels** (translucent at about 10%, so
  they still read); D18's "the labels draw over the tint" holds while the
  tint keeps its first form. At Task 14, before decision 29, `FZ1` at seed
  1010 found 465 of its region checks in that state.
- **Ruling 10-16's seam stays,** for a different reason. Honest fixtures
  for both steps exist (Task 13): step 2, columns 0.2 mm off two faces
  (since Task 14c, a pinched free island); step 3, a column turned 45°
  pinching the ring. `RG2` runs them without the seam. `room.dart` also
  re-checks, in `generate`, that the tint **mapped to the room's local
  frame** still triangulates, and steps down the chain rather than let the
  engine refuse the edit (Task 12; the controller kept it: this section
  forbids refusing an edit over a tint). That guard is practically
  unreachable (a 0.5 mm slit against ulp(1e9)), and `debugTintFailedSteps`
  is the only way to exercise it, so the seam stays, null in the library
  and reset in `tearDown`; removing the guard without the seam is
  equivalent by unreachability.
- **One helper for both readers:** `generate`'s stored step and
  `diagnose`'s `room.tint` come from one function (the relative `tintOf`
  and the local guard), so they cannot disagree (Task 12 review m-4).
- **The labels' "centre, middle"** is `packTextAttrs(h:
  TextJustifyH.centre, v: TextJustifyV.middle)`, not `TextJustifyH.middle`,
  which is DXF's other "middle" (Ruling 10-14).

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

**Pinned by:** `RL1` (thin L, all six placements (T-5): the asserted value is the
pole's **distance** to the boundary, 585.786 by hand, within the 10 mm
precision at every placement, and at the origin also the pole's
**coordinates**, (685.786, 685.786) by hand, within 10 mm), `RL2` (the column),
`RL3` (offset rides with the pole), `RL4` (a rotated room group);
M-10c, M-10centroid, M-10offset, M-10offsetref.

**Amended at execution (Plan 10):**
- **A mirrored room group is not covered.** "Horizontal and sized on
  paper under any similarity" holds for similarities without a
  reflection. Under a mirrored room group (only a file makes one) the
  labels are not kept horizontal (the Task 12 review's observation; no
  action, recorded as a known limit).
- **Measured** (`RL1`, this plan's final gate run): the pole's distance
  to the boundary is 583.40 mm at the origin and +1e9 mm unturned, and
  583.24 mm at the four turned placements, against 585.786 by hand:
  within the 10 mm precision, as asserted.
- **`RL3` and `RL4` pin the offset's frame** (Task 12 review m-1, m-2):
  a fractional label under `RL4`'s turned, scaled group satisfies `anchor
  − pole == toWorld.transformDirection(label)`, and a room whose offset is
  `(5.5, NaN)` is treated as auto (D2), so both components' finiteness
  counts.

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

**Amended at execution (Plan 10):**
- **One tie on purpose.** `RA1` holds a room of 1,524 × 1,714.5 mm =
  2,612,898 mm², exactly 28.125 ft². `304.8 × 304.8` in double arithmetic
  is 92,903.04000000001, a little above the true square foot, so the
  quotient falls just below the tie and reads **`28.12 ft²`**; squaring
  3,048 as integers first would give the tie itself and `28.13`. The case
  pins the double form this section specifies (the mutant X11-feet; Task
  19's audit). Every other expected label keeps the 0.0005 m² clearance.
- **A tie follows the binary value** (the Task 11 review: 29,265,000 mm²
  reads `29.27`); `-0.00` is unreachable (an area is never negative).

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

**Amended at execution (Plan 10):**
- **The engine's test clients** (Ruling 10-2) are `Caption` (`TX1`) and
  `Swatch` (`AT1`), in `test/parametric/support/clients.dart`.
- **The match by ordinal is pinned:** `Swatch` generates two TEXTs whose
  strings change independently, so matching the i-th generated TEXT to
  the i-th existing one goes red under an index mistake (the Task 1
  review's `rv1-idx`), in the engine (`AT1`) and in a room (`RG3`,
  `RG4`). The match reads the string through the column accessor
  `textAt`, not a record read.
- **`TX1` runs at fractional values** (its fixture at `(1234.5,
  -310.25)`, turned 0.4).

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

**Amended at execution (Plan 10):**
- **Every attribute must differ from its default in a fixture,** or
  dropping it from `_recordOf` is invisible: `Swatch` sets non-zero
  `flags` on its TEXT and plain children (`rv1-flags`), and its inherit
  variant sets its fill's flags to invisible so that `boundaryFlags`'
  default (`?? flags`) is observable (X2-default; the plan's fill flags
  of 0 would have let it survive).
- **A re-add in place of a match** is caught by handle equality
  (`rv2-readd`). No command sets a record's attributes, so nothing
  rewrites one under a match (the Task 2 review's minor on the
  add-versus-match contrast, not taken).

### D14 — Engine (c): the page

- **`ParametricView.page`**: the root's `PageComponent` in the view's
  survey (a snapshot, D16), or `null` when none is attached or the type is
  not registered.
- **`ParametricType.pageKey(PageComponent? page) → Object?`**, default
  `null`: the part of the page this type's `generate` reads, compared with
  `==`. The room returns the record `(unit, scaleDenominator)` of the page,
  or of `PageComponent()`'s defaults when `page` is null.
- **Seeds on a page change.** In `_run`, after the seeds are formed and
  **before the early return** (`regeneration.dart:585` returns when the
  seeds and the cleanup are both empty, and a page-only edit touches the
  root, which is not an object, so its seeds are otherwise empty; S-12):
  when
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
(a paper-colour or grid change calls no `generate` of a page-key client:
the client counts its calls, since a seeded object with an unchanged key
plans nothing either way); M-10page, M-10pagekey.

**Amended at execution (Plan 10):**
- **Where the page seeds sit** (Ruling 10-4): in `_run`, **after
  `_checkDangling`** and before the early return. Before the dangling
  check (the spike's place), a loaded `cascade` referrer with a dead
  reference whose type reads the page would refuse every page change;
  08's rule is that only seeds are checked, and a page-seeded object was
  not edited. `PG1` has the case (a `Gauge` with a dead `host`).
- **The guard is at the call site:** `if (before.page != after.page)
  seeds.addAll(_pageSeeds(...))`, so `pageKey` is never called on any
  other edit. A call counter on the `Gauge` client pins it (the Task 3
  review's `rv3-noShort`), and one `PG1` step changes the scale and the
  unit in one command (1:50 m → 1:100 ft-in) and expects both `Gauge` and
  `Dial` to regenerate (`rv3-firstType`).
- **M-10pagekey is read as "every type with a non-null key seeds"**;
  X3-allTypes (every registered type) is red at `PG1`.
- **The engine's clients** are `Gauge` (scale) and `Dial` (unit)
  (Ruling 10-2).

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
  *(Superseded 2026-10-10 by the host embedding spec's O-10: an undone
  removal restores the node's index, so the bytes compare exactly.)*
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

**Amended at execution (Plan 10):**
- **The plan's order has no state consequence.** "The subtree removal,
  then the detach" leaves the same state and the same undo in either
  order; `DV1` reads the order from the plan's replay, which is its only
  witness (X4-order is red only there, and the replay line also kills the
  Task 4 review's `rv4-noFills`). The order is kept as a convention (the
  Task 4 review's ruling).
- **`DV1` also plans past a dissolve:** one command dissolves a `Fuse`
  and changes a second `Fuse` later in the closure; `drift()` stays
  empty (`rv4-break`). A throwing verdict rolls the whole edit back.
- **Known limit: a referrer of a dissolving object.** "No other object
  reads a room" holds for everything 10 makes, but 08 D17 lets an opening
  name a live non-wall host. **Only a loaded file whose opening names a
  room as its host** reaches it: when that room dissolves, the opening is
  left with a dead reference, reported `parametric.dangling`, and an edit
  of the opening is refused (the Task 4 review's probe). No code in 10.

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
/// Called only when [contributesPlace]; must not mutate. A box with a
/// non-finite coordinate is treated as null (not placed).
Aabb2? placeBox(ParametricView view, Handle self) => null;
/// What this object contributes, compared with `==` between the before-
/// and after-views to tell whether it changed (a wall: its uncut band's
/// world ring; a separator: its world segment). Called only when
/// [contributesPlace], only for objects of an edit's spatial core, and
/// only when [placeBox] is not null. Default: a fresh `Object()`, equal to
/// nothing, so a contributor that does not override it always counts as
/// changed (T-2).
Object placeInput(ParametricView view, Handle self) => Object();
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
/// Ascending live objects of this view's survey whose registered component
/// is a [U] (S-3: a room's `diagnose` finds the other rooms with it).
/// Read from the survey's snapshot; memoised per view and type.
List<Handle> objectsOf<U extends Component>();
```

**`placeInput`'s default is "always changed"** (T-2). The alternative, a
default equal to the box, is unsafe: a contributor whose input changes
inside an unchanged box (a segment flipped from one diagonal of its box to
the other) would count as unchanged and leave its readers stale, and a
type that forgot to override would be silently wrong. Making it
*required* for contributors is not expressible on `ParametricType` without
forcing every non-contributor type to implement it (a Dart abstract member
binds every subclass). "Always changed" is revision 1's behaviour for a
type that does not override: it can only over-rebuild, never drift. The
wall and the separator override it (D4).

`objectsOf` is generic and survey-backed: the survey already holds every
live object with its registration, so the first call per type is one O(n)
pass and later calls are free. A room has an empty reach, no references
and is not a contributor, so nothing else in the view can find another
room (S-3).

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
dangling check, when the seeds are non-empty **and the after-survey holds
at least one live reader** (the survey counts readers as it registers
objects, so the check is O(1); S-4):
- `K = seeds ∪ neighbours_before(seeds) ∪ neighbours_after(seeds)` — the
  spatial part of 08 D3's core, already computed;
- for each contributor `k ∈ K`: its before place (box and input, from the
  before-view) if `k` was live before, and its after place (from the
  after-view) if it is live after. **`k` is changed** when exactly one of
  the two exists, or both exist and their inputs differ (`placeInput`,
  exact `==`: a stored-value style comparison of two deterministic
  computations; any bit difference counts as a change, which only ever
  rebuilds more). **Only a changed `k` adds its boxes (before and after)
  to `L`** (S-4): an unchanged neighbour's band is the same as before, so
  it can change no room;
- if `L` is empty, nothing more. Otherwise, **every live reader `R` (after)
  that is not a seed and whose `readBox(params, toWorld, stored)` touches
  any box of `L` joins the core**, before 08 D3's referrer step.
- **`stored`** (S-14) is formed by the engine: every `(x, y)` pair of the
  `coords` of each of `R`'s children's payloads (from the after-survey's
  children; a fill's payload has none), mapped by `toWorld(R)` (the
  snapshot), and boxed. It is a box of **defining points**, not of drawn
  extents: a reader whose output has arcs, circles or text extents that
  matter must grow it in its own `readBox`. The room's tint boundary holds
  every outer-ring vertex (D9), so its points suffice.
- **The after-view is the one `_plan` receives** (S-12): the trigger and
  the plan share one `ParametricView` object, so D4's band memo and the
  bulk neighbour pass are computed once per edit.

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
- `L` holds exactly the boxes of the changed `k` (point 2), and for each,
  its before and after boxes miss `readBox(R) ⊇ box(F_before) ⊕ m`. The
  proof reads only changed inputs, so restricting `L` to them (S-4) leaves
  it whole. So no member of `C_before` changed, no changed input
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

**6. Cost bound, per edit** (restated after S-4):
- a plain entity edit (no seeds): nothing (the early return);
- a document with no live reader: nothing beyond 08's closure (the O(1)
  check);
- an edit whose `K` holds no contributor (a door, a box, a room's own
  rename): nothing beyond 08's closure;
- an edit whose `K` holds contributors, with readers present: **one
  place-box call per `k ∈ K ∩ contributors` live before plus one per such
  `k` live after** (an added or deleted contributor has one, not two;
  S-13), with the same number of `placeInput` calls (both read D4's band
  memo, so each band is computed once per view), O(|K| · n) overlap tests
  (07 D10's order), and one read box per live reader (O(its stored
  points));
- **the rooms rebuilt:** exactly those whose read box touches the before
  or after box of a contributor **whose input changed**. For a wall move
  that is the rooms along the moved wall and along any joint partner whose
  band the move reshapes (an L or node partner; never a through wall the
  moved wall merely tees into, whose band does not depend on its stems).
  The review's example — moving P5 10 mm, whose reach neighbours E1 and P3
  are unchanged — rebuilds the two rooms P5 bounds (Kitchen, Bath), not
  the five whose read boxes E1's and P3's bands touch (worked from the
  plan's coordinates for this revision: P5's band, x 21,440–21,560 between
  E1's and P3's near faces, touches only those two read boxes; `RK2`
  measures it). That holds **at the plan's own axis-aligned placement**;
  under rotation the band boxes inflate and can add a neighbour room (the
  re-review's run at the corpus's 23°, in both its placements: `rebuilt
  (changed only) [Kitchen, Bath, Living]`; T-3);
- if any room regenerates: one bulk pass, O(n log n + pairs), and the
  place boxes the after-view does not hold yet: **`c − |K ∩ contributors
  live after|` more `placeBox` calls**, `c` the live contributors after
  the edit (the first `placedIn` of the view; the after boxes of `K` are
  memoised and not recomputed), O(n) band computations, once per edit;
  then D7's localised traces per room.
- **Counters,** `@visibleForTesting`, never reset by the library:
  `debugPlaceBoxCalls` counts **calls into a type's `placeBox`**, the bulk
  pass included; **a memo hit is not a call** (T-4). And
  `debugReadBoxCalls`. `SD6` pins the trigger's counts
  on a fixture where no reader regenerates, and the bulk pass's count
  separately (S-13).

**Pinned by:** `SV1`–`SV3` (the before-view), `SD1`–`SD11` (engine
clients: the trigger, two hops, before and after, readers, the counters,
the bulk pass, an unchanged neighbour adding nothing, no readers,
`objectsOf`, the diagonal flip `SD11`), `RS1`–`RS6` (rooms: c1–c4,
`Q3e`, `FB`), `RK1`, `RK2`; M-10nbr, M-10before, M-10snap, M-10e,
M-10bulk, M-10cand, M-10allK, M-10objects, M-10inputbox.

**Amended at execution (Plan 10):**
- **Staged in three tasks** (Ruling 10-3): the roles, the before-view and
  the trigger together (the before-view is read by nothing but the
  trigger, so `SV1`–`SV3` observe it through the trigger's `placeBox`
  calls), then the changed-input filter and the counters, then the bulk
  pass. One after-view is shared by the trigger and `_plan` (Ruling 10-5);
  the place memo lives on the view, and `_Registration.placeBoxOf` is the
  only caller of a type's `placeBox` (Ruling 10-6).
- **`paramsOf` on a view is narrowed to the registered component** (D16.1
  as written: the snapshot answers only the type's own component).
- **Point 2's "any bit difference", corrected:** a change is an **`==`
  difference**. `placeInput` values are compared with `==`, so `+0.0` and
  `-0.0` compare equal and count as unchanged although their bits differ;
  anything `==` tells apart counts as a change (the Task 6 review;
  `placeInput`'s doc says so).
- **`placeInput`'s contract** (Task 6 review, now in its doc): two equal
  inputs must mean an equal place box **and** equal everything a reader
  reads of the object. A wall's input is therefore its **joined ring**,
  after 07's joints and the short-wall fallback, never its parameters,
  which can stay equal while a neighbour reshapes its band.
- **Point 4's one-hop assumption** is now stated where a type author
  reads it, in `placeBox`'s doc (Task 5 review m-2): a place box, and
  `placeInput`, may read only the object itself and its reach neighbours,
  never a referent, a referrer or a second-hop neighbour.
- **Point 5's bound, corrected** (Task 7 review m-2): the sweep is
  **O(n log n + pairs whose x ranges overlap)**, not O(n log n + pairs).
  Its window is on x only, and a pair whose x ranges overlap is tested
  even when its y ranges miss; each window evaluation counts as a pair
  test in `debugOverlapTests` (Task 7 review I-1). The sweep's lists equal
  `neighboursOf`'s term by term (the review's check).
- **Point 6: "at most" the same number of `placeInput` calls.**
  `placeInput` is asked only for a contributor whose place box is not null
  in both views (an added or deleted contributor, or one whose box is
  null on one side, is changed without it), so the count is an upper
  bound (Task 6).
- **`SD7`'s count, split** (Task 7 review m-1): at Task 7, of 5,162
  overlap tests at n = 200, about 3,200 were the trigger's per-object
  neighbour searches and about 1,950 the sweep; since the fix round counts
  each window evaluation, the edit makes **5,408** (this plan's final run),
  against n²/4 = 10,000. The
  grid was re-spaced (2.25 × 1.75 mm; the neighbour-cost grid gives no
  neighbours at a 2 mm reach) and each cell turned by `0.25 × (i % 4)` so
  that a sweep sorted by `maxX` differs (`rv7-sortMax`). One size shows
  it is not quadratic at n = 200; the plan's design, accepted.
- **`FB`'s after-box premise holds unturned only** (Task 14): X's after
  place box misses R2's read box at 0°, not at every placement, so `RS6`
  asserts that premise at 0°.
- **M-10before is not masked by a T-joined partition** (Task 14): the
  shared partition of `RG3`, T-joined at both ends, kills it, so the named
  mutants' "partition fixtures cannot kill it" is too strong. **M-10e
  dies in `RG3` at 23°** (not at `RG3`'s origin), and at the origin in
  `RS4`.
- **`RK1` has no single-site killer:** three short circuits (`_run`'s
  early return, `_triggered`'s seed guard, its empty-`L` return) back each
  other up; removed together they are red at `RK1` (X14-noShortCircuit).
  The empty-`L` return removed alone is `X6-readAlways`, red at `SD6`; the
  other two alone only cost time (accepted, Task 19).
- **Point 6's example, measured:** P5 moved 10 mm on the sample plan
  rebuilds the Kitchen and the Bath (`LZ3`'s premise), and `RK2` counts
  the rooms rebuilt per move (below, and in the results note).
- **The test clients** are `Slab`, `Rod` and `Lens` (Ruling 10-2); `SD4`
  runs in two steps (onto `W` and off it), because its premise cannot
  hold in the plan's one direction; `SD5b` and `SD11b` are the plan's
  additions (two contributors of one kind listed in ascending order; an
  exact `Rod` moved by `TransformNodeCommand`).

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

**Amended at execution (Plan 10):** `RP2` is an **engine** test
(`test/document/reserved_handles_test.dart`; Ruling 10-1): it pins D17,
an engine property, where the default document is built. The default
document's linetypes are at handles 2, 3 and 4 (BYLAYER, BYBLOCK,
CONTINUOUS), unchanged, and handle 6 is free in it.

### The engine changes against 06's guarantees

One row per change; "—" means the change does not touch that guarantee.

| | Lives in | 06 D6 guard | 06 D8 cleanup | Undo | Save and load | Draw order | Frame path |
|---|---|---|---|---|---|---|---|
| (a) text | `Generated.text`; `_plan`'s TEXT match | unchanged: judges `r0.touched` only; a caller's text edit of a generated child is still refused | — | the rewrite is a planned command inside the one `ParametricEdit`; its inverse restores the old string | the string is in the record, persisted as any TEXT's | a matched TEXT keeps its handle | — (edit time only) |
| (b) attributes | `Generated`, `Generated.region`; `_recordOf` | — | — | written by the add, removed by its inverse | persisted with the record | — | the resolver already maps transparency and linetype; nothing new per frame |
| (c) page | `ParametricType.pageKey`, `ParametricView.page`; the survey's page; `_run`'s page seeds | — | — | the page edit and its regeneration are one step | the page is a component, as before | regenerated children keep their handles | — |
| (d) dissolve | `ParametricType.dissolves`; `_plan` | never meets it (planned commands) | the dissolve detaches its own component; `lost` never holds it | one step; the node is re-linked last (state-equal, root order normalised; *since O-10, 2026-10-10, at its index, byte-equal*) | — | handles restored, so unchanged | — |
| (e) place | `contributesPlace`, `placeBox`, `placeInput`, `readsPlaces`, `readBox`, `placedIn`, `placeBoxOf`, `objectsOf`; the survey's snapshots and reader count; `_closure`'s trigger; the bulk pass | — | — | only decides the closure; replay never regenerates | — | — | — (edit time only) |
| (f) handle | `ReservedHandles.dashedLinetype` | — | — | — | the default tables are unchanged; the app's record persists | — | — |
| (g) ring outline and move preview (render layer, D24) | `OutlineCache._addLeaf`'s fill arm; `GripCache.isMovable`; `_paintPreview` | — | — | — (the outline follows the document) | — | — (overlay only) | outline built at selection, hover and `DocChange` rate, never per frame, and painted from the cached path; the preview filter is one set lookup per key per frame, no allocation |

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
  *(Superseded 2026-10-10 by the host embedding spec's O-10: an undone
  removal restores the node's index, so the bytes compare exactly.)*
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

**Amended at execution (Plan 10):**
- **"The tint never covers a wall's band" is amended:** the tint's outer
  ring is the bands' faces, but a keyhole's slit end can sit up to 0.5 mm
  outside the face, so into a band (or across a separator, or through a
  wall thinner than 0.5 mm), at most 0.5 mm per chained bridge (D9's
  amendments). At any zoom where a room reads that is below a pixel.
- **"The labels draw over the tint"** holds while the tint keeps its
  first form: after D9's step 3, and after a return from it, the tint's
  handles are above the labels' and it draws over them, translucent (D9's
  amendment).
- **The undo of a dissolve** restores the content exactly; the restored
  children's tree order can differ (D8's amendment).
- **`RG7`**, a test the plan added (Task 12 review I-1), pins the read
  box's 2 mm margin: a room right of a separator at a fractional x, whose
  stored tint's least x rounds past the separator by 4.5e-13 mm; the
  separator moved 100 mm away must rebuild the room (`drift()` empty;
  labels 22.56 → 22.94 m², each 0.0018 from a tie). With margin 0 it
  drifts.

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
  room's seed** (decision 26; R-19): decision 24's shared space is for
  faces that later edits merge, not one the tool should create.
- **The status line says so** (decision 26). `RoomTool` exposes
  `ValueListenable<String?> notice`: while the hovered face already holds
  a room, and after a click there, it reads `Already a room: <name>`
  (the lowest-handle room whose seed is in the face); it is `null`
  otherwise, and cleared when the tool deactivates. The shell merges it
  into `_status` (`main.dart:247`) and `_statusLine` (287) appends
  ` — <notice>` when it is non-null **[spec ruling]** (R-29: the wording
  and the hover-time notice; decision 26 fixes only that the status line
  tells).
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
- **Hovering outside a room** (S-5, T-1). D7 reaches `Unbounded` only
  after growing over every contributor, so the tool **short-circuits**: a
  pointer outside `box(U)`, the **bounding box** of every contributor's
  finite place box (kept with the cache), is `Unbounded` without a trace.
  Not the union of the boxes itself: that is a set of thin rectangles
  along the walls, and a room's interior lies outside all of them
  whenever its walls are axis-aligned (the sample plan's Kitchen seed
  (19,000, 10,000) is outside every wall's box). A `SeedInWall` verdict is
  cached with its wall's band and reused while the pointer stays inside
  that band (a point-in-ring test). An `Unbounded` point inside `box(U)`
  (a courtyard open to the outside) is re-traced per move; a cache of the
  components' outer contours would avoid it (the re-review's T-8), but it
  is **not needed**: its cost is measured by `TT6` at 600 walls, printed.
- **Refused commits:** an `ArgumentError` or `StateError` from `execute`
  is caught and nothing is placed, as 07's and 08's tools do.

**Pinned by:** `TT1`–`TT7`; M-10name, M-10occupied, M-10seedsnap,
M-10notice, M-10hover, M-10hoverunion.

**Amended at execution (Plan 10):** the re-review's T-8 cache is
adopted, and the tool as built.
- **The outer-contour cache** (the Task 15 review's Minor 1: an
  `Unbounded` hover inside the bounds re-traced every move, 9.9 ms among
  600 walls and 12.4 ms outside a connected 636-wall plan, about 2,000 ×
  the Wall tool's hover; any non-rectangular footprint pays it). The
  tracer's arrangement is factored out (`_arrange`), and `RoomInputs`
  keeps, per generation, **every component's outer contour** (its most
  negative cycle; free trees kept) from the all-inputs arrangement,
  built lazily and box-rejected. The hover's verdict order is: **the
  bounds → a cached band → the cached face → the contours → a trace.** A
  point in the bounds but outside every outer contour is `Unbounded`
  without a trace; a point inside one still traces. Measured by `TT6` in
  this plan's run: **19.0 µs** per courtyard hover among 600 free walls
  and **11.6 µs** outside a connected 636-wall plan (the first hover,
  which builds the contours, 6.6 ms and 8.3 ms). `TT8`, a test the plan
  added, compares the cached and the uncached verdicts over a 36 × 36
  hover grid on four plans (the sample, the hollow column with its
  separator, the L, a connected grid with a garden wall) at six
  placements.
- **The bounding-box short-circuit now saves the contour build, not a
  trace** (Task 19's finding F1): once the contours exist, a hover outside
  the box gets the same verdict from them. `TT6` therefore hovers outside
  the box on a fresh generation first and asserts no trace **and no
  contour build**; M-10hover is red there (`ee610fd`).
- **A click, and the tool's change listener, build no contours** (the
  Task 15 re-review's Minor B): a click needs only the trace. `TT9`, a
  test the plan added, counts `RoomTool.debugContourBuilds`.
- **`RoomInputs.invalidate()`** is called at every click, so a click right
  after another sees the first room; the tool re-reads its verdict on each
  document change, so an undo updates the notice; the notice is set right
  after a placement. `RoomTool.debugTraces` joins the counters.
- **No snap marker:** the seed is the raw pointer, so the overlay draws
  nothing at it (the plain, no-snap glyph).
- **A refused commit:** a `DuplicateHandleError` would escape the catch;
  the real tool allocates inside the build and cannot raise it.
- **Known limits:** on hover, the warm face cache answers a point
  within about 1e-6 mm of a face edge from the cached face, where a fresh
  trace might not (the click re-traces); on a click, `RoomInputs` is
  rebuilt three times, about 22 ms per click at 636 walls (the Task 15
  review's nit; not taken, correctness first).
- **`TT5`'s geometry:** the plan's "a vertex 30 px away" lies outside the
  10 px aperture; the test puts the raw point 30 mm (7.5 px at 0.25 px/mm)
  from the face vertex, inside the 40 mm aperture. **`TT2`** compares the
  preview with the room's ring bit for bit after the room's store map
  (world to local and back), and includes a tied island (decision 29).

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

**Amended at execution (Plan 10):**
- **Trimming repeats** (the Task 15 review's Minor 2): at a mitred corner
  the walk from the other end can cross another wall's face and then pass
  through the mitre into the band that holds the end, so one trim left
  the end 39 mm inside the south wall. `trimSeparator` re-trims while the
  trimmed end lies in, or within `roomTrace.linear` of, a band it has not
  used; each step moves toward the start, so it ends. **`ST5`**, a test
  the plan added, pins the mitred corner and a two-joint chamfer (whose
  end lands on the south wall's **outer** face, the face the walk entered
  by, which is correct D20) at six placements; **`ST6`**, also added,
  pins "the first point where the segment enters the band" with an end in
  two crossing walls. The Task 15 re-review ran 39,161 random trims: no
  end with a wall behind it.
- **One function** (Ruling 10-9): `trimSeparator` in `room_inputs.dart`,
  called by the tool and the grips, so M-10trim has one site, red at
  `ST2` and `GR5`.

### D21 — Editing: selection, the Room section, the grips

**Selecting a room.** A click on either label selects the room's group
(`resolveHit`, topmost group); a window band selects it when its labels are
inside, a crossing band when it crosses them. The tint never answers
(D9). **What selection shows** (decision 27): the labels' outlines **and
the room's inner-face ring (with its holes), outlined in the selection
colour** by the selection overlay (D24), the **label grip**, and the
**Room section**. Hovering a label outlines the same in the hover colour.
The selection box (`GripCache.box`, the union of `worldBoundsOf`) grows to
the ring's box; no rotation grip is drawn, since a room is not movable.

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
  **amended by fix/live-object-rule:** a live room by the engine's object
  rule (06 D5, as amended), asked through `live_objects.dart`;
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

**The label grip** (`room_grips.dart`), every step in a named frame
(S-10):
- one `stretch` grip at the anchor, in world: `anchor_w =
  toWorld(room)(q) − (0, 0.7 · h_name_w)`, where `q` is the name TEXT's
  stored insertion point (local) and `h_name_w` the name's **world**
  height (D11: `2.5 mm × scaleDenominator`), since D10 offsets the lines
  in world directions;
- the pole in local space: `pole_l = toLocal(anchor_w) − label` (with
  `label = (0, 0)` when auto), `toLocal = toWorld(room)⁻¹`;
- `drag(p_w)` (the point the select tool has already resolved through the
  chain, 08 Ruling 08-15) stores `label = toLocal(p_w) − pole_l`;
  **a drop within the snap aperture of the pole** (`|p_w −
  toWorld(pole_l)|`, in world) **stores `null`** (auto)
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

**Pinned by:** `RN1`–`RN6` (the section), `GR1`–`GR6` (grips, movable,
the grip under a rotated, scaled room group), `OL4` (the ring in the
shell); M-10pin, M-10movable, M-10offset, M-10gripframe, M-10ring.

**Amended at execution (Plan 10):**
- **The return to auto is not gated on F3** (Ruling 10-17): `RoomGrips`
  takes the aperture from the shell (`kSnapAperturePixels / scale`)
  whatever F3 says; it is a reset gesture, not a snap, and with F3 off it
  would otherwise be unreachable. The distance is taken in world (`GR6`
  drops 1.2 apertures from the pole under a group scaled 1.5 and expects
  a label; `rv17-apertureLocal`), and `GR1` has a 1:100 ft-in page case.
- **A drop exactly on the grip returns null** (no command): the local →
  world → local round trip is not bit-exact, so an offset recomputed from
  that point would not equal the stored one (Task 17's reading).
- **The grips invalidate `RoomInputs` at release** (they never execute
  themselves; the select tool does).
- **The Room section as built** (Task 16): the Name field is a text
  keyboard with no unit suffix (`RN1`); the area line is the area TEXT's
  stored string, found by kind and handle order (the engine matches TEXTs
  by index in handle order; `RN6` holds a room whose area TEXT sits in a
  lower slot than its name), cached per room and document change: the
  lookup is linear in the document per change, off the frame path.
  `RN5`'s "refused edit" is two cases: a pinned room removed (the text is
  discarded) and a real refusal, from a file whose fill names another
  object's boundary (the text reverts). `RN2` checks the field after an
  undo with the room still selected. `RN3` takes its letter list from the
  shell; `SG1`, a test the plan added, types M and S into a text entry
  and switches no tool (`X15-guardMS`).

### D22 — Diagnostics

`RoomType.diagnose` and `SeparatorType.diagnose` report, each at most once
per object, severity `warning` unless stated:

- **`room.shared`** (decision 24) — two live rooms whose seeds lie in one
  face. The room finds the other rooms with `view.objectsOf<RoomParams>()`
  (D16, S-3). **Once per pair, by the lower handle** (08 R2's rule): the lower
  room reports each higher room whose seed lies inside its face (in the
  outer ring, in no hole). Handles `[lower, higher]`; message `"<name A>
  and <name B> share a space"`.
- **`room.broken`**, severity `error` — the trace is `SeedInWall` or
  `Unbounded`. An edit never leaves one (D8 dissolves it); only a file
  does, and `drift()` names it too.
- **`room.tint`** — D9's fallback step 2 or 3 was taken, or a hole was
  left out of the keyhole (no visible bridge vertex).
- **`room.degenerate`** — a non-finite `label` component (D2).
- **`separator.degenerate`**, severity `error` — a separator of length
  `≤ roomTrace.linear`, or with a non-finite endpoint (from a file only).
- **Not reported** (decision 25): a column touching the ring, a column
  outside the face.

`diagnose` traces with the diagnostics view (D7's source), memoised per
view, so O(rooms) traces plus O(rooms²) point tests, off the edit path.

**Pinned by:** `DG1`–`DG4`; M-10share2, M-10objects.

**Amended at execution (Plan 10):**
- **`room.shared` is once per pair, not once per room.** "Each at most
  once per object" holds for every code but `room.shared`: the lower room
  reports one entry **per** higher room in its face, so a room shares
  with two others twice (`DG1`: three rooms in one face give three
  entries) (Task 13).
- **Another room's seed is read through its own group** (the Task 13
  review's I-1): `DG1` holds a room, Bay, in a turned, translated group
  whose local seed lies outside the face.
- **A broken other room is skipped:** `room.shared` ignores a room whose
  own trace is not `Traced` (it reports `room.broken`): a file with a
  second room within `roomTrace.linear` inside a face edge gives that
  room's `room.broken` and no `room.shared` (`DG2`).
- **`room.tint`'s messages** name the step: step 2, "its tint covers its
  holes: the keyholed ring does not triangulate"; step 3, "its tint is an
  unfilled outline: its face does not triangulate"; a hole left out, "its
  tint covers n of its holes: no clear keyhole reaches them" (D9's
  amendments).
- **`M-10objects`' site is the room's call** (Ruling 10-27): `objectsOf`
  takes no `self`, so "answers only self" is `RoomType.diagnose`'s call
  replaced by `[self]`, killed by `DG1`; `OB1` pins `objectsOf` itself.

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
4. **seven rooms**, each by a `RoomParams` whose seed is below. Decision
   16 names six spaces **and** a separator that splits "Living from a
   Dining area", so the Dining area is a room within the decision
   (controller's ruling on S-16; revision 1's R-28 is withdrawn):

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

  The first five are the spike's measured values from the real plan with
  its fifteen openings (`Q2`: `21996100.0 mm2` …); Dining 23,043,600 and
  Living with the column 21,897,500 are the spike's measured values from
  its decision-16 fixture, the plan's nine walls **rebuilt** from
  `startup_plan.dart`'s numbers with the separator and the column (spike
  Q2, "The other fixtures"; S-19). The review's run over the real 07 walls
  with the separator and column read the same seven areas, total
  `111138800.0`. The
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
  doorway's 900 mm approach (the nearest door, P3's **bath/living** door
  at x 23,150–23,850 (x > 21,560 is the Bath; S-19), reaches y 12,460; the
  column starts at y 13,800);
- **`SP5` is extended:** ten walls (the column the tenth), one separator,
  seven rooms with the table's names and seeds, compared exactly; each
  room's area label as the table says; `drift()` and `diagnostics()`
  empty (no `room.shared`, no `wall.*`);
- `SP6` (save → load → save) unchanged;
- **new:** each room's net area against the table to 1e-2 mm², its label's
  heights 125 and 100, and the pole inside its face.

**Pinned by:** `SP1`–`SP7`.

**Amended at execution (Plan 10):** Task 18's probe (Ruling 10-20)
measured **every figure above**: 581 entities (549 + 28 + 1 + 3); the
seven areas to the square millimetre and their labels; total 111,138,800;
every tint at step 1; `diagnostics()` and `drift()` empty; the column
1,340 mm clear of the nearest door's approach. The review recomputed all
seven areas from the coordinates. Setting the page after the rooms
(X18-pageLate) is equivalent **on this plan**, since its page is 1:50 m,
the fallback's: the bytes are identical; `SP5`'s `drift()` catches R-27's
hazard as soon as the page differs (the review's probe at 1:100). The
pixel tests hide the page grid except `RR1` and `OL4`.

### D24 — Render layer (g): the selected room's ring (decision 27)

Decision 27: a selected room shows its labels **and** its inner-face ring,
outlined in the selection colour. Today the ring is not outlined:
`OutlineCache._addLeaf` (`jet_cad_2d_flutter/lib/src/outline_cache.dart:
372-380`) skips a leaf that `QueryFilter.rendering()` rejects — the tint's
boundary, which is invisible (D9) — and returns on every fill ("a fill has
no coordinates"). The selection and hover outlines are built only from
that cache (`selection_overlay.dart:152-160`).

- **The mechanism: a drawn fill outlines its area.** In `_addLeaf`'s fill
  arm, instead of returning: when the fill itself passes `rendering()`
  (already checked above it) and its boundary (`boundaryHandleOf(payload)`)
  is a live entity **that `rendering()` rejects** (its own invisible flag,
  or its layer hidden while the fill's is not; T-6) **and whose owner is
  the fill's owner**, the boundary's geometry is added to the key's
  outline with the fill's transform, exactly as a visible boundary leaf of
  that kind is added today (the polyline arm, or a circle's arc).
  Otherwise the fill adds nothing, as now. The owner test matters because
  the transform is the fill's: `AddRegionCommand` gives both one owner,
  but a loaded file can break that (08's `_subtreeRemoval` comment
  describes such a load); a boundary with another owner adds nothing.
  - **Why this rule:** the arm's own comment says the outline "is a
    statement about what is drawn". A fill **is** drawn from its boundary's
    geometry whatever the boundary's flag (the painter never reads it,
    `draft_painter.dart:700-760`), so a drawn fill whose stroke is hidden
    has a drawn extent the outline was missing. A visible boundary is
    already outlined by its own leaf, so it is not added twice; a hidden
    fill (its layer or container hidden) is rejected before the arm, as
    today. **[spec ruling]** (R-30).
  - **Generic, not a room rule.** Nothing in the render layer knows rooms.
    Today only the room tint produces a filled region with an invisible
    boundary, so no existing outline changes (walls, openings, furniture,
    boxes: visible boundaries). The hover outline, the same cache, gains
    the ring too.
  - **What else follows:** `worldBoundsOf(key)` is computed from the same
    world records, so a room's selection box (`grip_cache.dart:323`) covers
    its ring. Band selection, picking and snapping are untouched (they do
    not read the outline cache), so the tint stays unpickable (D9).
  - **Holes:** the stored tint is the keyholed ring (D9), so the outline
    shows the holes and the 0.5 mm slit's two close edges; at any zoom
    where a room reads, the slit is below a pixel (0.5 mm is 0.01 mm on
    paper at 1:50). Under fallback step 2 the holes are not outlined;
    under step 3 the tint is an invisible POLYLINE leaf, not a fill, and
    the rule does not reach it, so the ring is **not** outlined there —
    recorded with `room.tint`, which reports that case.
- **The frame path** (the non-negotiable). The outline cache is walked at
  selection-change, hover-change and `DocChange` rate, never per frame
  (02 D9); the new arm adds one `Float64List` segment record per selected
  or hovered room at that rate. Per frame the overlay only calls
  `pathFor(key, origin)`, which returns the cached `ui.Path` unless the
  rebase origin moved (then every path is rebuilt from the cached doubles,
  as for any outline). Nothing new is allocated per frame or per entity;
  `paint_allocation_test.dart` stays unedited and green, and `OL3` repeats
  02's steady-state check (`debugRebuilds` unchanged across frames) with a
  room selected.
- **The colour:** the overlay's existing selected and hover paints
  (`selection_overlay.dart`), unchanged: "the selection colour".

- **The move and rotate preview leaves out non-movable keys** (T-7,
  controller's ruling; R-31). `_paintPreview`
  (`selection_overlay.dart:207-228`) strokes every selected key's outline
  under the drag's `T`, and with D24 a room's outline is its whole ring,
  so in a mixed selection the ring would appear to move with the walls
  although R-22's move skips the room. Consistent with R-22, the preview
  draws only the keys the move will move:
  - `GripCache` already calls `movableKey(document, key, objects)` for
    each selected key at its rebuild (`grip_cache.dart:324`, selection and
    `DocChange` rate). It now **keeps the answer per key**
    (`bool isMovable(SelectionKey key)`, backed by a set built at that
    rebuild), instead of only the any-key flag it keeps today;
  - `_paintPreview` (and the point-cross preview beside it) **skips a key
    for which `grips?.isMovable(key)` is false**. With no grip cache (a
    host without one), every key is drawn, as today;
  - **frame path:** per frame this is one set lookup per selected key, no
    allocation; the set is rebuilt only at the grip cache's rebuild.

**Pinned by:** `OL5` (a mixed selection of a movable group and a group a
fake provider calls immovable: during a move drag the preview strokes the
movable key's path only, counted on a recording canvas; with the
provider calling both movable, both), M-10preview; and `OL1` (a selected
group with a fill whose boundary is
invisible outlines the boundary's loop, by coordinates, under a rotated
group transform at the corpus far origin), `OL2` (a fill with a visible
boundary is outlined exactly once; a fill whose layer is hidden, none; a
fill whose boundary is missing, none; a visible fill whose boundary sits
on a hidden layer, its loop (T-6); a fill whose boundary has another
owner, none), `OL3` (steady state: no path
rebuild across frames with a room selected, `debugRebuilds` unchanged), `OL4`
(app: selecting a sample-plan room outlines its labels and its ring; the
Living room's outline shows the column hole); M-10ring, M-10ringdup.

**Amended at execution (Plan 10):**
- **No kind check on the boundary** (the rule as written): a malformed
  file whose fill names a boundary of a kind the painter cannot fill from
  may outline a fill the painter skips; `validate` reports such files.
- **A fill leaf is never movable** (the Task 8 review's M2): `GripCache`
  does not put a fill leaf's key in the movable set, as `GripDrag`
  never captures a fill (03 D4), so `isMovable` agrees with the move, and
  a hidden-boundary fill selected alone shows no rotation grip.
- **`OL2` also holds a visible boundary on a locked layer,** outlined once
  (rendering accepts it, picking rejects it; `rv8-picking`).
- **Known limit: an ATTRIB key.** `GripCache` excludes a fill leaf from
  the movable set but not an ATTRIB leaf, although a move carries an
  attribute only with its host (a path older than D24). No pick or band
  yields an ATTRIB key, so no user reaches it (the controller's ruling,
  not taken).
- **`OL3` is at the render layer** (Ruling 10-24): "a room selected" is a
  root group holding a fill whose boundary is invisible. The Task 8 review
  measured the frame path with the VM's allocation tracer: `isMovable`'s
  hash allocates only while cold, nothing warm.

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
| (g) — | **Added by decision 27:** the selection outline of a fill whose boundary is invisible (render layer) | D24 |
| (e), revision 2 | **Also:** only a contributor whose input changed adds its boxes (S-4), no reader means no trigger, and `objectsOf` lets a room's `diagnose` find the other rooms (S-3) | D16 |

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
    `before_view_test.dart`, `objects_of_test.dart`, with **test-only
  clients**: a text client, a
    page-key client, a dissolving client, a contributor whose place box
    depends on its neighbours (for the two-hop test), and a reader that
    lists the contributors placed in a stored field.
- **Render layer, `packages/jet_cad_2d_flutter`:** **two `lib` changes**
  (D24): `lib/src/outline_cache.dart`'s fill arm (decision 27), and the
  move preview's movable filter (`lib/src/grip_cache.dart`'s per-key
  movability, `lib/src/selection_overlay.dart`'s `_paintPreview`; T-7),
  with tests in `test/outline_cache_test.dart` and
  `test/selection_overlay_test.dart`.
  Translucent fills, ACI 7's foreground, dashed polylines and invisible
  boundaries all exist already. Its gate stays green with only its
  standing failures.
- **App, `apps/floor_planner`:** D1's files; `object_grips.dart`,
  `catalog.dart`, `selection_panel.dart` (the text field kind and the Room
  section), `main.dart` (two tools, keys, the grips, the Room tool's
  notice in the status line), `shortcut_guard.dart`
  (M, S), `startup_plan.dart` (D23); tests.
- **Roadmap:** `roadmap/13-export-and-print.md` gains, under "Decisions
  already made": "**Room separators do not plot** (10, decision 15): a
  separator is a screen aid; an export skips entities carrying
  `SeparatorParams`' group, or 13 adds a plot flag." `roadmap/10` is marked
  done at the merge, as usual.

**Amended at execution (Plan 10):** the files as built.
- **Engine:** the three `lib` files named above, no other
  (`document/style.dart` for D17). Tests: `text_test.dart`,
  `attributes_test.dart`, `page_test.dart`, `dissolve_test.dart`,
  `before_view_test.dart`, `place_test.dart`, `objects_of_test.dart`, and
  `test/document/reserved_handles_test.dart` (`RP2`, Ruling 10-1). The
  clients (Ruling 10-2), `Caption`, `Swatch`, `Gauge`, `Dial`, `Fuse`,
  `Slab`, `Rod` and `Lens`, are in `test/parametric/support/clients.dart`;
  `SD8`'s two-role type is built inside its test.
- **Render layer:** exactly the three `lib` files named above.
- **App:** D1's files. `room.dart` imports `package:flutter/foundation.dart`
  for `@visibleForTesting` (`debugRoomGenerates`, Ruling 10-19;
  `debugTintFailedSteps`, Ruling 10-16); it is not one of the three pure
  files. `wall.dart` and `wall_geometry.dart` change for Ruling 10-8 only.
  Tests, all new files (Ruling 10-1): `room_inputs_test`, `room_trace_test`,
  `room_localise_test`, `room_tint_test`, `room_label_test`,
  `room_object_test`, `room_dissolve_test`, `room_diagnostics_test`,
  `room_follow_test`, `room_cost_test`, `room_tie_test` (decision 29),
  `room_tool_test`, `room_panel_test`, `room_grips_test`,
  `room_paint_test`, `separator_test`, `separator_tool_test`, and
  `test/support/room_fixture.dart`. Of 07's and 08's app tests only
  `startup_plan_test.dart` (D23) and `planner_shell_test.dart` (Ruling
  10-22, D8's amendment) changed.
- **Roadmap:** `roadmap/13-export-and-print.md` carries the line above, as
  its fourth "Decision already made" (Task 20).

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
| 02 D9 (the overlay's outline cache: "a statement about what is drawn") | D24 | a drawn fill whose boundary is not drawn, with the fill's owner, contributes its boundary's loop |
| 03 D7 (the move and rotate preview) | D24, R-31 | non-movable keys are left out of the preview, as 08 D16 leaves them out of the move |

**Amended at execution (Plan 10):** one row more. **07 D6 (the wall's
local ring)**, by D4 and Ruling 10-8: `_localOutlineOf` is a wrapper over
a pure `localOutlineOf` in `wall_geometry.dart`; the wall's stored
children are unchanged bit for bit.

### Invariants

- **The frame path allocates nothing new.** Traces, poles and previews
  run on edits and pointer moves; the tint is one more fill per room; the
  ring outline (D24) is one more cached segment list, built off the frame
  path. The allocation tests stay green, unedited.
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

**Placements per test** (S-18), so the degenerate-fixture trap is closed
here and not left to the plan:
- **all six placements** (the origin; the corpus's far origin turned 23°;
  the same in own groups; +1e9 mm turned, unturned, and turned in own
  groups): every tracer fixture (`RT1`–`RT9`, `RI1`, `LZ1`, `LZ2`), `RL1`,
  `RL2`, and the room-object tests `RG1`, `RG2`, `RS5`, `RS6`;
- **at least the origin and the corpus far origin in own groups**: every
  relational edit (`RG3`–`RG6`, `RD1`–`RD8`, `RS1`–`RS4`, `RA2`, `GR1`,
  `GR2`, `ST2`, `ST4`, `DG1`);
- **`RL4`, `GR6` and `OL1`** use a non-identity similarity on the room's
  (or the fill's) group, at the corpus far origin;
- renders (`RR1`–`RR4`, `OL4`) and the sample plan (`SP1`–`SP7`) at the
  sample plan's own placement, which is off-origin and not symmetric by
  construction (08 D18).

- **Engine (test-only clients):**
  - `TX1` a text client: added with its string and `textAttrs`; a
    parameter change rewrites the string in place (same handle), one undo
    step; undo and redo; a caller's `SetEntityTextCommand` on the child is
    refused; the plain form refuses TEXT and ATTRIB;
  - `AT1` each attribute written on add, none rewritten on a match; a
    region's boundary flags apart from its fill's;
  - `PG1` a page-key client: a page change seeds exactly the types whose
    key changed; one undo step; a **page-only** edit (seeds otherwise
    empty) still regenerates (S-12); `PG2` a paper-colour and a grid
    change: the client's `generate` call count is unchanged (S-8);
  - `DV1` a dissolving client: removed in the edit, component detached,
    one undo step, undo restores handles (root order normalised;
    *superseded 2026-10-10 by O-10: the root order as it was*);
    `drift()` names a loaded one;
  - `SV1`–`SV3` the before-view: parameters, transforms and the page as
    they were, for a moved, re-parameterised and deleted object;
  - `SD1` a contributor moved into a reader's field regenerates the reader;
    `SD2` moved out of it (before box); `SD3` moved far (before-view); `SD4`
    the two-hop: a contributor's neighbour's place box changes; `SD5` two
    readers touched by one contributor both regenerate; `SD6` counters,
    on a fixture where no reader regenerates: no seeds → 0 place and read
    box calls; a non-contributor edit → 0; a contributor edit → exactly
    one place box per `k ∈ K ∩ contributors` live before plus one per
    such `k` live after (a moved, an added and a deleted contributor), and
    one read box per live reader; the bulk pass's count, `c − |K ∩
    contributors live after|` (memo hits not counted), pinned separately
    on a fixture where a reader does regenerate (S-13, T-4); `SD7` the bulk pass gives the same neighbour lists
    as `neighboursOf`, its overlap tests counted and below n²/4 on a
    spread layout; `SD8` the catalog refuses a type with both roles;
    `SD9` an **unchanged** neighbour in `K` adds nothing: a contributor
    moved away from a reader, whose unchanged neighbour's box touches the
    reader, regenerates no reader (the reader's `generate` count; S-4);
    `SD11` the diagonal flip (T-2): a contributor client whose segment
    goes from (0, 0)→(10, 10) to (0, 10)→(10, 0), its box unchanged,
    regenerates the reader it splits, once with the default `placeInput`
    and once with an override that returns the segment;
    `SD10` a document with no live reader makes no place-box call on a
    contributor edit; `objectsOf<U>()` lists exactly the live objects of
    `U`, ascending, and not a lost or re-parented one (S-3).
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
    `LZ2` the triangle: the column lies beyond the first growth box and
    must be found by the certificate (32.77 m², not 32.93); `LZ3`
    `debugTracedSegments` per rebuild on the sample plan, below a bound
    set from the plan's run;
  - `TN1` `tintOf` directly: a pinched outer ring (touching itself at one
    vertex) takes step 3; a two-hole ring where the second hole's view of
    the ring is blocked by the first bridges it to the growing keyholed
    ring (S-11); a hole with no visible vertex is left out and reported.
- **The room object (app):**
  - `RP1` `RoomParams`; `RP2` the default tables unchanged;
  - `RG1` children, order, attributes; `RG2` holes and the fallback chain
    in a room: the column (step 1), two columns in one room (step 1, two
    bridges), and step 2 with its `room.tint`; `RG3` the shared partition of the two-room fixture moved
    500 mm: both rooms' areas and labels follow, same handles, one step,
    undo, redo; `RG4` handles across undo, redo,
    purge; `RG5` save → load → save; `RG6` same state + same edit;
  - `RL1` the thin L at all six placements (T-5):
    the pole inside; its distance to the boundary against 585.786 by hand
    at every placement, and at the origin its coordinates against
    (685.786, 685.786) by hand, both within the 10 mm precision;
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
    deleted (Living kept); `RD5` the partition pulled back 160 mm (both
    survive, one face of 29,266,000 mm² by area, `room.shared`; S-2); `RD6` the separator pulled 50 mm short;
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
    four walls, **at the origin and at the corpus rotation, and on a
    layout with long exterior walls that many partitions tee into** (S-4),
    printing also the number of rooms rebuilt per move; recorded in the
    results note.
- **Renders and picks (app, the shell in `flutter_test`):**
  - `RR1` a click on a furniture fill inside a room picks the furniture;
    on a wall's face 5 mm inside, the wall; on bare floor, nothing;
    on a label, the room (the spike's Q6 probes);
  - `RR2` the tint's pixel over white paper (`#E5E5E5` to the
    rasteriser's rounding) and over furniture: the foreground at ~10% over
    what is there; `RR3` the same on Blueprint;
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
    hover allocates nothing in steady state; a hover outside the bounding
    box of every finite place box traces nothing (`debugTracedSegments`
    unchanged; S-5); **a hover at the Kitchen seed (19,000, 10,000),
    outside every place box but inside that bounding box, is traced and
    previewed** (`debugTracedSegments` grows, the preview is the Kitchen's
    ring; T-1); inside a wall's band the cached verdict is re-used; timing of an `Unbounded`
    hover inside the plan at 600 walls, printed; `TT7` a click in an
    occupied face makes nothing and the status line reads
    `Already a room: <name>` (decision 26); hovering there shows it too;
    it clears on leaving the face and on deactivation;
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
    rotation grip for rooms alone; `GR5` separator end grips, trimmed;
    `GR6` `GR1` and `GR2` under a room group at a rotated, translated,
    scaled similarity (S-10).
- **Render layer (`jet_cad_2d_flutter`):** `OL1`–`OL3` and `OL5` (D24).
- **The ring highlight in the shell (app):** `OL4` (D24).
- **Diagnostics:** `DG1` `room.shared` once per pair by the lower handle,
  three rooms in one face give three entries; `DG2` `room.broken` from a
  file; `DG3` `room.tint`; `DG4` `separator.degenerate` and
  `room.degenerate`.
- **The sample plan:** `SP1`–`SP7` (D23).

**Amended at execution (Plan 10):** identifiers as built.
- **Ruling 10-1:** `SD10` is split: its first half stays `SD10` (no live
  reader, no place-box call), its second (`objectsOf`) is **`OB1`**, in
  `objects_of_test.dart`. `RP2` is an engine test (D17's amendment).
- **Tests the plan and its rulings added**, each with a mutant red on it:
  - `SR5` (`ensureDashedLinetype`, D3), `DF1` (the Differential check),
    `FZ1` (a seeded random run: no edit refused because of rooms; Ruling
    10-1);
  - `RI2` (`RoomInput`'s exact `==`, D4), `LZ4` (non-finite seeds and empty
    documents, D7), `RG7` (the read box's margin, D18), `SD5b` and `SD11b`
    (D16);
  - `DE1`–`DE3` (decision 29's tied islands, `room_tie_test.dart`; `DE1`
    holds a star of 1,002 columns tied to one column, which a split pass
    that stops at 1,000 loops gets wrong, `rv14b-splitOnce`);
  - `TT8` (the contour cache against a trace), `TT9` (a click builds no
    contour), `SG1` (M and S typed into a text entry), `ST5` (re-trimming),
    `ST6` (the first crossing) (D19–D21).
- **Cases added inside existing tests:** `TN1` grew beyond the spec's
  three cases (the flush column, the acute slit, the far holes of the fuzz
  plans t107, t0 and t92, a slit crossing and a slit touching a hole not
  yet joined, a pinched hole's step 2); `RT6`'s pinch with 20 relabelled
  variants; `RT8`'s free tree, diagonal and 0.5 nm-short separators and
  the triangle hole; `RA1`'s ft² tie (D11's amendment).
- **Ruling 10-23:** `RR1` also runs a window band over bare floor
  (selects nothing) and over a label (selects the room), and `RR2` also
  samples the keyhole's bridge in Living (the tint's colour, not a
  stroke): gate 10's "band-selected or stroked".
- **Ruling 10-18:** "the hover allocates nothing" is read as counters
  (`debugTracedSegments`, `RoomTool.debugPreviewBuilds`, and since the
  contour cache `debugTraces` and `debugContourBuilds`); the render
  layer's allocation tests stay unedited.
- **Ruling 10-21:** `DF1` runs its twenty edits on the fixture's rebuild
  of the sample plan at the corpus far origin in own groups; one edit
  dissolves the Bath (the Task 14 review's m-4). In this plan's run it
  compared 60 tint points of six rooms bit for bit.
- **Ruling 10-28:** the pixel tests frame with `fit` or a fractional
  translation and sample the brightest or darkest of a 3 × 3
  neighbourhood.

### Named mutants

Each is fired with a `cp` backup, restored with `cp`, then `diff` against
the backup and `git diff --quiet` (never `git checkout`), and logged in
`plan-10-mutation-log.md`.

**From the roadmap** (M-10a–f, carried; M-10e redefined):

| Mutant | What it breaks | Must be killed by |
|---|---|---|
| M-10a | centrelines traced instead of the uncut bands | `RT1`, `RT7` (four thicknesses: 20,000,000 against 18,093,750), `SP7` |
| M-10b | **redefined** (S-1): cycles of **either sign** accepted and the least **signed** area wins, so the most negative cycle holding the seed — the building's outer contour — is taken as the room (the spike's M-10b). The roadmap's "shoelace without the absolute value" has no meaning here: a face's orientation is structural in the half-edge walk. Revision 1's "least absolute area" is equivalent (a negative cycle holding the seed encloses the seed's positive face, so its |area| is larger; the review's run: `+84: All tests passed!` with it fired) and is dropped | `RT1`, `RT2` (the mixed-direction L); spike: `+8 −71` |
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
| M-10allK | every contributor in `K` adds its boxes, changed or not (revision 1's rule) | `SD9` |
| M-10inputbox | `placeInput`'s default returns the place box (revision 2's default) | `SD11` (the default client: the reader stays stale) |
| M-10objects | `objectsOf` answers only `self` (no other room found) | `DG1` |
| M-10pagelate | page seeds added after the early return | `PG1` (the page-only edit) |
| M-10hover | the Room tool's hover never short-circuits | `TT6` (the traced-segment counter) |
| M-10hoverunion | the short-circuit tests the union of the place boxes, not their bounding box (revision 2's wording) | `TT6` (the Kitchen-seed hover gets no preview) |
| M-10notice | the Room tool sets no status notice | `TT7` |
| M-10gripframe | the label grip subtracts the world line offset from the local insertion point (revision 1's frames) | `GR6` |
| M-10ring | `OutlineCache`'s fill arm returns on every fill (today's behaviour) | `OL1`, `OL4` |
| M-10ringdup | the fill arm also adds a **visible** boundary's geometry | `OL2` (the loop outlined twice) |
| M-10preview | the move preview draws every selected key, movable or not (today's behaviour) | `OL5` |
| M-10before | the trigger uses after boxes only | `SD2`; `RD4` (the column, which has no neighbour, deleted: Living keeps its hole without the before box); `RD8` (a separator moved 60 m away: the two rooms it split must merge). A partition's own neighbours mask it, so partition fixtures cannot kill it |
| M-10snap | the before-view reads the live stores (no snapshot) | `SV1`–`SV3`, `SD3` |
| M-10cand | `placedIn` by reach instead of place box | `SD1`, `RG1`, `SP7` (a band's faces lie outside its wall's reach, so every room traces `Unbounded` and dissolves) |
| M-10cert | D7 **returns its first `Traced` result** (steps 2 and 3 skipped; S-7) | `LZ2` (the triangle's column is missed: 32.93 against 32.77) |
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

**Amended at execution (Plan 10):** the mutants as fired
([plan-10-mutation-log.md](../notes/plan-10-mutation-log.md)).
- **All 51 killed, at 60 fires** (one per site or form, Ruling 10-26):
  M-10dissolve at three (the engine's planner in two forms,
  `RoomType.dissolves`), M-10pagekey, M-10offset, M-10sep and M-10preview
  at two each, M-10grow and M-10pin in two forms each, M-10inputbox's
  literal form besides its value form. M-10inputbox's literal form
  (`placeBoxOf ?? Object()`) is equivalent: `Aabb2` has no `==`, so its
  identity never matches; the value form is killed by `SD11`.
- **Killers that differ from the tables:** X11-canonical is killed by the
  tracer tests, not `LZ1` (D5's amendment); M-10before by `RG3` too (D16's
  amendment); M-10cert's app-level killers are `FZ1` and `LZ2`, not `DF1`;
  M-10offset's grip site is killed by `GR1`, not `RL3` (a model-level
  test); M-10pagekey's room site by `RA2`. **M-10hover** survived `TT6`
  once the contour cache existed and was killed after a fixture fix
  (`ee610fd`; D19's amendment).
- **The tally** (362 fired, 331 killed, 26 equivalent, 5 accepted as cost
  only, 0 surviving) is in the results note.

### Differential check

- **`drift()` is empty** after every edit in every relational test.
- **A full regeneration from scratch agrees with the incremental one** on
  the sample plan after a scripted sequence of twenty edits (wall moves,
  end drags, a partition added and deleted, a separator added and moved, a
  column added, a page change).
- **The localised trace equals the all-inputs trace, bit for bit**
  (`LZ1`), on every fixture at every placement, with and without far
  clutter.

**Amended at execution (Plan 10):** the second item is `DF1` (Ruling
10-21; the tests' amendment), and `FZ1` and `DF1`'s end also compare
`traceRoomAmong` with the all-inputs `traceRoom` over every input, bit
for bit, and each area label with `formatArea` of the all-inputs area
(the Task 14 review's m-1). `DF1`'s own bitwise comparison
(`expectSameTrace`) has no killer: every face in its script closes in its
first tracing box.

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
    picked, band-selected or stroked by the painter; a selected or hovered
    room outlines its labels and its ring (decision 27, D24).
11. The separator is dashed, splits a face, and is trimmed to faces.
12. The Room and Separator tools (the status notice included), the Room
    section (focus hand-back, pinned target, free text), the label grip
    and the separator grips behave as D19–D21 say.
13. The spatial trigger is exact (the proof's tests) and its cost is
    pinned by counters; the timing is recorded.
14. The allocation invariants pass unchanged; the render layer's `lib`
    changes only in `outline_cache.dart`'s fill arm and the move preview's
    movable filter (D24), and its gate is green with only its standing
    failures.
15. The sample plan is D23's; its tests pass; `drift()` and
    `diagnostics()` are empty.
16. Every named mutant is killed, logged in `plan-10-mutation-log.md`;
    `roadmap/13` carries "separators do not plot".
17. **The human's look — owed by the human, never simulated:** on macOS,
    in Chrome and in Firefox: the Room and Separator tools and their
    previews; the Room tool's status notice; the sample plan's tints and
    labels on White and on Blueprint; a selected room's ring and labels in
    the selection colour; the separator's dashes and whether 0.35 mm reads
    as thin (S-15); moving and deleting walls around rooms, and undo; the
    label grip; the Room section's name field.

**Amended at execution (Plan 10):** criterion 10's witnesses include
`RR1`'s window bands and `RR2`'s bridge sample (Ruling 10-23).
Criteria 1's macOS half and 17 stay owed by the human; the results note
lists the look as an unticked checklist per item and platform.

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
- **R-8** (D9) — the tint's colour is explicit ACI 7 (the foreground is
  decision 28's; explicit rather than ByLayer is the ruling).
- **R-9** (D9) — the tint's transparency is 229 (about 10%): **now decision
  28**; kept here for the number only.
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
- **R-19** (D19) — the Room tool makes no room in an occupied face:
  **now decision 26**.
- **R-20** (D20) — the Separator tool is not chained.
- **R-21** (D20) — band trimming of separator ends, gated on F3.
- **R-22** (D21) — rooms are not moved or rotated by the select tool.
- **R-23** (D21) — the Name field also commits on focus loss.
- **R-24** (D21) — an empty name reverts.
- **R-25** (D21) — the Room section's area is the label's stored string.
- **R-26** (D21) — a label dropped on the pole returns to auto.
- **R-27** (D23) — the sample plan sets its page before its rooms.
- **R-28** — *withdrawn*: the seventh room, Dining, is within decision 16
  (controller's ruling on S-16).
- **R-29** (D19) — the status notice reads `Already a room: <name>`, and
  also shows while hovering an occupied face.
- **R-30** (D24) — a drawn fill whose boundary is not drawn (rejected by
  `rendering()`) and has the fill's owner outlines its boundary's geometry
  in the selection overlay.
- **R-31** (D24) — the move and rotate preview leaves out the keys the
  move leaves out (controller's ruling on T-7).

## Open questions for the human

**None.** Revision 1's three were answered by the human on 2026-09-26:
1 (a click in an occupied face) by decision 26, 2 (what a selected room
outlines) by decision 27, 3 (the tint's strength) by decision 28. The
controller ruled that the Dining room (S-16) is within decision 16 and
that the separator's weight (S-15) stays at the thinnest weight with
evidence; gate 17's look covers whether it reads as thin.

**Amended at execution (Plan 10):** one question arose in flight and the
human answered it. **Decision 29** (2026-09-26, after Task 14's review):
the tint lost to a separator tying an island to the ring is fixed in 10,
by a new task after Task 14 (Tasks 14b and 14c; D5 step 9, D6 and D9).


## Revision 2

The independent review of revision 1 (`5015828`; "Ready with amendments",
S-1 to S-19, four major) and the human's decisions 26–28. Each finding was
checked against the code or the arithmetic before it was applied.

| Finding | Outcome |
|---|---|
| S-1 (major) M-10b equivalent | **Adopted.** My own check agrees: a negative cycle holding the seed encloses the seed's positive face. M-10b is now the spike's (either sign, least signed area); the roadmap's shoelace-sign mutant is recorded as meaningless here |
| S-2 (major) the 150 mm pull-back area | **Adopted, 160 mm.** The partition keeps its north T, so its band stays in the merged face: 29,640,000 − 100 × 3,740 = 29,266,000 (`29.27 m²`, 0.001 from a tie). D8's row and `RD5` (asserting the area) changed |
| S-3 (major) `room.shared` has no way to find other rooms | **Adopted.** `ParametricView.objectsOf<U>()`, survey-backed and memoised (D16), listed in the engine tables; `SD10`, M-10objects |
| S-4 (major) the trigger rebuilds rooms along unchanged neighbours | **Adopted in full.** `placeInput` compared before and after; only a changed contributor adds its boxes; no reader, no trigger; the cost bound restated (D16.2, D16.6); `SD9`, M-10allK; `RK2` at the corpus rotation and on long exterior walls. The no-drift proof reads only changed inputs and stands |
| S-5 hover outside a face re-traces everything | **Adopted, partly.** A pointer outside the union of place boxes short-circuits to `Unbounded`; a `SeedInWall` verdict is cached with its band. An `Unbounded` point inside the plan (an open courtyard) is re-traced per move, measured in `TT6` (D19); M-10hover. *Revision 3 (T-1, T-8): the short-circuit is on the bounding box of the place boxes, and a courtyard cache is possible but not needed* |
| S-6 growth loop may not terminate | **Adopted.** A non-finite place box is `null`; the loop ends when `B` contains the union of the finite boxes (D7); separators with a non-finite endpoint are degenerate |
| S-7 M-10cert ambiguous | **Adopted the definition** (return the first `Traced`). **Not adopted: the two-round fixture.** One certificate round always suffices (the re-traced face lies inside the first, so its grown box does too; now stated in D7), so no fixture can need two; `LZ2` kills the mutant as defined |
| S-8 `PG2` cannot see M-10pagekey | **Adopted:** `PG2` counts `generate` calls |
| S-9 the counter unnamed | **Adopted:** `debugTracedSegments` (D7) |
| S-10 label grip frames | **Adopted:** every step in a named frame (D21); `GR6`, M-10gripframe |
| S-11 keyhole rules and `RG2` seam | **Adopted:** `tintOf` in the seed-relative frame, bridges to the growing keyholed ring, a hole with no visible vertex left out and reported (D9); `TN1` tests `tintOf` directly with a pinched ring (step 3) and a blocked second hole |
| S-12 page seeds and the early return | **Adopted:** page seeds join before the early return (D14); the trigger and the plan share one after-view (D16.2); M-10pagelate |
| S-13 `SD6`'s "exactly" | **Adopted:** one box per `k` live before plus one per `k` live after, on a fixture where no reader regenerates; the bulk pass counted separately |
| S-14 how `stored` is formed | **Adopted** (D16.2) |
| S-15 0.35 mm as "thin" | **Controller's ruling:** the thinnest weight shown to render in a cited run stands, so 0.35 mm (spike finding 4); the hairline stays in R-17's follow-up. Not an open question; gate 17's look includes it (D3) |
| S-16 the seventh room | **Controller's ruling:** within decision 16; R-28 withdrawn, D23 cites decision 16 |
| S-17 `ensureDashedLinetype` duplicates | **Adopted,** after checking `tables.dart:113-118` (D3) |
| S-18 placements per test | **Adopted:** a placements paragraph at the head of "Tests by area" |
| S-19 small accuracy items | **Adopted:** `#E5E5E5`; the bath/living door; Dining and Living from the spike's rebuilt decision-16 walls; `LZ2` "beyond the first growth box"; `RL1` asserts the distance at every placement and the coordinates at the origin |

**The human's decisions:**
- **26** — a Room tool click in an occupied face does nothing and the
  status line says so: R-19 now cites it; `RoomTool.notice` and the shell's
  status line (D19, R-29); `TT7`, M-10notice.
- **27** — a selected room outlines its labels and its inner-face ring in
  the selection colour: **D24**, a render-layer change to
  `OutlineCache._addLeaf`'s fill arm (a drawn fill whose boundary is
  invisible contributes its boundary's geometry), built off the frame path;
  D21 updated; `OL1`–`OL4`, M-10ring, M-10ringdup; gates 10, 14 and 17.
- **28** — the tint is the page's foreground at about 10%: R-8 and R-9 now
  cite it (D9).
- **Open questions for the human:** none left.

## Revision 3

The independent re-review of revision 2 (`6163da8`; "Ready with
amendments", T-1 to T-8, one major). Each finding was checked against the
spec and the code before it was applied; the controller's instructions
are marked.

| Finding | Outcome |
|---|---|
| T-1 (major) the hover short-circuit calls room interiors `Unbounded` | **Adopted** (controller). Checked: the Kitchen seed (19,000, 10,000) lies outside every wall's band box (E1 to y 8,250, P3 from y 11,440, P1 to x 17,060, P5 from x 21,440). The short-circuit is now "outside the **bounding box** of every finite place box" (D19); `TT6` gains the Kitchen-seed hover, which must be traced and previewed; M-10hover and a new M-10hoverunion (the union wording) are in D19's "Pinned by" |
| T-2 `placeInput` defaults to the box | **Adopted: the default is "always changed"** (a fresh `Object()`), not "required". Why: a Dart abstract member would bind every parametric type, contributor or not, and "always changed" can only over-rebuild. The wall and separator override it. `SD11` (the diagonal flip, with the default and with an override) and M-10inputbox |
| T-3 S-4's example is axis-aligned only | **Adopted** (controller): D16.6 says so and quotes the re-review's run at 23° (`[Kitchen, Bath, Living]`) |
| T-4 the bulk pass's count | **Adopted** (controller): `debugPlaceBoxCalls` counts calls into a type's `placeBox`, memo hits excluded, so the bulk pass makes `c − |K ∩ contributors live after|` calls; D16.6 and `SD6` agree |
| T-5 `RL1`'s placements | **Adopted** (controller): all six, in D10 and the tests |
| T-6 D24 keys on the flag; the transform assumes one owner | **Adopted** (controller): the rule keys on "the boundary is rejected by `rendering()`" (which covers the flag and a hidden boundary layer) and requires the boundary's owner to be the fill's; `OL2` gains both cases; R-30 reworded |
| T-7 the move preview drags a room's ring | **Controller's ruling: non-movable keys are left out of the move and rotate preview**, consistent with R-22. `GripCache` keeps each key's movability at its rebuild (`isMovable`); `_paintPreview` skips the others; one set lookup per key per frame, no allocation (D24, R-31); `OL5` and M-10preview; the render `lib` change list, the 03 D7 amendment row and gate 14 updated |
| T-8 a courtyard cache exists | **Not adopted** (controller): the per-move re-trace stays, timed in `TT6`. Revision 2's "no cheap containment test" is reworded to "not needed" (D19 and the Revision 2 table) |

**Open questions for the human:** none.

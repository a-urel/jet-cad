# Page, grid and rulers — design

**Date:** 2026-09-22. **Status:** design, **revision 2**, not yet a plan.
Revision 1 (`15d2fe0`) was reviewed the same day by two independent
reviewers (Codex CLI, an Opus subagent; Copilot CLI ran out of quota before
producing a finding); every finding was re-verified against the tree and is
recorded, with its ruling, in
[2026-09-22-page-grid-rulers-spec-review-r1.md](../notes/2026-09-22-page-grid-rulers-spec-review-r1.md).
Revision 2 applies all of them. Three were blockers: a page edit on the root
handle rebuilt the whole spatial index (D13 is the fix), the differential
oracle shared its ladder with the subject, and the grid's iteration range
was unstated.
**Sub-project:** `roadmap/04-page-grid-rulers.md`. **Size:** M.
**Brainstormed with the human on 2026-09-22**, on `main` at `4895fc8`, the
day Plan 02 closed its exit gate at 15 of 15 and `CompoundCommand` landed.
**Depends on:** 01 (merged at `bae5f73`). **Blocks:** 13 (export and print),
and 03's snap-to-grid wiring.

**Evidence of record.** Every claim below about what exists was read from the
tree at `4895fc8` on 2026-09-22, files cited by line (corrected in revision
2 where the reviewers found them off):
`packages/jet_cad_2d/lib/src/document/header.dart` (`DrawingUnits` 5 —
unitless, millimeters, centimeters, meters, inches, feet —, `units` 9, a
plain mutable field with no command; 12-17 says the same of
`globalLinetypeScale`), `document/component.dart` (`Component` 13: immutable,
value-equal, fixed key order; `ComponentRegistry.register` 67 — **replaces
the store for `T` wholesale**, so registering twice drops a live component;
`registerBuiltIns` 80 registers only `OriginComponent`; `toJson` 130 writes
registered and unknown types alike, sorted; `loadJson` 171 — an
unregistered `typeId` is kept verbatim through `attachUnknown`, 181-186),
`document/origin_component.dart` (the one shipped component, the shape every
new one copies), `document/commands.dart` (`SetComponentCommand<T>` 400 —
value-diff inverse, `touched: {handle}` at 424, capability `components`;
`CompoundCommand` at the end of the file, whose `capability` is the
highest-ranked child's), `document/doc_change.dart` (`CommandApplied` 15,
`CommandUndone` 22, `CommandRedone` 29 — label and touched, **no kind and
no capability**; `DocumentLoaded` 37, `DocumentPurged` 43),
`document/tree.dart` (the root **is** in `_nodes`, 60-62),
`document/undo.dart` (the three construction sites, 114, 143, 164),
`codec/json_codec.dart` (the class is **`DraftDocumentCodec`** at 22;
`decode` 92 builds the document with `DraftDocument.empty` at 108, which
calls `registerBuiltIns`, and loads components at 127-128 — **there is no
way for an application to register a type before that load**;
`decodeString` 146 forwards to `decode`), `codec/schema_version.dart`
(`kSchemaVersion = 6`; adding a component type is not a schema change, the
`components` map is open by `typeId`), `index/spatial_index.dart`
(`_onChange` 2583 routes every command change to `_reconcile` 2599; a
touched handle that still resolves to a node sets `structural` at
2646-2651 and `rebuildAll()` follows at 2668-2674; a touched handle that
resolves to *nothing* reaches `rebuildAll()` through `_reconcileEntity`'s
`last == null` branch at 2721-2748; `rebuildCount` 2339 is public),
`packages/jet_cad_2d_flutter/lib/src/tile_cache.dart` (its `DocChange`
handler at 1866-1880 is the index's twin: every command change with a
non-empty `touched` is reconciled), `draft_canvas.dart`
(`kLogicalPixelsPerMm = 96.0 / 25.4` at 22; `pixelsPerPaperMm` 117; `build`
at 458 wraps the painter in its own `RepaintBoundary` at 465),
`viewport_transform.dart` (`fit` 27 with a 5% margin and a positive-scale
guard, `scale` 54 is the geometric mean of the axis scales,
`worldToScreen` 56, `screenToWorld` 59, `visibleWorld` 65 transforms all
four corners), `camera_controller.dart` (`rebaseOriginFor` 18-33 is a
power-of-two quantiser of the view span, built for float32 residuals — it
is not a grid ladder and this spec does not reuse it), `interaction_layer.dart`
(an opaque `Listener` at 191-197 with `onPointerHover`; a `Listener` above
it in the tree still receives every event — Flutter's `Listener` defaults
to `deferToChild` and ancestors stay on the hit-test path —, which is how
the rulers learn the pointer without touching 02's layer),
`outline_cache.dart` (65: subscribes to `document.changes` **and seeds its
state in the constructor** — the pattern D10 copies, seeding included),
`apps/floor_planner/lib/main.dart` (three chrome slots keyed `chrome-top`
44 px — holding the `status-text` at 103 —, `chrome-left` 240 px and
`chrome-right` 280 px, the latter two empty; `CallbackShortcuts` binds
cmd/ctrl+Z to undo at 88-91; the camera is built with `kMinScale = 0.001`
and `kMaxScale = 100.0` px/mm from `startup_plan.dart:22-23` at 42),
`planner_view.dart` (fits the camera once to `document.extents` on first
layout from `LayoutBuilder`'s `constraints.biggest`, 55-63, Ruling 01-2;
the tree `CameraGestureDetector > InteractionLayer > Stack[DraftCanvas,
selection overlay]`), `startup_plan.dart` (`kPlanOriginX = 12000`,
`kPlanOriginY = 8000`, `kPlanWidth = 14000`, `kPlanHeight = 9000`, 26-29; the
plan is drawn in millimetres by construction — a 250 mm exterior wall at
31). `packages/jet_cad_2d_flutter/test/support/spy_canvas.dart` records every
`Canvas` call by name with its positional arguments, by reference.
`test/invariants/paint_allocation_test.dart:55` seeds its random corpus
explicitly (`0xFEEDFACE`), the house practice for any random fixture.

**What the roadmap got wrong.** "Any unit system … does not exist": the
header carries `DrawingUnits` already, mirroring DXF `$INSUNITS`. Nothing
reads it. 04 makes the app set it — for a later import or export to read —
and adds a *display* unit beside it (D1) that the rulers honour, because the
model unit and the unit a person reads are different questions.

---

## What this delivers

The paper under the drawing and the chrome around it:

- A **page**: sheet size (A4, A3, Letter, Tabloid, or custom), orientation,
  drawing scale (1:50), the sheet's position in the world, its paper colour,
  and the display unit. Document data, saved, undoable one edit at a time,
  and — after D13 — an edit that costs the spatial index nothing.
- An **adaptive grid** on the sheet, in the display unit, with a documented
  step ladder and a bounded line count at every zoom the app allows.
- **Rulers** along the top and left of the drawing area, zeroed at the
  sheet's bottom-left corner, labelled in the display unit at the drawing
  scale, with a pointer marker.
- **Page breaks**: the sheet tiled outward over the drawing when the toggle
  is on, so a plan larger than one sheet shows where it would split.
- **Snap-to-grid** as a pure function and a document setting, for 03 to
  wire into drags.
- A minimal **page panel** in the app's right chrome slot, and a zoom
  readout in the top bar, so a human can drive the page before 12 builds
  the real panels.

## Non-goals

- Wiring snap into any pointer path. Nothing in 02 moves geometry; 03 calls
  `snapToGrid` during a drag and decides precedence (D6).
- Multiple pages as document data. One sheet; page breaks are drawn, not
  stored (human decision, D2).
- Print, PDF, PNG — 13. This spec gives 13 a page rectangle, a scale and
  the paper arithmetic in the engine; it does not render to paper.
- A ruler origin other than the page corner (human decision, D5).
- Rotated cameras. `CameraController` pans and zooms; the grid and rulers
  assume an axis-aligned world-to-screen affine, as 02's band did.
- Reading `header.units` to *convert* geometry. The app sets it to
  `millimeters` and nothing rescales. A document whose header says otherwise
  is displayed as if it were millimetres, and the results note must say so.
- Themes, dark mode, or a background colour for the area outside the sheet.
  That is the app's surface colour; the component's colour is the paper's.
- Editing the sheet's world origin, a custom sheet size or a fixed grid step
  from the app. The data exists and the engine tests exercise it; 12's panel
  exposes it (D12).
- The property panel, layer panel, menus — 12.

---

## Decisions

Decisions marked **(human)** were made by the human during brainstorming on
2026-09-22 and are not up for re-litigation in the plan.

### D1 — Units: model millimetres, display-convert (human)

World coordinates are real-world millimetres. The app sets
`header.units = DrawingUnits.millimeters` when it builds the startup plan
(a plain field, no command, like `globalLinetypeScale`). The **display
unit** lives on the page component (D3): one of `millimeters`,
`centimeters`, `meters`, `inches`, `feetInches`. Everything a person reads —
ruler labels, the grid ladder, later dimensions — converts on display.

Why: `pixelsPerPaperMm` already assumes millimetres on the render side, and
lineweights are already paper-based. One convention. The alternative (model
in the display unit) makes every later sub-project read the header before
doing arithmetic and makes changing the unit a geometry rescale.

Conversion table, millimetres per display unit, exact:

| unit | mm per unit |
|---|---|
| millimeters | 1 |
| centimeters | 10 |
| meters | 1000 |
| inches | 25.4 |
| feetInches | 304.8 (one foot); labels show feet and inches |

### D2 — One sheet; page breaks are an overlay (human)

The document has exactly one page. The Page Breaks toggle draws the sheet
tiled outward from the sheet's own origin over the visible world (D8). Nothing
multi-page is stored; 13 prints one sheet or the N × M tiles.

### D3 — `PageComponent`: document data on the root handle, app-registered

Engine, `packages/jet_cad_2d/lib/src/document/page_component.dart`,
exported from `jet_cad_2d.dart`. Attached to the **root handle**
(`DraftDocument.rootHandle`). `typeId = 'jetcad.page'`. **Not** a built-in:
`registerBuiltIns` is for engine bookkeeping; the app registers it with
`PageComponent.register(registry)` (a static that calls
`registry.register<PageComponent>(typeId, PageComponent.fromJson)`), and the
codec gains a hook so a load can too (D9). **Register once per registry:**
`register` replaces the store for the type, so a second call would drop a
live page; the app registers in `startupPlan` and passes the same static to
the codec hook, and nowhere else. Roadmap decision 1, kept; the class lives
in the engine package because it is pure data that 13's export needs
without Flutter, and D11's arithmetic lives beside it for the same reason.

Immutable, value-equal, `toJson` keys in **alphabetical order** (fixed by
construction, no list to maintain):

| key | type | meaning | default |
|---|---|---|---|
| `background` | int, ARGB | paper colour | `0xFFFFFFFF` |
| `displayUnit` | enum name | D1 | `meters` |
| `gridStepMm` | double or null | null: adaptive ladder; a value: the exact snap step and the floor of the drawing ladder (D6, D7) | null |
| `gridVisible` | bool | draw the grid | true |
| `heightMm` | double | sheet height in **portrait** | 297 |
| `orientation` | `portrait` / `landscape` | swaps width and height on display | `landscape` |
| `originX` | double, world mm | sheet's bottom-left corner | 0 |
| `originY` | double, world mm | sheet's bottom-left corner | 0 |
| `pageBreaks` | bool | draw the tiling | false |
| `scaleDenominator` | double | 1:D — world mm per paper mm; any finite positive number | 50 |
| `snapToGrid` | bool | D6 | true |
| `widthMm` | double | sheet width in portrait | 210 |

Presets as `static const` sheet sizes (portrait, mm): `a4` 210 × 297, `a3`
297 × 420, `letter` 215.9 × 279.4, `tabloid` 279.4 × 431.8. A preset is
recognised on display by exact `==` on both dimensions; anything else shows
as "Custom". Effective size: portrait → (width, height); landscape →
(height, width). **M-04e (swap orientation) is only observable on a
non-square sheet; the fixtures use A4 landscape and Letter portrait, never
a square.**

Validation: the constructor throws `ArgumentError` on a non-finite or
non-positive dimension, denominator or `gridStepMm`, or a non-finite origin;
`fromJson` rethrows the same through the constructor and throws
`FormatException` on a missing required key. Missing **optional** keys take
their defaults (`gridStepMm`, every bool, and the colour — listed so a file
from a build that did not have them still loads): required keys are
`widthMm`, `heightMm`, `orientation`, `scaleDenominator`, `originX`,
`originY`, `displayUnit`.

`copyWith` for every field (`gridStepMm` via a sentinel so it can be set
back to null). Equality and `hashCode` over every field; doubles compared
with `==` — stored values, not decisions.

Every edit is `SetComponentCommand<PageComponent>(root, next)`: one undo
step, exact restore by value equality. `touched = {root}`, which is how the
render layer notices (D10), and `capability = components`, which is how the
index knows to ignore it (D13). No new command type.

### D4 — Coordinate model: paper between world and screen

Three spaces. World millimetres (the document), paper millimetres (the
sheet), logical pixels (the screen).

- world → paper: divide by `scaleDenominator` D.
- paper → screen: multiply by `pixelsPerPaperMm` (96/25.4) and by **zoom**.

So the camera's `scale` (px per world mm) is `pixelsPerPaperMm · zoom / D`,
and `zoom = scale · D / pixelsPerPaperMm`. **100 % means the sheet appears
at its physical size on a 96-dpi screen**, the same convention lineweights
already follow. The camera is not changed; zoom is a derived readout.

Pure arithmetic in the **engine**, `document/page_geometry.dart`:

- `sheetWorldRect(page) → Aabb2`: `(originX, originY)` to
  `(originX + effectiveWidthMm · D, originY + effectiveHeightMm · D)`.
- `zoomOf(double pxPerWorldMm, page, double pixelsPerPaperMm) → double`
  (1.0 = 100 %).
- `pageWorldOf(world, page) → Vector2` and `worldOfPage(pageMm, page)`:
  world minus origin and back, for the rulers and the snap.

In the render layer, `page_fit.dart`: `fitToPage(page, Size viewport) →
ViewportTransform` = the existing `ViewportTransform.fit` on the sheet rect
(5 % margin, y flipped). Only this needs `Size` and the camera type.

The startup plan: A4 landscape at 1:50 is 297 × 210 paper mm = 14 850 ×
10 500 world mm; the flat is 14 000 × 9 000. The app places the sheet
centred on the plan's extents (origin = extents centre − sheet world size /
2, computed once in `startup_plan.dart`) and fits the camera to the **page**,
not the extents (Ruling 01-2's "fit once to the real size" is unchanged; only
the target rectangle differs, and D11 says which size). Letter landscape at
1:50 would be 279.4 wide against a 280 mm plan — 0.6 mm short — so A4 is the
default, and Letter is one panel click away as a demonstration of page
breaks.

### D5 — Rulers zeroed at the page corner (human)

The rulers read `pageWorldOf(world)` in the display unit: zero at the sheet's
bottom-left; the top ruler increases rightward, the left ruler increases
**upward** (world y is up). Moving the page moves the zero.

### D6 — Snap: 04 ships the rule, 03 wires it (human)

`snapToGrid(Vector2 world, double stepMm, PageComponent page) → Vector2`
in the engine's `geometry/grid_scale.dart`: result = origin +
`round((p − origin) / step) · step` per axis, **anchored at the sheet
origin**, nearest not truncated, everywhere in the world (outside the sheet
there is no drawn line to coincide with, and the snap still lands on the
same lattice). Returns a fresh vector — this is not the frame path.

The step is `page.gridStepMm` **exactly** when it is non-null — a user who
sets 250 mm gets 250 mm at every zoom. When it is null, the caller passes the
zoom-adaptive step (`scale.minorMm ?? scale.majorMm` from D7's `pick` at the
current camera), and the spec says so in as many words: adaptive snap is a
function of the zoom. `page.snapToGrid == false` is the caller's check, not
this function's. 03 calls it during drags and gives an entity snap within
its own tolerance precedence over the grid — the standard CAD rule, stated
here so 03 does not have to invent it.

### D7 — The grid ladder, shared by grid, rulers and snap

`GridScale.pick(DisplayUnit unit, double pxPerWorldMm, {double? floorMm})
→ GridScale?(majorMm, minorMm?, unit)` in the engine's
`geometry/grid_scale.dart`. One function, three consumers, so they cannot
disagree; a test asserts an adaptive snap inside the sheet lands on a drawn
line.

Ladders, in world millimetres, ascending:

- metric (mm, cm, m): `{1, 2, 5} × 10^k` for k in −1 … 7 (0.1 mm to
  50 000 000 mm).
- imperial (in, ft-in): inches `{1/16, 1/8, 1/4, 1/2, 1, 2, 6} × 25.4`, then
  feet `{1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 5000} × 304.8`.
- with `floorMm` set: `floorMm × {1, 2, 5} × 10^k` for k ≥ 0 — the fixed step
  is exact when it fits and the ladder climbs from it when it does not.

**Major** = the smallest ladder step whose screen spacing
`step · pxPerWorldMm ≥ kMajorMinPixels (64)`. If even the top step is under
64 px — extreme zoom-**out** — `pick` returns **null**: no grid, no ticks,
no snap step; nothing is drawn. **Minor** = major divided by 4 when major's
ladder mantissa is 2 (metric) or for every imperial step, else by 5; drawn
only when `minor · pxPerWorldMm ≥ kMinorMinPixels (8)`, otherwise `null`.

Bound, by construction over the **iteration range** (D8): majors per axis ≤
`viewport / 64 + 2`, minors ≤ `viewport / 8 + 2`, at every zoom including
the app's `kMaxScale = 100` px/mm and its `kMinScale = 0.001`. Both
thresholds are named constants in `chrome_style.dart`.

Formatting, `formatLength(double mm, DisplayUnit unit) → String`:

| unit | example |
|---|---|
| millimeters | `1500 mm` |
| centimeters | `150 cm` |
| meters | `1.5 m` (up to 3 decimals, trailing zeros trimmed) |
| inches | `12.25 in` (up to 4 decimals, trimmed) |
| feetInches | `3'-6"`, `3'-6 1/2"` (inches to the nearest 1/16, fraction reduced, `0'-6"` below a foot) |

Negative values carry a leading minus; zero is `0 m` / `0'-0"`.

### D8 — One chrome painter under the canvas

`PageChromePainter` (render layer, `page_chrome_painter.dart`), a
`CustomPainter` in its own `RepaintBoundary`, **below** `DraftCanvas` in the
stack. Paints, in order:

1. The sheet: a filled rect in `page.background`, a 1 px `kSheetEdgeColor`
   outline, no shadow.
2. The grid, when `gridVisible` and `pick` is non-null. **Iteration range:
   `camera.visibleWorld(size) ∩ sheetWorldRect(page)`** — the lines are
   enumerated over the intersection, never over the sheet; at `kMaxScale =
   100` the A4 sheet is 1.485e6 px wide and iterating it at a 1 mm major
   would be ~14 850 lines per axis, which is why the range, not the clip,
   is the bound. The canvas clip to the sheet rect is belt-and-braces for
   the half-pixel at the edge. Minors then majors as two
   `drawRawPoints(PointMode.lines, …)` calls; the list handed to `dart:ui`
   is **exactly `count · 4` long** — a `Float32List.sublistView` of a buffer
   reused across frames and grown to the bound once — because
   `PointMode.lines` draws every pair in the list and a padded tail would
   draw segments through (0, 0). Screen coordinates, so no rebase is
   needed; the float32 hazard is a world-coordinate hazard.
3. The page breaks, when `pageBreaks` is on: dashed lines at
   `originX + i · sheetWorldWidth` and `originY + j · sheetWorldHeight` for
   every tile intersecting `camera.visibleWorld(size)`, drawn only while the
   sheet's **screen** size is ≥ `kBreaksMinSheetPixels (16)` on both axes —
   the bound at extreme zoom-out.

Repaint source: `Listenable.merge([camera, pageNotifier])` (D10).
`shouldRepaint` false. It draws nothing outside the sheet: the app's
surface colour shows there. Nothing it does touches the entity store, the
index or the tile cache; with D13 a page edit does not either, and a test
asserts the entity count and `SpatialIndex.rebuildCount` are unchanged
across a chrome toggle *through the command log*.

Per-frame allocation is bounded and stated: two `sublistView`s for the
grid, one `Path` for the breaks, no per-entity work. The frame-path rule is
"nothing per entity"; this is chrome, O(lines), and lines are bounded.

### D9 — Codec: a registration hook on `decode` and `decodeString`

`DraftDocumentCodec.decode(json, {…, void Function(ComponentRegistry)?
registerComponents})` and the same parameter on `decodeString`, which
forwards it. Called after `DraftDocument.empty` and **before**
`doc.components.loadJson`. `encode` needs nothing: registered and unknown
components both serialise. The app passes `PageComponent.register`.

Two tests, because `component.dart:181-186` makes the naive one lie:

1. **Typed round-trip.** `encode → decode(registerComponents:
   PageComponent.register)` yields `components.get<PageComponent>(root) ==
   original`, and `encode` of the result is byte-identical to the first.
   M-04d is a **production** mutant of this: move the hook call to *after*
   `loadJson`, and the typed value comes back null while the bytes still
   survive.
2. **The trap, made explicit.** `decode` **without** the hook yields
   `get<PageComponent>` null, `unknownOf(root)` holding one payload with
   `typeId == 'jetcad.page'`, and a re-encode still byte-identical. The test
   is named for what it proves: the bytes surviving is not the type
   surviving.

### D10 — `PageNotifier`: how the render layer hears a page edit

`document.changes` is an async broadcast. `PageNotifier extends
ValueNotifier<PageComponent?>` (render layer, `page_notifier.dart`) **seeds
its value from `components.get<PageComponent>(root)` in its constructor**
(as `OutlineCache` seeds), then listens, and on any
`CommandApplied`/`CommandUndone`/`CommandRedone` whose `touched` contains
the root handle, or on `DocumentLoaded`/`DocumentPurged`, re-reads the
component and sets its value (`ValueNotifier` skips the notification when
the value is `==`, so an unrelated root-touching edit does not repaint).
Constructed by the view, disposed with it. Every chrome painter and the
app's panel listen to it, never to the document directly.

### D11 — Rulers: two bars and a corner, outside the drawing area

`RulerFrame` (render layer, `ruler_frame.dart`): a widget that lays out a
`kRulerThickness (24)` px bar across the top, one down the left, a
24 × 24 corner box, and its `child` (the drawing area) in the rest. **Each
bar is exactly co-extensive with the child on its own axis** — the top bar
starts after the corner box and spans the child's width; the left bar
starts below it and spans the child's height — so a tick placed at the
child's screen x is at that x in the bar. **The `LayoutBuilder` that fits
the camera moves inside the child slot**: the fit and both rulers use the
child's size, never the frame's, and the shell test compares the fitted
camera against `DraftCanvas`'s size as Plan 01's test does.

It wraps the child in a translucent `Listener` (`onPointerHover`,
`onPointerMove`, `onPointerCancel`) plus a `MouseRegion.onExit`, feeding a
`ValueNotifier<Offset?>` of the pointer's position in the child's
coordinates; 02's opaque `Listener` beneath it still receives every event,
unchanged.

`RulerPainter(axis, camera, pageNotifier, pointer, pixelsPerPaperMm)`
repaints on `Listenable.merge([camera, pageNotifier, pointer])`:

- Range: `camera.visibleWorld(childSize)` along the axis, converted to page
  space (D5).
- Ticks from `GridScale.pick(unit, camera.scale, floorMm: page.gridStepMm)`;
  none when it returns null. Minors `kMinorTickPixels (6)` long, majors
  `kMajorTickPixels (12)` with a label from `formatLength`. Screen positions
  through `camera.worldToScreen` of the world point on the axis — the
  camera's translation and scale both enter, which is what M-04a/b fire at.
  The left ruler's labels are rotated −90° so they read upward.
- The pointer marker: a 1 px line across the bar at the pointer's screen
  coordinate on that axis, when the pointer is non-null.
- The corner box shows the unit's symbol (`mm`, `cm`, `m`, `in`, `ft`).

Labels are `TextPainter`s laid out per frame, bounded by the major count
(≤ viewport/64 + 2 per bar); that bound is the reason there is no cache.

### D12 — The app: register, place, panel, zoom readout

- `startupPlan` registers `PageComponent` on the document (once), sets
  `header.units = millimeters`, attaches the default page centred on the
  plan (D4) through `SetComponentCommand` — so it is on the undo stack like
  the rest of the plan. Nothing in 04 decodes a file; the codec hook is
  exercised by the engine tests and the app passes it the day it loads.
- `PlannerView` fits the camera to the page on first layout when a page
  exists, else to the extents as before; its tree becomes `RulerFrame >
  LayoutBuilder > CameraGestureDetector > InteractionLayer >
  Stack[PageChromePainter, DraftCanvas, selection overlay]`.
- `PagePanel` (app, `page_panel.dart`) in `chrome-right`, plain Material
  widgets, owning **these fields and only these**: a sheet-preset dropdown
  (A4, A3, Letter, Tabloid; "Custom" shown, disabled, when the dims match
  none), an orientation segmented button, a scale text field (`1:` prefix,
  any positive number, committed on submit), a unit dropdown, three
  checkboxes (grid, snap, page breaks), four paper swatches (white
  `0xFFFFFFFF`, ivory `0xFFFAF6EC`, light grey `0xFFEDEDED`, blueprint
  `0xFF1F3A5F`). Origin, custom dimensions and `gridStepMm` are not editable
  here (non-goal). Each control executes one `SetComponentCommand` with
  `copyWith`; the panel rebuilds from `PageNotifier`, so undo (cmd/ctrl+Z,
  already bound) moves the controls back.
- The top bar gains a `Text` keyed `zoom-text`: `1:50 · 100%` (scale, then
  zoom rounded to an integer percent), rebuilt on camera and page changes.
  The `status-text` string is unchanged.

### D13 — Component-only edits are invisible to the index and the tile cache

The blocker both reviewers found: `SetComponentCommand` on the root reports
`touched: {root}`; the root is a tree node; `SpatialIndex._reconcile` treats
any touched node as `structural` and rebuilds everything. Every grid
checkbox would rebuild the R-tree over the whole plan. Moving the component
off the root does not help — a handle that resolves to nothing rebuilds too
(`_reconcileEntity`'s `last == null` branch).

The fix is in the change, not the index's guesswork. `CommandApplied`,
`CommandUndone` and `CommandRedone` gain `final Capability capability`
(named, **default `Capability.geometry`**, so every existing construction
site — `undo.dart` and the tile tests' `const CommandApplied(label:,
touched:)` — compiles unchanged and keeps its old meaning).
`CommandDispatcher` fills it from `command.capability` on execute, and from
the inverse's on undo/redo. `SpatialIndex._onChange` and `TileCache`'s
handler **return before reconciling when `capability ==
Capability.components`**: components are data the index never reads
(`Component`'s own contract: "data only, never behavior"). A
`CompoundCommand`'s summary capability is exactly what this needs — a
components-only compound skips, a compound with any geometry or structure
member reconciles — and the previously informational summary now has one
consumer, which the compound test's comment must say.

Mutant M-04r: remove the skip in the index; `rebuildCount` grows on a page
edit. M-04s: the dispatcher passes `Capability.geometry` regardless; same
test. The tile cache gets the same test through its own handler.

---

## Architecture

### Files

Engine, `packages/jet_cad_2d`:

| file | role |
|---|---|
| `lib/src/document/page_component.dart` (new) | `PageComponent`, `PageOrientation`, `DisplayUnit`, `SheetSize` presets, `register` |
| `lib/src/document/page_geometry.dart` (new) | `sheetWorldRect`, `zoomOf`, `pageWorldOf`, `worldOfPage` |
| `lib/src/geometry/grid_scale.dart` (new) | `GridScale`, `pick`, ladders, `formatLength`, `snapToGrid`, the two pixel thresholds |
| `lib/src/document/doc_change.dart` (modify) | `capability` on the three command changes |
| `lib/src/document/undo.dart` (modify) | fills `capability` |
| `lib/src/index/spatial_index.dart` (modify) | the `components` skip in `_onChange` |
| `lib/src/codec/json_codec.dart` (modify) | `registerComponents` on `decode` and `decodeString` |
| `lib/jet_cad_2d.dart` (modify) | exports |
| `test/document/page_component_test.dart` (new) | value semantics, validation, defaults, effective size |
| `test/document/page_geometry_test.dart` (new) | rect, zoom, page space |
| `test/geometry/grid_scale_test.dart` (new) | ladder, thresholds, null at zoom-out, floor, format, snap |
| `test/codec/page_component_roundtrip_test.dart` (new) | D9's two tests |
| `test/index/component_edit_skip_test.dart` (new) | D13: `rebuildCount` unchanged across a page edit, undo and redo |
| `test/document/compound_command_test.dart` (modify) | the summary-capability comment |

Render layer, `packages/jet_cad_2d_flutter`:

| file | role |
|---|---|
| `lib/src/chrome_style.dart` (new) | `kRulerThickness = 24`, `kMajorTickPixels = 12`, `kMinorTickPixels = 6`, `kBreaksMinSheetPixels = 16`, colours |
| `lib/src/page_fit.dart` (new) | `fitToPage` |
| `lib/src/page_notifier.dart` (new) | D10 |
| `lib/src/page_chrome_painter.dart` (new) | D8 |
| `lib/src/ruler_painter.dart` (new) | D11's painter |
| `lib/src/ruler_frame.dart` (new) | D11's widget and pointer notifier |
| `lib/src/tile_cache.dart` (modify) | the `components` skip |
| `lib/jet_cad_2d_flutter.dart` (modify) | exports |
| `test/page_fit_test.dart`, `test/page_notifier_test.dart`, `test/page_chrome_painter_test.dart`, `test/ruler_painter_test.dart`, `test/ruler_frame_test.dart` (new); `test/tile_invalidation_test.dart` (modify) | per the testing section |

App, `apps/floor_planner`:

| file | role |
|---|---|
| `lib/startup_plan.dart` (modify) | register, `header.units`, place the page |
| `lib/planner_view.dart` (modify) | fit to page, the new tree, the notifier's lifetime |
| `lib/page_panel.dart` (new) | D12 |
| `lib/main.dart` (modify) | panel in `chrome-right`, `zoom-text` |
| `test/page_panel_test.dart` (new), `test/planner_shell_test.dart` (modify) | panel edits are commands and undo; the tree; fit to page against `DraftCanvas`'s size; zoom text |

### Signatures

```dart
// engine — document/page_component.dart
enum PageOrientation { portrait, landscape }
enum DisplayUnit { millimeters, centimeters, meters, inches, feetInches }

class SheetSize {            // portrait dims, mm
  const SheetSize(this.widthMm, this.heightMm);
  static const a4 = SheetSize(210, 297);
  static const a3 = SheetSize(297, 420);
  static const letter = SheetSize(215.9, 279.4);
  static const tabloid = SheetSize(279.4, 431.8);
  final double widthMm, heightMm;
}

class PageComponent implements Component {
  static const componentTypeId = 'jetcad.page';
  static void register(ComponentRegistry registry);   // once per registry
  PageComponent({double widthMm = 210, double heightMm = 297,
      PageOrientation orientation = PageOrientation.landscape,
      double scaleDenominator = 50, double originX = 0, double originY = 0,
      DisplayUnit displayUnit = DisplayUnit.meters,
      int background = 0xFFFFFFFF, bool gridVisible = true,
      double? gridStepMm, bool snapToGrid = true, bool pageBreaks = false});
  double get effectiveWidthMm; double get effectiveHeightMm;
  SheetSize? get preset;      // exact match or null
  PageComponent copyWith({...});
  static PageComponent fromJson(Map<String, Object?> json);
}

// engine — document/page_geometry.dart
Aabb2 sheetWorldRect(PageComponent page);
double zoomOf(double pxPerWorldMm, PageComponent page, double pixelsPerPaperMm);
Vector2 pageWorldOf(Vector2 world, PageComponent page);
Vector2 worldOfPage(Vector2 pageMm, PageComponent page);

// engine — geometry/grid_scale.dart
const double kMajorMinPixels = 64.0;
const double kMinorMinPixels = 8.0;
class GridScale { final double majorMm; final double? minorMm; final DisplayUnit unit;
  static GridScale? pick(DisplayUnit unit, double pxPerWorldMm, {double? floorMm}); }
String formatLength(double mm, DisplayUnit unit);
Vector2 snapToGrid(Vector2 world, double stepMm, PageComponent page);

// engine — document/doc_change.dart
final class CommandApplied extends DocChange {
  const CommandApplied({required this.label, required this.touched,
      this.capability = Capability.geometry}); ... }   // Undone, Redone alike

// engine — codec
static DraftDocument decode(Map<String, Object?> json, {..., 
    void Function(ComponentRegistry registry)? registerComponents});
static DraftDocument decodeString(String source, {..., registerComponents});

// render layer
ViewportTransform fitToPage(PageComponent page, Size viewport);
class PageNotifier extends ValueNotifier<PageComponent?> { PageNotifier(DraftDocument doc); }
class PageChromePainter extends CustomPainter { ... }
class RulerPainter extends CustomPainter { ... }
class RulerFrame extends StatefulWidget { ... child, camera, pageNotifier, pixelsPerPaperMm }
```

---

## Invariants

1. **Zero entities, zero index work.** The grid, rulers, sheet and breaks
   never enter the entity store, the tree, the R-tree or the tile cache,
   and — by D13 — a page edit through the command log causes no index
   reconcile and no tile drop. Test: entity count, `SpatialIndex.rebuildCount`
   and the tile cache's tile count are equal before and after toggling every
   chrome flag through `SetComponentCommand`, undoing and redoing it, and
   painting a frame.
2. **Bounded lines.** Over the iteration range `visibleWorld ∩ sheetRect`:
   grid majors ≤ viewport/64 + 2 per axis, minors ≤ viewport/8 + 2 per axis,
   none when `pick` is null, breaks only while the sheet is ≥ 16 px on
   screen. Holds at `kMinScale` and `kMaxScale`.
3. **One ladder.** Grid, rulers and adaptive snap read the same
   `GridScale.pick` result for the same camera and page; an adaptively
   snapped point **inside the sheet** lies on a drawn line.
4. **The camera is untouched.** Zoom is derived (D4); 100 % is
   `scale == pixelsPerPaperMm / D`.
5. **Screen coordinates only into `dart:ui`.** Chrome painters compute in
   `double` and hand screen pixels to the canvas; no rebase, no float32
   hazard; the point list is exactly as long as the lines it draws.
6. **Stored values compare exactly.** `PageComponent ==` is field-wise `==`;
   preset recognition is `==` on both dimensions. Geometric decisions
   (which tile intersects the view, which step fits) are pixel-threshold
   comparisons; none need `Tolerance`.
7. **One edit, one undo step.** Every page change is one
   `SetComponentCommand`; the app never mutates the component in place (it
   cannot: immutable).
8. **The allocation invariants stand.** `query_allocation_test.dart` and
   `paint_allocation_test.dart` are unchanged and green; the chrome painters
   are outside the vertices sink path.
9. **Existing `DocChange` consumers keep their meaning.** The `capability`
   default is `geometry`; nothing that constructed a change before D13
   changes behaviour.

---

## Testing

The bar is CLAUDE.md's: a test lands only if a named mutant makes it red;
fixtures never sit at the identity, the origin, scale 1.0 or a default.
Standard fixture: **page at origin (7350, −1230) world mm, A4 landscape,
1:50, unit metres; camera at scale 0.137 px/mm translated by (−611.5,
412.25) px** — every number chosen so that no tick, line or label falls at a
round screen coordinate, and the sheet is partly visible so the iteration
range is a genuine intersection.

### Named mutants

| id | mutant | test that must go red |
|---|---|---|
| M-04a | drop the camera translation from ruler tick placement | `ruler_painter_test`: tick screen x at the standard camera |
| M-04b | drop the camera scale from ruler tick spacing | same test, spacing |
| M-04c | remove the ladder: major = 64 px / pxPerMm (continuous) | `grid_scale_test`: major is a value from the literal table; the differential check |
| M-04d | call `registerComponents` **after** `components.loadJson` in `decode` | `page_component_roundtrip_test` test 1 (test 2 documents why the bytes still survive) |
| M-04e | swap portrait and landscape in `effectiveWidthMm` | `page_component_test` on A4 landscape; `page_geometry_test` sheet rect |
| M-04f | anchor the grid at world (0, 0) instead of the sheet origin | `page_chrome_painter_test`: first major line's screen x with the off-origin page; the differential check |
| M-04g | draw minors regardless of spacing | `page_chrome_painter_test`: minor count at a zoom where minor spacing is 5 px |
| M-04h | snap with `truncate` instead of `round` | `grid_scale_test`: a point at 0.7 of a step, negative side |
| M-04i | `formatLength` ignores the unit (always mm) | `grid_scale_test`: metres and feet-inches labels |
| M-04j | sheet rect ignores `scaleDenominator` | `page_geometry_test` |
| M-04k | `fitToPage` fits the extents | `planner_shell_test`: camera scale at startup equals the page fit at `DraftCanvas`'s size |
| M-04l | `PageNotifier` ignores `CommandUndone` | `page_notifier_test`: undo after an edit notifies with the old value |
| M-04m | breaks drawn without the 16 px guard | `page_chrome_painter_test`: break-line count at `kMinScale` is zero |
| M-04n | `zoomOf` omits `D` | `page_geometry_test`: 100 % at `scale = pixelsPerPaperMm / 50` |
| M-04o | the panel issues two commands per control | `page_panel_test`: `undoDepth` grows by exactly one per edit |
| M-04p | left ruler reads downward (no y flip) | `ruler_painter_test`: label order along y |
| M-04q | `floorMm` ignored by `pick` | `grid_scale_test`: fixed step 250 mm at a zoom where the ladder would say 200 |
| M-04r | remove the `components` skip in `SpatialIndex._onChange` | `component_edit_skip_test`: `rebuildCount` grows on a page edit |
| M-04s | the dispatcher passes `Capability.geometry` for every change | same test |
| M-04t | iterate the grid over the sheet rect instead of the intersection | `page_chrome_painter_test`: line count at `kMaxScale` over the standard page exceeds the bound |
| M-04u | `PageNotifier` does not seed in its constructor | `page_notifier_test`: value non-null before any event |
| M-04v | the point list is the whole buffer, not a `sublistView` | `page_chrome_painter_test`: recorded list length is `4 · lines` |

### Equivalence

None claimed. Every mutant above names a production line and a test.

### Differential check

`page_chrome_painter_test`: for 50 random cameras seeded `0x5EED0004`
(scale log-uniform in [`kMinScale`, `kMaxScale`], translation uniform in
±5 000 px) over the standard page, the set of major-line screen x positions
recorded by `SpyCanvas` equals a brute-force list computed **in the test
from a literal copy of the metric ladder table**, its own 64 px rule,
`sheetWorldRect` and `worldToScreen`, to 1e−6 px. The oracle shares no
code with `GridScale.pick`. M-04c, M-04f and M-04t fail it.

### Widget tests

- `ruler_frame_test`: hover over the child moves the pointer notifier; exit
  clears it; the child's own `Listener` still receives the event (a spy
  counter inside the child); a major tick in the top bar sits at the same
  screen x as its world point in the child (S10).
- `page_panel_test`: each control executes exactly one command; undo moves
  the control back; "Custom" appears for a non-preset size.
- `planner_shell_test`: the tree contains `RulerFrame` and
  `PageChromePainter` under `DraftCanvas`; the camera fits the page at
  `DraftCanvas`'s size; the entity count is unchanged from Plan 02's (500+);
  `zoom-text` reads `1:50 · N%` with N = the fitted zoom.

---

## Exit gate

| # | criterion |
|---|---|
| 1 | `PageComponent` round-trips **typed** through the codec with registration, and `encode(decode(encode(doc)))` is byte-identical. |
| 2 | Without registration the component survives as unknown bytes and re-encodes byte-identically; the test says so in its name. |
| 3 | Every page edit is one undo step and undo restores the previous value by `==`. |
| 4 | Ruler tick positions and spacing are correct at a camera that is both zoomed and panned, over an off-origin page (M-04a, M-04b). |
| 5 | The grid picks the documented ladder step at the documented thresholds; minors appear only at ≥ 8 px; nothing at all past the ladder's top (M-04c, M-04g). |
| 6 | Line count is bounded over the intersection range at `kMinScale` and `kMaxScale`; breaks vanish below a 16 px sheet (M-04m, M-04t). |
| 7 | Grid, rulers, sheet and breaks add zero entities; a page edit, its undo and its redo cause zero index rebuilds and zero tile drops (M-04r, M-04s). |
| 8 | `query_allocation_test.dart` and `paint_allocation_test.dart` pass unchanged. |
| 9 | An adaptively snapped point inside the sheet lies on a drawn grid line; snap is nearest, anchored at the sheet corner, exact at `gridStepMm` (M-04f, M-04h). |
| 10 | Labels are in the display unit (M-04i), the left ruler reads upward (M-04p). |
| 11 | The camera fits the page at startup at the drawing area's size; 100 % ⇔ `scale = pixelsPerPaperMm / D` (M-04k, M-04n). |
| 12 | The differential check passes for 50 seeded random cameras against an oracle that shares no code with `pick`. |
| 13 | The panel drives its eight controls with one command each; cmd/ctrl+Z reverts the control (M-04o). |
| 14 | Every named mutant (M-04a…v) fired, killed or declared equivalent with a reason, in `docs/superpowers/notes/plan-04-mutation-log.md`. |
| 15 | The two package gate lines, the harness and the app — `CI=true` on every test command — are green at merge, with the one standing exception carried from Plan 02: the five `text_ladder_golden_test.dart` failures that predate 01, recorded in STATUS, and no other. `analysis_options.yaml` untouched. |
| 16 | A human looked, on macOS, in Chrome and in Firefox from `build/web`: the sheet under the plan, the grid at three zoom levels, ruler zero at the sheet corner and labels in metres, page breaks with Letter selected, a unit change to ft-in, one panel edit and its undo; each recorded seen / not seen / could not judge. |

---

## Open questions

Not blocking; each is answered here provisionally and the plan may not
reopen them.

- **Grid over the whole world or only the sheet?** Sheet only. A plan that
  overflows the sheet shows it by having no grid there — that is the
  information. Snap still works there (D6).
- **Dark paper.** The blueprint swatch is dark; the grid and sheet-edge
  colours are fixed light-theme greys and will be faint on it. Acceptable in
  04; 12 owns theming.
- **`header.units` disagreement.** A loaded file whose header says `inches`
  is still displayed as millimetres (non-goal). 13 or an import sub-project
  decides whether to convert.
- **Pointer marker on touch.** The notifier is fed by hover and move; a
  touch pointer has no hover, so the marker appears only during a drag.
  Desktop is the target.
- **Adaptive snap under 03.** D6 makes the adaptive step a function of the
  zoom. If 03's look finds that surprising, the fix is a default
  `gridStepMm` on the page, not a change to `snapToGrid`.

## What this changes outside 04

- Engine: three new exported files, a `capability` field on three
  `DocChange` classes (defaulted, so no caller changes), one skip in the
  index, one optional parameter on two codec entry points. No schema bump,
  no store change, no command type.
- Render layer: five new files, one skip in the tile cache, no change to
  `DraftCanvas`, `CameraController`, `InteractionLayer` or the selection
  overlay.
- App: the right chrome slot is no longer empty; `PlannerView`'s tree gains
  the ruler frame and the chrome painter; the startup plan carries a page.
- 03 inherits `snapToGrid` and the precedence rule in D6. 13 inherits
  `sheetWorldRect`, the scale, `formatLength` and `pixelsPerPaperMm` as its
  whole paper model, all in the engine.
- 06 inherits a `DocChange` that says what kind of edit it was, which its
  regeneration trigger (roadmap 06's "`DocChange.touched`, or explicit dirty
  marking?") can now answer with the capability.

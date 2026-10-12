# Plan colours: a colour per table and per room — design

**Date:** 2026-10-12. **Status:** revision 2, for the human's review.
Revision 1 (`abc06cb`) was reviewed independently: **Approve with
fixes**, V-1 to V-12, one blocker (V-1); revision 2 folds in every fix
(see [Review](#review)).

**Asked for by the human, 2026-10-12:** "O-6 ile devam et" — the host
embedding API spec's out-of-scope item O-6, "a per-table colour on the plan
itself (status is not plan data)" — and, mid-brainstorm, "color per room
should also be considered".

**Branch:** `spec/plan-colors`, from `main` at `1414680` (release 0.5.1,
tag `v0.5.1` → `3f8f7ad`). **Size:** M, two slices. **Touched:**
`jet_cad_2d` (the schema version; regeneration's stamp on a matched
child, PC-3a), `jet_cad_2d_flutter` (the page export's underlay),
`jet_cad_floor_plan` (the palette, the room, the table colour component,
the fill painter, the panel, the host API, the export flows, the
strings), the host guide, the CHANGELOG. **Release:** 0.6.0, after
Slice 2.

## Purpose

A restaurant's floor is divided into sections — the terrace, the window
row, one waiter's tables. The designer marks them on the plan with a
colour: a room takes a coloured tint, a table a coloured fill under its
drafting. The colours are **plan data**: saved, undone, drawn in both
modes, exported and printed. They are not the service status (free,
occupied), which stays the host's, live and never saved; in the selection
mode a status covers a table's colour.

## Decisions taken in the brainstorm (the human, 2026-10-12)

1. **Section colour**, set by the designer in the editor (and by the host
   for tables), saved, drawn in both modes, exported and printed.
2. **A colour per object**, not named sections: no section list, no
   legend.
3. **A fixed palette** of eight hues, not free RGB.
4. **A status covers a table's colour** in the selection mode.
5. **Rooms too**; a room's colour and its tables' colours are
   **independent** in the data (a table does not take its room's
   colour).
6. **Approach A** for tables: a painter under the drafting (the status
   painter's chain), with an export underlay; not a stamped tint entity
   (it would draw over the table's lines, by ascending handle, and a
   status could not cover it) and not a `ByBlock` fill in the symbol
   definitions (plans already saved carry their definitions without one).
7. Sections 1 to 4 of the design approved as presented, with: the room's
   coloured tint at 20 %; the table's fill at 0.35; the export at the
   exporting view's theme; the colour **on** in `tablesOnly`; a refused
   capability shows the picker read-only; release 0.6.0.

## Facts (at `1414680`)

- **F-1. Schema.** `kSchemaVersion = 9`
  (`jet_cad_2d/lib/src/codec/schema_version.dart:48`). The reader throws
  `SchemaVersionError` for a version that is not an int, below 1 or
  **above** `kSchemaVersion` (`json_codec.dart:106-107`); an older
  version is migrated. Every bump so far exists for the reader (the
  file's own doc comment, 6 to 9): 9 was bumped for `jetcad.table_data`,
  which a v8 build would keep as preserve-unknown data and orphan on a
  delete.
- **F-2. The room.** `RoomParams` (`floor_planner.room`,
  `jet_cad_floor_plan/lib/src/parametric/room.dart:34-99`) stores
  `seed`, `name`, `label`, all three always written (08 D6's one-shape
  rule, `toJson` `:51`); `fromJson` (`:61`) reads the three keys and
  ignores any other; `copyWith` clears `label` through a `_keep`
  sentinel (`:20, :80`). `RoomType.generate` makes the tint first — a
  region, `kRoomTintColor` (`IndexedColor(7)`, `:105`) on both records,
  `kRoomTintTransparency` 229 (`:109`), its boundary invisible
  (`:301-309`) — then the name, then the area; the children keep their
  handles for the room's life (D18).
- **F-3. Table data, the precedent.** `FloorPlanTableData`
  (`jetcad.table_data`, `tables/table_data_component.dart`) is a
  component on the table's **instance** node; `fromJson` never throws: a
  payload of another shape is kept verbatim, read as empty, written back
  as read, and reported as `table.invalid_data`
  (`table_index.dart:168, :196`). It is registered in
  `registerAppComponents` (`parametric/catalog.dart:58`). A delete drops
  it and an undo restores it through `RemoveNodeCommand`
  (node-components D-1, 0.5.0). The controller's `setTableData` /
  `setTablesData` (`host/floor_plan_controller.dart:1557-1597`) refuse
  the selection mode (`StateError`), refuse an unknown or shared number
  (false), skip equal entries, and execute one `CompoundCommand`
  labelled "Table data".
- **F-4. The status painter.** `TableStatusPainter`
  (`service/table_status_painter.dart:106`) fills each visible table's
  top — the definition's first leaf, a closed polyline or a circle —
  under the drafting, in its effective status: its group's status when
  the group has one, else its own. The fills are rebuilt (`_rebuild`,
  `:175`) when the statuses, the groups, the plan's state, the paper or
  the theme move; a frame is an indexed loop over prebuilt `Path`,
  `Paint` and `Paragraph` objects (the allocation bar, measured
  structurally by `test/service/table_status_painter_test.dart`). The
  theme's `statusFillOpacity` multiplies each status colour's alpha at
  rebuild. **The survey runs only when a status map is not empty**
  (`:185`), and **an unnumbered table is skipped** (`:197`). The plan's
  state is compared when a paint happens: something in `repaint` must
  trigger it.
- **F-5. The canvases.** `PlannerView` has an `underlay` slot between the
  page chrome and `DraftCanvas` (`planner_view.dart:419`). The selection
  mode fills it with the group frames and the status layer
  (`host/service_view.dart:556-575`); the design mode leaves it empty.
- **F-6. The service copy** is the design re-decoded
  (`_copyOf`, `floor_plan_controller.dart:1302-1308`): it carries every
  component, read only.
- **F-7. Export.** `exportPagePdf` / `exportPagePng`
  (`jet_cad_2d_flutter/lib/src/export/page_export.dart:34, :104`) draw
  the document through a `DrawSink` (`PdfDrawSink`, or a
  `CanvasDrawSink` on an opaque white ground) with `DraftPainter`, the
  resolver's foreground black, `omitOwners` (the separators) skipped. A
  residual is the whole local-to-device transform: the painter passes
  `camera.worldToScreenMatrix ∘ placement` (`draft_painter.dart:588,
  :756`); a sink applies no camera of its own. `fillPolygon` takes the
  loop **with** its closing point and a non-empty triangulation
  (`draw_sink.dart:69-85`); `fillCircle` takes none; both take a
  `ResolvedStyle` (`argb` and the rest). The engine triangulates with
  `triangulateSimplePolygon(coords, count)`
  (`jet_cad_2d/lib/src/geometry/triangulate.dart:27`). The floor plan's
  `exportBytes`, `exportPdfBytes`, `exportOnce` and `printOnce`
  (`export/`) take no theme; `controller.exportPlan` and `printPlan`
  (`floor_plan_controller.dart:1334, :1348`) export with no view.
- **F-8. The panel.** `SelectionPanel`'s sections each edit one object;
  the Layer picker (`selection_panel.dart:1400`, `layer_picker.dart:74`)
  shows for any non-empty selection and applies to all of it. A refused
  capability hides a button or menu and shows a value field read-only
  (C-5, S-10). An object's editor also respects the document's
  permissions: a room's fields need `components` and
  `RoomType.editCapability` (geometry) (`selection_panel.dart:349-367`).
- **F-9. Capabilities.** `FloorPlanEditorCapabilities`
  (`host/editor_capabilities.dart:138-236`): `full`, `tablesOnly`
  (`selectTablesOnly`, no mirror, reshape or layer change) and
  `readOnly`. Its constructor is `const` with named, defaulted
  parameters.
- **F-10. The table detail.** `FloorPlanTableDetail`
  (`host/table_detail.dart:24`) is value-equal over table, centre, size,
  rotation, mirror, corners, layer, lock and data (`:84-94`);
  `designChanges` reports a `FloorPlanTableChanged` when a table's
  detail differs from the last report.
- **F-11. The theme.** `FloorPlanTheme` (`host/floor_plan_theme.dart`)
  holds nullable fields, null being today's value; `copyWith`, `merge`,
  `lerp`, `==`, `hashCode`, the debug map and the range check
  (`:380`, `opacity(...)`) list every field.
- **F-12. Picking.** `QueryFilter.picking()` excludes hidden and locked
  layers (`jet_cad_2d/lib/src/index/query_filter.dart:36-39`): the
  editor never selects an object on either.
- **F-13. Regeneration writes a child's attributes on add only.**
  `Generated`'s contract (`jet_cad_2d/lib/src/parametric/
  parametric_system.dart:198-209`): colour, transparency, flags and the
  rest are written when the child is **added**, and only then (06 D11,
  10 D13); a regeneration rewrites a matched child's payload (and a
  TEXT's string) in place. `_recordOf` (`regeneration.dart:446`) is the
  only writer. The one exception is the layer (12b D2): a matched child
  whose stored layer differs (exact `==`) gets a
  `SetEntityLayerCommand.restore` in the plan (`_stampLayer`, `:476`),
  a region's fill and boundary each; the guard is load-bearing (R-15).
  There is no command that sets an entity's colour or transparency.
- **F-14. The dark canvas re-tones every colour.** On a dark paper the
  canvas resolves through `DarkCanvasStyleResolver`
  (`jet_cad_2d_flutter/lib/src/dark_canvas.dart:96-108`), which maps
  each RGB, a `TrueColor` included, through `darkCanvasTone(rgb, paper)`
  (`:65`, exported); alpha passes through. The status painter draws the
  host's ARGB raw.
- **F-15. Pinned versions and shapes.** Besides the codec fingerprints,
  these tests pin schema 9, assert 10 refused, or pin the room's three
  keys: `jet_cad_2d/test/codec/schema_9_test.dart:94-99, :186`, the
  planner's `controller_test.dart:1013`, `table_data_test.dart:118`,
  `room_object_test.dart:106`.
- **F-16. Colour literals.** `jet_cad_floor_plan/test/invariants/
  theme_colours_test.dart` flags any `Color(0x…` literal in `lib/`
  outside its allow-list (`layer_row.dart` has an entry).
- **F-17. Change size** swaps a table's definition and keeps its
  instance (`symbols/symbol_section.dart:196-222`).

## Design

### PC-1. The palette

```dart
/// A plan colour (plan colours spec PC-1): one of eight fixed hues.
enum FloorPlanColor {
  red(0xE53935), orange(0xFB8C00), yellow(0xFDD835), green(0x43A047),
  teal(0x00897B), blue(0x1E88E5), purple(0x8E24AA), grey(0x757575);

  const FloorPlanColor(this.rgb);

  /// The hue as the document stores it, `0xRRGGBB`.
  final int rgb;
}
```

- Exported from the host barrel. The file stores the colour by its
  **name** (`"teal"`), never by its index: reordering or extending the
  palette in a later release breaks no file. (It does break a host's
  exhaustive `switch` on `FloorPlanColor`: a later hue is an API change,
  caught by the old-host probe, P-1.)
- A name this release does not know (a later release's hue) is **kept
  as read**, draws as no colour, and is saved back unchanged.
- **Document colour and display colour.** `rgb` is the document's
  colour: what white paper, the export and the print show. A dark canvas
  shows `darkCanvasTone(rgb, paper)` (F-14) — for a room through the
  canvas resolver, for a table through the painter (PC-5) — so a room
  and a table of one hue show one tone on every paper. The hue is not
  themed.

### PC-2. Schema 10

- `kSchemaVersion` becomes **10**. The v9→v10 migration is empty: no
  colour key and no colour component mean no colour; a v9 (or older)
  plan opens unchanged.
- The bump exists for the reader, as 6's to 9's did: a v9 build would
  read a room's `color` key as nothing and drop it on its next save, and
  would keep a table's colour as preserve-unknown data, orphaned by a
  delete. With the bump, that build refuses the file and says why.
- `schema_version.dart`'s comment gains the 10 entry. The codec
  fingerprints that encode the version move with it; the engine's two
  standing macOS fingerprints of `generate_document_test` stay standing
  (the human's macOS re-baseline is still owed). The tests of F-15 move
  **on purpose**, each to say 10 (and a room's four keys); a v10 test
  file beside `schema_9_test.dart` pins the empty migration.

### PC-3. The room's colour

- `RoomParams` gains `final String? color`: a palette name, or null for
  no colour. `toJson` writes **four** keys, always, `color` last: `null`
  when none (the one-shape rule). `fromJson` reads a missing key as null
  (a v9 room) and a string as itself, **known or not**; another type
  throws, as a wrong type does for the other keys today. `copyWith`
  takes `Object? color = _keep` (the `label` sentinel, F-2), so
  `copyWith(color: null)` clears it; `==`, `hashCode` and `toString`
  carry it.
- `RoomParams.colorValue` (`FloorPlanColor?`): the palette entry of that
  name, or null — for no colour and for a name this release does not
  know.
- `RoomType.generate`: with no `colorValue`, the tint is today's,
  unchanged (`kRoomTintColor`, `kRoomTintTransparency`), byte for byte.
  With one, both tint records carry `TrueColor(colorValue.rgb)` and
  `kRoomColorTransparency` **204** (alpha 51, 20 %); the step-3 outline
  (an invisible polyline) takes the same colour. The children's order
  and handles do not change (D18).
- A colour change is a `SetComponentCommand<RoomParams>`; the parametric
  system regenerates the room in the same undo step, and PC-3a carries
  the new colour onto the **existing** tint.

### PC-3a. The engine: colour and transparency on a matched child

F-13's contract would leave a recoloured room's tint as it was: the
params change, the undo step lands, the tint stays ACI 7. So the
planner takes two more columns, as 12b D2 took the layer:

- **`SetEntityStyleCommand`** (`jet_cad_2d`, beside
  `SetEntityLayerCommand`): sets one entity's `color` and
  `transparency`; `.restore` builds the inverse, as the layer command's
  does; its capability is the layer command's.
- **The stamp:** for each **matched** child — a region's fill and its
  boundary each, as `_stampLayer` — when the stored colour or
  transparency differs from the `Generated`'s (exact `==` on both, a
  stored value), the plan adds one `SetEntityStyleCommand.restore`;
  otherwise nothing. The guard is load-bearing (12b R-15): an untouched
  room plans no command and its `ParametricEdit` reports no geometry.
- **The contract** (`Generated`'s doc, F-13) is amended: colour and
  transparency join the layer as the planner's columns; flags, linetype,
  lineweight and text attributes stay written on add only. Every
  existing client keeps its colours fixed, so for every existing object
  the stamp plans nothing: no file and no edit changes.

### PC-4. The table's colour

- A new component on the table's instance node:

```dart
final class FloorPlanTableColor implements Component {
  static const String componentTypeId = 'jetcad.table_color';
  // {"color": "<palette name>"}
}
```

- Made from a `FloorPlanColor` by the controller and the panel; no
  colour is **no component** (setting none removes it).
- `fromJson` **never throws**, as `FloorPlanTableData`'s: exactly
  `{"color": <string>}` reads as that name, known or not; any other
  payload is kept verbatim and written back as read. `colorValue` is the
  palette entry, or null for a kept payload or an unknown name.
- `TableSurvey.diagnostics` reports a kept payload or an unknown name as
  **`table.invalid_color`**, beside `table.invalid_data`.
- Registered in `registerAppComponents` beside `FloorPlanTableData`. A
  delete drops it and an undo restores it (`RemoveNodeCommand`, F-3); a
  renumbering, a move, a turn, a mirror and **Change size** (F-17: the
  instance stays, the fill follows the new top) keep it.

### PC-5. The fill painter

- `TableStatusPainter` gains one rung at the bottom of its chain: each
  visible table's fill is its group's status, else its own status, else
  **its colour** (PC-4's `colorValue`). A status covers a colour
  (decision 4). A colour carries no caption.
- **The survey always runs** at rebuild (F-4's `:185` skip goes): the
  colours live in the document, so there is no empty case to skip. The
  rebuild is at plan-change rate, never per frame.
- **The colour rung needs no number:** an unnumbered table is filled in
  its colour; the status rungs still key by number (F-4's `:197` skip
  moves down to them).
- A colour's fill: `rgb` — or `darkCanvasTone(rgb, paper)` when the
  canvas resolves through `DarkCanvasStyleResolver` (PC-1, F-14), by the
  same predicate the canvas uses — at alpha `round(255 × o)`, `o` the
  resolved theme's `tableColorOpacity` (PC-6), applied once at rebuild.
  A status's fill is unchanged (the host's ARGB, its own opacity).
- **Visibility:** as a status's — every live table on a visible layer;
  a locked layer's tables are filled.
- **Design mode:** the shell mounts the same painter in `PlannerView`'s
  `underlay` (F-5) with no statuses and no groups. Its `repaint` merges
  the document's changes, the camera, the paper and the theme; the
  shell holds its resolved theme in a `ValueNotifier` the painter
  listens to. Only the colours draw, under the drafting and under the
  selection overlay.
- **Selection mode:** unchanged mount; the service copy carries the
  colours (F-6).
- **Under the drafting** means under a room's tint too: a coloured
  table inside a coloured room shows the table's fill composited under
  the room's 20 % tint, on the canvas and in the export alike.
- The painter's allocation bar extends to the design mode's mount:
  steady-state frames allocate nothing per table.

### PC-6. The theme

- `FloorPlanTheme.tableColorOpacity` (`double?`, null = **0.35**), in
  `0..1` (the range check's `opacity`). Carried by `copyWith`, `merge`,
  `lerp`, `==`, `hashCode` and the debug map, as every field (F-11).
- The palette's hues are not themed (PC-1).

### PC-7. Export and print

- `exportPagePdf` and `exportPagePng` gain an optional
  `List<PageUnderlayFill> underlay = const []`, drawn after the ground
  and before the document, through the same `DrawSink`:

```dart
/// A fill under the drawing (plan colours spec PC-7): a closed shape in
/// its own space, placed in world by [placement], in [argb].
@immutable
sealed class PageUnderlayFill {
  Transform2 get placement;
  int get argb;
}
/// [xy]: the loop, its closing point included; [triangles]: its
/// triangulation, never empty (DrawSink.fillPolygon's contract).
final class PageUnderlayPolygon extends PageUnderlayFill { /* xy, count, triangles */ }
final class PageUnderlayCircle extends PageUnderlayFill { /* cx, cy, r */ }
```

- Each fill is drawn as the painter draws a leaf (F-7): its residual is
  `camera.worldToScreenMatrix ∘ placement`, bracketed by
  `beginResidual` / `endResidual` around `fillPolygon` or `fillCircle`,
  with `ResolvedStyle(argb: argb, …)` (the rest at a fill's defaults).
  A turned or mirrored circle is a circle (or an ellipse) in the PDF,
  never a tessellated polygon.
- The floor plan builds the underlay from the document: every visible
  coloured table's top in its definition's space — a polygon closed and
  triangulated once with `triangulateSimplePolygon` (a top that does not
  triangulate is skipped, as the painter skips an unfillable boundary),
  or a circle — its instance's **world** transform, and `rgb` (the
  export is always white paper: no tone) at the opacity below. No status
  is exported (spec 14c D13 stands). Rooms need nothing: their tint is
  an entity.
- **The opacity's source.** `exportBytes`, `exportPdfBytes`,
  `exportOnce` and `printOnce` gain a `tableColorOpacity` parameter.
  The view's Export and Print pass the exporting view's resolved
  `tableColorOpacity` (decision 7). `controller.exportPlan` and
  `printPlan`, which have no view, gain an optional `tableColorOpacity`
  (null = 0.35, the theme's default).
- An empty underlay draws exactly what the export draws today, byte for
  byte.

### PC-8. The capability

- `FloorPlanEditorCapabilities` gains `recolor` (default `true`): `full`
  and **`tablesOnly`** on, `readOnly` off. A refused `recolor` shows the
  picker read-only (the current colour marked, no tap acts), as a value
  field (F-8).
- `tablesOnly` hosts see the picker after upgrading: the CHANGELOG and
  the guide say so. (In `tablesOnly` no room can be selected, so the
  picker there only ever holds tables.)

### PC-9. The panel's Colour picker

- A **Colour** row after the sections, on the Layer picker's pattern
  (F-8): shown while the selection holds **at least one table or room**
  and no tool's settings show; other objects in the selection are
  ignored.
- Nine swatches: **None**, then the eight hues in palette order. The
  swatch of the colour every selected table and room shares is marked;
  a mixed selection marks none. A table or room whose stored name is
  unknown counts as its own colour, shared with nothing. A swatch shows
  the hue as the canvas would (PC-1's display colour).
- A tap sets that colour on every selected table and room as **one undo
  step**, labelled "Colour": one `CompoundCommand` of
  `SetComponentCommand<RoomParams>` (each room's params,
  `copyWith(color: …)`) and `SetComponentCommand<FloorPlanTableColor>`
  (each table's component, or null for None). Objects already at that
  colour are skipped; nothing left is no edit.
- **Read-only** when `recolor` is refused, or when the document's
  permissions refuse what the selection needs: `components` for a
  table, `components` and `RoomType.editCapability` for a room (F-8).
- An object on a hidden or locked layer is never selected (F-12), so the
  picker never reaches one.
- Each swatch is a button with a tooltip and a semantics label carrying
  the colour's name; None's says "None".
- The swatches build their `Color` from `rgb` in one function, the
  single allow-listed entry the colour-literal invariant (F-16) gains;
  no `Color(0x…` literal is added elsewhere.

### PC-10. The strings

- `FloorPlanStrings` gains the row's title, None, and the eight colour
  names, in `strings_en`, `strings_de` and `strings_tr`:

| | en | de | tr |
|---|---|---|---|
| title | Colour | Farbe | Renk |
| none | None | Keine | Yok |
| red | Red | Rot | Kırmızı |
| orange | Orange | Orange | Turuncu |
| yellow | Yellow | Gelb | Sarı |
| green | Green | Grün | Yeşil |
| teal | Teal | Petrol | Turkuaz |
| blue | Blue | Blau | Mavi |
| purple | Purple | Lila | Mor |
| grey | Grey | Grau | Gri |

- A native read of the German and Turkish names joins the human's owed
  list. A host's language subclass keeps compiling (the new members
  carry the built-in's values).

### PC-11. The host API (tables)

- `FloorPlanTableDetail.color` (`FloorPlanColor?`): the table's colour,
  null for none and for a payload this release cannot read. Joins `==`,
  `hashCode` and `toString`; `designChanges` therefore reports a colour
  change as a `FloorPlanTableChanged` whose `before.color` and
  `after.color` differ.
- `bool setTableColor(String number, FloorPlanColor? color)` and
  `bool setTablesColor(Map<String, FloorPlanColor?> byNumber)`: exactly
  `setTableData`'s and `setTablesData`'s rules (F-3) — design mode only
  (`StateError` in the selection mode); the number trimmed; false and no
  change for a number that names no table or two, or two keys that trim
  to one; all or nothing; entries already equal skipped; true with no
  edit when nothing is left; one `CompoundCommand` labelled
  **"Table colour"**; `dirty`, `canUndo` and `revision` as for any edit.
  A table on a hidden or locked layer takes a colour (a section is not a
  drawing edit). Null removes the component; it also replaces a kept or
  unknown payload — an edit that makes the plan `dirty` but reports
  **no** `FloorPlanTableChanged` (`color` reads null before and after),
  as clearing a kept data payload does.
- The two setters share one private path with the table-data setters
  (resolve the numbers, refuse, skip equal, execute), so their rules
  cannot drift.
- **No room API**: rooms are not host objects (O-2 of the host spec).

### PC-12. The guide and the CHANGELOG

- **Slice 1:** the CHANGELOG's Unreleased gains the schema bump (a 0.5.1
  build refuses a 0.6.0 plan), `FloorPlanColor`, the room's colour,
  `recolor` and the `tablesOnly` picker; the guide's §11 says schema 10
  and its capabilities section names `recolor`.
- **Slice 2:** the guide gains a "Colours on the plan" section: the
  palette, `color`, the two setters, a status covering a colour, the
  dark canvas, the export and the headless opacity,
  `tableColorOpacity`; the CHANGELOG gains the tables' part. Every code
  block goes in the host probe (`check_guide`).

## Slices

- **Slice 1, the palette and rooms:** PC-1, PC-2, PC-3, **PC-3a**,
  PC-8, PC-9 (rooms only), PC-10, PC-12's Slice 1 part. The schema bump
  and the engine stamp sit in this slice, apart from the tables'
  drawing.
- **Slice 2, tables:** PC-4, PC-5, PC-6, PC-7, PC-9 (tables), PC-11,
  PC-12's Slice 2 part. It depends on Slice 1 (the palette, the schema,
  the picker); Slice 1 depends on nothing in it.

Each slice is one plan, executed task by task with a fresh implementer
and an independent reviewer per task; release 0.6.0 follows Slice 2.

## Testing

**Fixtures.** Every drawing test places a table **turned and mirrored**,
away from the origin, whose top is **off-centre in its definition and
asymmetric** (a circle or a centred rectangle is invariant under a turn
and a mirror about its centre, so only the translation would be
tested), beside a circular top off-centre too; rooms sit in a group that
is turned and scaled. Status, group status and colour are combined on
different tables of one plan; one coloured table stands in a coloured
room; one coloured table is unnumbered; one is on a locked layer.

**Named mutants**, each killed by a test that lands with it:

| # | Mutant | The killing test |
|---|---|---|
| M-C1 | an unknown colour name throws in `fromJson` (room or table) | open, then save byte-exact |
| M-C2 | a kept table payload is saved canonicalised | save byte-exact |
| M-C3 | a recolour leaves an existing room's tint as it was | recolour an **existing** room, then undo, then redo: the tint's records each time |
| M-C4 | `RoomParams.toJson` omits a null `color` | the encoding's keys |
| M-C5 | the colour is above the status in the chain | a pixel of a statused, coloured table |
| M-C6 | a table on a hidden layer is filled | a pixel |
| M-C7 | the export underlay ignores `placement` (or its linear part) | the PDF's vertices through the content reader (`pdf_content_test.dart`); PNG pixels; the asymmetric off-centre top |
| M-C8 | the opacity applied twice, not at all, or hard-coded 0.35 | a non-default `tableColorOpacity` beside a different `statusFillOpacity`, on the canvas and in the export |
| M-C9 | `setTablesColor` applies some entries before refusing | no edit, `canUndo` false |
| M-C10 | the codec still writes 9 | the encoding |
| M-C11 | a deleted table's colour stays in the store | delete; undo restores it |
| M-C12 | the picker sets the first selected object only | a selection of two tables and a room |
| M-C13 | a refused `recolor` still applies a tap | the read-only picker |
| M-C14 | `FloorPlanTableDetail.==` ignores `color` | `designChanges` |
| M-C15 | the fill rebuild misses a colour change | the fill after undo |
| M-C16 | an uncoloured room's tint changes | a v9 plan opened, regenerated, byte-exact |
| M-C17 | the stamp unguarded (PC-3a) | an unrelated edit (a wall moved elsewhere) plans no style command; its `ParametricEdit` capabilities |
| M-C18 | the survey still skipped with no statuses | the design mode's fill |
| M-C19 | an unnumbered coloured table not filled | a pixel |
| M-C20 | a locked layer's coloured table not filled | a pixel |
| M-C21 | an unknown name drawn as some hue | a pixel (no fill) |
| M-C22 | `RoomParams.==` or `copyWith` drops `color` | rename a coloured room: the colour stays |
| M-C23 | the export ignores the view's opacity | the view's Export at a non-default theme |
| M-C24 | the design mount's repaint misses the document | set a colour by the API with nothing else moving: the next frame fills |
| M-C25 | the dark canvas's table fill not toned | a dark paper: the table's fill pixel equals the room tint's tone of the same hue |

**Differential.** One plan, drawn on the design canvas (white paper, the
light theme) and exported as a PNG: each coloured table's top, sampled
**off its number label** (the label is centred, `table_label.dart:66`),
composites to the same colour over white, within one unit per channel.
A dark-canvas case compares the table's fill and the room's tint of one
hue (M-C25).

**Gates.** Every package through `tool/ci/expect_failures.dart`; the
planner with `--enable-vmservice`; `tool/ci/check_guide.dart`;
`tool/ci/host_probe.sh`; `tool/ci/old_host_probe.sh` for `v0.3.0`,
`v0.4.0` and **`v0.5.1`** (a released host still compiles: `recolor`,
`color` and the export's `underlay` are added with defaults).

## Out of scope, recorded

- **PC-O1.** Named sections with a legend; a colour changed once for
  many tables.
- **PC-O2.** A table taking its room's colour.
- **PC-O3.** Free RGB colours; a themed palette.
- **PC-O4.** A room's colour from the host (rooms are not host objects).
- **PC-O5.** A colour on other objects (walls, boxes, symbols that do
  not seat).

## Risks

- **The schema bump** refuses 0.6.0 plans in 0.5.1 builds; a host that
  ships two builds side by side must upgrade both. Stated in the
  CHANGELOG and §11.
- **The engine's regeneration contract changes** (PC-3a): two more
  columns are the planner's. Guarded by exact `==`, so no existing
  object plans a command; M-C16 and M-C17 hold it.
- **The design canvas gains a painter** on the frame path: the allocation
  bar is extended (PC-5), not assumed.
- **`tablesOnly` changes** for existing hosts (a new picker): stated.

## Review

Revision 1 was reviewed by an independent reviewer (read-only, at
`abc06cb`): **Approve with fixes**, no redesign of Approach A. Each
finding was checked against the code before it was folded in.

| Finding | Severity | Folded in |
|---|---|---|
| V-1 a recolour never reaches an existing room's tint: attributes are written on add only | Blocker | F-13, PC-3a (the engine stamp), M-C3 rewritten, M-C17, Risks |
| V-2 the dark canvas re-tones a room's `TrueColor` but not a painter's fill | Major | F-14, PC-1 (document and display colour), PC-5, M-C25 |
| V-3 the survey is skipped with no statuses; unnumbered tables are skipped; the design mount's repaint | Major | F-4, PC-5, M-C18, M-C19, M-C24 |
| V-4 the headless export and print have no theme | Major | F-7, PC-7 (the opacity's source), M-C23 |
| V-5 the residual's composition; `fillPolygon`'s closing point and triangles; `ResolvedStyle` | Major | F-7, PC-7 |
| V-6 `copyWith(color: null)` cannot clear | Minor | PC-3 |
| V-7 the document's permissions | Minor | F-8, PC-9 |
| V-8 the colour-literal invariant | Minor | F-16, PC-9 |
| V-9 the tests that pin 9 and three keys | Minor | F-15, PC-2 |
| V-10 a cleared kept payload reports nothing; an exhaustive `switch` | Minor | PC-11, PC-1 |
| V-11 Change size keeps the instance | Minor | F-17, PC-4 |
| V-12 a table's fill composites under a room's tint | Info | PC-5, the fixtures |
| Testing: symmetric tops, PDF read by vertices, a hard-coded 0.35, the label at the centre, eight missing mutants | — | Fixtures, M-C7, M-C8, the differential, M-C17 to M-C25 |
| Scope: Slice 1 ships public API but no CHANGELOG | — | PC-12 split by slice |

F-1's wording (an older version is migrated, not refused) and the line
ranges of F-2, F-3, F-6 and F-9 were corrected.

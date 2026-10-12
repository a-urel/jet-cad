# Plan colours: a colour per table and per room — design

**Date:** 2026-10-12. **Status:** revision 1, for the human's review.
**Asked for by the human, 2026-10-12:** "O-6 ile devam et" — the host
embedding API spec's out-of-scope item O-6, "a per-table colour on the plan
itself (status is not plan data)" — and, mid-brainstorm, "color per room
should also be considered".

**Branch:** `spec/plan-colors`, from `main` at `1414680` (release 0.5.1,
tag `v0.5.1` → `3f8f7ad`). **Size:** M, two slices. **Touched:**
`jet_cad_2d` (the schema version), `jet_cad_2d_flutter` (the page export's
underlay), `jet_cad_floor_plan` (the palette, the room, the table colour
component, the fill painter, the panel, the host API, the strings), the
host guide, the CHANGELOG. **Release:** 0.6.0, after Slice 2.

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
   **independent** (a table does not take its room's colour).
6. **Approach A** for tables: a painter under the drafting (the status
   painter's chain), with an export underlay; not a stamped tint entity
   (it would draw over the table's lines, by ascending handle, and a
   status could not cover it) and not a `ByBlock` fill in the symbol
   definitions (plans already saved carry their definitions without one).
7. Sections 1 to 4 of the design below approved as presented, with: the
   room's coloured tint at 20 %; the table's fill at 0.35; the export at
   the exporting view's theme; the colour **on** in `tablesOnly`; a
   refused capability shows the picker read-only; release 0.6.0.

## Facts (at `1414680`)

- **F-1. Schema.** `kSchemaVersion = 9`
  (`jet_cad_2d/lib/src/codec/schema_version.dart:48`); a reader refuses
  any other version with `SchemaVersionError` (`json_codec.dart:107`).
  Every bump so far exists for the reader (the file's own doc comment, 6
  to 9): 9 was bumped for `jetcad.table_data`, which a v8 build would
  keep as preserve-unknown data and orphan on a delete.
- **F-2. The room.** `RoomParams` (`floor_planner.room`,
  `jet_cad_floor_plan/lib/src/parametric/room.dart:33-98`) stores
  `seed`, `name`, `label`, all three always written (08 D6's one-shape
  rule, `toJson` `:51`); `fromJson` (`:61`) reads the three keys and
  ignores any other. `RoomType.generate` makes the tint first — a region,
  `kRoomTintColor` (`IndexedColor(7)`, `:105`) on both records,
  `kRoomTintTransparency` 229 (`:109`), its boundary invisible
  (`:300-310`) — then the name, then the area; the children keep their
  handles for the room's life (D18). The tint is an entity: both modes,
  the export and the print draw it as the document does.
- **F-3. Table data, the precedent.** `FloorPlanTableData`
  (`jetcad.table_data`, `tables/table_data_component.dart`) is a
  component on the table's **instance** node; `fromJson` never throws: a
  payload of another shape is kept verbatim, read as empty, written back
  as read, and reported as `table.invalid_data`
  (`table_index.dart:168, :196`). It is registered in the catalogue
  (`parametric/catalog.dart:58`). A delete drops it and an undo restores
  it through `RemoveNodeCommand` (node-components D-1, 0.5.0). The
  controller's `setTableData` / `setTablesData`
  (`host/floor_plan_controller.dart:1559-1597`) refuse the selection
  mode (`StateError`), refuse an unknown or shared number (false), skip
  equal entries, and execute one `CompoundCommand` labelled
  "Table data".
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
  rebuild.
- **F-5. The canvases.** `PlannerView` has an `underlay` slot between the
  page chrome and `DraftCanvas` (`planner_view.dart:419`). The selection
  mode fills it with the group frames and the status layer
  (`host/service_view.dart:556-575`); the design mode leaves it empty.
- **F-6. The service copy** is the design re-decoded
  (`_copyOf`, `floor_plan_controller.dart:1302-1305`): it carries every
  component, read only.
- **F-7. Export.** `exportPagePdf` / `exportPagePng`
  (`jet_cad_2d_flutter/lib/src/export/page_export.dart:34, :104`) draw
  the document through a `DrawSink` (`PdfDrawSink`, or a
  `CanvasDrawSink` on an opaque white ground) with `DraftPainter`, the
  resolver's foreground black, `omitOwners` (the separators) skipped.
  `DrawSink` has `fillPolygon`, `fillCircle` and
  `beginResidual(Transform2)` / `endResidual`
  (`pdf_draw_sink.dart:126, :256, :274`). The floor plan's
  `exportBytes` (`export/export_bytes.dart`) calls them; nothing but the
  document is drawn.
- **F-8. The panel.** `SelectionPanel`'s sections each edit one object;
  the Layer picker (`selection_panel.dart:1400`) shows for any non-empty
  selection and applies to all of it. A refused capability hides a
  button or menu and shows a value field read-only (C-5, S-10).
- **F-9. Capabilities.** `FloorPlanEditorCapabilities`
  (`host/editor_capabilities.dart:139-236`): `full`, `tablesOnly`
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

## Design

### PC-1. The palette

```dart
/// A plan colour (plan colours spec PC-1): one of eight fixed hues.
enum FloorPlanColor {
  red(0xE53935), orange(0xFB8C00), yellow(0xFDD835), green(0x43A047),
  teal(0x00897B), blue(0x1E88E5), purple(0x8E24AA), grey(0x757575);

  const FloorPlanColor(this.rgb);

  /// The hue, `0xRRGGBB`: the same on every paper, in the export and in
  /// the print.
  final int rgb;
}
```

- Exported from the host barrel. The file stores the colour by its
  **name** (`"teal"`), never by its index: reordering or extending the
  palette in a later release breaks no file.
- A name this release does not know (a later release's hue) is **kept
  as read**, draws as no colour, and is saved back unchanged.
- The hue is not themed: a room bakes it into its tint entity (PC-3),
  so a table's fill must use the same value.

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
  (the human's macOS re-baseline is still owed).

### PC-3. The room's colour

- `RoomParams` gains `final String? color`: a palette name, or null for
  no colour. `toJson` writes **four** keys, always, `color` last: `null`
  when none (the one-shape rule). `fromJson` reads a missing key as null
  (a v9 room) and a string as itself, **known or not**; another type
  throws, as a wrong type does for the other keys today. `copyWith`,
  `==`, `hashCode` and `toString` carry it.
- `RoomParams.colorValue` (`FloorPlanColor?`): the palette entry of that
  name, or null — for no colour and for a name this release does not
  know.
- `RoomType.generate`: with no `colorValue`, the tint is today's,
  unchanged (`kRoomTintColor`, `kRoomTintTransparency`), byte for byte.
  With one, both tint records carry `TrueColor(colorValue.rgb)` and
  `kRoomColorTransparency` **204** (alpha 51, 20 %). The step-3 outline
  (an invisible polyline) takes the same colour. The children's order
  and handles do not change (D18).
- A colour change is a `SetComponentCommand<RoomParams>`; the parametric
  system regenerates the tint in the same undo step, as for a rename.

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
- Registered in the catalogue beside `FloorPlanTableData`. A delete
  drops it and an undo restores it (`RemoveNodeCommand`, F-3); a
  renumbering, a move, a turn and a mirror keep it.

### PC-5. The fill painter

- `TableStatusPainter` gains one rung at the bottom of its chain: each
  visible table's fill is its group's status, else its own status, else
  **its colour** (PC-4's `colorValue`). A status covers a colour
  (decision 4). A colour carries no caption.
- A colour's fill is `rgb` at alpha `round(255 × o)`, `o` the resolved
  theme's `tableColorOpacity` (PC-6), applied once at rebuild.
- The colours are read from the painted document's components when the
  fills rebuild. The plan's state is already in the rebuild key (F-4),
  so a colour set, undone or redone rebuilds; the frame path is
  unchanged: an indexed loop over prebuilt objects.
- **Visibility:** as a status's — every live table on a visible layer;
  a locked layer's tables are filled.
- **Design mode:** the shell mounts the same painter in `PlannerView`'s
  `underlay` (F-5) with no statuses and no groups: only the colours
  draw, under the drafting and under the selection overlay.
- **Selection mode:** unchanged mount; the service copy carries the
  colours (F-6).
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
  and before the document, through the same `DrawSink` and the same
  page camera:

```dart
/// A fill under the drawing (plan colours spec PC-7): a closed shape in
/// its own space, placed in world by [placement], in [argb].
@immutable
sealed class PageUnderlayFill {
  Transform2 get placement;
  int get argb;
}
final class PageUnderlayPolygon extends PageUnderlayFill { /* Float64List xy */ }
final class PageUnderlayCircle extends PageUnderlayFill { /* cx, cy, r */ }
```

- Each fill is drawn with `placement` as a residual (`beginResidual` /
  `endResidual`) around `fillPolygon` / `fillCircle`, so a turned or
  mirrored circle is a circle (or an ellipse) in the PDF, never a
  tessellated polygon.
- The floor plan's `exportBytes` builds the underlay from the document:
  every visible coloured table's top in its definition's space, its
  instance's **world** transform, the colour at the exporting view's
  resolved `tableColorOpacity`. No status is exported (spec 14c D13
  stands). Rooms need nothing: their tint is an entity.
- An empty underlay draws exactly what the export draws today, byte for
  byte.

### PC-8. The capability

- `FloorPlanEditorCapabilities` gains `recolor` (default `true`): `full`
  and **`tablesOnly`** on, `readOnly` off. A refused `recolor` shows the
  picker read-only (the current colour marked, no tap acts), as a value
  field (F-8).
- `tablesOnly` hosts see the picker after upgrading: the CHANGELOG and
  the guide say so.

### PC-9. The panel's Colour picker

- A **Colour** row after the sections, on the Layer picker's pattern
  (F-8): shown while the selection holds **at least one table or room**
  and no tool's settings show; other objects in the selection are
  ignored.
- Nine swatches: **None**, then the eight hues in palette order. The
  swatch of the colour every selected table and room shares is marked;
  a mixed selection marks none. A table or room whose stored name is
  unknown counts as its own colour, shared with nothing.
- A tap sets that colour on every selected table and room as **one undo
  step**, labelled "Colour": one `CompoundCommand` of
  `SetComponentCommand<RoomParams>` (each room's params with the new
  `color`) and `SetComponentCommand<FloorPlanTableColor>` (each table's
  component, or null for None). Objects already at that colour are
  skipped; nothing left is no edit.
- An object on a hidden or locked layer is never selected (F-12), so the
  picker never reaches one.
- Each swatch is a button with a tooltip and a semantics label carrying
  the colour's name; None's says "None".

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
  unknown payload.
- The two setters share one private path with the table-data setters
  (resolve the numbers, refuse, skip equal, execute), so their rules
  cannot drift.
- **No room API**: rooms are not host objects (O-2 of the host spec).

### PC-12. The guide and the CHANGELOG

- The host guide gains a "Colours on the plan" section: the palette,
  `color`, the two setters, a status covering a colour, the export,
  `recolor` and `tablesOnly`'s picker, `tableColorOpacity`. §11 says
  schema 10. Every code block goes in the host probe (`check_guide`).
- The CHANGELOG's Unreleased lists the feature, the schema bump (a 0.5.1
  build refuses a 0.6.0 plan) and the `tablesOnly` picker.

## Slices

- **Slice 1, the palette and rooms:** PC-1, PC-2, PC-3, PC-8, PC-9
  (rooms only), PC-10. The schema bump goes first, alone in the smaller
  slice, so its fingerprint fallout is not mixed with drawing faults.
- **Slice 2, tables:** PC-4, PC-5, PC-6, PC-7, PC-9 (tables), PC-11,
  PC-12.

Each slice is one plan, executed task by task with a fresh implementer
and an independent reviewer per task; release 0.6.0 follows Slice 2.

## Testing

**Fixtures.** Every drawing test places a table **turned and mirrored**,
away from the origin, with a **circular** top beside a rectangular one;
rooms sit in a group that is turned and scaled. Status, group status and
colour are combined on different tables of one plan.

**Named mutants**, each killed by a test that lands with it:

| # | Mutant | The killing test |
|---|---|---|
| M-C1 | an unknown colour name throws in `fromJson` (room or table) | open, then save byte-exact |
| M-C2 | a kept table payload is saved canonicalised | save byte-exact |
| M-C3 | a coloured room's tint stays ACI 7 | the tint's records |
| M-C4 | `RoomParams.toJson` omits a null `color` | the encoding's keys |
| M-C5 | the colour is above the status in the chain | a pixel of a statused, coloured table |
| M-C6 | a table on a hidden layer is filled | a pixel |
| M-C7 | the export underlay ignores `placement` | PDF and PNG pixels of the turned, mirrored circular table |
| M-C8 | the opacity applied twice, or not at all | the composited pixel |
| M-C9 | `setTablesColor` applies some entries before refusing | no edit, `canUndo` false |
| M-C10 | the codec still writes 9 | the encoding |
| M-C11 | a deleted table's colour stays in the store | delete; undo restores it |
| M-C12 | the picker sets the first selected object only | a selection of two tables and a room |
| M-C13 | a refused `recolor` still applies a tap | the read-only picker |
| M-C14 | `FloorPlanTableDetail.==` ignores `color` | `designChanges` |
| M-C15 | the fill rebuild misses a colour change | the fill after undo |
| M-C16 | an uncoloured room's tint changes | a v9 plan opened, regenerated, byte-exact |

**Differential.** One plan, drawn on the design canvas and exported as a
PNG: each coloured table's top centre composites to the same colour over
white, within one unit per channel.

**Gates.** Every package through `tool/ci/expect_failures.dart`; the
planner with `--enable-vmservice`; `tool/ci/check_guide.dart`;
`tool/ci/host_probe.sh`; `tool/ci/old_host_probe.sh` for `v0.3.0`,
`v0.4.0` and **`v0.5.1`** (a released host still compiles: `recolor`
and `color` are added with defaults).

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
- **The design canvas gains a painter** on the frame path: the allocation
  bar is extended (PC-5), not assumed.
- **`tablesOnly` changes** for existing hosts (a new picker): stated.
